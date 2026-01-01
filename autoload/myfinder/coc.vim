" autoload/myfinder/coc.vim

" --- Diagnostics ---
function! myfinder#coc#diagnostics() abort
  if !exists('*CocAction')
    call myfinder#core#echo('coc.nvim not installed', 'error')
    return
  endif
  let l:diags = CocAction('diagnosticList')
  if empty(l:diags)
    call myfinder#core#echo('No diagnostics found', 'warn')
    return
  endif

  let l:items = []
  for l:d in l:diags
    let l:file = get(l:d, 'file', '')
    let l:lnum = get(l:d, 'lnum', 0)
    let l:col = get(l:d, 'col', 0)
    let l:msg = get(l:d, 'message', '')
    let l:severity = get(l:d, 'severity', 'Unknown')
    
    let l:display = printf('%s %s:%d:%d %s', l:severity[0], fnamemodify(l:file, ':t'), l:lnum, l:col, l:msg)
    
    let l:item = {
          \ 'text': l:msg,
          \ 'display': l:display,
          \ 'path': l:file,
          \ 'line': l:lnum,
          \ 'col': l:col,
          \ 'prefix_len': len(l:display) - len(l:msg),
          \ }
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:OpenDiag'),
        \ 'preview': function('s:PreviewDiag'),
        \ 'copy_path': function('s:CopyDiagMsg'),
        \ }, { 
        \ 'name': 'Diagnostics',
        \ 'preview_enabled': 1,
        \ 'syntax': [
        \   {'match': '^[E]', 'link': 'ErrorMsg'},
        \   {'match': '^[W]', 'link': 'WarningMsg'},
        \   {'match': '^[I]', 'link': 'MoreMsg'},
        \   {'match': '^[H]', 'link': 'Special'},
        \   {'match': '\%>2l\s*\zs[^:]\+\ze:', 'link': 'Directory'},
        \   {'match': ':\d\+:\d\+', 'link': 'Number'},
        \ ],
        \ })
endfunction

function! s:CopyDiagMsg() dict
  let l:msg = get(self.selected, 'text', '')
  if !empty(l:msg)
    call setreg('+', l:msg)
    call setreg('*', l:msg)
    call myfinder#core#echo('Copied diagnostic: ' . l:msg, 'success')
  else
    call myfinder#core#echo('No message to copy', 'warn')
  endif
endfunction

function! s:OpenDiag() dict
  call self.quit()
  execute 'edit ' . fnameescape(self.selected.path)
  call cursor(self.selected.line, self.selected.col)
  normal! zz
endfunction

function! s:PreviewDiag() dict
  if self.preview_winid == 0
    return
  endif
  let l:path = get(self.selected, 'path', '')
  if empty(l:path) || !filereadable(l:path)
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif
  
  let l:lines = readfile(l:path, '', 500)
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(self.preview_winid, l:lines)
  
  let l:ft = myfinder#core#GuessFiletype(l:path)
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  
  let l:line = self.selected.line
  call win_execute(self.preview_winid, 'call matchadd("Search", "\\%" . ' . l:line . ' . "l")')
  call win_execute(self.preview_winid, 'normal! ' . l:line . 'Gzz')
endfunction

" --- Commands ---
function! myfinder#coc#commands() abort
  if !exists('*CocAction')
     call myfinder#core#echo('coc.nvim not installed', 'error')
     return
  endif
  let l:cmds = CocAction('commands')
  let l:items = []
  
  for l:cmd in l:cmds
     if type(l:cmd) == v:t_dict
        let l:id = get(l:cmd, 'id', '')
        let l:title = get(l:cmd, 'title', '')
     else
        let l:id = l:cmd
        let l:title = ''
     endif
     call add(l:items, {
        \ 'text': l:id,
        \ 'title': l:title,
        \ 'command': l:id,
        \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:RunCommand'),
        \ }, {
        \ 'name': 'Commands',
        \ 'display': ['text', 'title'],
        \ 'match_item': 'text',
        \ 'columns_hl': ['Type', 'Comment'],
        \ 'align_columns': 1,
        \ })
endfunction

function! s:RunCommand() dict
  call self.quit()
  if exists('*CocAction')
    call CocAction('runCommand', self.selected.command)
  else
    execute 'CocCommand ' . self.selected.command
  endif
endfunction

" --- Extensions ---
function! myfinder#coc#extensions() abort
  let l:start_time = reltime()
  if !exists('*CocAction')
    call myfinder#core#echo('coc.nvim not installed', 'error')
    return
  endif
  let l:exts = CocAction('extensionStats')
  if empty(l:exts)
    call myfinder#core#echo('No extensions found', 'warn')
    return
  endif
  

  let l:items = []
  for l:e in l:exts
    let l:state = get(l:e, 'state', 'unknown')
    let l:id = get(l:e, 'id', '')
    let l:version = get(l:e, 'version', '')
    let l:root = get(l:e, 'root', '')
    
    let l:state_icon = l:state ==# 'activated' ? '*' : (l:state ==# 'disabled' ? 'x' : '-')
    
    call add(l:items, {
          \ 'text': l:id,
          \ 'state_icon': l:state_icon,
          \ 'version': l:version,
          \ 'state': l:state,
          \ 'root': l:root,
          \ })
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:ToggleExt'),
        \ 'delete': function('s:UninstallExt'),
        \ }, { 
        \ 'name': 'Extensions',
        \ 'display': ['state_icon','text','version','root'],
        \ 'columns_hl': ['', 'Type', 'Number', 'Directory'],
        \ 'start_time': l:start_time,
        \ 'actions': {
        \   'toggle': function('s:ToggleExt'),
        \   'uninstall': function('s:UninstallExt'),
        \ },
        \ 'syntax': [
        \   {'match': '^\*', 'link': 'String'},
        \   {'match': '^x', 'link': 'ErrorMsg'},
        \   {'match': '^-', 'link': 'Comment'},
        \ ],
        \ })
