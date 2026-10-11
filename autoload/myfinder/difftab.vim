" Diff mode: a dedicated tab that holds diff windows. Shared by the finders and
" by anything else that wants a throwaway diff view (e.g. vim-fugitive glue).
"
"   call myfinder#difftab#open(Setup [, opts])
"
" opens a new tab and calls Setup() in it; Setup builds the diff windows (and
" leaves the cursor in the window that should get focus). While the tab is
" open:
"   q   :q, i.e. closes the diff window (g:myfinder_difftab_keys.quit)
"   gF  goes back (g:myfinder_difftab_keys.back)
" Closing any of the diff windows by any means (:q, :close, ZZ, :tabclose, ...)
" closes the whole tab, leaves diff mode and returns to where it was opened
" from. If a finder opened it, the finder (which is only hidden, not closed)
" comes back.
"
" opts:
"   'ctx'      finder context to suspend now and resume when coming back
"   'origin'   window id to return to (default: the current window)
"   'on_maps'  funcref, called in every diff window to add more mappings
"
" Customize the keys with:
"   let g:myfinder_difftab_keys = {'back': 'gF', 'quit': 'q'}

let s:origin = {}
let s:wins = {}
let s:switching = 0
let s:timer = -1

function! myfinder#difftab#active() abort
  return exists('t:myfinder_difftab')
endfunction

function! myfinder#difftab#open(Setup, ...) abort
  let l:opts = a:0 > 0 ? a:1 : {}
  if myfinder#difftab#active()
    " Already in a diff tab: rebuild its windows, keep the origin
    let l:opts = extend(copy(t:myfinder_difftab.opts), l:opts)
    let l:new_tab = 0
  else
    let l:ctx = get(l:opts, 'ctx', {})
    let s:origin = {'winid': get(l:opts, 'origin', win_getid()), 'ctx': l:ctx}
    if !empty(l:ctx)
      call myfinder#core#suspend(l:ctx)
    endif
    let l:new_tab = 1
  endif

  let s:switching = 1
  try
    if l:new_tab
      tabnew
    else
      silent! only
      silent! diffoff!
    endif
    let t:myfinder_difftab = {'opts': l:opts}
    call a:Setup()
  catch
    let s:switching = 0
    if l:new_tab
      silent! tabclose
    endif
    call s:Finish(0)
    call myfinder#utils#echo(v:exception, 'error')
    return
  finally
    let s:switching = 0
  endtry

  let s:wins = {}
  for l:nr in range(1, winnr('$'))
    let s:wins[win_getid(l:nr)] = 1
    call win_execute(win_getid(l:nr), 'call myfinder#difftab#maps()')
  endfor
  call s:StartWatch()
endfunction

" Setup helper: show the given buffers side by side (left to right) in diff mode
function! myfinder#difftab#show_buffers(bufs, lines) abort
  for l:i in range(len(a:bufs))
    if l:i > 0
      execute 'silent rightbelow vertical sbuffer ' . a:bufs[l:i]
    else
      execute 'silent buffer ' . a:bufs[l:i]
    endif
    diffthis
    if get(a:lines, l:i, 0) > 0
      call cursor(a:lines[l:i], 1)
      normal! zz
    endif
  endfor
endfunction

function! myfinder#difftab#maps() abort
  let l:keys = extend({'back': 'gF', 'quit': 'q'}, get(g:, 'myfinder_difftab_keys', {}))
  if l:keys.back !=# ''
    execute 'nnoremap <buffer><silent> ' . l:keys.back . ' :call myfinder#difftab#back()<CR>'
  endif
  if l:keys.quit !=# ''
    " Buffer-local, so it wins over any other mapping of this key. Closing the
    " window is noticed by the watcher, which then closes the whole tab.
    execute 'nnoremap <buffer><silent> ' . l:keys.quit . ' :q<CR>'
  endif
  if has_key(t:myfinder_difftab.opts, 'on_maps')
    call t:myfinder_difftab.opts.on_maps()
  endif
endfunction

function! myfinder#difftab#back() abort
  call timer_start(0, function('s:Finish'))
endfunction

" Poll the diff windows: when any of them is gone close the whole tab. This does
" not depend on which command closed the window.
function! s:StartWatch() abort
  if s:timer == -1
    let s:timer = timer_start(100, function('s:Watch'), {'repeat': -1})
  endif
endfunction

function! s:StopWatch() abort
  if s:timer != -1
    call timer_stop(s:timer)
    let s:timer = -1
  endif
endfunction

function! s:Watch(timer) abort
  if s:switching || empty(s:wins)
    return
  endif
  for l:id in keys(s:wins)
    if win_id2tabwin(str2nr(l:id))[0] == 0
      call s:Finish(a:timer)
      return
    endif
  endfor
endfunction

" Leave diff mode, close the diff tab and go back to where it was opened from.
" The timers may fire while Vim is busy with something that forbids changing
" windows (E565, e.g. a statusline plugin calling fugitive synchronously), so a
" failed attempt is simply retried a moment later.
let s:retries = 0

function! s:Finish(timer) abort
  try
    call s:Leave()
    let s:retries = 0
  catch
    let s:retries += 1
    if s:retries < 100
      call timer_start(50, function('s:Finish'))
    else
      let s:retries = 0
      let s:wins = {}
      call s:StopWatch()
    endif
  endtry
endfunction

function! s:Leave() abort
  for l:id in keys(s:wins)
    let l:tw = win_id2tabwin(str2nr(l:id))
    if l:tw[0] > 0
      call win_gotoid(str2nr(l:id))
      silent! diffoff!
      try
        execute 'tabclose ' . l:tw[0]
      catch /:E784:/
        " last tab page: nothing to close
      endtry
      " :tabclose silently does nothing while changing windows is not allowed
      if win_id2tabwin(str2nr(l:id))[0] > 0 && tabpagenr('$') > 1
        throw 'myfinder: diff tab not closed yet'
      endif
      break
    endif
  endfor
  " Only now stop watching: if anything above failed it is retried
  let s:wins = {}
  call s:StopWatch()
  if !empty(s:origin) && win_gotoid(s:origin.winid)
    if !empty(s:origin.ctx)
      call myfinder#core#resume(s:origin.ctx)
    endif
  endif
  let s:origin = {}
  redraw!
endfunction
