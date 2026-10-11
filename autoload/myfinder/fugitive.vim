" vim-fugitive integration: the diff that dd / dv / dh / ds open in the :Git
" status window is moved into the shared diff tab (myfinder#difftab), so q (or
" closing any diff window) closes the tab and returns to the status window.
"
" It only does something when fugitive is installed. Disable it with:
"   let g:myfinder_fugitive_difftab = 0
"
" On a commit line (under "Unpushed to" / "Unpulled from") dd lists the files
" changed by that commit with :FinderGitDiff instead.
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

" Hash of the commit on the cursor line of the :Git status buffer (the lines under
" "Unpushed to" / "Unpulled from"), or ''.
function! myfinder#fugitive#commit_at_cursor() abort
  return matchstr(getline('.'), '^\x\{7,40}\ze\s')
endfunction

function! myfinder#fugitive#open_commit() abort
  execute 'FinderGitDiff ' . myfinder#fugitive#commit_at_cursor()
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
    " ':<C-U>BODY<CR>'  ->  on a commit line (dd only) list its files in
    " MyFinder, otherwise run BODY with the diff moved into the diff tab
    let l:body = substitute(substitute(l:m.rhs, '^:<C-U>', '', ''), '<CR>$', '', '')
    let l:new = ':<C-U>'
    if l:key ==# 'dd'
      let l:new .= 'if myfinder#fugitive#commit_at_cursor() !=# ""<Bar>call myfinder#fugitive#open_commit()<Bar>else<Bar>'
    endif
    let l:new .= 'call myfinder#fugitive#snapshot()<Bar>' . l:body . '<Bar>call myfinder#fugitive#adopt()'
    if l:key ==# 'dd'
      let l:new .= '<Bar>endif'
    endif
    let l:m.rhs = l:new . '<CR>'
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