endfunction

function! s:ToggleExt() dict
  let l:id = self.selected.id
  call CocAction('toggleExtension', l:id)
  " Small delay to allow coc to update state
  call timer_start(100, {-> s:RefreshExts(self)})
endfunction

function! s:UninstallExt() dict
  let l:id = self.selected.id
  call CocAction('uninstallExtension', l:id)
  call timer_start(100, {-> s:RefreshExts(self)})
endfunction

function! s:RefreshExts(ctx) abort
  let l:exts = CocAction('extensionStats')
  let l:items = s:BuildExtItems(l:exts)
  let a:ctx.items = l:items
  let a:ctx.matches = l:items
  let a:ctx.filter = ''
  call a:ctx.update_res()
endfunction

" --- Symbols (Document) ---
function! myfinder#coc#symbols() abort
  let l:start_time = reltime()
  if !exists('*CocAction')
    call myfinder#core#echo('coc.nvim not installed', 'error')
    return
  endif
  let l:symbols = CocAction('documentSymbols')
  if empty(l:symbols) || l:symbols == v:null
    call myfinder#core#echo('No symbols found', 'warn')
    return
  endif
  
  let l:items = s:ProcessSymbols(l:symbols, '', 0)
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:OpenSymbol'),
        \ 'preview': function('s:PreviewSymbol'),
        \ }, {
        \ 'name': 'Symbols',
        \ 'start_time': l:start_time,
        \ 'display': ['line', 'kind', 'text'],
        \ 'columns_hl': ['Number', 'Type', 'Identifier'],
        \ 'preview_enabled': 1,
        \ })
endfunction

function! s:ProcessSymbols(symbols, p, level) abort
  let l:items = []
  for l:sym in a:symbols
    let l:name = get(l:sym, 'text', '') . a:p
    let l:kind = get(l:sym, 'kind', 'Unknown')
    let l:range = get(l:sym, 'range', {})
    let l:start = get(l:range, 'start', {})
    let l:lnum = get(l:start, 'line', 0) + 1
    let l:col = get(l:start, 'character', 0) + 1
    
    let l:item = {
          \ 'text': l:name,
          \ 'path': expand('%:p'),
          \ 'line': l:lnum,
          \ 'col': l:col,
          \ 'kind': l:kind,
          \ }
    call add(l:items, l:item)
    
    if has_key(l:sym, 'children') && !empty(l:sym.children)
      call extend(l:items, s:ProcessSymbols(l:sym.children, l:name . '>', a:level + 1))
    endif
  endfor
  return l:items
endfunction

function! s:OpenSymbol() dict
  call self.quit()
  call cursor(self.selected.line, self.selected.col)
  normal! zz
endfunction

function! s:PreviewSymbol() dict
  if self.preview_winid == 0
    return
  endif
  
  let l:path = self.selected.path
  if empty(l:path) || !filereadable(l:path)
    call popup_settext(self.preview_winid, ['No preview available'])
    return
  endif
  
  let l:lines = readfile(l:path, '', 500)
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(self.preview_winid, l:lines)
  
  let l:ft = myfinder#core#GuessFiletype(l:path)
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
  
  let l:line = self.selected.line
  call win_execute(self.preview_winid, 'call clearmatches()')
  call win_execute(self.preview_winid, 'call matchadd("Search", "\\%" . ' . l:line . ' . "l")')
  call win_execute(self.preview_winid, 'normal! ' . l:line . 'G0zz')
endfunction

" --- Symbols (Workspace) ---
function! myfinder#coc#workspace_symbols() abort
  if !exists('*CocAction')
    call myfinder#core#echo('coc.nvim not installed', 'error')
    return
  endif
  
  " This requires user input for query
  let l:query = input('Workspace Symbols: ')
  if empty(l:query)
    return
  endif
  
  let l:symbols = CocAction('workspaceSymbols', l:query)
  if empty(l:symbols)
    call myfinder#core#echo('No symbols found', 'warn')
    return
  endif
  
  let l:items = []
  for l:sym in l:symbols
    let l:name = get(l:sym, 'name', '')
    let l:kind = get(l:sym, 'kind', 'Unknown')
    let l:path = get(l:sym, 'filepath', '')
    let l:lnum = get(l:sym, 'lnum', 1)
    let l:col = get(l:sym, 'col', 1)
    
    let l:display = printf('%-20s [%s] %s:%d', l:name, l:kind, fnamemodify(l:path, ':t'), l:lnum)
    
    let l:item = {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'path': l:path,
          \ 'line': l:lnum,
          \ 'col': l:col,
          \ 'kind': l:kind,
          \ 'prefix_len': len(l:display) - len(l:name),
          \ }
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'open': function('s:OpenWorkspaceSymbol'),
        \ 'preview': function('s:PreviewSymbol'),
        \ }, {
        \ 'name': 'WorkspaceSymbols',
        \ 'preview_enabled': 1,
        \ 'syntax': [
        \   {'match': '\%>2l^.\{-20\}', 'link': 'Identifier'},
        \   {'match': '\[.*\]', 'link': 'Type'},
        \   {'match': '\s\zs\S\+\ze:\d\+$', 'link': 'Directory'},
        \   {'match': ':\d\+$', 'link': 'Number'},
        \ ],
        \ })
endfunction

function! s:OpenWorkspaceSymbol() dict
  call self.quit()
  execute 'edit ' . fnameescape(self.selected.path)
  call cursor(self.selected.line, self.selected.col)
  normal! zz
endfunction
