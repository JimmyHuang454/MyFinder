" autoload/myfinder/ctags.vim

function! myfinder#ctags#start(...) abort
  let l:scope = get(a:, 1, 'file')
  let l:start_time = reltime()

  let l:tag_file = s:GenerateTags(l:scope)
  if empty(l:tag_file)
    return
  endif

  let l:save_tags = &tags
  let &tags = l:tag_file

  try
    let l:tags = taglist('.*')
  finally
    let &tags = l:save_tags
    call delete(l:tag_file)
  endtry

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
        \ 'line': l:cmd,
        \ })
  endfor

  let l:display = ['line', 'kind', 'text']

  if l:scope == 'project'
    call add(l:display, 'file_display')
  endif

  call myfinder#core#start(l:items, {
        \ 'open': function('s:JumpToTag'),
        \ 'preview': function('s:PreviewTag'),
        \ 'refresh': function('s:RefreshTags'),
        \ }, {
        \ 'name': 'Ctags (' . l:scope . ')',
        \ 'scope': l:scope,
        \ 'mappings': {'<C-r>': 'refresh'},
        \ 'display': l:display,
        \ 'match_item': 'text',
        \ 'columns_hl': ['Identifier', 'Type', 'Number', 'Comment'],
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

  let l:cmd = get(self.selected, 'cmd', '')
  let l:target_line = 0
  if l:cmd =~# '^\d\+$'
    let l:target_line = str2nr(l:cmd)
  endif

  " Read enough lines to show the target
  let l:limit = 1000
  if l:target_line > 0
    let l:limit = max([1000, l:target_line + 50])
  endif

  let l:lines = readfile(l:path, '', l:limit)
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(self.preview_winid, l:lines)
  
  let l:ft = myfinder#core#GuessFiletype(l:path)
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  
  call win_execute(self.preview_winid, 'call clearmatches()')
  if l:target_line > 0
    call win_execute(self.preview_winid, 'normal! ' . l:target_line . 'Gzz')
    call win_execute(self.preview_winid, 'call matchadd("Search", "\\%" . l:target_line . "l")')
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
  let l:scope = get(self, 'scope', 'file')
  call myfinder#ctags#start(l:scope)
endfunction

function! s:GenerateTags(scope) abort
  if !executable('ctags')
    call myfinder#core#echo('ctags not found', 'error')
    return ''
  endif

  call myfinder#core#echo('Generating tags (' . a:scope . ')...', 'info')

  let l:ctags_options = {
        \ 'aspvbs': '--asp-kinds=f',
        \ 'awk': '--awk-kinds=f',
        \ 'c': '--c-kinds=fp',
        \ 'cpp': '--c++-kinds=fp --language-force=C++',
        \ 'cs': '--c#-kinds=m',
        \ 'erlang': '--erlang-kinds=f',
        \ 'fortran': '--fortran-kinds=f',
        \ 'java': '--java-kinds=m',
        \ 'javascript': '--javascript-kinds=f',
        \ 'lisp': '--lisp-kinds=f',
        \ 'lua': '--lua-kinds=f',
        \ 'matlab': '--matlab-kinds=f',
        \ 'pascal': '--pascal-kinds=f',
        \ 'php': '--php-kinds=f',
        \ 'python': '--python-kinds=fm --language-force=Python',
        \ 'ruby': '--ruby-kinds=fF',
        \ 'scheme': '--scheme-kinds=f',
        \ 'sh': '--sh-kinds=f',
        \ 'sql': '--sql-kinds=f',
        \ 'tcl': '--tcl-kinds=m',
        \ 'verilog': '--verilog-kinds=f',
        \ 'vim': '--vim-kinds=f',
        \ 'go': '--go-kinds=f',
        \ 'rust': '--rust-kinds=fPM',
        \ 'ocaml': '--ocaml-kinds=mf',
        \ }

  let l:ft = &filetype
  let l:extra_cmd = ''
  if has_key(l:ctags_options, l:ft)
    let l:extra_cmd = l:ctags_options[l:ft]
  endif

  let l:temp_file = tempname()
  
  if a:scope ==# 'project'
    let l:cmd = 'ctags --excmd=number -f ' . fnameescape(l:temp_file) . ' -R' . (l:extra_cmd == '' ? '' : ' ' . l:extra_cmd) . ' ' . fnameescape(getcwd())
  else
    " current file
    let l:file = expand('%:p')
    if empty(l:file)
      call myfinder#core#echo('No file to tag', 'warn')
      return ''
    endif
    let l:cmd = 'ctags --excmd=number -f ' . fnameescape(l:temp_file) . (l:extra_cmd == '' ? '' : ' ' . l:extra_cmd) . ' ' . fnameescape(l:file)
  endif

  call system(l:cmd)

  if v:shell_error
    call myfinder#core#echo('ctags failed', 'error')
    return ''
  endif

  return l:temp_file
endfunction
