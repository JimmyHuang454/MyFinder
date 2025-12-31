
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
 
 function! myfinder#mark#toggle() abort
   let l:file = expand('%:p')
   if empty(l:file)
     return
   endif
   let l:line = line('.')
   let l:col = col('.')
   let l:text = getline('.')
   let l:marks = s:LoadMarks()
   let l:exists = 0
   let l:new_marks = []
   for l:mark in l:marks
     if l:mark.file ==# l:file && l:mark.line == l:line
       let l:exists = 1
       continue
     endif
     call add(l:new_marks, l:mark)
   endfor
   if l:exists
     call s:SaveMarks(l:new_marks)
     if has('signs')
       let l:buf = bufnr('%')
       let l:placed = sign_getplaced(l:buf, {'group': 'MyFinderMarkGroup'})
       if !empty(l:placed) && has_key(l:placed[0], 'signs')
         for l:s in l:placed[0].signs
           if get(l:s, 'lnum', -1) == l:line && get(l:s, 'name', '') ==# 'MyFinderMark'
             call sign_unplace('MyFinderMarkGroup', {'id': l:s.id, 'buffer': l:buf})
           endif
         endfor
       endif
     endif
     echo 'Mark removed.'
     return
   endif
   let l:mark = {
         \ 'file': l:file,
         \ 'line': l:line,
         \ 'col': l:col,
         \ 'text': l:text,
         \ 'time': strftime('%Y-%m-%d %H:%M:%S'),
         \ }
   call add(l:marks, l:mark)
   call s:SaveMarks(l:marks)
   if has('signs')
     call sign_place(0, 'MyFinderMarkGroup', 'MyFinderMark', bufnr('%'), {'lnum': l:line})
   endif
   call myfinder#core#echo('Mark added.', 'success')
 endfunction
 
 function! myfinder#mark#next() abort
   let l:file = expand('%:p')
   let l:cur = line('.')
   let l:marks = s:LoadMarks()
   let l:candidates = []
   for l:mark in l:marks
     if l:mark.file ==# l:file
       call add(l:candidates, l:mark.line)
     endif
   endfor
   if empty(l:candidates)
     call myfinder#core#echo('No marks in this buffer.', 'warn')
     return
   endif
   call sort(l:candidates)
   let l:target = 0
   for lnum in l:candidates
     if lnum > l:cur
       let l:target = lnum
       break
     endif
   endfor
   if l:target == 0
     let l:target = l:candidates[0]
   endif
   let l:col = 1
   for l:mark in l:marks
     if l:mark.file ==# l:file && l:mark.line == l:target
       let l:col = get(l:mark, 'col', 1)
       break
     endif
   endfor
   call cursor(l:target, l:col)
   normal! zz
 endfunction
 
 function! myfinder#mark#prev() abort
   let l:file = expand('%:p')
   let l:cur = line('.')
   let l:marks = s:LoadMarks()
   let l:candidates = []
   for l:mark in l:marks
     if l:mark.file ==# l:file
       call add(l:candidates, l:mark.line)
     endif
   endfor
   if empty(l:candidates)
     call myfinder#core#echo('No marks in this buffer.', 'warn')
     return
   endif
   call sort(l:candidates)
   let l:target = 0
   for lnum in l:candidates
     if lnum < l:cur
       let l:target = lnum
     else
       break
     endif
   endfor
   if l:target == 0
     let l:target = l:candidates[-1]
   endif
   let l:col = 1
   for l:mark in l:marks
     if l:mark.file ==# l:file && l:mark.line == l:target
       let l:col = get(l:mark, 'col', 1)
       break
     endif
   endfor
   call cursor(l:target, l:col)
   normal! zz
 endfunction
 
" Save marks to file
function! s:SaveMarks(marks) abort
  try
    call writefile([json_encode(a:marks)], s:marks_file)
  catch
    call myfinder#core#echo('Failed to save marks: ' . v:exception, 'error')
  endtry
endfunction

function! myfinder#mark#restore_signs_for_buffer() abort
  if !has('signs')
    return
  endif
  let l:file = expand('%:p')
  if empty(l:file)
    return
  endif
  let l:buf = bufnr('%')
  " Clear existing signs for this buffer/group to avoid duplicates
  call sign_unplace('MyFinderMarkGroup', {'buffer': l:buf})
  let l:marks = s:LoadMarks()
  for l:mark in l:marks
    if l:mark.file ==# l:file
      call sign_place(0, 'MyFinderMarkGroup', 'MyFinderMark', l:buf, {'lnum': l:mark.line})
    endif
  endfor
