let s:original_colorscheme = ''

function! myfinder#colorscheme#start() abort
  let l:start_time = reltime()
  let s:original_colorscheme = get(g:, 'colors_name', 'default')
  
  let l:schemes = getcompletion('', 'color')
  let l:items = []
  for l:s in l:schemes
    call add(l:items, {'text': l:s, 'display': l:s})
  endfor

  call myfinder#core#start(l:items, {
        \ 'preview': function('s:Preview'),
        \ 'open': function('s:Open'),
        \ 'esc': function('s:Esc'),
        \ }, {
        \ 'name': 'Colorscheme',
        \ 'name_color': {'guibg': '#e5c07b', 'ctermbg': 3},
        \ 'start_time': l:start_time
        \ })
endfunction

function! s:Preview() dict
  try
    execute 'colorscheme ' . self.selected.text
  catch
  endtry

  if self.preview_winid != 0
    call popup_settext(self.preview_winid, ['Previewing: ' . self.selected.text])
  endif

  redraw
endfunction

function! s:Open() dict
  call self.quit()
  execute 'colorscheme ' . self.selected.text
  call myfinder#core#echo('Colorscheme set to ' . self.selected.text, 'success')
endfunction

function! s:Esc() dict
  call self.quit()
  execute 'colorscheme ' . s:original_colorscheme
endfunction
