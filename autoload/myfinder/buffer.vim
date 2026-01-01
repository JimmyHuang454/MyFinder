
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
    
    let l:item = {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'bufnr': l:buf.bufnr,
          \ 'name': l:name,
          \ 'prefix_len': len(l:display) - len(l:name),
          \ }
    
    if !empty(l:buf.name)
       let l:item.path = l:buf.name
    endif
    
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'delete': function('s:Delete'),
        \ 'preview': function('s:BufferPreview'),
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
    let l:item = {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'bufnr': l:buf.bufnr,
          \ 'name': l:name,
          \ 'prefix_len': len(l:display) - len(l:name),
          \ }
    if !empty(l:buf.name)
       let l:item.path = l:buf.name
    endif
    call add(l:new_items, l:item)
  endfor
  
  " Update the context with new items
  let self.items = l:new_items
  let self.filter = ''
  call self.update_res()
endfunction

function! s:BufferPreview() dict
  if self.preview_winid == 0
    return
  endif
  let l:bufnr = get(self.selected, 'bufnr', -1)
  if l:bufnr == -1
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif

  let l:lines = []
  if bufloaded(l:bufnr)
    let l:count = len(getbufline(l:bufnr, 1, '$'))
    let l:end = min([l:count, 200])
    let l:lines = getbufline(l:bufnr, 1, l:end)
  else
    let l:path = bufname(l:bufnr)
    if !empty(l:path) && filereadable(l:path)
      let l:lines = readfile(l:path, '', 200)
    endif
  endif

  if empty(l:lines)
    let l:lines = ['[Buffer not loaded and file not readable]']
  endif
  call popup_settext(self.preview_winid, l:lines)
  let l:ft = getbufvar(l:bufnr, '&filetype', 'text')
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
endfunction
