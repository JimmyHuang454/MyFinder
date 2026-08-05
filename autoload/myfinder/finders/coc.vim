" autoload/myfinder/coc.vim

if !exists('g:myfinder_coc_timeout')
  let g:myfinder_coc_timeout = 5000
endif

function! s:RequestTick(state, timer) abort
  if a:state.done
    call timer_stop(a:timer)
    return
  endif
  let l:elapsed = reltimefloat(reltime(a:state.start_time))
  if g:myfinder_coc_timeout > 0 && l:elapsed * 1000 >= g:myfinder_coc_timeout
    let a:state.done = 1
    call timer_stop(a:timer)
    redraw
    call myfinder#utils#echo(printf('%s timed out after %.3fs', a:state.label, l:elapsed), 'error')
    return
  endif
  redraw
  echohl MoreMsg
  echon printf('[MyFinder] %s... %.3fs', a:state.label, l:elapsed)
  echohl None
endfunction

function! s:RequestDone(state, err, result) abort
  if a:state.done
    return
  endif
  let l:elapsed = reltimefloat(reltime(a:state.start_time))
  if g:myfinder_coc_timeout > 0 && l:elapsed * 1000 >= g:myfinder_coc_timeout
    let a:state.done = 1
    call timer_stop(a:state.timer)
    redraw
    call myfinder#utils#echo(printf('%s timed out after %.3fs', a:state.label, l:elapsed), 'error')
    return
  endif
  let a:state.done = 1
  call timer_stop(a:state.timer)
  redraw
  echo ''
  if !empty(a:err)
    call myfinder#utils#echo(a:state.label . ': ' . string(a:err), 'error')
    return
  endif
  call call(a:state.callback, [a:result, a:state.start_time])
endfunction

function! s:CocRequest(action, args, label, Callback) abort
  if !exists('*CocAction')
    call myfinder#utils#echo('coc.nvim not installed', 'error')
    return
  endif
  let l:state = {
        \ 'done': 0,
        \ 'label': a:label,
        \ 'start_time': reltime(),
        \ 'callback': a:Callback,
        \ 'timer': -1,
        \ }
  let l:state.timer = timer_start(100, function('s:RequestTick', [l:state]), {'repeat': -1})
  try
    if exists('*CocActionAsync')
      call call('CocActionAsync', [a:action] + a:args + [function('s:RequestDone', [l:state])])
    else
      let l:result = call('CocAction', [a:action] + a:args)
      call s:RequestDone(l:state, v:null, l:result)
    endif
  catch
    call s:RequestDone(l:state, v:exception, v:null)
  endtry
endfunction

" --- Navigation ---
function! s:DecodeUriByte(value) abort
  return eval('"\\x' . strpart(a:value, 1) . '"')
endfunction

function! s:UriToPath(uri) abort
  if a:uri !~# '^file://'
    return a:uri
  endif
  let l:path = substitute(a:uri, '^file://', '', '')
  return substitute(l:path, '%\x\x', '\=s:DecodeUriByte(submatch(0))', 'g')
endfunction

function! s:OpenLocation(item) abort
  execute 'edit ' . fnameescape(a:item.abs_path)
  call cursor(a:item.lnum, a:item.col)
  normal! zz
endfunction

function! s:Locations(action, name) abort
  call s:CocRequest(a:action, [], a:name, function('s:ShowLocations', [a:name]))
endfunction

