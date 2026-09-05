" rg.vim — project-wide (global) search backed by ripgrep.
"
" This is the "ag-style" global search of myfinder. Every typed query re-runs
" rg (debounced) over the search root and streams JSON results into the list
" asynchronously.
"
" Behavior / options (all optional):
"   g:myfinder_rg_extra_args   extra rg flags appended after --json.
"                             Default: [] (rg defaults: case-sensitive,
"                             gitignore-aware, hidden files skipped)
"                             e.g. ['-S']                  smart case like ag
"                             e.g. ['-S', '--hidden', '-g', '!*.min.js']
"   g:myfinder_rg_debounce_ms keystroke debounce before (re)starting rg.
"                             Default: 120. 0 disables debounce.
"   g:myfinder_rg_max_results max items kept per search. Default: 500.
"                             0 means unlimited.
"   g:myfinder_rg_search_root where to search:
"                             ''   -> current working directory (default)
"                             'git'-> git repository root of the current file
"                                     (falls back to cwd outside a repo)
"                             else -> treated as a directory path
"   g:myfinder_rg_literal_fallback
"                             when the typed pattern is an invalid regex,
"                             automatically retry it as a literal string.
"                             Default: 1.

function! myfinder#finders#rg#start(query) abort
  let l:start_time = reltime()
  if !executable('rg')
    call myfinder#utils#echo('ripgrep (rg) is not installed', 'error')
    return
  endif

  let l:ctx = myfinder#core#start([], {
        \ 'on_change': function('s:OnInputChange'),
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ }, {
        \ 'name': 'Rg ' . a:query,
        \ 'name_color': {'guibg': '#e06c75', 'ctermbg': 1},
        \ 'start_time': l:start_time,
        \ 'display': ['p','text'],
        \ 'match_item': 'text',
        \ 'columns_hl': ['Number', 'Identifier'],
        \ 'syntax': [
        \   {'match': '^[^:]\+', 'link': 'String'},
        \   {'match': ':\d\+:', 'link': 'Number'},
        \ ],
        \ 'dynamic_search': 1,
        \ })

  " --- search lifecycle state -----------------------------------------
  let l:ctx.rg_job_id = -1            " nvim job id of the current job
  let l:ctx.rg_job = 0                " vim8 job of the current job (0 = none)
  let l:ctx.rg_has_job = 0            " a vim8 job is currently running
  let l:ctx.rg_seq = 0                " generation counter, guards stale callbacks
  let l:ctx.rg_pending = 0            " an update timer is already scheduled
  let l:ctx.rg_timer = -1             " streaming update timer
  let l:ctx.rg_restart_timer = -1     " input debounce timer
  let l:ctx.rg_partial = ''           " nvim partial line accumulator
  let l:ctx.rg_stderr = ''            " accumulated stderr (errors)
  let l:ctx.rg_truncated = 0          " result cap reached
  let l:ctx.rg_literal = 0            " current run uses -F
  let l:ctx.rg_root = s:ResolveRoot()

  " Hook cleanup into quit so running jobs/timers never outlive the popup.
  let l:ctx.rg_base_quit = l:ctx.quit
  let l:ctx.quit = function('s:RgQuit')

  call s:StartRg(l:ctx, a:query)
endfunction

" =====================================================================
" Configuration helpers
" =====================================================================

function! s:GetExtraArgs() abort
  return get(g:, 'myfinder_rg_extra_args', [])
endfunction

function! s:GetDebounce() abort
  return get(g:, 'myfinder_rg_debounce_ms', 120)
endfunction

function! s:GetMaxResults() abort
  return get(g:, 'myfinder_rg_max_results', 500)
endfunction

function! s:GetLiteralFallback() abort
  return get(g:, 'myfinder_rg_literal_fallback', 1)
endfunction

" =====================================================================
" Search scope
" =====================================================================

function! s:ResolveRoot() abort
  let l:mode = get(g:, 'myfinder_rg_search_root', '')
  if l:mode ==# 'git'
    " Root of the git repository containing the current file.
    let l:dir = expand('%:p:h')
    if empty(l:dir)
      let l:dir = getcwd()
    endif
    let l:out = systemlist('git -C ' . shellescape(l:dir) . ' rev-parse --show-toplevel')
    if !v:shell_error && !empty(l:out)
      return l:out[0]
    endif
    return getcwd()
  elseif empty(l:mode)
    return getcwd()
  else
    " Treat non-empty values other than 'git' as an explicit directory.
    return l:mode
  endif
endfunction

