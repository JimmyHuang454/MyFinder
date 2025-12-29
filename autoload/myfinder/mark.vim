
let s:marks_file = expand('~/.vim_marks.json')

" Load marks from file
function! s:LoadMarks() abort
  if !filereadable(s:marks_file)
    return []
  endif
  
  try
    let l:content = join(readfile(s:marks_file), "\n")
    return json_decode(l:content)
  catch
    return []
  endtry
endfunction

" Save marks to file
function! s:SaveMarks(marks) abort
  try
    call writefile([json_encode(a:marks)], s:marks_file)
  catch
    echoerr 'Failed to save marks: ' . v:exception
  endtry
endfunction

" Add a mark at current position
function! myfinder#mark#add() abort
  let l:file = expand('%:p')
  if empty(l:file)
    echohl WarningMsg
    echo 'Cannot mark [No Name] buffer'
    echohl None
    return
  endif
  
  let l:line = line('.')
  let l:col = col('.')
  let l:text = getline('.')
  
  let l:marks = s:LoadMarks()
  
  " Create new mark
  let l:mark = {
        \ 'file': l:file,
        \ 'line': l:line,
        \ 'col': l:col,
        \ 'text': l:text,
        \ 'time': strftime('%Y-%m-%d %H:%M:%S'),
        \ }
  
  call add(l:marks, l:mark)
  call s:SaveMarks(l:marks)
  
  echohl MoreMsg
  echo 'Mark added: ' . fnamemodify(l:file, ':~') . ':' . l:line
  echohl None
endfunction

function! myfinder#mark#start() abort
  let l:marks = s:LoadMarks()
  
  if empty(l:marks)
    echohl WarningMsg
    echo 'No marks found. Use mm to add marks.'
    echohl None
    return
  endif
  
  let l:items = []
  let l:idx = 0
  
  for l:mark in l:marks
    let l:rel_path = fnamemodify(l:mark.file, ':~:.')
    if l:rel_path[0] == '~' || l:rel_path[0] == '/'
      let l:rel_path = fnamemodify(l:mark.file, ':~')
    endif
    
    let l:display = printf('%s:%d  %s', l:rel_path, l:mark.line, l:mark.text)
    call add(l:items, {
          \ 'text': l:display,
          \ 'display': l:display,
          \ 'file': l:mark.file,
          \ 'line': l:mark.line,
          \ 'col': l:mark.col,
          \ 'index': l:idx,
          \ })
    let l:idx += 1
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'delete': function('s:Delete'),
        \ }, {'name': 'Marks'})
endfunction

function! s:Delete() dict
  " Load current marks
  let l:marks = s:LoadMarks()
  
  " Remove the selected mark
  call remove(l:marks, self.selected.index)
  
  " Save updated marks
  call s:SaveMarks(l:marks)
  
  " Refresh the mark list
  let l:new_items = []
  let l:idx = 0
  
  for l:mark in l:marks
    let l:rel_path = fnamemodify(l:mark.file, ':~:.')
    if l:rel_path[0] == '~' || l:rel_path[0] == '/'
      let l:rel_path = fnamemodify(l:mark.file, ':~')
    endif
    
    let l:display = printf('%s:%d  %s', l:rel_path, l:mark.line, l:mark.text)
    call add(l:new_items, {
          \ 'text': l:display,
          \ 'display': l:display,
          \ 'file': l:mark.file,
          \ 'line': l:mark.line,
          \ 'col': l:mark.col,
          \ 'index': l:idx,
          \ })
    let l:idx += 1
  endfor
  
  " Update the context with new items
  let self.items = l:new_items
  let self.filter = ''
  call self.update_res()
endfunction
