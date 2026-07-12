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
  let l:abs_path = ''
  if has_key(self.selected, 'abs_path')
    let l:abs_path = self.selected.abs_path
  endif
  
  if !empty(l:abs_path)
    call setreg('+', l:abs_path)
    call setreg('*', l:abs_path)
    call myfinder#utils#echo('Copied: ' . l:abs_path, 'success')
  else
    call myfinder#utils#echo('No abs_path to copy', 'warn')
  endif
endfunction

function! myfinder#actions#preview() dict
  if self.preview_winid == 0
    return
  endif

  let l:selected = self.selected
  let l:lines = []
  let l:abs_path = s:GetAbsPath(l:selected)
  let l:bufnr = has_key(l:selected, 'bufnr') ? l:selected.bufnr : -1
  if has_key(l:selected, 'winid')
    let l:bufnr = winbufnr(l:selected.winid)
  elseif l:bufnr <= 0 && !empty(l:abs_path)
    let l:bufnr = bufnr(l:abs_path)
  endif

  " Fall back to Vim's last cursor position for a previously opened buffer.
  let l:has_lnum = has_key(l:selected, 'lnum')
  let l:lnum = get(l:selected,'lnum', 1)
  if !l:has_lnum && l:bufnr > 0
    let l:bufinfo = getbufinfo(l:bufnr)
    if !empty(l:bufinfo) && get(l:bufinfo[0], 'lnum', 0) > 0
      let l:lnum = l:bufinfo[0].lnum
      let l:has_lnum = 1
    endif
  endif

  let l:title_parts = []
  let l:title_path = l:abs_path
  if empty(l:title_path) && l:bufnr > 0
    let l:title_path = bufname(l:bufnr)
  endif
  if !empty(l:title_path)
    call add(l:title_parts, fnamemodify(l:title_path, ':p'))
  endif
  if l:has_lnum
    call add(l:title_parts, 'lnum:' . l:lnum)
  endif
  let l:winnr = get(l:selected, 'winnr', 0)
  if l:winnr <= 0 && has_key(l:selected, 'winid')
    let l:winnr = win_id2win(l:selected.winid)
  elseif l:winnr <= 0 && l:bufnr > 0
    let l:bufinfo = getbufinfo(l:bufnr)
    if !empty(l:bufinfo) && !empty(l:bufinfo[0].windows)
      let l:winnr = win_id2win(l:bufinfo[0].windows[0])
    endif
  endif
  if l:winnr > 0
    call add(l:title_parts, 'winnr:' . l:winnr)
  endif
  if l:bufnr > 0
    call add(l:title_parts, 'bufnr:' . l:bufnr)
  endif
  call popup_setoptions(self.preview_winid, {
        \ 'title': empty(l:title_parts) ? ' Preview ' : ' ' . join(l:title_parts, ' | ') . ' '
        \ })

  let l:preview_lnum = l:lnum
  let l:start_lnum = 1
  let l:end_lnum = '$'
  if l:has_lnum
    let l:wininfo = getwininfo(self.preview_winid)
    let l:context = empty(l:wininfo) ? 20 : max([5, l:wininfo[0].height / 2])
    let l:start_lnum = max([1, l:lnum - l:context])
    let l:end_lnum = l:lnum + l:context
    let l:preview_lnum = l:lnum - l:start_lnum + 1
  endif
  if l:bufnr > 0 && bufloaded(l:bufnr)
    let l:lines = getbufline(l:bufnr, l:start_lnum, l:end_lnum)
  else
    if l:abs_path != ''
      if l:has_lnum
        let l:lines = readfile(l:abs_path, '', l:end_lnum)
        let l:lines = l:lines[l:start_lnum - 1 :]
      else
        let l:lines = readfile(l:abs_path, '', 500)
      endif
    endif
  endif

  call myfinder#utils#setFiletype(self.selected, l:abs_path)

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

  if l:ft != ''
    call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  endif

  if l:has_lnum
    call win_execute(self.preview_winid, [
          \ 'call clearmatches()',
          \ 'highlight link FinderPreviewLine Search',
          \ "call matchaddpos('FinderPreviewLine', [[" . l:preview_lnum . ", 1, " . strlen(get(l:lines, l:preview_lnum - 1, '')) . "]])",
          \ 'normal! ' . l:preview_lnum . 'G0zz',
          \ ])
  endif
endfunction