" Convert an absolute root directory into the path argument passed to rg,
" expressed relative to the current working directory (keeps every result
" openable/previewable from the current buffer's cwd).
function! s:RootArg(root) abort
  if empty(a:root) || a:root ==# getcwd()
    return '.'
  endif
  return fnamemodify(a:root, ':.')
endfunction

" =====================================================================
" Starting / stopping a search
" =====================================================================

function! s:RgQuit() dict
  let self.rg_closed = 1
  call s:StopAll(self)
  call call(self.rg_base_quit, [], self)
endfunction

function! s:StopAll(ctx) abort
  " Invalidate any in-flight callback before tearing down.
  let a:ctx.rg_seq += 1
  if a:ctx.rg_timer != -1
    call timer_stop(a:ctx.rg_timer)
    let a:ctx.rg_timer = -1
  endif
  if a:ctx.rg_restart_timer != -1
    call timer_stop(a:ctx.rg_restart_timer)
    let a:ctx.rg_restart_timer = -1
  endif
  call s:StopJob(a:ctx)
endfunction

function! s:StopJob(ctx) abort
  if a:ctx.rg_job_id > 0
    silent! call jobstop(a:ctx.rg_job_id)
  endif
  if get(a:ctx, 'rg_has_job', 0)
    silent! call job_stop(a:ctx.rg_job)
  endif
  let a:ctx.rg_job_id = -1
  let a:ctx.rg_job = 0
  let a:ctx.rg_has_job = 0
endfunction

function! s:StartRg(ctx, query, ...) abort
  if !executable('rg')
    return
  endif

  " A search session cannot be torn down: do not resurrect dead contexts.
  if !has_key(a:ctx, 'rg_seq') || get(a:ctx, 'rg_closed', 0)
    return
  endif

  let a:ctx.rg_query = a:query
  let l:literal = get(a:000, 0, 0)

  " Stop any previous run and invalidate its callbacks.
  call s:StopAll(a:ctx)
  let a:ctx.rg_seq += 1
  let l:seq = a:ctx.rg_seq

  " Reset per-search state.
  let a:ctx.items = []
  let a:ctx.matches = []
  let a:ctx.rg_pending = 0
  let a:ctx.rg_partial = ''
  let a:ctx.rg_stderr = ''
  let a:ctx.rg_truncated = 0
  let a:ctx.rg_literal = l:literal

  " Empty pattern: don't dump every line of the tree (that is what the
  " RgAllLine entry point, pattern '^', is for). Just clear the list.
  if empty(a:query)
    call a:ctx.update_res()
    return
  endif

  " Re-render immediately so the stale results of the previous query are
  " replaced while rg runs.
  call a:ctx.update_res()

  let l:cmd = ['rg', '--json']
  call extend(l:cmd, s:GetExtraArgs())
  if l:literal
    " Retry of an invalid regex pattern: treat it as a literal string.
    call add(l:cmd, '-F')
  endif
  call add(l:cmd, '-e')
  call add(l:cmd, a:query)
  call add(l:cmd, s:RootArg(a:ctx.rg_root))

  if has('nvim')
    let l:job_id = jobstart(l:cmd, {
          \ 'on_stdout': function('s:OnEvent', [a:ctx, l:seq]),
          \ 'on_stderr': function('s:OnEvent', [a:ctx, l:seq]),
          \ 'on_exit':   function('s:OnEvent', [a:ctx, l:seq]),
          \ 'stdout_buffered': 0,
          \ 'stderr_buffered': 0,
          \ })
    if l:job_id <= 0
      call myfinder#utils#echo('Failed to start rg', 'error')
      return
    endif
    let a:ctx.rg_job_id = l:job_id
  else
    let l:job = job_start(l:cmd, {
          \ 'out_cb': function('s:VimOutHandler', [a:ctx, l:seq]),
          \ 'err_cb': function('s:VimErrHandler', [a:ctx, l:seq]),
          \ 'exit_cb': function('s:VimExitHandler', [a:ctx, l:seq]),
          \ 'mode': 'nl',
          \ })
    if job_status(l:job) ==# 'fail'
      call myfinder#utils#echo('Failed to start rg', 'error')
      return
    endif
    let a:ctx.rg_job = l:job
    let a:ctx.rg_has_job = 1
  endif
endfunction

" =====================================================================
" Input handling (debounced restarts)
" =====================================================================

