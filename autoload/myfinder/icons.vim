
function! myfinder#icons#get(filename) abort
  if exists('*WebDevIconsGetFileTypeSymbol')
    return WebDevIconsGetFileTypeSymbol(a:filename, isdirectory(a:filename))
  endif
  return ''
endfunction
