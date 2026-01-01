function! s:OpenTab() dict
  call self.quit()
  let l:bufnr = winbufnr(self.selected.target_winid)
  if l:bufnr != -1
    execute 'tab split'
    execute 'buffer ' . l:bufnr
  endif
endfunction

function! s:OpenRight() dict
  call self.quit()
  let l:bufnr = winbufnr(self.selected.target_winid)
  if l:bufnr != -1
    execute 'rightbelow vertical split'
    execute 'buffer ' . l:bufnr
  endif
endfunction

function! myfinder#window#start() abort
  let l:start_time = reltime()
  let l:wins = getwininfo()
  let l:items = []
  
  for l:w in l:wins
    let l:bufname = bufname(l:w.bufnr)
    if empty(l:bufname)
      let l:bufname = '[No Name]'
    endif
    let l:text = printf('%3d:%-3d %s', l:w.tabnr, l:w.winnr, l:bufname)
    let l:item = {
          \ 'text': l:text,
          \ 'display': l:text,
          \ 'target_winid': l:w.winid,
          \ 'lnum': 1,
          \ }
    if !empty(l:bufname) && l:bufname != '[No Name]'
        let l:item.path = l:bufname
    endif
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open_with_new_tab': function('s:OpenTab'),
        \ 'open_vertically': function('s:OpenRight'),
        \ }, {
        \ 'name': 'Windows',
        \ 'name_color': {'guibg': '#e06c75', 'ctermbg': 1},
        \ 'start_time': l:start_time
        \ })
endfunction
