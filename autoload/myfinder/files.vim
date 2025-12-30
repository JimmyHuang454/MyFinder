function! myfinder#files#start() abort
  let l:start_time = reltime()
  let l:is_git = 0
  
  " Fugitive integration
  if exists('g:loaded_fugitive')
    if fugitive#statusline() != ''
      let l:is_git = 1
    endif
  endif

  let l:cmd = 'find . -maxdepth 5 -not -path "*/.*" -type f'
  let l:name = 'Files'
  let l:bg = '#98c379'
  let l:status = 'Workspace'
  
  if l:is_git
    let l:cmd = 'git ls-files --cached --others --exclude-standard'
    let l:name = 'Git Files'
    let l:bg = '#e5c07b'
    let l:status = 'Git'
    
    if exists('g:loaded_fugitive')
      let l:branch = FugitiveHead()
      if !empty(l:branch)
        let l:status = 'Git(' . l:branch . ')'
      endif
    endif

    echo 'Finder: Running in Git repository'
  else
    echo 'Finder: Running in Vim workspace'
  endif
  
  let l:files = systemlist(l:cmd)
  if v:shell_error
    echoerr 'Failed to list files'
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
        \ 'name': l:name,
        \ 'name_color': {'guibg': l:bg, 'ctermbg': (l:is_git ? 3 : 2)},
        \ 'status': l:status,
        \ 'start_time': l:start_time
        \ })
endfunction

function! s:Open() dict
  call self.quit()
  if exists(':Gedit') && !empty(get(self.selected, 'path', ''))
    execute 'Gedit ' . fnameescape(self.selected.path)
  else
    execute 'edit ' . fnameescape(self.selected.path)
  endif
endfunction

function! s:OpenTab() dict
  call self.quit()
  if exists(':Gtabedit')
    execute 'Gtabedit ' . fnameescape(self.selected.path)
  else
    execute 'tab split'
    execute 'edit ' . fnameescape(self.selected.path)
  endif
endfunction

function! s:OpenLeft() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'leftabove Gvsplit ' . fnameescape(self.selected.path)
  else
    execute 'leftabove vsplit'
    execute 'edit ' . fnameescape(self.selected.path)
  endif
endfunction

function! s:OpenRight() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'rightbelow Gvsplit ' . fnameescape(self.selected.path)
  else
    execute 'rightbelow vertical split'
    execute 'edit ' . fnameescape(self.selected.path)
  endif
endfunction
