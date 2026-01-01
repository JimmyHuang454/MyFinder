
function! myfinder#git#log() abort
  let l:start_time = reltime()
  if !executable('git')
    call myfinder#core#echo('Git is not executable', 'error')
    return
  endif

  let l:commits = systemlist('git log --format="%h|%an|%s"')
  if v:shell_error
    call myfinder#core#echo('Failed to get git log', 'error')
    return
  endif

  let l:items = []
  
  for l:line in l:commits
    let l:p1 = stridx(l:line, '|')
    let l:p2 = stridx(l:line, '|', l:p1 + 1)
    if l:p1 == -1 || l:p2 == -1 | continue | endif
    let l:hash = l:line[:l:p1-1]
    let l:author = l:line[l:p1+1 : l:p2-1]
    let l:subject = l:line[l:p2+1:]
    
    let l:display = printf('%-8s %-15.15s %s', l:hash, l:author, l:subject)
    
    call add(l:items, {
          \ 'text': l:display,
          \ 'display': l:display,
          \ 'hash': l:hash,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:Show'),
        \ 'open_with_new_tab': function('s:ShowTab'),
        \ 'open_vertically': function('s:ShowRight'),
        \ }, {
        \ 'name': 'Git Log',
        \ 'syntax': [
        \   {'match': '\%>2l\%>0v.*\%<9v',  'link': 'Constant'},
        \   {'match': '\%>2l\%>9v.*\%<25v', 'link': 'Identifier'},
        \   {'match': '\%>2l\%>25v.*',       'link': 'Comment'},
        \ ],
        \ 'status': 'Git',
        \ 'start_time': l:start_time
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
    execute 'tabnew'
    execute 'read !git show ' . self.selected.hash
    setlocal buftype=nofile bufhidden=wipe filetype=git
    normal! ggdd
  endif
endfunction

function! s:ShowRight() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'rightbelow Gvsplit ' . self.selected.hash
  else
    execute 'rightbelow vnew'
    execute 'read !git show ' . self.selected.hash
    setlocal buftype=nofile bufhidden=wipe filetype=git
    normal! ggdd
  endif
endfunction
