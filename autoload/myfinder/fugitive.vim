" vim-fugitive integration: the diff that dd / dv / dh / ds open in the :Git
" status window is moved into the shared diff tab (myfinder#difftab), so q (or
" closing any diff window) closes the tab and returns to the status window.
"
" It only does something when fugitive is installed. Disable it with:
"   let g:myfinder_fugitive_difftab = 0
"
" How: fugitive opens the diff as usual, then the buffers of the diff windows
" are shown in a new diff tab and the current tab is put back to the layout it
" had before the diff was opened. fugitive's own mappings are wrapped, not
" replaced, so this works with whatever the installed version maps.

function! s:Enabled() abort
  return get(g:, 'myfinder_fugitive_difftab', 1) && exists('*FugitiveGitDir')
endfunction

function! myfinder#fugitive#snapshot() abort
  let t:myfinder_fugitive_layout = {
        \ 'wins': map(range(1, winnr('$')), 'win_getid(v:val)'),
        \ 'origin': win_getid(),
        \ 'bufs': map(range(1, winnr('$')), '[win_getid(v:val), winbufnr(v:val)]'),
        \ }
endfunction

function! myfinder#fugitive#adopt() abort
  if !exists('t:myfinder_fugitive_layout')
    return
  endif
  let l:layout = t:myfinder_fugitive_layout
  unlet t:myfinder_fugitive_layout

  let l:wins = filter(range(1, winnr('$')), 'getwinvar(v:val, "&diff")')
  if len(l:wins) < 2
    return
  endif
  let l:ids = map(copy(l:wins), 'win_getid(v:val)')
  let l:bufs = map(copy(l:wins), 'winbufnr(v:val)')
  let l:lines = map(copy(l:ids), 'line(".", v:val)')

  " Show them in the new tab first: fugitive's temporary buffers are deleted
  " when the last window showing them closes.
  call myfinder#difftab#open(function('myfinder#difftab#show_buffers', [l:bufs, l:lines]),
        \ {'origin': l:layout.origin})
  let l:cur = win_getid()

  " Restore the current tab: close the windows the diff opened, put back the
  " buffers it replaced, leave diff mode.
  for l:id in reverse(copy(l:ids))
    if index(l:layout.wins, l:id) < 0
      call win_gotoid(l:id)
      silent! close
    else
      call win_execute(l:id, 'diffoff')
    endif
  endfor
  for [l:id, l:buf] in l:layout.bufs
    let l:nr = win_id2win(l:id)
    if l:nr > 0 && winbufnr(l:nr) != l:buf && bufexists(l:buf) && bufname(l:buf) !=# ''
      call win_execute(l:id, 'silent! buffer ' . l:buf)
    endif
  endfor
  call win_gotoid(l:cur)
endfunction

" Called on User FugitiveIndex (the :Git status buffer has just been set up)
function! myfinder#fugitive#wrap_maps() abort
  if !s:Enabled()
    return
  endif
  for l:key in ['dd', 'dv', 'dh', 'ds']
    let l:m = maparg(l:key, 'n', 0, 1)
    if empty(l:m) || !get(l:m, 'buffer', 0) || l:m.rhs =~# 'myfinder#fugitive'
      continue
    endif
    let l:m.rhs = substitute(l:m.rhs, '^:<C-U>', ':<C-U>call myfinder#fugitive#snapshot()<Bar>', '')
    let l:m.rhs = substitute(l:m.rhs, '<CR>$', '<Bar>call myfinder#fugitive#adopt()<CR>', '')
    call mapset('n', 0, l:m)
  endfor
endfunction

" Buffer-local key in fugitive / git buffers (:Git status, commit, log...) that
" lists the files changed by the commit under the cursor (:FinderGitDiff).
" Customize or disable (empty string) with:
"   let g:myfinder_fugitive_keys = {'git_diff': '<leader>v'}
function! myfinder#fugitive#maps() abort
  if !s:Enabled()
    return
  endif
  let l:keys = extend({'git_diff': '<leader>v'}, get(g:, 'myfinder_fugitive_keys', {}))
  if l:keys.git_diff !=# ''
    execute 'nnoremap <buffer><silent> ' . l:keys.git_diff . ' :FinderGitDiff<CR>'
  endif
endfunction
