
function! myfinder#line#start() abort
  let l:lines = getline(1, '$')
  let l:items = []
  let l:winid = win_getid()
  
  " Prepare items: {text, display, lnum, winid}
  for i in range(len(l:lines))
    let l:prefix = printf('%4s ', i + 1)
    call add(l:items, {
          \ 'text': l:lines[i],
          \ 'display': l:prefix . l:lines[i],
          \ 'lnum': i + 1,
          \ 'winid': l:winid,
          \ 'prefix_len': len(l:prefix)
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:LineFinderOpen'),
        \ 'open_tab': function('s:LineFinderOpenTab'),
        \ 'open_left': function('s:LineFinderOpenLeft'),
        \ 'open_right': function('s:LineFinderOpenRight'),
        \ }, {
        \ 'name': 'Lines',
        \ 'name_color': {'guibg': '#d19a66', 'ctermbg': 3},
        \ 'filetype': &filetype,
        \ })
endfunction

function! s:LineFinderOpen() dict
  call win_execute(self.selected.winid, self.selected.lnum)
  call win_execute(self.selected.winid, 'normal! zz')
  call self.quit()
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

function! s:LineFinderOpenLeft() dict
  let l:bufnr = winbufnr(self.selected.winid)
  if l:bufnr != -1
      call self.quit()
      execute 'vsplit'
      execute 'buffer ' . l:bufnr
      execute self.selected.lnum
      normal! zz
  endif
endfunction

function! s:LineFinderOpenRight() dict
  let l:bufnr = winbufnr(self.selected.winid)
  if l:bufnr != -1
      call self.quit()
      execute 'vsplit'
      execute 'buffer ' . l:bufnr
      execute self.selected.lnum
      normal! zz
  endif
endfunction
