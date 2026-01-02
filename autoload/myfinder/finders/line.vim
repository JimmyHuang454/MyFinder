
function! myfinder#finders#line#start() abort
  let l:start_time = reltime()
  let l:lines = getline(1, '$')
  let l:items = []
  let l:winid = win_getid()
  let l:ft = &filetype

  for i in range(len(l:lines))
    call add(l:items, {
          \ 'text': l:lines[i],
          \ 'lnum': i + 1,
          \ 'winid': l:winid,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ }, {
        \ 'name': 'Lines',
        \ 'display': ['lnum', 'text'],
        \ 'name_color': {'guibg': '#d19a66', 'ctermbg': 3},
        \ 'filetype': l:ft,
        \ 'preview_enabled': 1,
        \ 'start_time': l:start_time
        \ })
endfunction
