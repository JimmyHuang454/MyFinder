
function! myfinder#git#log() abort
  if !executable('git')
    echoerr 'Git is not executable'
    return
  endif

  let l:commits = systemlist('git log --oneline')
  if v:shell_error
    echoerr 'Failed to get git log'
    return
  endif

  let l:items = []
  
  for l:commit in l:commits
    let l:hash = split(l:commit)[0]
    call add(l:items, {
          \ 'text': l:commit,
          \ 'display': l:commit,
          \ 'hash': l:hash,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:Show'),
        \ 'open_tab': function('s:ShowTab'),
        \ 'open_left': function('s:ShowLeft'),
        \ 'open_right': function('s:ShowRight'),
        \ }, {
        \ 'name': 'Git Log',
        \ 'syntax': [
        \   {'match': '\%>2l^[0-9a-f]\{7,40\}\ze ', 'link': 'Constant'}
        \ ]
        \ })
endfunction

function! s:Show() dict
  call self.quit()
  if exists(':Gedit')
    execute 'Gedit ' . self.selected.hash
  else
    execute 'new'
    execute 'read !git show ' . self.selected.hash
    setlocal buftype=nofile bufhidden=wipe filetype=git
    normal! ggdd
  endif
endfunction

function! s:ShowTab() dict
  call self.quit()
  if exists(':Gtabedit')
    execute 'Gtabedit ' . self.selected.hash
  else
    execute 'tab new'
    execute 'read !git show ' . self.selected.hash
    setlocal buftype=nofile bufhidden=wipe filetype=git
    normal! ggdd
  endif
endfunction

function! s:ShowLeft() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'leftabove Gvsplit ' . self.selected.hash
  else
    execute 'vnew'
    execute 'read !git show ' . self.selected.hash
    setlocal buftype=nofile bufhidden=wipe filetype=git
    normal! ggdd
  endif
endfunction

function! s:ShowRight() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'Gvsplit ' . self.selected.hash
  else
    execute 'vnew'
    execute 'read !git show ' . self.selected.hash
    setlocal buftype=nofile bufhidden=wipe filetype=git
    normal! ggdd
  endif
endfunction
