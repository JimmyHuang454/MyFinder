
if !exists('s:usage')
  " In-memory usage tracking
  let s:usage = {}
endif

function! s:DoNothing() dict
  echohl MoreMsg
  echo "[MyFinder-Master] Only Support Enter To Open."
  echohl None
endfunction

function! myfinder#master#start() abort
  let l:start_time = reltime()
  let l:defs = [
        \ {'text': 'Line',    'cmd': 'LineFinder',    'help': 'Search lines in current buffer'},
        \ {'text': 'Buffer',  'cmd': 'BufferFinder',  'help': 'List and manage buffers'},
        \ {'text': 'Window',  'cmd': 'WindowFinder',  'help': 'Switch to another window'},
        \ {'text': 'Mark',    'cmd': 'MarkFinder',    'help': 'Saved marks'},
        \ {'text': 'MRU',     'cmd': 'MRUFinder',     'help': 'Most Recently Used files'},
        \ {'text': 'Files',   'cmd': 'FilesFinder',   'help': 'Find files (Smart Git detection)'},
        \ {'text': 'GitLog',  'cmd': 'GitLogFinder',  'help': 'Search git log'},
        \ {'text': 'Colorscheme',  'cmd': 'ColorschemeFinder',  'help': 'Choose and preview color schemes'},
        \ ]
  
  " Sort by usage count (descending)
  call sort(l:defs, {a, b -> get(s:usage, b.cmd, 0) - get(s:usage, a.cmd, 0)})
  
  let l:items = []
  for l:def in l:defs
    let l:count = get(s:usage, l:def.cmd, 0)
    let l:count_str = l:count > 0 ? printf('[%d] ', l:count) : ''
    let l:display = printf('%-13s %s %s', l:def.text, l:def.help, l:count_str)
    call add(l:items, {
          \ 'text': l:def.text,
          \ 'display': l:display,
          \ 'cmd': l:def.cmd,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \'open': function('s:FinderOpen'),
        \     'open_tab': function('s:DoNothing'),
        \'open_left': function('s:DoNothing'),'open_right': function('s:DoNothing'),
        \}, 
        \{
        \ 'name': 'Master',
        \ 'syntax': [
        \   {'match': '\%>2l\%>0v.*\%<14v', 'link': 'Type'},
        \   {'match': '\%>2l\%>13v.*',       'link': 'Comment', 'contains': 'Number'},
        \   {'match': '\[\d\+\]\s*$',        'link': 'Number',  'contained': 1},
        \ ],
        \ 'start_time': l:start_time
        \ })
endfunction

function! s:FinderOpen() dict
  let l:cmd = self.selected.cmd
  " Increment usage count
  let s:usage[l:cmd] = get(s:usage, l:cmd, 0) + 1
  call self.quit()
  call timer_start(10, {-> execute(l:cmd)})
endfunction
