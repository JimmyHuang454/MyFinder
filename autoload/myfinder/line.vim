
function! myfinder#line#start() abort
  let l:start_time = reltime()
  let l:lines = getline(1, '$')
  let l:items = []
  let l:winid = win_getid()
  
  " Prepare items: {text, display, lnum, winid}
  for i in range(len(l:lines))
    call add(l:items, {
          \ 'text': l:lines[i],
          \ 'lnum': i + 1,
          \ 'winid': l:winid,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:LineFinderOpen'),
        \ 'open_with_new_tab': function('s:LineFinderOpenTab'),
        \ 'open_vertically': function('s:LineFinderOpenRight'),
        \ 'preview': function('s:LineFinderPreview'),
        \ }, {
        \ 'name': 'Lines',
        \ 'display': ['lnum', 'text'],
        \ 'name_color': {'guibg': '#d19a66', 'ctermbg': 3},
        \ 'filetype': &filetype,
        \ 'start_time': l:start_time
        \ })
endfunction

function! s:LineFinderOpen() dict
  call win_execute(self.selected.winid, self.selected.lnum)
  call win_execute(self.selected.winid, 'normal! zz')
  call self.quit()
endfunction

function! s:LineFinderPreview() dict
  if self.preview_winid == 0
    return
  endif
  let l:bufnr = winbufnr(self.selected.winid)
  if l:bufnr == -1
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif
  let l:lnum = self.selected.lnum
  let l:start = max([1, l:lnum - 20])
  let l:count = len(getbufline(l:bufnr, 1, '$'))
  let l:end = min([l:count, l:lnum + 20])
  let l:lines = getbufline(l:bufnr, l:start, l:end)
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(self.preview_winid, l:lines)
  let l:ft = getbufvar(l:bufnr, '&filetype', 'text')
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft . ' nonumber norelativenumber signcolumn=no foldcolumn=0 nofoldenable nolist')
  " Highlight the target line within preview
  let l:rel = l:lnum - l:start + 1
  let l:len = strlen(get(l:lines, l:rel - 1, ''))
  call win_execute(self.preview_winid, [
        \ 'call clearmatches()',
        \ 'highlight link FinderPreviewLine Search',
        \ "call matchaddpos('FinderPreviewLine', [[" . l:rel . ", 1, " . l:len . "]])",
        \ 'normal! ' . l:rel . 'G0zz',
        \ ])
endfunction

function! s:LineFinderOpenTab() dict
  let l:bufnr = winbufnr(self.selected.winid)
  if l:bufnr != -1
      call self.quit()
      execute 'tab split'
      execute 'buffer ' . l:bufnr
      execute self.selected.lnum
      normal! zz
  endif
endfunction

function! s:LineFinderOpenRight() dict
  let l:bufnr = winbufnr(self.selected.winid)
  if l:bufnr != -1
      call self.quit()
      execute 'rightbelow vertical split'
      execute 'buffer ' . l:bufnr
      execute self.selected.lnum
      normal! zz
  endif
endfunction