endfunction
if has('signs')
  call sign_define('MyFinderMark', {'text': 'M>', 'texthl': 'WarningMsg'})
endif

" Remove mark at current position
 function! myfinder#mark#remove() abort
   let l:file = expand('%:p')
   let l:line = line('.')
   let l:marks = s:LoadMarks()
   let l:new_marks = []
   let l:found = 0
  
  for l:mark in l:marks
    if l:mark.file ==# l:file && l:mark.line == l:line
      let l:found = 1
      continue
    endif
    call add(l:new_marks, l:mark)
  endfor
  
   if l:found
     call s:SaveMarks(l:new_marks)
     if has('signs')
       let l:buf = bufnr('%')
       let l:placed = sign_getplaced(l:buf, {'group': 'MyFinderMarkGroup'})
       if !empty(l:placed) && has_key(l:placed[0], 'signs')
         for l:s in l:placed[0].signs
           if get(l:s, 'lnum', -1) == l:line && get(l:s, 'name', '') ==# 'MyFinderMark'
             call sign_unplace('MyFinderMarkGroup', {'id': l:s.id, 'buffer': l:buf})
           endif
         endfor
       endif
     endif
     call myfinder#core#echo('Mark removed.', 'success')
   else
     call myfinder#core#echo('No mark found at current line.', 'warn')
   endif
endfunction

" Add a mark at current position
function! myfinder#mark#add() abort
  let l:file = expand('%:p')
  if empty(l:file)
    call myfinder#core#echo('Cannot mark [No Name] buffer', 'warn')
    return
  endif
  
  let l:line = line('.')
  let l:col = col('.')
  let l:text = getline('.')
  
  let l:marks = s:LoadMarks()
  
  " Check if mark already exists at this line to avoid duplicates
  for l:existing in l:marks
    if l:existing.file ==# l:file && l:existing.line == l:line
        call myfinder#core#echo('Mark already exists at this line.', 'warn')
        return
    endif
  endfor
  
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
  
  if has('signs')
    call sign_place(0, 'MyFinderMarkGroup', 'MyFinderMark', bufnr('%'), {'lnum': l:line})
  endif
  
  call myfinder#core#echo('Mark added: ' . fnamemodify(l:file, ':~') . ':' . l:line, 'success')
endfunction

function! myfinder#mark#start() abort
  let l:start_time = reltime()
  let l:marks = s:LoadMarks()
  
  if empty(l:marks)
    call myfinder#core#echo('No marks found. Use mm to add marks.', 'warn')
    return
  endif
  
  let l:items = []
  let l:idx = 0
  
  for l:mark in l:marks
    let l:rel_path = fnamemodify(l:mark.file, ':~:.')
    if l:rel_path[0] == '~' || l:rel_path[0] == '/'
      let l:rel_path = fnamemodify(l:mark.file, ':~')
    endif
    
    let l:display = printf('%s %4d: %s', l:rel_path, l:mark.line, l:mark.text)
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
        \ 'preview': function('s:MarkPreview'),
        \ }, {
        \ 'name': 'Marks',
        \ 'start_time': l:start_time
        \ })
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

function! s:MarkPreview() dict
  if self.preview_winid == 0
    return
  endif
  let l:path = get(self.selected, 'file', '')
  if empty(l:path) || !filereadable(l:path)
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif
  let l:lnum = get(self.selected, 'line', 1)
  let l:start = max([1, l:lnum - 20])
  let l:end = l:lnum + 20
  let l:head = readfile(l:path, '', l:end)
  let l:lines = l:head[l:start - 1 :]
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(self.preview_winid, l:lines)
  let l:ft = myfinder#core#GuessFiletype(l:path)
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  let l:rel = l:lnum - l:start + 1
  let l:len = strdisplaywidth(get(l:lines, l:rel - 1, ''))
  call win_execute(self.preview_winid, 'call clearmatches()')
  call win_execute(self.preview_winid, 'highlight link FinderPreviewLine Search')
  call win_execute(self.preview_winid, "call matchaddpos('FinderPreviewLine', [[" . l:rel . ", 1, " . l:len . "]])")
endfunction
