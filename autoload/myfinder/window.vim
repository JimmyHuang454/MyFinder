
function! myfinder#window#start() abort
  let l:wins = getwininfo()
  let l:items = []
  
  for l:w in l:wins
    let l:bufname = bufname(l:w.bufnr)
    if empty(l:bufname)
      let l:bufname = '[No Name]'
    endif
    let l:text = printf('%4d:%-3d %s', l:w.tabnr, l:w.winnr, l:bufname)
    call add(l:items, {
          \ 'text': l:text,
          \ 'display': l:text,
          \ 'target_winid': l:w.winid,
          \ 'lnum': 1,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {}, {
        \ 'name': 'Windows',
        \ 'name_color': {'guibg': '#e06c75', 'ctermbg': 1}
        \ })
endfunction
