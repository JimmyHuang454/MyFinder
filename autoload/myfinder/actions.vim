function! myfinder#actions#esc() dict
  call self.quit()
endfunction

function! myfinder#actions#open() dict
  call self.quit()
  let g:dd = self.selected
  call s:OpenItem(self.selected)
endfunction

function! myfinder#actions#open_with_new_tab() dict
  call self.quit()
  execute 'tab split'
  call s:OpenItem(self.selected)
endfunction

function! myfinder#actions#open_horizontally() dict
  call self.quit()
  execute 'split'
  call s:OpenItem(self.selected)
endfunction

function! myfinder#actions#open_vertically() dict
  call self.quit()
  execute 'rightbelow vertical split'
  call s:OpenItem(self.selected)
endfunction

function! myfinder#actions#bs() dict
  let self.filter = strcharpart(self.filter, 0, strchars(self.filter) - 1)
  call self.update_res()
endfunction

function! myfinder#actions#clear() dict
  let self.filter = ''
  call self.update_res()
endfunction

function! myfinder#actions#delete_a_word() dict
  let l:len = strchars(self.filter)
  if l:len > 0
    let l:new_filter = substitute(self.filter, '\v\S+\s*$', '', '')
    if l:new_filter == self.filter && l:len > 0
      let l:new_filter = strcharpart(self.filter, 0, l:len - 1)
    endif
    let self.filter = l:new_filter
    call self.update_res()
  endif
endfunction

function! myfinder#actions#copy_path() dict
  let l:path = ''
  if has_key(self.selected, 'path')
    let l:path = self.selected.path
  elseif has_key(self.selected, 'file')
    let l:path = self.selected.file
  elseif has_key(self.selected, 'file_path')
    let l:path = self.selected.file_path
  endif
  
  if !empty(l:path)
    let l:abs_path = fnamemodify(l:path, ':p')
    call setreg('+', l:abs_path)
    call setreg('*', l:abs_path)
    call myfinder#utils#echo('Copied: ' . l:abs_path, 'success')
  else
    call myfinder#utils#echo('No path to copy', 'warn')
  endif
endfunction

function! myfinder#actions#preview() dict
  if self.preview_winid == 0
    return
  endif

  let l:selected = self.selected
  let l:lines = []
  let l:lnum = get(l:selected,'lnum', 1)

  if has_key(l:selected, 'winid')
    let l:bufnr = winbufnr(l:selected['winid'])
    let l:lines = getbufline(l:bufnr, 1, '$')
  elseif has_key(l:selected, 'bufnr')
    let l:lines = getbufline(l:selected.bufnr, 1, '$')
  elseif has_key(l:selected,'file_path')
    let l:file_path = self.selected.file_path
    let l:lines = readfile(l:file_path, '', 500)
  elseif has_key(l:selected, 'path')
    let l:file_path = self.selected.path
    let l:lines = readfile(l:file_path, '', 500)
  endif

  if empty(l:lines)
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif

  call popup_settext(self.preview_winid, l:lines)

  let l:ft = ''
  if has_key(l:selected, 'filetype')
    let l:ft = l:selected['filetype']
  elseif has_key(self,'filetype')
    let l:ft = self.filetype
  endif

  if l:ft!=''
    call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  endif

  if l:lnum != 1
    call win_execute(self.preview_winid, [
          \ 'call clearmatches()',
          \ 'highlight link FinderPreviewLine Search',
          \ "call matchaddpos('FinderPreviewLine', [[" . l:lnum . ", 1, " . strlen(get(l:lines, l:lnum - 1, '')) . "]])",
          \ 'normal! ' . l:lnum . 'G0zz',
          \ ])
  endif
endfunction

" Helper function
function! s:OpenItem(item) abort
  if has_key(a:item, 'winid')
    call win_gotoid(a:item.winid)
  else
    if has_key(a:item, 'bufnr')
      execute 'buffer ' . a:item.bufnr
    else
      let l:path = ''
      if has_key(a:item, 'file_path')
        let l:path =  fnameescape(a:item.file_path)
      elseif has_key(a:item, 'path')
        let l:path =  fnameescape(a:item.path)
      endif
      if l:path != ''
        call myfinder#frequency#increase(l:path)
        if !has_key(a:item, 'bufnr') && !has_key(a:item, 'winid')
          execute 'edit ' . l:path
        endif
      endif
    endif
  endif

  if has_key(a:item, 'lnum')
    call cursor(a:item.lnum, get(a:item, 'col', 1))
    normal! zz
  endif
  redraw!
endfunction

function! s:GetPath(selected)
  if has_key(a:selected, 'path')
    return a:selected.path
  elseif has_key(a:selected, 'file')
    return a:selected.file
  elseif has_key(a:selected, 'file_path')
    return a:selected.file_path
  endif
  return ''
endfunction

function! s:RemoveItem(ctx, item)
  let l:idx = index(a:ctx.items, a:item)
  if l:idx != -1
    call remove(a:ctx.items, l:idx)
    call a:ctx.update_res()
  endif
endfunction

