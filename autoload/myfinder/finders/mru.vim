
function! s:Delete() dict
  if empty(self.selected)
    return
  endif
  let l:path = self.selected.path
  
  call myfinder#frequency#remove(l:path)
  
  let l:idx = -1
  for l:i in range(len(self.items))
    if self.items[l:i].path ==# l:path
      let l:idx = l:i
      break
    endif
  endfor
  
  if l:idx != -1
    call remove(self.items, l:idx)
    call self.update_res()
    call myfinder#utils#echo('Deleted: ' . fnamemodify(l:path, ':~:.'), 'success')
  endif
endfunction

function! myfinder#finders#mru#start() abort
  let l:start_time = reltime()
  let l:mru_dict = {}
  let l:items = []
  
  for l:file in v:oldfiles
    let l:abs_path = fnamemodify(l:file, ':p')
    if has_key(l:mru_dict, l:abs_path) || !filereadable(l:abs_path)
      continue
    endif

    let l:mru_dict[l:abs_path] = 1
    let l:display_text = fnamemodify(l:abs_path, ':~:.')
    let l:freq = myfinder#frequency#get(l:abs_path)
    if l:freq > 0
      let l:display_text .= ' [' . l:freq . ']'
    endif

    let l:item = {
          \ 'text': l:display_text,
          \ 'path': l:abs_path,
          \ }
    
    call myfinder#utils#setFiletype(l:item, l:file)

    if has_key(l:item,'bufnr')
      let l:item['text'] .= printf("*")
    endif
    
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'delete': function('s:Delete'),
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ 'copy_path': function('myfinder#actions#copy_path'),
        \ }, {
        \ 'name': 'MRU',
        \ 'name_color': {'guibg': '#c678dd', 'ctermbg': 5},
        \ 'start_time': l:start_time,
        \ 'display': ['text'],
        \ })
endfunction
