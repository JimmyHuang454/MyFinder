" autoload/myfinder/ctags.vim

let s:tex_kinds = {
      \ 'p': 'part',
      \ 'c': 'chapter',
      \ 's': 'section',
      \ 'u': 'subsection',
      \ 'b': 'subsubsection',
      \ 'P': 'paragraph',
      \ 'G': 'subparagraph',
      \ }

function! myfinder#finders#ctags#start(...) abort
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
    call myfinder#utils#echo('No tags found', 'warn')
    return
  endif

  let l:items = []
  for l:tag in l:tags
    let l:name = get(l:tag, 'name', '')
    let l:file = get(l:tag, 'filename', '')
    let l:kind = get(l:tag, 'kind', '')
    let l:cmd = get(l:tag, 'cmd', '')
    
    let l:file_display = fnamemodify(l:file, ':t')

    if l:file =~? '\.\(tex\|sty\|cls\)$'
      let l:kind = get(s:tex_kinds, l:kind, l:kind)
    endif

    let l:lnum = 0
    if l:cmd =~# '^\d\+$'
      let l:lnum = str2nr(l:cmd)
    endif
    
    let l:item = {
        \ 'text': l:name,
        \ 'kind': l:kind,
        \ 'file_display': l:file_display,
        \ 'path': l:file,
        \ 'file_path': l:file,
        \ 'cmd': l:cmd,
        \ 'lnum': l:lnum,
        \ }
    call myfinder#utils#setFiletype(l:item, l:file)
    call add(l:items, l:item)
  endfor

  call s:NumberTexItems(l:items)

  let l:display = ['lnum', 'kind', 'text']

  let l:preview_enabled = 1
  if l:scope == 'project'
    call add(l:display, 'file_display')
    let l:preview_enabled = 0
  endif

  call myfinder#core#start(l:items, {
        \ 'open': function('myfinder#actions#open'),
        \ 'preview': function('myfinder#actions#preview'),
        \ 'refresh': function('s:RefreshTags')
        \ }, {
        \ 'name': 'Ctags (' . l:scope . ')',
        \ 'scope': l:scope,
        \ 'mappings': {'<C-r>': 'refresh'},
        \ 'display': l:display,
        \ 'match_item': 'text',
        \ 'columns_hl': ['Identifier', 'Type', 'Number', 'Comment'],
        \ 'start_time': l:start_time,
        \ 'preview_enabled': l:preview_enabled,
        \ })
endfunction

" Sort tex items by file/line and prefix headings with their number (1, 1.1, ...).
function! s:NumberTexItems(items) abort
  let l:levels = {'chapter': 1, 'section': 2, 'subsection': 3,
        \ 'subsubsection': 4, 'paragraph': 5, 'subparagraph': 6}

  let l:has_tex = 0
  for l:item in a:items
    if l:item.path =~? '\.\(tex\|sty\|cls\)$'
      let l:has_tex = 1
      break
    endif
  endfor
  if !l:has_tex
    return
  endif

  call sort(a:items, {a, b -> a.path ==# b.path ? a.lnum - b.lnum : (a.path <# b.path ? -1 : 1)})

  " Shallowest level used per file, so \section-only articles start at "1".
  let l:top = {}
  for l:item in a:items
    let l:lv = get(l:levels, l:item.kind, 0)
    if l:lv && (!has_key(l:top, l:item.path) || l:lv < l:top[l:item.path])
      let l:top[l:item.path] = l:lv
    endif
  endfor

  let l:cur_path = ''
  let l:counters = []
  for l:item in a:items
    let l:lv = get(l:levels, l:item.kind, 0)
    if !l:lv
      continue
    endif
    if l:item.path !=# l:cur_path
      let l:cur_path = l:item.path
      let l:counters = repeat([0], 7)
    endif
    let l:counters[l:lv] += 1
    for l:i in range(l:lv + 1, 6)
      let l:counters[l:i] = 0
    endfor
    let l:nums = map(l:counters[l:top[l:item.path] : l:lv], 'string(v:val)')
    let l:item.text = join(l:nums, '.') . ' ' . l:item.text
  endfor
endfunction

function! s:RefreshTags() dict
  call self.quit()
  let l:scope = get(self, 'scope', 'file')
  call myfinder#finders#ctags#start(l:scope)
endfunction

function! s:GenerateTags(scope) abort
  if !executable('ctags')
    call myfinder#utils#echo('ctags not found', 'error')
    return ''
  endif

  call myfinder#utils#echo('Generating tags (' . a:scope . ')...', 'info')

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
        \ 'tex': '--tex-kinds=pcsubPG',
        \ 'plaintex': '--tex-kinds=pcsubPG --language-force=Tex',
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
      call myfinder#utils#echo('No file to tag', 'warn')
      return ''
    endif
    let l:cmd = 'ctags --excmd=number -f ' . fnameescape(l:temp_file) . (l:extra_cmd == '' ? '' : ' ' . l:extra_cmd) . ' ' . fnameescape(l:file)
  endif

  call system(l:cmd)

  if v:shell_error
    call myfinder#utils#echo('ctags failed', 'error')
    return ''
  endif

  return l:temp_file
endfunction
