
function! myfinder#buffer#start() abort
  let l:start_time = reltime()
  let l:buffers = getbufinfo({'buflisted': 1})
  let l:items = []
  let l:cwd = getcwd()
  
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

    call add(l:items, {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'bufnr': l:buf.bufnr,
          \ 'name': l:name,
          \ 'prefix_len': len(l:display) - len(l:name),
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'delete': function('s:Delete'),
        \ }, {
        \ 'name': 'Buffers',
        \ 'name_color': {'guibg': '#61afef', 'ctermbg': 4},
        \ 'start_time': l:start_time
        \ })
endfunction

function! s:Delete() dict
  " Delete the buffer
  let l:bufnr = self.selected.bufnr
  execute 'bdelete ' . l:bufnr
  
  " Refresh the buffer list
  let l:buffers = getbufinfo({'buflisted': 1})
  let l:new_items = []
  let l:cwd = getcwd()
  
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
    let l:display = printf('%3d %s%s', l:buf.bufnr, l:name, l:modified)
    call add(l:new_items, {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'bufnr': l:buf.bufnr,
          \ 'name': l:name,
          \ 'prefix_len': len(l:display) - len(l:name),
          \ })
  endfor
  
  " Update the context with new items
  let self.items = l:new_items
  let self.filter = ''
  call self.update_res()
endfunction
