
if !exists('s:usage')
  " In-memory usage tracking
  let s:usage = {}
endif

function! myfinder#master#start() abort
  let l:start_time = reltime()
  let l:defs = [
        \ {'text': 'Line',    'cmd': 'FinderLine',    'help': 'Search lines in current buffer'},
        \ {'text': 'Buffer',  'cmd': 'FinderBuffer',  'help': 'List and manage buffers'},
        \ {'text': 'Window',  'cmd': 'FinderWindow',  'help': 'Switch to another window'},
        \ {'text': 'Mark',    'cmd': 'FinderMark',    'help': 'Saved marks'},
        \ {'text': 'MRU',     'cmd': 'FinderMRU',     'help': 'Most Recently Used files'},
        \ {'text': 'Files',   'cmd': 'FinderFiles',   'help': 'Find files (Smart Git detection)'},
        \ {'text': 'GitLog',  'cmd': 'FinderGitLog',  'help': 'Search git log'},
        \ {'text': 'Colorscheme',  'cmd': 'FinderColorscheme',  'help': 'Choose and preview color schemes'},
        \ {'text': 'History', 'cmd': 'FinderHistory', 'help': 'Vim command history'},
        \ {'text': 'CocDiagnostics', 'cmd': 'FinderCocDiagnostics', 'help': 'Coc diagnostics'},
        \ {'text': 'CocCommands', 'cmd': 'FinderCocCommands', 'help': 'Coc commands'},
        \ {'text': 'CocExtensions', 'cmd': 'FinderCocExtensions', 'help': 'Manage Coc extensions'},
        \ {'text': 'CocSymbols', 'cmd': 'FinderCocSymbols', 'help': 'Coc document symbols'},
        \ {'text': 'CocWorkspaceSymbols', 'cmd': 'FinderCocWorkspaceSymbols', 'help': 'Coc workspace symbols'},
        \ {'text': 'CtagsFile', 'cmd': 'FinderCtagsFile', 'help': 'File Ctags'},
        \ {'text': 'CtagsWorkspace', 'cmd': 'FinderCtagsWorkspace', 'help': 'Workspace Ctags'},
        \ ]

  " Sort by usage count (descending)
  call sort(l:defs, {a, b -> get(s:usage, b.cmd, 0) - get(s:usage, a.cmd, 0)})
  
  let l:items = []
  for l:def in l:defs
    let l:count = get(s:usage, l:def.cmd, 0)
    let l:count_str = l:count > 0 ? printf('[%d] ', l:count) : ''
    call add(l:items, {
          \ 'text': l:def.text,
          \ 'help': l:def.help,
          \ 'count': l:count_str,
          \ 'cmd': l:def.cmd,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \'open': function('s:FinderOpen'),
        \}, 
        \{
        \ 'name': 'Master',
        \ 'display': ['text', 'help', 'count'],
        \ 'match_item': 'text',
        \ 'columns_hl': ['Type', 'Comment', 'Number'],
        \ 'align_columns': 2,
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
