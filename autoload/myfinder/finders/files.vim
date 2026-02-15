if !exists('g:myfinder_file_cache')
  let g:myfinder_file_cache = {}
endif

function! myfinder#finders#files#start() abort
  let l:start_time = reltime()
  let l:is_git = 0
  
  " Check for git repository
  if exists('g:loaded_fugitive') && !empty(fugitive#statusline())
    let l:is_git = 1
  endif

  let l:name = 'Files'
  let l:bg = '#98c379'
  let l:files = []

  if l:is_git
    let l:name = 'Git'
    let l:bg = '#e5c07b'
    
    " Try to get git root
    let l:git_root = ''
    let l:git_root = fnamemodify(FugitiveGitDir(bufnr('%')), ':h')
    
    if !empty(l:git_root)
      execute 'lcd ' . l:git_root
    endif

    let l:branch = FugitiveHead()
    if !empty(l:branch)
      let l:name .= printf(" (%s)", l:branch)
    endif
  endif

  let l:cwd = getcwd()
  let l:use_cache = 0
  if has_key(g:myfinder_file_cache, l:cwd) && l:use_cache
    let l:files = g:myfinder_file_cache[l:cwd]
  else
    if l:is_git
      " Use git ls-files to respect gitignore
      " let l:files = systemlist('git ls-files --cached --others --exclude-standard')
      let l:files = fugitive#Execute(['ls-files'])['stdout']
      
      " Fallback if git failed or returned nothing (unlikely for valid repo)
      if empty(l:files)
        let l:files = s:GlobFiles()
      endif
    else
      let l:files = s:GlobFiles()
    endif
    if l:use_cache
      let g:myfinder_file_cache[l:cwd] = l:files
    endif
  endif


  let l:items = []

  for l:file in l:files
    if empty(l:file)
      continue
    endif

    let l:abs_path = fnamemodify(l:file, ':p')
    
    " Double check it's not a directory
    if isdirectory(l:abs_path)
      continue
    endif

    let l:display_text = l:file
    
    let l:freq = myfinder#frequency#get(l:abs_path)

    if l:freq > 0
      let l:display_text .= ' [' . l:freq . ']'
    endif

    let l:item = {
          \ 'text': l:display_text,
          \ 'abs_path': l:abs_path,
          \ }
    " call myfinder#utils#setFiletype(l:item, l:file)

    if has_key(l:item,'bufnr')
      let l:item['text'] .= printf("*")
    endif

    call add(l:items, l:item)
  endfor

  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ 'copy_path': function('myfinder#actions#copy_path'),
        \ 'delete_file': function('myfinder#actions#delete_file'),
        \ 'create_file': function('myfinder#actions#create_file'),
        \ 'move_file': function('myfinder#actions#move_file'),
        \ 'copy_file': function('myfinder#actions#copy_file'),
        \ 'paste_file': function('myfinder#actions#paste_file'),
        \ }, {
        \ 'name': l:name,
        \ 'name_color': {'guibg': l:bg, 'ctermbg': (l:is_git ? 3 : 2)},
        \ 'start_time': l:start_time,
        \ 'display': ['text'],
        \ 'mappings': {
        \   "\<C-g>": 'create_file',
        \   "\<C-d>": 'delete_file',
        \   "\<C-r>": 'move_file',
        \   "\<C-y>": 'copy_file',
        \   "\<C-v>": 'paste_file',
        \ },
        \ })
endfunction

function! s:GlobFiles() abort
  let l:files = glob('**', 0, 1)
  let l:res = []
  
  for l:f in l:files
    if isdirectory(l:f)
      continue
    endif
    
    " Basic filtering for common ignored folders
    if l:f =~# '\.git/' || l:f =~# 'node_modules/'
      continue
    endif
    
    call add(l:res, l:f)
  endfor
  
  return l:res
endfunction
