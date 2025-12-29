
function! myfinder#mru#start() abort
  let l:mru_dict = {}
  let l:items = []
  
  " 1. Add current buffers first (they are the most recent)
  let l:buffers = getbufinfo({'buflisted': 1})
  " Sort buffers by last used time if available (Vim 8.2.19xx+)
  " Otherwise they are in buffer number order.
  for l:buf in l:buffers
    if !empty(l:buf.name) && filereadable(l:buf.name)
      let l:path = fnamemodify(l:buf.name, ':p')
      let l:display = fnamemodify(l:path, ':~:.')
      if !has_key(l:mru_dict, l:path)
        let l:mru_dict[l:path] = 1
        call add(l:items, {
              \ 'text': l:display,
              \ 'display': l:display,
              \ 'path': l:path,
              \ })
      endif
    endif
  endfor
  
  " 2. Add v:oldfiles
  for l:file in v:oldfiles
    let l:path = fnamemodify(l:file, ':p')
    if !has_key(l:mru_dict, l:path) && filereadable(l:path)
      let l:display = fnamemodify(l:path, ':~:.')
      let l:mru_dict[l:path] = 1
      call add(l:items, {
            \ 'text': l:display,
            \ 'display': l:display,
            \ 'path': l:path,
            \ })
    endif
  endfor
  
  call myfinder#core#start(l:items, {}, {
        \ 'name': 'MRU',
        \ 'name_color': {'guibg': '#c678dd', 'ctermbg': 5}
        \ })
endfunction
