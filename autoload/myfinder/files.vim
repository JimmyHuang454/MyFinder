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
    let l:name = 'Git Files'
    let l:bg = '#e5c07b'
    let l:status = 'Git'
    
    if exists('g:loaded_fugitive')
      let l:branch = FugitiveHead()
      if !empty(l:branch)
        let l:status = 'Git(' . l:branch . ')'
      endif
    endif

    call myfinder#core#echo('Running in Git repository', 'info')
  else
    call myfinder#core#echo('Running in Vim workspace', 'info')
  endif
  
  if l:is_git
    let l:files = fugitive#Execute(['ls-files','--exclude-standard','--cached','--others'])['stdout']
  else
    let l:files = systemlist(l:cmd)
    if v:shell_error
      call myfinder#core#echo('Failed to list files', 'error')
      return
    endif
  endif

  let l:items = []

  for l:file in l:files
    if l:file == ''
      continue
    endif
    
    call add(l:items, {
          \ 'text': l:file,
          \ 'display': l:file,
          \ 'path': l:file,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:Open'),
        \ 'open_with_new_tab': function('s:OpenTab'),
        \ 'open_vertically': function('s:OpenRight'),
        \ 'preview': function('s:PreviewFile'),
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

function! s:PreviewFile() dict
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
  let l:ft = myfinder#core#GuessFiletype(l:path)
  if exists('*myfinder#core#GuessFiletype')
    let l:ft = myfinder#core#GuessFiletype(l:path)
  endif
  if !empty(l:ft)
    call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
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

function! s:OpenRight() dict
  call self.quit()
  if exists(':Gvsplit')
    execute 'rightbelow Gvsplit ' . fnameescape(self.selected.path)
  else
    execute 'rightbelow vertical split'
    execute 'edit ' . fnameescape(self.selected.path)
  endif
endfunction
