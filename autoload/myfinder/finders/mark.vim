
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
 
 function! myfinder#finders#mark#toggle() abort
   let l:abs_path = expand('%:p')
   if empty(l:abs_path)
     return
   endif
   let l:lnum = line('.')
   let l:col = col('.')
   let l:text = getline('.')
   let l:marks = s:LoadMarks()
   let l:exists = 0
   let l:new_marks = []
   for l:mark in l:marks
     if l:mark.abs_path ==# l:abs_path && l:mark.lnum == l:lnum
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
           if get(l:s, 'lnum', -1) == l:lnum && get(l:s, 'name', '') ==# 'MyFinderMark'
             call sign_unplace('MyFinderMarkGroup', {'id': l:s.id, 'buffer': l:buf})
           endif
         endfor
       endif
     endif
     echo 'Mark removed.'
     return
   endif
   let l:mark = {
         \ 'abs_path': l:abs_path,
         \ 'lnum': l:lnum,
         \ 'col': l:col,
         \ 'text': l:text,
         \ 'time': strftime('%Y-%m-%d %H:%M:%S'),
         \ }
   call add(l:marks, l:mark)
   call s:SaveMarks(l:marks)
   if has('signs')
     call sign_place(0, 'MyFinderMarkGroup', 'MyFinderMark', bufnr('%'), {'lnum': l:lnum})
   endif
   call myfinder#utils#echo('Mark added.', 'success')
 endfunction
 
 function! myfinder#finders#mark#next() abort
   let l:abs_path = expand('%:p')
   let l:cur = line('.')
   let l:marks = s:LoadMarks()
   let l:candidates = []
   for l:mark in l:marks
     if l:mark.abs_path ==# l:abs_path
       call add(l:candidates, l:mark.lnum)
     endif
   endfor
   if empty(l:candidates)
     call myfinder#utils#echo('No marks in this buffer.', 'warn')
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
     if l:mark.abs_path ==# l:abs_path && l:mark.lnum == l:target
       let l:col = get(l:mark, 'col', 1)
       break
     endif
   endfor
   call cursor(l:target, l:col)
   normal! zz
 endfunction
 
 function! myfinder#finders#mark#prev() abort
   let l:abs_path = expand('%:p')
   let l:cur = line('.')
   let l:marks = s:LoadMarks()
   let l:candidates = []
   for l:mark in l:marks
     if l:mark.abs_path ==# l:abs_path
       call add(l:candidates, l:mark.lnum)
     endif
   endfor
   if empty(l:candidates)
     call myfinder#utils#echo('No marks in this buffer.', 'warn')
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
     if l:mark.abs_path ==# l:abs_path && l:mark.lnum == l:target
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
    call myfinder#utils#echo('Failed to save marks: ' . v:exception, 'error')
  endtry
endfunction

function! myfinder#finders#mark#restore_signs_for_buffer() abort
  if !has('signs')
    return
  endif
  let l:abs_path = expand('%:p')
  if empty(l:abs_path)
    return
  endif
  let l:buf = bufnr('%')
  " Clear existing signs for this buffer/group to avoid duplicates
  call sign_unplace('MyFinderMarkGroup', {'buffer': l:buf})
  let l:marks = s:LoadMarks()
  for l:mark in l:marks
    if l:mark.abs_path ==# l:abs_path
      call sign_place(0, 'MyFinderMarkGroup', 'MyFinderMark', l:buf, {'lnum': l:mark.lnum})
    endif
  endfor
endfunction
if has('signs')
  call sign_define('MyFinderMark', {'text': 'M>', 'texthl': 'WarningMsg'})
endif

" Remove mark at current position
 function! myfinder#finders#mark#remove() abort
   let l:abs_path = expand('%:p')
   let l:lnum = line('.')
   let l:marks = s:LoadMarks()
   let l:new_marks = []
   let l:found = 0
  
  for l:mark in l:marks
    if l:mark.abs_path ==# l:abs_path && l:mark.lnum == l:lnum
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
           if get(l:s, 'lnum', -1) == l:lnum && get(l:s, 'name', '') ==# 'MyFinderMark'
             call sign_unplace('MyFinderMarkGroup', {'id': l:s.id, 'buffer': l:buf})
           endif
         endfor
       endif
     endif
     call myfinder#utils#echo('Mark removed.', 'success')
   else
     call myfinder#utils#echo('No mark found at current line.', 'warn')
   endif
endfunction