function! s:OnInputChange(ctx, query) abort
  " Drop the previous query's results right away and stop its job, so the
  " list never shows stale matches under the new pattern. The actual
  " restart is debounced below.
  let a:ctx.items = []
  let a:ctx.matches = []
  call s:StopAll(a:ctx)

  if a:ctx.rg_restart_timer != -1
    call timer_stop(a:ctx.rg_restart_timer)
    let a:ctx.rg_restart_timer = -1
  endif

  let l:debounce = s:GetDebounce()
  if l:debounce <= 0
    call s:StartRg(a:ctx, a:query)
    return
  endif
  let a:ctx.rg_restart_timer = timer_start(l:debounce,
        \ function('s:DebouncedRestart', [a:ctx, a:query]))
endfunction

function! s:DebouncedRestart(ctx, query, ...) abort
  let a:ctx.rg_restart_timer = -1
  call s:StartRg(a:ctx, a:query)
endfunction

" =====================================================================
" Job output
" =====================================================================

" nvim unified handler. a:data is a list of lines for stdout/stderr and the
" exit code for the exit event.
function! s:OnEvent(ctx, seq, job_id, data, event) abort
  " Drop callbacks of a stale generation or of an already-stopped job.
  if a:seq != a:ctx.rg_seq || a:job_id != a:ctx.rg_job_id
    return
  endif

  if a:event == 'stdout'
    call s:ProcessLines(a:ctx, a:seq, a:data)
  elseif a:event == 'stderr'
    call s:CollectStderr(a:ctx, a:data)
  elseif a:event == 'exit'
    call s:FinishSearch(a:ctx, a:seq, a:data)
  endif
endfunction

function! s:VimOutHandler(ctx, seq, channel, msg) abort
  if a:seq != a:ctx.rg_seq
    return
  endif
  call s:ProcessLines(a:ctx, a:seq, [a:msg])
endfunction

function! s:VimErrHandler(ctx, seq, channel, msg) abort
  if a:seq != a:ctx.rg_seq
    return
  endif
  call s:CollectStderr(a:ctx, [a:msg])
endfunction

function! s:VimExitHandler(ctx, seq, job, status) abort
  if a:seq != a:ctx.rg_seq
    return
  endif
  call s:FinishSearch(a:ctx, a:seq, a:status)
endfunction

function! s:CollectStderr(ctx, data) abort
  if empty(a:ctx.rg_stderr)
    let a:ctx.rg_stderr = join(a:data, "\n")
  else
    let a:ctx.rg_stderr .= "\n" . join(a:data, "\n")
  endif
  " Never let an error flood the context.
  if strlen(a:ctx.rg_stderr) > 4096
    let a:ctx.rg_stderr = strpart(a:ctx.rg_stderr, 0, 4096)
  endif
endfunction

" =====================================================================
" Parsing rg --json output
" =====================================================================

function! s:ProcessLines(ctx, seq, lines) abort
  if a:seq != a:ctx.rg_seq | return | endif
  if empty(a:lines) | return | endif

  let l:lines = copy(a:lines)

  if has('nvim')
    " nvim delivers output in chunks split on '\n'; a chunk ending exactly
    " on a line boundary carries a trailing '' element, otherwise the last
    " element is a partial line that continues in the next chunk.
    if !empty(a:ctx.rg_partial)
      let l:lines[0] = a:ctx.rg_partial . l:lines[0]
      let a:ctx.rg_partial = ''
    endif
    let a:ctx.rg_partial = l:lines[-1]
    let l:lines = l:lines[:-2]
  endif

  call s:DecodeLines(a:ctx, a:seq, l:lines)
endfunction

function! s:DecodeLines(ctx, seq, lines) abort
  let l:max = s:GetMaxResults()

  for l:line in a:lines
    if a:seq != a:ctx.rg_seq | return | endif
    if empty(l:line) | continue | endif

    let l:decoded = v:null
    try
      let l:decoded = json_decode(l:line)
    catch
      continue
    endtry
    if type(l:decoded) != v:t_dict || get(l:decoded, 'type', '') !=# 'match'
      continue
    endif

    let l:item = s:MatchToItem(l:decoded.data)
    call add(a:ctx.items, l:item)

    if l:max > 0 && len(a:ctx.items) >= l:max
      let a:ctx.rg_truncated = 1
      call add(a:ctx.items, {
            \ 'text': printf('… result limit reached (max %d shown)', l:max),
            \ 'p': '',
            \ })
      call s:StopJob(a:ctx)
      call s:Update(a:ctx, a:seq)
      call myfinder#utils#echo(
            \ printf('Result limit (%d) reached, search stopped', l:max), 'warn')
      return
    endif
  endfor

  call s:ScheduleUpdate(a:ctx, a:seq)
endfunction