function! s:OpenItem(item) abort
  if has_key(a:item, 'winid')
    call win_gotoid(a:item.winid)
  else
    if has_key(a:item, 'bufnr')
      execute 'buffer ' . a:item.bufnr
    else
      let l:abs_path =  s:GetAbsPath(a:item)
      if l:abs_path != ''
        call myfinder#frequency#increase(l:abs_path)
        execute 'edit ' . l:abs_path
      endif
    endif
  endif

  if has_key(a:item, 'lnum')
    call cursor(a:item.lnum, get(a:item, 'col', 1))
    normal! zz
  endif
  redraw!
endfunction

function! s:GetAbsPath(selected)
  let l:res = ''
  if has_key(a:selected, 'abs_path')
    let l:res = a:selected.abs_path
  elseif has_key(a:selected, 'file')
    let l:res = a:selected.file
  elseif has_key(a:selected, 'path')
    let l:res = a:selected.path
  elseif has_key(a:selected, 'file_path')
    let l:res = a:selected.file_path
  endif
  return fnameescape(l:res)
endfunction

function! s:RemoveItem(ctx, item)
  let l:idx = index(a:ctx.items, a:item)
  if l:idx != -1
    call remove(a:ctx.items, l:idx)
    call a:ctx.update_res()
  endif
endfunction

function! myfinder#actions#delete_file() dict
  let l:abs_path = s:GetAbsPath(self.selected)
  if empty(l:abs_path)
    call myfinder#utils#echo('No file to delete', 'warn')
    return
  endif

  let l:msg = 'Delete ' . l:abs_path . '?'
  if isdirectory(l:abs_path)
     let l:msg = 'Delete directory ' . l:abs_path . ' recursively?'
  endif

  let l:choice = confirm(l:msg, "&Yes\n&No", 2)
  if l:choice != 1
    return
  endif

  let l:res = 0
  if isdirectory(l:abs_path)
    let l:res = delete(l:abs_path, 'rf')
  else
    let l:res = delete(l:abs_path)
  endif

  if l:res == 0
    call myfinder#utils#echo('Deleted: ' . l:abs_path, 'success')
    call s:RemoveItem(self, self.selected)
  else
    call myfinder#utils#echo('Failed to delete: ' . l:abs_path, 'error')
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
          \ 'abs_path': l:abs_path,
          \ }
    call myfinder#utils#setFiletype(l:item, l:name)
    call add(self.items, l:item)
    call self.update_res()
  else
    call myfinder#utils#echo('Failed to create: ' . l:name, 'error')
  endif
endfunction

function! myfinder#actions#move_file() dict
  let l:abs_path = s:GetAbsPath(self.selected)
  if empty(l:abs_path)
    return
  endif

  let l:new_name = input('Move/Rename to: ', l:abs_path)
  if empty(l:new_name) || l:new_name ==# l:abs_path
    return
  endif

  if rename(l:abs_path, l:new_name) == 0
    call myfinder#utils#echo('Renamed to: ' . l:new_name, 'success')
    let l:abs_path = fnamemodify(l:new_name, ':p')
    let self.selected.abs_path = l:abs_path
    
    if self.selected.text ==# l:abs_path
       let self.selected.text = l:new_name
    endif
    
    call self.update_res()
  else
    call myfinder#utils#echo('Failed to move: ' . l:abs_path, 'error')
  endif
endfunction

let s:clipboard = {'abs_path': '', 'mode': ''}

function! myfinder#actions#copy_file() dict
  let l:abs_path = s:GetAbsPath(self.selected)
  if empty(l:abs_path)
    return
  endif

  let s:clipboard.abs_path = l:abs_path
  let s:clipboard.mode = 'copy'
  call myfinder#utils#echo('Yanked: ' . l:abs_path, 'success')
endfunction

function! myfinder#actions#paste_file() dict
  if empty(s:clipboard.abs_path)
    call myfinder#utils#echo('Clipboard is empty', 'warn')
    return
  endif

  let l:source = s:clipboard.abs_path
  if !filereadable(l:source) && !isdirectory(l:source)
    call myfinder#utils#echo('Source file not found: ' . l:source, 'error')
    return
  endif

  " Determine target directory
  let l:target_dir = ''
  let l:selected_path = s:GetAbsPath(self.selected)
  
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
          \ 'abs_path': l:abs_path,
          \ }
    call myfinder#utils#setFiletype(l:item, l:dest)
    call add(self.items, l:item)
    call self.update_res()
  endif
endfunction