" Add a mark at current position
function! myfinder#finders#mark#add() abort
  let l:abs_path = expand('%:p')
  if empty(l:abs_path)
    call myfinder#utils#echo('Cannot mark [No Name] buffer', 'warn')
    return
  endif
  
  let l:lnum = line('.')
  let l:col = col('.')
  let l:text = getline('.')
  
  let l:marks = s:LoadMarks()
  
  " Check if mark already exists at this lnum to avoid duplicates
  for l:existing in l:marks
    if l:existing.abs_path ==# l:abs_path && l:existing.lnum == l:lnum
        call myfinder#utils#echo('Mark already exists at this line.', 'warn')
        return
    endif
  endfor
  
  " Create new mark
  let l:mark = {
        \ 'abs_path': l:abs_path,
        \ 'lnum': l:lnum,
        \ 'col': l:col,
        \ 'text': l:text,
        \ 'time': strftime('%Y-%m-%d %H:%M:%S'),
        \ }
  
  call add(l:marks, l:mark)
  call s:SaveMarks(l:marks)
  
  if has('signs')
    call sign_place(0, 'MyFinderMarkGroup', 'MyFinderMark', bufnr('%'), {'lnum': l:lnum})
  endif
  
  call myfinder#utils#echo('Mark added: ' . fnamemodify(l:abs_path, ':~') . ':' . l:lnum, 'success')
endfunction

function! myfinder#finders#mark#start() abort
  let l:start_time = reltime()
  let l:marks = s:LoadMarks()
  let l:items = []
  
  for l:mark in l:marks
    let l:text = l:mark.text
    let l:abs_path = l:mark.abs_path
    
    let l:freq = myfinder#frequency#get(l:abs_path)
    if l:freq > 0
        let l:text .= ' [' . l:freq . ']'
    endif

    let l:item = {
          \ 'text': l:text,
          \ 'p': fnamemodify(l:abs_path, ':~:.'),
          \ 'path': l:abs_path,
          \ 'lnum': l:mark.lnum,
          \ 'col': l:mark.col,
          \ }
    call myfinder#utils#setFiletype(l:item, l:abs_path)
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'delete': function('s:DeleteMark'),
        \ 'preview': function('myfinder#actions#preview'),
        \ 'open': function('myfinder#actions#open'),
        \ 'open_with_new_tab': function('myfinder#actions#open_with_new_tab'),
        \ 'open_vertically': function('myfinder#actions#open_vertically'),
        \ 'open_horizontally': function('myfinder#actions#open_horizontally'),
        \ }, {
        \ 'name': 'Marks',
        \ 'display': ['p','lnum','text'],
        \ 'columns_hl': ['Type','Number','Identifier'],
        \ 'name_color': {'guibg': '#98c379', 'ctermbg': 2},
        \ 'start_time': l:start_time,
        \ })
endfunction

function! s:DeleteMark() dict
  let l:path = self.selected.path
  let l:lnum = self.selected.lnum
  let l:marks = s:LoadMarks()
  let l:new_marks = []
  
  for l:mark in l:marks
    if l:mark.abs_path ==# l:path && l:mark.lnum == l:lnum
      continue
    endif
    call add(l:new_marks, l:mark)
  endfor
  
  call s:SaveMarks(l:new_marks)
  
  if has('signs')
    let l:buf = bufnr(l:path)
    if l:buf != -1
      let l:placed = sign_getplaced(l:buf, {'group': 'MyFinderMarkGroup'})
      if !empty(l:placed) && has_key(l:placed[0], 'signs')
        for l:s in l:placed[0].signs
          if get(l:s, 'lnum', -1) == l:lnum && get(l:s, 'name', '') ==# 'MyFinderMark'
            call sign_unplace('MyFinderMarkGroup', {'id': l:s.id, 'buffer': l:buf})
          endif
        endfor
      endif
    endif
  endif
  
  " Refresh list
  let l:items = []
  for l:mark in l:new_marks
    let l:display = printf('%s:%d:%d  %s', fnamemodify(l:mark.abs_path, ':t'), l:mark.lnum, l:mark.col, trim(l:mark.text))
    call add(l:items, {
          \ 'text': l:mark.text,
          \ 'display': l:display,
          \ 'path': l:mark.abs_path,
          \ 'file_path': l:mark.abs_path,
          \ 'lnum': l:mark.lnum,
          \ 'col': l:mark.col,
          \ 'prefix_len': len(l:display) - len(trim(l:mark.text)),
          \ })
  endfor
  
  let self.items = l:items
  let self.filter = ''
  call self.update_res()
endfunction
