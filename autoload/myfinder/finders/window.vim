function! myfinder#finders#window#start() abort
  let l:start_time = reltime()
  let l:wins = getwininfo()
  let l:items = []
  
  for l:w in l:wins
    let l:bufname = bufname(l:w.bufnr)
    if empty(l:bufname)
      let l:bufname = '[No Name]'
    endif
    let l:text = printf('%3d:%-3d %s:%d:%d', l:w.tabnr, l:w.winnr, l:bufname, l:w.winrow, l:w.wincol)
    let l:item = {
          \ 'text': l:text,
          \ 'display': l:text,
          \ 'target_winid': l:w.winid,
          \ 'lnum': l:w.winrow,
          \ 'col': l:w.wincol,
          \ }
    if !empty(l:bufname) && l:bufname != '[No Name]'
        let l:item.path = l:bufname
    endif

    call myfinder#utils#setFiletype(l:item, l:bufname)
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ }, {
        \ 'name': 'Windows',
        \ 'name_color': {'guibg': '#e06c75', 'ctermbg': 1},
        \ 'start_time': l:start_time
        \ })
endfunction
