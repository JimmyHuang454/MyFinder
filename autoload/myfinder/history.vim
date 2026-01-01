function! myfinder#history#start() abort
  let l:hist_list = []
  let l:count = histnr('cmd')
  for l:i in range(l:count, 1, -1)
    let l:cmd = histget('cmd', l:i)
    if !empty(l:cmd) && index(l:hist_list, l:cmd) == -1
      call add(l:hist_list, l:cmd)
    endif
  endfor

  let l:items = []
  for l:cmd in l:hist_list
    call add(l:items, {
          \ 'text': l:cmd,
          \ 'display': l:cmd,
          \ })
  endfor

  call myfinder#core#start(l:items, {
        \ 'open': function('s:Execute'),
        \ 'delete': function('s:Delete'),
        \ }, {
        \ 'name': 'History',
        \ 'name_color': {'guibg': '#e06c75', 'ctermbg': 1},
        \ 'filetype': 'vim',
        \ })
endfunction

function! s:Execute() dict
  call self.quit()
  call histadd('cmd', self.selected.text)
  call timer_start(10, {-> execute(self.selected.text)})
endfunction

function! s:Delete() dict
  let l:cmd = self.selected.text
  " Remove from vim history
  call histdel('cmd', '^\V' . escape(l:cmd, '\') . '$')
  
  " Remove from items list
  call filter(self.items, 'v:val.text !=# l:cmd')
  
  " Refresh the view
  call self.update_res()
endfunction
