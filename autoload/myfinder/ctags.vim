" autoload/myfinder/ctags.vim

function! myfinder#ctags#start() abort
  let l:start_time = reltime()
  let l:tagfiles = tagfiles()
  if executable('ctags') && empty(l:tagfiles)
    call myfinder#core#echo('Generating tags...', 'info')
    call system('ctags -R --kinds-all=f .')
    let l:tagfiles = tagfiles()
  endif

  if empty(l:tagfiles)
    call myfinder#core#echo('No tags file found', 'warn')
    return
  endif
  
  " This might be slow for large projects
  let l:tags = taglist('.*')
  if empty(l:tags)
    call myfinder#core#echo('No tags found', 'warn')
    return
  endif

  let l:items = []
  for l:tag in l:tags
    let l:name = get(l:tag, 'name', '')
    let l:file = get(l:tag, 'filename', '')
    let l:kind = get(l:tag, 'kind', '')
    let l:cmd = get(l:tag, 'cmd', '')
    
    let l:file_display = fnamemodify(l:file, ':t')
    
    call add(l:items, {
          \ 'text': l:name,
          \ 'kind': l:kind,
          \ 'file_display': l:file_display,
          \ 'path': l:file,
          \ 'cmd': l:cmd,
          \ })
  endfor

  call myfinder#core#start(l:items, {
        \ 'open': function('s:JumpToTag'),
        \ 'preview': function('s:PreviewTag'),
        \ 'refresh': function('s:RefreshTags'),
        \ }, {
        \ 'name': 'Ctags',
        \ 'mappings': {'<C-r>': 'refresh'},
        \ 'display': ['text', 'kind', 'file_display'],
        \ 'match_item': 'text',
        \ 'columns_hl': ['Identifier', 'Type', 'Comment'],
        \ 'start_time': l:start_time,
        \ 'preview_enabled': 1,
        \ })
endfunction

function! s:JumpToTag() dict
  call self.quit()
  let l:file = self.selected.path
  let l:cmd = self.selected.cmd
  
  execute 'edit ' . fnameescape(l:file)
  
  if l:cmd =~# '^\d\+$'
    execute l:cmd
  else
    try
        execute l:cmd
    catch
    endtry
  endif
  normal! zz
endfunction

function! s:PreviewTag() dict
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
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  
  let l:cmd = get(self.selected, 'cmd', '')
  call win_execute(self.preview_winid, 'call clearmatches()')
  if l:cmd =~# '^\d\+$'
    call win_execute(self.preview_winid, 'normal! ' . l:cmd . 'Gzz')
    call win_execute(self.preview_winid, 'call matchadd("Search", "\\%" . l:cmd . "l")')
  else
    try
       call win_execute(self.preview_winid, l:cmd)
       call win_execute(self.preview_winid, 'normal! zz')
       call win_execute(self.preview_winid, 'call matchadd("Search", "\\%" . line(".") . "l")')
    catch
    endtry
  endif
endfunction

function! s:RefreshTags() dict
  call self.quit()
  if executable('ctags')
    call myfinder#core#echo('Updating tags...', 'info')
    call system('ctags -R --kinds-all=f .')
  endif
  call myfinder#ctags#start()
endfunction
