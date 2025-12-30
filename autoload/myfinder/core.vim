
let s:finders = {}

function! s:Quit() dict
  call popup_close(self.winid, -1)
endfunction

function! s:CtxUpdateRes() dict
  " self is ctx
  let l:start = reltime()
  if empty(self.filter)
    let self.matches = self.items
    if has_key(self, 'match_positions')
      unlet self.match_positions
    endif
  else
    let l:res = matchfuzzypos(self.items, self.filter, {'key': 'text'})
    let self.matches = l:res[0]
    let self.match_positions = l:res[1]
  endif
  
  let l:content = s:BuildContent(self)
  call popup_settext(self.winid, l:content)
  
  call s:ApplyHighLights(self)
  
  call win_execute(self.winid, 'normal! 3G')
  call s:TriggerPreview(self)

  let self.search_time = reltimefloat(reltime(l:start))
  " Re-render header with search time
  let l:content[0] = s:BuildPrompt(self)
  call popup_settext(self.winid, l:content)
endfunction


function! myfinder#core#start(items, actions, ...) abort
  let l:options = get(a:000, 0, {})
  let l:ctx = {
        \ 'items': a:items,
        \ 'actions': a:actions,
        \ 'name': get(l:options, 'name', 'Finder'),
        \ 'name_color': get(l:options, 'name_color', {}),
        \ 'filetype': get(l:options, 'filetype', ''),
        \ 'syntax': get(l:options, 'syntax', []),
        \ 'status': get(l:options, 'status', ''),
        \ 'filter': '',
        \ 'winid': 0,
        \ 'matches': [], 
        \ 'start_idx': 0,
        \ 'start_time': get(l:options, 'start_time', reltime()),
        \ 'search_time': 0.0,
        \ 'width': float2nr(&columns * 0.8),
        \ 'height': float2nr(&lines * 0.6),
        \ 'quit': function('s:Quit'),
        \ 'update_res': function('s:CtxUpdateRes'),
        \ 'save_t_ve': '',
        \ 'save_guicursor': '',
        \ 'default_actions': {
        \     'esc': function('s:ESC'), 
        \     'open': function('s:GenericOpen'),
        \     'open_tab': function('s:GenericOpenTab'),
        \     'open_left': function('s:GenericOpenLeft'),
        \     'open_right': function('s:GenericOpenRight'),
        \     'bs': function('s:BS'),
        \     'clear': function('s:CLEAR'),
        \     'delete_a_word': function('s:DeleteAWord'),
        \     'select_up': function('s:SelectUp'),
        \     'select_down': function('s:SelectDown'),
        \     },
        \ }
  
  " Reserve lines for Prompt (1), Separator (1)
  let l:ctx.render_limit = l:ctx.height - 2
        
  call s:HideCursor(l:ctx)
        
  " Prepare initial matches (all items)
  let l:ctx.matches = copy(a:items)
  
  let l:attr = {
        \ 'minwidth': l:ctx.width,
        \ 'maxwidth': l:ctx.width,
        \ 'minheight': l:ctx.height,
        \ 'maxheight': l:ctx.height,
        \ 'border': [1,1,1,1],
        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \ 'borderhighlight': ['FinderSeparator'],
        \ 'padding': [0,1,0,1],
        \ 'cursorline': 1,
        \ 'filter': function('s:FinderFilter'),
        \ 'callback': function('s:FinderCallback'),
        \ 'footer': (empty(l:ctx.status) ? '' : ' ' . l:ctx.status . ' '),
        \ 'mapping': 0,
        \ }
  
  let l:content = s:BuildContent(l:ctx)
  let l:ctx.winid = popup_create(l:content, l:attr)
  
  " Store context in script-local dictionary
  let s:finders[l:ctx.winid] = l:ctx
  
  call s:ApplyHighLights(l:ctx)
  
  " Select first item (line 3)
  call win_execute(l:ctx.winid, "normal! 3G")
  call s:TriggerPreview(l:ctx)
endfunction

function! s:BuildPrompt(ctx) abort
  let l:cursor_char = '█'
  let l:name_str = printf('[%s] ', a:ctx.name)
  let l:prompt = l:name_str . '> ' . a:ctx.filter . l:cursor_char
  
  " Count string on the right
  let l:load_time = reltimefloat(reltime(a:ctx.start_time))
  if has_key(a:ctx, 'load_time')
    let l:load_time = a:ctx.search_time
  else
    let a:ctx.load_time = l:load_time
  endif
  let l:cnt_str = printf('(%d/%d) [%.3fs]', len(a:ctx.matches), len(a:ctx.items), l:load_time)
  let l:p_width = strdisplaywidth(l:prompt)
  let l:c_width = strdisplaywidth(l:cnt_str)
  let l:spaces = a:ctx.width - l:p_width - l:c_width - 1
  if l:spaces < 1
    let l:spaces = 1
  endif
  return l:prompt . repeat(' ', l:spaces) . l:cnt_str
