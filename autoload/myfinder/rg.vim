function! myfinder#rg#start(query) abort
  let l:start_time = reltime()
  if !executable('rg')
    call myfinder#core#echo('ripgrep (rg) is not installed', 'error')
    return
  endif

  
  " Initial items empty, we will populate via job
  let l:items = []
  
  let l:ctx = myfinder#core#start(l:items, {
        \ 'open': function('s:Open'),
        \ 'open_with_new_tab': function('s:OpenTab'),
        \ 'open_vertically': function('s:OpenRight'),
        \ 'preview': function('s:Preview'),
        \ 'on_change': function('s:OnInputChange'),
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
  
  let l:ctx.rg_items_buffer = []
  let l:ctx.rg_timer = -1
  let l:ctx.rg_partial = ''
  
  " If query is provided, we should ideally set it as the filter in the UI,
  " but for now we just run the search. The input will appear empty initially
  " unless we modify core.vim to accept an initial filter.
  call s:StartRg(l:ctx, a:query)
endfunction

function! s:StartRg(ctx, query) abort
  " Stop existing job if any
  if has_key(a:ctx, 'job_id') && a:ctx.job_id > 0
    silent! call jobstop(a:ctx.job_id)
    let a:ctx.job_id = 0
  endif
  if has_key(a:ctx, 'job')
    " Vim 8
    silent! call job_stop(a:ctx.job)
  endif

  " Reset state
  let a:ctx.items = []
  let a:ctx.matches = []
  let a:ctx.rg_items_buffer = []
  let a:ctx.rg_partial = ''
  
  " Update UI to show empty list initially
  call a:ctx.update_res()
  
  " Use the query as pattern. Empty pattern matches everything in rg.
  let l:pattern = a:query
  
  let l:cmd = ['rg', '--json',l:pattern,'.']
  
  if has('nvim')
    let l:job_id = jobstart(l:cmd, {
          \ 'on_stdout': function('s:OnEvent', [a:ctx]),
          \ 'on_stderr': function('s:OnEvent', [a:ctx]),
          \ 'on_exit': function('s:OnEvent', [a:ctx]),
          \ 'stdout_buffered': 0,
          \ 'stderr_buffered': 0,
          \ })
    let a:ctx.job_id = l:job_id
  else
    " Vim 8
    let l:job = job_start(l:cmd, {
          \ 'out_cb': function('s:VimOutHandler', [a:ctx]),
          \ 'exit_cb': function('s:VimExitHandler', [a:ctx]),
          \ 'mode': 'nl',
          \ })
    let a:ctx.job = l:job
  endif
endfunction

function! s:OnInputChange(ctx, query) abort
  call s:StartRg(a:ctx, a:query)
endfunction


function! s:OnEvent(ctx, job_id, data, event) dict
  let l:ctx = a:ctx

  if a:event == 'stdout'
    call s:ProcessLines(l:ctx, a:data)
  elseif a:event == 'exit'
    " Process any remaining partial line
    if !empty(l:ctx.rg_partial)
      call s:ProcessLines(l:ctx, [l:ctx.rg_partial])
      let l:ctx.rg_partial = ''
    endif
    
    call s:Update(l:ctx)
  endif
endfunction

function! s:VimOutHandler(ctx, channel, msg)
  call s:ProcessLines(a:ctx, [a:msg])
endfunction

function! s:VimExitHandler(ctx, job, status)
  call s:Update(a:ctx)
endfunction

function! s:ProcessLines(ctx, lines) abort
  if empty(a:lines) | return | endif
  
  let l:lines = copy(a:lines)

  if has('nvim')
    " Handle partial lines for Neovim
    if !empty(a:ctx.rg_partial)
      let l:lines[0] = a:ctx.rg_partial . l:lines[0]
      let a:ctx.rg_partial = ''
    endif
    
    let a:ctx.rg_partial = l:lines[-1]
    let l:lines = l:lines[:-2]
  endif
  
  for l:line in l:lines
    if empty(l:line) | continue | endif
    let l:decoded = json_decode(l:line)
    if l:decoded.type == 'match'
      let l:data = l:decoded.data
      let l:path = l:data.path.text
      let l:lnum = l:data.line_number
      " Remove newline at the end of text if present
      
      let l:p = printf('%s:%d', l:path, l:lnum)
      let l:item = {
            \ 'text': trim(l:data.lines.text),
            \ 'p': l:p,
            \ 'path': l:path,
            \ 'line': l:lnum,
            \ 'col': 1,
            \ 'highlights': [],
            \ }
      
      " Handle submatches
      " if !empty(l:data.submatches)
      "   let l:item.col = l:data.submatches[0].start + 1
      "   for l:sub in l:data.submatches
      "      " rg start is 0-based, end is exclusive.
      "      " matchaddpos expects [line, col, len]
      "      " col is 1-based.
      "      call add(l:item.highlights, [l:sub.start-1, l:sub.end - l:sub.start])
      "   endfor
      " endif

      call add(a:ctx.items, l:item)
      call add(a:ctx.rg_items_buffer, l:item)
    endif
  endfor
  
  " Throttle updates
  if a:ctx.rg_timer == -1
    let a:ctx.rg_timer = timer_start(100, {-> s:Update(a:ctx)})
  endif
endfunction

function! s:Update(ctx) abort
  let a:ctx.rg_timer = -1
  if empty(a:ctx.rg_items_buffer)
    return
  endif
  
  " Clear buffer
  let a:ctx.rg_items_buffer = []
  
  " In dynamic search mode, ctx.matches IS ctx.items (controlled by us)
  " But core.vim s:CtxUpdateRes sets matches = items if dynamic_search is true.
  " So we just need to ensure ctx.items is updated (which we did in ProcessLines)
  " and call update_res().
  
  " Refresh UI
  call a:ctx.update_res()
endfunction

function! s:Open() dict
  call self.quit()
  execute 'edit ' . fnameescape(self.selected.path)
  call cursor(self.selected.line, self.selected.col)
  normal! zz
endfunction

function! s:OpenTab() dict
  call self.quit()
  execute 'tab split'
  execute 'edit ' . fnameescape(self.selected.path)
  call cursor(self.selected.line, self.selected.col)
  normal! zz
endfunction

function! s:OpenRight() dict
  call self.quit()
  execute 'rightbelow vertical split'
  execute 'edit ' . fnameescape(self.selected.path)
  call cursor(self.selected.line, self.selected.col)
  normal! zz
endfunction

function! s:Preview() dict
  if self.preview_winid == 0
    return
  endif
  
  let l:path = get(self.selected, 'path', '')
  if empty(l:path) || !filereadable(l:path)
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif
  
  let l:lines = readfile(l:path, '', 500)
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(self.preview_winid, l:lines)
  
  if exists('*myfinder#core#GuessFiletype')
     let l:ft = myfinder#core#GuessFiletype(l:path)
     call win_execute(self.preview_winid, 'setfiletype ' . l:ft)
  endif

  " Highlight the target line within preview
  let l:line = self.selected.line
  call win_execute(self.preview_winid, [
        \ 'call clearmatches()',
        \ 'highlight link FinderPreviewLine Search',
        \ "call matchadd('FinderPreviewLine', '\\%" . l:line . "l')",
        \ 'normal! ' . l:line . 'G0zz',
        \ ])
endfunction
