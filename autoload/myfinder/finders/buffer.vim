function! myfinder#finders#buffer#start() abort
  let l:start_time = reltime()
  
  call myfinder#core#start(s:BuildBuffer(), {
        \ 'delete': function('s:Delete'),
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ }, {
        \ 'name': 'Buffers',
        \ 'name_color': {'guibg': '#61afef', 'ctermbg': 4},
        \ 'start_time': l:start_time
        \ })
endfunction

function! s:BuildBuffer() abort
  let l:buffers = getbufinfo({'buflisted': 1})
  let l:items = []
  for l:buf in l:buffers
    let l:name = empty(l:buf.name) ? '[No Name]' : l:buf.name
    
    " Make path relative to current working directory
    if !empty(l:buf.name) && l:buf.name[0] == '/'
      let l:rel_path = fnamemodify(l:buf.name, ':~:.')
      if l:rel_path[0] != '~' && l:rel_path[0] != '/'
        let l:name = l:rel_path
      endif
    endif
    
    let l:modified = l:buf.changed ? ' [+]' : ''
    let l:display = printf('%4d %s%s', l:buf.bufnr, l:name, l:modified)
    let l:bufnr = l:buf.bufnr
    
    let l:item = {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'bufnr': l:bufnr,
          \ 'name': l:name,
          \ 'filetype': getbufvar(l:bufnr, '&filetype'),
          \ }
    
    if !empty(l:buf.name)
       let l:item.path = l:buf.name
       let l:item.file_path = l:buf.name
    endif
    
    call add(l:items, l:item)
  endfor
  return l:items
endfunction

function! s:Open() dict
  call self.quit()
endfunction

function! s:Delete() dict
  " Delete the buffer
  let l:bufnr = self.selected.bufnr
  execute 'bdelete ' . l:bufnr
  
  " Refresh the buffer list
  let l:buffers = getbufinfo({'buflisted': 1})
  let l:new_items = []
  let l:cwd = getcwd()
  
  " Update the context with new items
  let self.items = s:BuildBuffer()
  call self.update_res()
endfunction