function! s:ShowLocations(name, locations, start_time) abort
  let l:locations = a:locations
  if empty(l:locations) || l:locations == v:null
    call myfinder#utils#echo(printf('No %s found [%.3fs]', tolower(a:name), reltimefloat(reltime(a:start_time))), 'warn')
    return
  endif
  if type(l:locations) == v:t_dict
    let l:locations = [l:locations]
  endif

  let l:items = []
  for l:location in l:locations
    let l:uri = get(l:location, 'uri', get(l:location, 'targetUri', ''))
    let l:range = get(l:location, 'range', get(l:location, 'targetSelectionRange', {}))
    let l:start = get(l:range, 'start', {})
    let l:path = s:UriToPath(l:uri)
    let l:lnum = get(l:start, 'line', 0) + 1
    let l:col = get(l:start, 'character', 0) + 1
    let l:text = ''
    if filereadable(l:path)
      let l:file_lines = readfile(l:path, '', l:lnum)
      let l:text = substitute(get(l:file_lines, l:lnum - 1, ''), '^\s*', '', '')
    endif
    call add(l:items, {
          \ 'text': l:text,
          \ 'short_file': fnamemodify(l:path, ':t') . ':' . l:lnum . ':' . l:col,
          \ 'abs_path': l:path,
          \ 'lnum': l:lnum,
          \ 'col': l:col,
          \ })
  endfor

  if len(l:items) == 1
    call s:OpenLocation(l:items[0])
    call myfinder#utils#echo(printf('%s opened [%.3fs]', a:name, reltimefloat(reltime(a:start_time))), 'success')
    return
  endif
  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ }, {
        \ 'name': a:name,
        \ 'display': ['short_file', 'text'],
        \ 'columns_hl': ['Directory', 'Identifier'],
        \ 'preview_enabled': 1,
        \ 'start_time': a:start_time,
        \ })
endfunction

function! myfinder#finders#coc#definition() abort
  call s:Locations('definitions', 'Definitions')
endfunction

function! myfinder#finders#coc#declaration() abort
  call s:Locations('declarations', 'Declarations')
endfunction

function! myfinder#finders#coc#type_definition() abort
  call s:Locations('typeDefinitions', 'TypeDefinitions')
endfunction

function! myfinder#finders#coc#implementation() abort
  call s:Locations('implementations', 'Implementations')
endfunction

function! myfinder#finders#coc#references() abort
  call s:Locations('references', 'References')
endfunction

" --- Diagnostics ---
function! myfinder#finders#coc#diagnostics() abort
  call s:CocRequest('diagnosticList', [], 'Diagnostics', function('s:ShowDiagnostics'))
endfunction

function! s:ShowDiagnostics(diags, start_time) abort
  let l:diags = a:diags
  if empty(l:diags)
    call myfinder#utils#echo('No diagnostics found', 'warn')
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
          \ 'short_file': fnamemodify(l:file, ':t') . ':' .l:lnum,
          \ 'msg_type': l:severity[0],
          \ 'abs_path': l:file,
          \ 'lnum': l:lnum,
          \ 'msg': l:msg,
          \ 'col': l:col,
          \ 'prefix_len': len(l:display) - len(l:msg),
          \ }
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ 'copy_path': function('myfinder#actions#copy_path'),
        \ 'copy_msg': function('s:CopyDiagMsg'),
        \ }, { 
        \ 'name': 'Diagnostics',
        \ 'start_time': a:start_time,
        \ 'preview_enabled': 1,
        \ 'display': ['msg_type', 'short_file','text'],
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
  let l:msg = get(self.selected, 'msg', '')
  if !empty(l:msg)
    call setreg('+', l:msg)
    call setreg('*', l:msg)
    call myfinder#utils#echo('Copied diagnostic: ' . l:msg, 'success')
  else
    call myfinder#utils#echo('No message to copy', 'warn')
  endif
endfunction

" --- Commands ---
function! myfinder#finders#coc#commands() abort
  call s:CocRequest('commands', [], 'Commands', function('s:ShowCommands'))
endfunction

function! s:ShowCommands(cmds, start_time) abort
  let l:cmds = a:cmds
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
        \ 'start_time': a:start_time,
        \ 'display': ['text', 'title'],
        \ 'match_item': 'text',
        \ 'columns_hl': ['Type', 'Comment'],
        \ 'align_columns': 1,
        \ })
endfunction

function! s:RunCommand() dict
  call self.quit()
  call s:CocRequest('runCommand', [self.selected.command], 'Command ' . self.selected.command, function('s:ActionFinished'))
endfunction

function! s:ActionFinished(result, start_time) abort
  call myfinder#utils#echo(printf('Completed in %.3fs', reltimefloat(reltime(a:start_time))), 'success')
endfunction

" --- Extensions ---
function! myfinder#finders#coc#extensions() abort
  call s:CocRequest('extensionStats', [], 'Extensions', function('s:ShowExtensions'))
endfunction

