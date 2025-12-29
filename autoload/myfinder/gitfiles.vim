
function! myfinder#gitfiles#start() abort
  if !executable('git')
    echoerr 'Git is not executable'
    return
  endif

  let l:files = systemlist('git ls-files')
  if v:shell_error
    echoerr 'Not in a git repository or git ls-files failed'
    return
  endif

  let l:items = []
  
  for l:file in l:files
    call add(l:items, {
          \ 'text': l:file,
          \ 'display': l:file,
          \ 'path': l:file,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:Open'),
        \ 'open_tab': function('s:OpenTab'),
        \ 'open_left': function('s:OpenLeft'),
        \ 'open_right': function('s:OpenRight'),
        \ }, {
        \ 'name': 'Git Files',
        \ 'name_color': {'guibg': '#e5c07b', 'ctermbg': 3}
        \ })
endfunction

" Keep fugitive integration for git files
function! s:Open() dict
  call self.quit()
  if exists(':Gedit')
    execute 'Gedit ' . self.selected.path
  else
    execute 'edit ' . self.selected.path
  endif
endfunction

function! s:OpenTab() dict
  call self.quit()
  if exists(':Gtabedit')
    execute 'Gtabedit ' . self.selected.path
  else
    execute 'tab split'
    execute 'edit ' . self.selected.path
  endif
endfunction

function! s:OpenLeft() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'leftabove Gvsplit ' . self.selected.path
  else
    execute 'vsplit'
    execute 'edit ' . self.selected.path
  endif
endfunction

function! s:OpenRight() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'Gvsplit ' . self.selected.path
  else
    execute 'vsplit'
    execute 'edit ' . self.selected.path
  endif
endfunction
