
function! myfinder#files#start() abort
  let l:cmd = 'find . -maxdepth 5 -not -path "*/.*" -type f'
  if isdirectory('.git') || filereadable('.git')
    if executable('git')
      let l:cmd = 'git ls-files'
    endif
  endif
  
  let l:files = systemlist(l:cmd)
  if v:shell_error
    echoerr 'Failed to list files: ' . l:cmd
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
  
  call myfinder#core#start(l:items, {}, {
        \ 'name': 'Files',
        \ 'name_color': {'guibg': '#98c379', 'ctermbg': 2}
        \ })
endfunction