endfunction

function! s:BuildContent(ctx) abort
  let l:prompt = s:BuildPrompt(a:ctx)
  
  " Separator with workspace path
  let l:workspace = getcwd()
  let l:ws_display = ' ' . fnamemodify(l:workspace, ':~') . ' '
  let l:ws_width = strdisplaywidth(l:ws_display)
  let l:dash_count = (a:ctx.width - 2 - l:ws_width) / 2
  if l:dash_count < 1
    let l:separator = repeat('-', a:ctx.width - 2)
  else
    let l:separator = repeat('-', l:dash_count) . l:ws_display . repeat('-', a:ctx.width - 2 - l:dash_count - l:ws_width)
  endif
  
  let l:content = [l:prompt, l:separator]
  
  let l:list_content = []
  let l:limit = min([len(a:ctx.matches), a:ctx.render_limit])
  for i in range(l:limit)
    let l:item = a:ctx.matches[i]
    call add(l:list_content, has_key(l:item, 'display') ? l:item.display : l:item.text)
  endfor
  
  if empty(l:list_content)
    call add(l:content, 'No matches')
  else
    call extend(l:content, l:list_content)
  endif

  return l:content
endfunction

function! s:ApplyHighLights(ctx) abort
  call win_execute(a:ctx.winid, 'call clearmatches()')
  
  if !empty(a:ctx.filetype)
    call win_execute(a:ctx.winid, 'setlocal filetype=' . a:ctx.filetype)
  else
    call win_execute(a:ctx.winid, 'syntax clear')
  endif
  
  call win_execute(a:ctx.winid, 'highlight link FinderPrompt Title')
  call win_execute(a:ctx.winid, 'highlight link FinderSeparator Comment')
  call win_execute(a:ctx.winid, 'highlight link FinderMatch Special')
  call win_execute(a:ctx.winid, 'highlight link FinderCursor CursorIM')
  call win_execute(a:ctx.winid, 'highlight link FinderStatus Type')
  call win_execute(a:ctx.winid, 'highlight link FinderDir Directory')
  call win_execute(a:ctx.winid, 'highlight link FinderFile String')
  call win_execute(a:ctx.winid, 'highlight link FinderNumber Number')
  call win_execute(a:ctx.winid, 'highlight link FinderStatusAlt WarningMsg')
  call win_execute(a:ctx.winid, 'highlight link FinderNone ErrorMsg')
  call win_execute(a:ctx.winid, 'highlight link FinderHash Identifier')
  
  " Apply custom or default finder name color
  let l:default_color = {'ctermbg': 6, 'ctermfg': 0, 'guibg': '#56b6c2', 'guifg': '#282c34'}
  let l:color = extend(copy(l:default_color), a:ctx.name_color)
  let l:hl_cmd = printf('highlight FinderName ctermfg=%s ctermbg=%s guifg=%s guibg=%s',
        \ l:color.ctermfg, l:color.ctermbg, l:color.guifg, l:color.guibg)
  call win_execute(a:ctx.winid, l:hl_cmd)
  
  call win_execute(a:ctx.winid, 'syntax match FinderPrompt /^.*> .*$/ contains=FinderName,FinderCursor')
  call win_execute(a:ctx.winid, 'syntax match FinderName /^\[.\{-}\]/ contained')
  call win_execute(a:ctx.winid, 'syntax match FinderSeparator /^-\{10,\}$/')
  call win_execute(a:ctx.winid, 'syntax match FinderCursor /█/ contained')
  
  " Generic highlighting for listings (restricted to line 3+)
  " Only apply defaults if no custom syntax is provided
  if empty(a:ctx.syntax)
    call win_execute(a:ctx.winid, 'syntax match FinderHash /\%>2l^[0-9a-f]\{7,40\}\ze /')
    call win_execute(a:ctx.winid, 'syntax match FinderNumber /\%>2l\s*\d\+[: ]/ nextgroup=FinderFile')
    call win_execute(a:ctx.winid, 'syntax match FinderDir /\%>2l[^ ]\{-}\//')
    call win_execute(a:ctx.winid, 'syntax match FinderStatusAlt /\%>2l\[+\]/')
  endif
  call win_execute(a:ctx.winid, 'syntax match FinderNone /No matches/')
  
  " Apply custom syntax rules
  for l:rule in a:ctx.syntax
    if has_key(l:rule, 'match') && has_key(l:rule, 'link')
      let l:contains = get(l:rule, 'contains', '')
      let l:contained = get(l:rule, 'contained', 0)
      let l:opt = ''
      if !empty(l:contains)
        let l:opt .= ' contains=' . l:contains
      endif
      if l:contained
        let l:opt .= ' contained'
      endif
      
      let l:cmd = printf('syntax match %s /%s/%s', l:rule.link, l:rule.match, l:opt)
      call win_execute(a:ctx.winid, l:cmd)
    endif
  endfor
  
  if empty(a:ctx.filter) || empty(a:ctx.matches)
    return
  endif
  
  if has_key(a:ctx, 'match_positions')
    let l:match_positions = a:ctx.match_positions " list of list of byte indices
    
    let l:max_hl = min([len(a:ctx.matches), a:ctx.render_limit])
    let l:cmds = []
    
    for i in range(l:max_hl)
      let l:pos_list = l:match_positions[i]
      let l:item = a:ctx.matches[i]
      let l:line_num = i + 3
      let l:offset = has_key(l:item, 'prefix_len') ? l:item.prefix_len : 0
      
      let l:hl_positions = []
      for l:byte_idx in l:pos_list
          call add(l:hl_positions, [l:line_num, l:byte_idx + 1 + l:offset, 1])
      endfor
      
      if !empty(l:hl_positions)
         call add(l:cmds, "call matchaddpos('FinderMatch', " . string(l:hl_positions) . ")")
      endif
    endfor
    
    if !empty(l:cmds)
      call win_execute(a:ctx.winid, l:cmds)
    endif
  endif