" Convert one rg JSON 'match' payload into a list item.
function! s:MatchToItem(data) abort
  let l:path = get(a:data, 'path', {})
  let l:path_text = get(l:path, 'text', '')
  " 'rg --json pattern .' prefixes paths with './'; strip it for display.
  if l:path_text =~# '^\./'
    let l:path_text = strpart(l:path_text, 2)
  endif

  let l:lnum = get(a:data, 'line_number', 0)
  let l:lines = get(a:data, 'lines', {})
  let l:raw = type(l:lines) == v:t_dict ? get(l:lines, 'text', '') : ''
  let l:raw = substitute(l:raw, '\r\?\n$', '', '')
  let l:text = trim(l:raw)

  " Byte offset of the first non-whitespace char: used to translate rg's
  " byte offsets (relative to the raw line) onto the trimmed display text.
  let l:lead = matchend(l:raw, '^\s*')
  if l:lead < 0 | let l:lead = 0 | endif

  let l:item = {
        \ 'text': l:text,
        \ 'p': l:path_text . ':' . l:lnum,
        \ 'path': l:path_text,
        \ 'lnum': l:lnum,
        \ 'col': 1,
        \ 'highlights': [],
        \ }

  let l:subs = get(a:data, 'submatches', [])
  if !empty(l:subs)
    " Jump straight to the first match column in the buffer.
    let l:first = l:subs[0]
    let l:item.col = get(l:first, 'start', 0) + 1
    if l:item.col < 1 | let l:item.col = 1 | endif

    " Highlight matched spans on the trimmed display text.
    for l:sub in l:subs
      let l:start = get(l:sub, 'start', 0)
      let l:len = get(l:sub, 'end', l:start) - l:start
      let l:dstart = l:start - l:lead + 1
      if l:len <= 0
        continue
      endif
      " Clamp to the trimmed text (trailing whitespace / newline removed).
      let l:dend = l:dstart + l:len - 1
      if l:dend > strlen(l:text)
        let l:len = strlen(l:text) - l:dstart + 1
      endif
      if l:dstart > 0 && l:len > 0
        call add(l:item.highlights, [l:dstart, l:len])
      endif
    endfor
  endif

  return l:item
endfunction

" =====================================================================
" Rendering / update throttling
" =====================================================================

function! s:ScheduleUpdate(ctx, seq) abort
  if a:seq != a:ctx.rg_seq | return | endif
  if a:ctx.rg_pending | return | endif
  let a:ctx.rg_pending = 1
  let a:ctx.rg_timer = timer_start(100, function('s:Update', [a:ctx, a:seq]))
endfunction

function! s:Update(ctx, seq, ...) abort
  if a:seq != a:ctx.rg_seq
    return
  endif
  let a:ctx.rg_pending = 0
  let a:ctx.rg_timer = -1
  if empty(a:ctx.items) && !a:ctx.rg_truncated
    return
  endif
  call a:ctx.update_res()
endfunction

" Called when the rg process has exited (or was stopped).
function! s:FinishSearch(ctx, seq, code) abort
  if a:seq != a:ctx.rg_seq
    return
  endif

  " The job has ended; no further callbacks will arrive for it.
  let a:ctx.rg_job_id = -1
  let a:ctx.rg_job = 0
  let a:ctx.rg_has_job = 0

  " Flush whatever partial JSON record may still be buffered.
  if has('nvim') && !empty(a:ctx.rg_partial)
    let l:tail = a:ctx.rg_partial
    let a:ctx.rg_partial = ''
    call s:DecodeLines(a:ctx, a:seq, [l:tail])
    if a:seq != a:ctx.rg_seq
      return
    endif
  endif

  " A pattern that is not valid regex confuses users; offer a literal retry.
  if a:code != 0 && !a:ctx.rg_truncated && !a:ctx.rg_literal
        \ && s:GetLiteralFallback()
        \ && !empty(a:ctx.rg_stderr) && a:ctx.rg_stderr =~# 'regex parse error'
    " Defer the restart one tick so it never runs inside a job callback.
    call timer_start(1, function('s:StartRg', [a:ctx, a:ctx.rg_query, 1]))
    return
  endif

  if a:code != 0 && !a:ctx.rg_truncated && empty(a:ctx.items)
        \ && !empty(a:ctx.rg_stderr)
    " Show the rg error as a (non-openable) list row.
    let l:err = substitute(a:ctx.rg_stderr, "\n", ' ', 'g')
    let l:err = trim(l:err)
    if strlen(l:err) > 90
      let l:err = strpart(l:err, 0, 90) . '…'
    endif
    call add(a:ctx.items, {'text': '! rg: ' . l:err, 'p': ''})
    call s:Update(a:ctx, a:seq)
    return
  endif

  call s:Update(a:ctx, a:seq)
endfunction
