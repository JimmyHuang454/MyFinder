function! myfinder#finders#window#start() abort
  let l:start_time = reltime()
  let l:wins = getwininfo()
  let l:cur_winid = win_getid()
  let l:prev_winid = get(s:, 'prev_winid', -1)
  let s:prev_winid = l:cur_winid
  call sort(l:wins, {a, b ->
        \ a.winid == l:prev_winid ? -1 :
        \ b.winid == l:prev_winid ? 1 :
        \ a.winid == l:cur_winid ? -1 :
        \ b.winid == l:cur_winid ? 1 :
        \ a.tabnr == b.tabnr ? a.winnr - b.winnr :
        \ a.tabnr - b.tabnr
        \ })
  let l:items = []
  
  for l:w in l:wins
    let l:bufname = bufname(l:w.bufnr)
    if empty(l:bufname)
      let l:bufname = '[No Name]'
    endif
    let l:cursor_line = getcurpos(l:w.winid)[1]
    let l:cursor_col = getcurpos(l:w.winid)[2]
    let l:item = {
          \ 'text': l:bufname,
          \ 'lnum': l:cursor_line,
          \ 'col': l:cursor_col,
          \ 'tabid': l:w.tabnr,
          \ 'winnr': l:w.winnr,
          \ 'winid': l:w.winid,
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
        \ 'display': ['tabid', 'winnr', 'lnum', 'text'],
        \ 'name_color': {'guibg': '#e06c75', 'ctermbg': 1},
        \ 'start_time': l:start_time
        \ })
endfunction