function! s:ShowExtensions(exts, start_time) abort
  let l:exts = a:exts
  if empty(l:exts)
    call myfinder#utils#echo('No extensions found', 'warn')
    return
  endif
  

  let l:items = s:BuildExtItems(l:exts)
  call myfinder#core#start(l:items, {
        \ 'open': function('s:ToggleExt'),
        \ 'delete': function('s:UninstallExt'),
        \ }, { 
        \ 'name': 'Extensions',
        \ 'display': ['state_icon','text','version','root'],
        \ 'columns_hl': ['', 'Type', 'Number', 'Directory'],
        \ 'start_time': a:start_time,
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

function! s:BuildExtItems(exts) abort
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
  return l:items
endfunction

function! s:ToggleExt() dict
  let l:id = self.selected.text
  call s:CocRequest('toggleExtension', [l:id], 'Toggle ' . l:id, function('s:AfterExtensionChange', [self]))
endfunction

function! s:UninstallExt() dict
  let l:id = self.selected.text
  call s:CocRequest('uninstallExtension', [l:id], 'Uninstall ' . l:id, function('s:AfterExtensionChange', [self]))
endfunction

function! s:AfterExtensionChange(ctx, result, start_time) abort
  call s:CocRequest('extensionStats', [], 'Refresh Extensions', function('s:RefreshExts', [a:ctx]))
endfunction

function! s:RefreshExts(ctx, exts, start_time) abort
  let l:items = s:BuildExtItems(a:exts)
  let a:ctx.items = l:items
  let a:ctx.matches = l:items
  let a:ctx.filter = ''
  call a:ctx.update_res()
endfunction

" --- Symbols (Document) ---
function! myfinder#finders#coc#symbols() abort
  call s:CocRequest('documentSymbols', [], 'Symbols', function('s:ShowSymbols'))
endfunction

function! s:ShowSymbols(symbols, start_time) abort
  let l:symbols = a:symbols
  if empty(l:symbols) || l:symbols == v:null
    call myfinder#utils#echo('No symbols found', 'warn')
    return
  endif
  
  let l:items = s:ProcessSymbols(l:symbols, '', 0)
  
  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ }, {
        \ 'name': 'Symbols',
        \ 'start_time': a:start_time,
        \ 'display': ['lnum', 'kind', 'text'],
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
          \ 'file_path': expand('%:p'),
          \ 'lnum': l:lnum,
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
function! myfinder#finders#coc#workspace_symbols() abort
  " This requires user input for query
  let l:query = input('Workspace Symbols: ')
  if empty(l:query)
    return
  endif
  
  call s:CocRequest('getWorkspaceSymbols', [l:query], 'WorkspaceSymbols', function('s:ShowWorkspaceSymbols'))
endfunction

function! s:ShowWorkspaceSymbols(symbols, start_time) abort
  let l:symbols = a:symbols
  if empty(l:symbols)
    call myfinder#utils#echo('No symbols found', 'warn')
    return
  endif
  
  let l:items = []
  for l:sym in l:symbols
    let l:name = get(l:sym, 'name', '')
    let l:kind = get(l:sym, 'kind', 'Unknown')
    let l:location = get(l:sym, 'location', {})
    let l:path = get(l:sym, 'filepath', s:UriToPath(get(l:location, 'uri', '')))
    let l:range = get(l:location, 'range', {})
    let l:start = get(l:range, 'start', {})
    let l:lnum = get(l:sym, 'lnum', get(l:start, 'line', 0) + 1)
    let l:col = get(l:sym, 'col', get(l:start, 'character', 0) + 1)
    
    let l:display = printf('%-20s [%s] %s:%d', l:name, l:kind, fnamemodify(l:path, ':t'), l:lnum)
    
    let l:item = {
          \ 'text': l:name,
          \ 'display': l:display,
          \ 'abs_path': l:path,
          \ 'lnum': l:lnum,
          \ 'col': l:col,
          \ 'kind': l:kind,
          \ 'prefix_len': len(l:display) - len(l:name),
          \ }
    call add(l:items, l:item)
  endfor
  
  call myfinder#core#start(l:items, {
        \ 'preview': function('myfinder#actions#preview'),
        \ }, {
        \ 'name': 'WorkspaceSymbols',
        \ 'start_time': a:start_time,
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