endfunction


function! s:HandleCallback(ctx, key, action, selected) abort
  let l:Callback = ''
  if has_key(a:ctx.actions, a:action)
    let l:Callback = a:ctx.actions[a:action]
  elseif has_key(a:ctx.default_actions, a:action)
    let l:Callback = a:ctx.default_actions[a:action]
  endif
  
  if !empty(l:Callback)
    " Prevent actions that require selection if no item is selected
    if empty(a:selected) && index(['open', 'open_tab', 'open_left', 'open_right', 'delete'], a:action) != -1
      return 0
    endif
    let a:ctx.selected = a:selected
    let a:ctx.key = a:key
    let a:ctx.action = a:action
    call call(l:Callback, [], a:ctx)
    return 1
  endif
  return 0 
endfunction

function! s:TriggerPreview(ctx) abort
  let l:Preview = get(a:ctx.actions, 'preview', '')
  if empty(l:Preview)
    let l:Preview = get(a:ctx.default_actions, 'preview', '')
  endif

  if !empty(l:Preview)
    let l:line = line('.', a:ctx.winid)
    let l:index = l:line - 3
    if l:index >= 0 && l:index < len(a:ctx.matches)
      let a:ctx.selected = a:ctx.matches[l:index]
      call call(l:Preview, [], a:ctx)
    endif
  endif
endfunction

function! s:BS() dict
  let self.filter = strcharpart(self.filter, 0, strchars(self.filter) - 1)
  call self.update_res()
endfunction

function! s:CLEAR() dict
  let self.filter = ''
  call self.update_res()
endfunction

function! s:ESC() dict
  call self.quit()
endfunction

function! s:ENTER() dict
  call self.quit()
endfunction

" Generic open actions that work with different item types
function! s:GenericOpen() dict
  call self.quit()
  call s:OpenItem(self.selected, 'edit')
endfunction

function! s:GenericOpenTab() dict
  call self.quit()
  execute 'tab split'
  call s:OpenItem(self.selected, 'edit')
endfunction

function! s:GenericOpenLeft() dict
  call self.quit()
  execute 'leftabove vsplit'
  call s:OpenItem(self.selected, 'edit')
endfunction

function! s:GenericOpenRight() dict
  call self.quit()
  execute 'rightbelow vertical split'
  call s:OpenItem(self.selected, 'edit')
endfunction