function! myfinder#actions#delete_file() dict
  let l:path = s:GetPath(self.selected)
  if empty(l:path)
    call myfinder#utils#echo('No file to delete', 'warn')
    return
  endif

  let l:msg = 'Delete ' . l:path . '?'
  if isdirectory(l:path)
     let l:msg = 'Delete directory ' . l:path . ' recursively?'
  endif

  let l:choice = confirm(l:msg, "&Yes\n&No", 2)
  if l:choice != 1
    return
  endif

  let l:res = 0
  if isdirectory(l:path)
    let l:res = delete(l:path, 'rf')
  else
    let l:res = delete(l:path)
  endif

  if l:res == 0
    call myfinder#utils#echo('Deleted: ' . l:path, 'success')
    call s:RemoveItem(self, self.selected)
  else
    call myfinder#utils#echo('Failed to delete: ' . l:path, 'error')
  endif
endfunction

function! myfinder#actions#create_file() dict
  let l:name = input('New file: ')
  if empty(l:name)
    return
  endif

  if filereadable(l:name)
    call myfinder#utils#echo('File already exists: ' . l:name, 'error')
    return
  endif

  if writefile([], l:name) == 0
    call myfinder#utils#echo('Created: ' . l:name, 'success')
    let l:abs_path = fnamemodify(l:name, ':p')
    let l:item = {
          \ 'text': l:name,
          \ 'path': l:abs_path,
          \ }
    call myfinder#utils#setFiletype(l:item, l:name)
    call add(self.items, l:item)
    call self.update_res()
  else
    call myfinder#utils#echo('Failed to create: ' . l:name, 'error')
  endif
endfunction

function! myfinder#actions#move_file() dict
  let l:path = s:GetPath(self.selected)
  if empty(l:path)
    return
  endif

  let l:new_name = input('Move/Rename to: ', l:path)
  if empty(l:new_name) || l:new_name ==# l:path
    return
  endif

  if rename(l:path, l:new_name) == 0
    call myfinder#utils#echo('Renamed to: ' . l:new_name, 'success')
    let l:abs_path = fnamemodify(l:new_name, ':p')
    let self.selected.path = l:abs_path
    
    if self.selected.text ==# l:path
       let self.selected.text = l:new_name
    endif
    
    call self.update_res()
  else
    call myfinder#utils#echo('Failed to move: ' . l:path, 'error')
  endif
endfunction

let s:clipboard = {'path': '', 'mode': ''}

function! myfinder#actions#copy_file() dict
  let l:path = s:GetPath(self.selected)
  if empty(l:path)
    return
  endif

  let s:clipboard.path = l:path
  let s:clipboard.mode = 'copy'
  call myfinder#utils#echo('Yanked: ' . l:path, 'success')
endfunction

function! myfinder#actions#paste_file() dict
  if empty(s:clipboard.path)
    call myfinder#utils#echo('Clipboard is empty', 'warn')
    return
  endif

  let l:source = s:clipboard.path
  if !filereadable(l:source) && !isdirectory(l:source)
    call myfinder#utils#echo('Source file not found: ' . l:source, 'error')
    return
  endif

  " Determine target directory
  let l:target_dir = ''
  let l:selected_path = s:GetPath(self.selected)
  
  if !empty(l:selected_path)
    if isdirectory(l:selected_path)
      let l:target_dir = l:selected_path
    else
      let l:target_dir = fnamemodify(l:selected_path, ':h')
    endif
  else
    let l:target_dir = getcwd()
  endif

  let l:basename = fnamemodify(l:source, ':t')
  let l:dest = l:target_dir . '/' . l:basename
  
  if filereadable(l:dest) || isdirectory(l:dest)
    let l:new_name = input('File exists. Rename to: ', l:dest)
    if empty(l:new_name) || l:new_name ==# l:dest
       " If user cancelled or didn't change name but file exists, abort to prevent overwrite without explicit confirmation
       " Or we can implement overwrite confirmation.
       " For safety, let's assume input cancellation means abort.
       " If user just pressed enter, it means overwrite? Dangerous.
       " Let's prompt for overwrite if name is same.
       if l:new_name ==# l:dest
         let l:choice = confirm('Overwrite ' . l:dest . '?', "&Yes\n&No", 2)
         if l:choice != 1
           return
         endif
       else
         return
       endif
    else
      let l:dest = l:new_name
    endif
  endif
  
  " Execute copy
  let l:cmd = printf('cp -r %s %s', shellescape(l:source), shellescape(l:dest))
  call system(l:cmd)
  
  if v:shell_error
    call myfinder#utils#echo('Failed to paste: ' . l:dest, 'error')
  else
    call myfinder#utils#echo('Pasted to: ' . l:dest, 'success')
    let l:abs_path = fnamemodify(l:dest, ':p')
    let l:item = {
          \ 'text': fnamemodify(l:abs_path, ':.'),
          \ 'path': l:abs_path,
          \ }
    call myfinder#utils#setFiletype(l:item, l:dest)
    call add(self.items, l:item)
    call self.update_res()
  endif
endfunction
