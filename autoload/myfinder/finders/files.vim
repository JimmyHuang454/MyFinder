function! myfinder#finders#files#start() abort
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


  if l:is_git
    let l:name = 'Git'
    let l:bg = '#e5c07b'

    let l:git_dir = FugitiveGitDir(bufnr('%'))
    let l:git_root = fnamemodify(git_dir, ':h')

    execute 'lcd ' . l:git_root

    let l:branch = FugitiveHead()
    if !empty(l:branch)
      let l:name .= printf(" (%s)", l:branch)
    endif
  endif

  if l:is_git
    let l:files = fugitive#Execute(['ls-files'])['stdout']
  else
    let l:files = systemlist(l:cmd)
    if v:shell_error
      call myfinder#utils#echo('Failed to list files', 'error')
      return
    endif
  endif

  let l:items = []

  for l:file in l:files
    if l:file == ''
      continue
    endif

    let l:abs_path = fnamemodify(l:file, ':p')
    let l:display_text = l:file
    let l:freq = myfinder#frequency#get(l:abs_path)

    if l:freq > 0
      let l:display_text .= ' [' . l:freq . ']'
    endif

    let l:item = {
          \ 'text': l:display_text,
          \ 'path': l:abs_path,
          \ }
    call myfinder#utils#setFiletype(l:item, l:file)

    call add(l:items, l:item)
  endfor

  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ 'copy_path': function('myfinder#actions#copy_path'),
        \ }, {
        \ 'name': l:name,
        \ 'name_color': {'guibg': l:bg, 'ctermbg': (l:is_git ? 3 : 2)},
        \ 'start_time': l:start_time,
        \ 'display': ['is_loaded', 'text'],
        \ })
endfunction
