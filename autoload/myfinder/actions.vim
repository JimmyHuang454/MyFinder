function! myfinder#actions#esc() dict
  call self.quit()
endfunction

function! myfinder#actions#open() dict
  call self.quit()
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
  endif

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

  if has_key(a:item, 'lnum')
    call cursor(a:item.lnum, get(a:item, 'col', 1))
    normal! zz
  endif
  redraw!
endfunction
