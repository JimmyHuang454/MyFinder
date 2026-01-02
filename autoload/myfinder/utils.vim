function! myfinder#utils#echo(msg, ...) abort
  let l:type = get(a:000, 0, 'info')
  let l:hl = get({'info': 'MoreMsg', 'success': 'MoreMsg', 'warn': 'WarningMsg', 'error': 'ErrorMsg'}, l:type, 'MoreMsg')
  execute 'echohl ' . l:hl
  echo '[MyFinder] ' . a:msg
  echohl None
endfunction

function! myfinder#utils#GuessFiletype(path) abort
  let l:ext = tolower(fnamemodify(a:path, ':e'))
  let l:map = {
        \ 'vim': 'vim',
        \ 'tex': 'tex',
        \ 'vue': 'vue',
        \ 'lua': 'lua',
        \ 'js': 'javascript',
        \ 'ts': 'typescript',
        \ 'json': 'json',
        \ 'py': 'python',
        \ 'go': 'go',
        \ 'rs': 'rust',
        \ 'java': 'java',
        \ 'sh': 'sh',
        \ 'md': 'markdown',
        \ 'yaml': 'yaml',
        \ 'yml': 'yaml',
        \ }
  return get(l:map, l:ext, 'text')
endfunction

function! myfinder#utils#setFiletype(item, path) abort
  let l:abs_path = fnamemodify(a:path, ':p')
  let l:bufnr = bufnr(l:abs_path)
  if l:bufnr > 0
    let a:item['bufnr'] = l:bufnr
    let a:item['is_loaded'] = l:bufnr
    let a:item['filetype'] = getbufvar(l:bufnr, '&filetype')
  else
    let a:item['is_loaded'] = ''
    let a:item['filetype'] = myfinder#utils#GuessFiletype(l:abs_path)
  endif
endfunction