" Helper function to open different item types
function! s:OpenItem(item, cmd) abort
  " Handle buffer
  if has_key(a:item, 'bufnr')
    execute 'buffer ' . a:item.bufnr
    if has_key(a:item, 'line')
      call cursor(a:item.line, get(a:item, 'col', 1))
      normal! zz
    endif
    return
  endif
  
  " Handle window
  if has_key(a:item, 'target_winid')
    call win_gotoid(a:item.target_winid)
    return
  endif
  
  " Handle file path
  if has_key(a:item, 'file')
    execute a:cmd . ' ' . a:item.file
    if has_key(a:item, 'line')
      call cursor(a:item.line, get(a:item, 'col', 1))
      normal! zz
    endif
    return
  endif
  
  " Handle path
  if has_key(a:item, 'path')
    execute a:cmd . ' ' . a:item.path
    if has_key(a:item, 'line')
      call cursor(a:item.line, get(a:item, 'col', 1))
      normal! zz
    endif
    return
  endif
  
  " Handle winid (for line finder)
  if has_key(a:item, 'winid') && has_key(a:item, 'lnum')
    call win_execute(a:item.winid, a:item.lnum)
    call win_execute(a:item.winid, 'normal! zz')
    return
  endif
endfunction

function! s:DeleteAWord() dict
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

function! s:SelectDown() dict
  let l:lnum = line('.', self.winid)
  let l:max_line = min([len(self.matches), self.render_limit]) + 2
  if l:lnum < l:max_line
    call win_execute(self.winid, "normal! j")
    call s:TriggerPreview(self)
  endif
endfunction

function! s:SelectUp() dict
  let l:lnum = line('.', self.winid)
  if l:lnum > 3
    call win_execute(self.winid, "normal! k")
    call s:TriggerPreview(self)
  endif
endfunction

function! s:FinderFilter(winid, key) abort
  let l:ctx = get(s:finders, a:winid, {})
  if empty(l:ctx)
    return 0
  endif

  let l:action = ''
  if a:key == "\<Esc>" || a:key == "\<C-c>"
    let l:action = 'esc'
  elseif a:key == "\<BS>" || a:key == "\<Del>" || a:key == "\<C-h>"
    let l:action = 'bs'
  elseif a:key == "\<C-w>"
    let l:action = 'delete_a_word'
  elseif a:key == "\<C-u>"
    let l:action = 'clear'
  elseif a:key == "\<C-j>" || a:key == "\<C-n>" || a:key == "\<Down>"
    let l:action = 'select_down'
  elseif a:key == "\<C-k>" || a:key == "\<C-p>" || a:key == "\<Up>"
    let l:action = 'select_up'
  elseif a:key == "\<CR>"
    let l:action = 'open'
  elseif a:key == "\<C-S-]>"
    let l:action = 'open_left'
  elseif a:key == "\<C-]>"
    let l:action = 'open_right'
  elseif a:key == "\<C-t>"
    let l:action = 'open_tab'
  elseif a:key == "\<C-d>"
    let l:action = 'delete'
  elseif a:key =~ '^\p$'
    let l:ctx.filter .= a:key
    call l:ctx.update_res()
    return 1
  endif
  
  let l:selected = {}
  let l:line = line('.', a:winid)
  if l:line < 3
    let l:line = 3
  endif
  let l:index = l:line - 3
  if l:index < len(l:ctx.matches)
    let l:selected = l:ctx.matches[l:index]
  endif
  
  if l:action != ''
    call s:HandleCallback(l:ctx, a:key, l:action, l:selected)
  endif
  
  return 1
endfunction

function! s:FinderCallback(winid, result) abort
  let l:ctx = get(s:finders, a:winid, {})
  if !empty(l:ctx)
    call s:RestoreCursor(l:ctx)
    if has_key(s:finders, a:winid)
      unlet s:finders[a:winid]
    endif
  endif
endfunction

function! s:HideCursor(ctx) abort
  " Save and hide terminal cursor
  let a:ctx.save_t_ve = &t_ve
  set t_ve=
  
  " Save and hide GUI/modern terminal cursor
  let a:ctx.save_guicursor = &guicursor
  if has('gui_running') || &termguicolors || exists('$TERM_PROGRAM')
    " Use 'Ignore' highlight group which is typically invisible
    set guicursor+=a:Ignore
  endif
endfunction

function! s:RestoreCursor(ctx) abort
  " Restore terminal cursor
  if has_key(a:ctx, 'save_t_ve')
    let &t_ve = a:ctx.save_t_ve
  endif
  
  " Restore GUI/modern terminal cursor
  if has_key(a:ctx, 'save_guicursor')
    let &guicursor = a:ctx.save_guicursor
  endif
endfunction
