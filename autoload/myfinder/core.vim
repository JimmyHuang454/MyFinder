let s:finders = {}
let s:action_menus = {}

if !exists('g:myfinder_preview_enabled')
  let g:myfinder_preview_enabled = 0
endif
if !exists('g:myfinder_preview_delay')
  let g:myfinder_preview_delay = 200
endif
if !exists('g:myfinder_preview_layout')
  let g:myfinder_preview_layout = 'column'
endif

if !exists('g:myfinder_popup_borders')
  let g:myfinder_popup_borders = ["─","│","─","│","╭","╮","╯","╰"]
endif

function! myfinder#core#echo(msg, ...) abort
  let l:type = get(a:000, 0, 'info')
  let l:hl = get({'info': 'MoreMsg', 'success': 'MoreMsg', 'warn': 'WarningMsg', 'error': 'ErrorMsg'}, l:type, 'MoreMsg')
  execute 'echohl ' . l:hl
  echo '[MyFinder] ' . a:msg
  echohl None
endfunction

function! myfinder#core#toggle_preview() abort
  let g:myfinder_preview_enabled = !g:myfinder_preview_enabled
  call myfinder#core#echo('Preview ' . (g:myfinder_preview_enabled ? 'Enabled' : 'Disabled'), g:myfinder_preview_enabled ? 'success' : 'warn')
endfunction

function! myfinder#core#set_preview_layout(layout) abort
  if index(['column', 'row'], a:layout) == -1
    call myfinder#core#echo('Invalid preview layout: ' . a:layout, 'error')
    return
  endif
  let g:myfinder_preview_layout = a:layout
  call myfinder#core#echo('Preview layout set to ' . a:layout, 'success')
endfunction

function! s:Quit() dict
  call popup_close(self.winid, -1)
  if has_key(self, 'preview_timer') && self.preview_timer != -1
    call timer_stop(self.preview_timer)
    let self.preview_timer = -1
  endif
  if has_key(self, 'preview_winid') && self.preview_winid != 0
    call popup_close(self.preview_winid, -1)
    let self.preview_winid = 0
  endif
endfunction

function! s:CtxUpdateRes() dict
  " self is ctx
  let l:start = reltime()
  
  " Dynamic search support
  if get(self, 'dynamic_search', 0)
    " If filter changed, invoke callback
    let l:last = get(self, 'last_filter', '')
    if self.filter !=# l:last
      let self.last_filter = self.filter
      if has_key(self, 'on_change')
        call self.on_change(self, self.filter)
      endif
    endif
    " In dynamic mode, items are managed by external source
    let self.matches = self.items
  else
    if empty(self.filter)
      let self.matches = self.items
      if has_key(self, 'match_positions')
        unlet self.match_positions
      endif
    else
      let l:res = matchfuzzypos(self.items, self.filter, {'key': self.match_item})
      let self.matches = l:res[0]
      let self.match_positions = l:res[1]
    endif
  endif
  
  let l:content = s:BuildContent(self)
  
  call s:ApplyHighLights(self)
  
  call win_execute(self.winid, 'normal! 3G')
  call s:TriggerPreview(self, self.preview_delay)

  let self.search_time = reltimefloat(reltime(l:start))
  " Re-render header with search time
  let l:content[0] = s:BuildPrompt(self)
  call popup_settext(self.winid, l:content)
endfunction


function! myfinder#core#start(items, actions, ...) abort
  let l:options = get(a:000, 0, {})

  let l:preview_enabled = get(l:options, 'preview_enabled', g:myfinder_preview_enabled)
  let l:preview_layout = get(l:options, 'preview_layout', g:myfinder_preview_layout)
  let l:w = float2nr(&columns * 0.8)
  let l:h = float2nr(&lines * 0.6)
  if l:preview_enabled
    if l:preview_layout ==# 'column'
      let l:w = float2nr(l:w / 2)
    else
      let l:h = float2nr(l:h / 2)
    endif
  endif
  let l:ctx = {
        \ 'items': a:items,
        \ 'actions': a:actions,
        \ 'name': get(l:options, 'name', 'Finder'),
        \ 'name_color': get(l:options, 'name_color', {}),
        \ 'filetype': get(l:options, 'filetype', ''),
        \ 'syntax': get(l:options, 'syntax', []),
        \ 'display': get(l:options, 'display', ['text']),
        \ 'match_item': get(l:options, 'match_item', 'text'),
        \ 'columns_hl': get(l:options, 'columns_hl', []),
        \ 'align_columns': get(l:options, 'align_columns', len(get(l:options, 'display', ['text']))),
        \ 'status': get(l:options, 'status', ''),
        \ 'filter': '',
        \ 'winid': 0,
        \ 'matches': [], 
        \ 'start_idx': 0,
        \ 'start_time': get(l:options, 'start_time', reltime()),
        \ 'search_time': 0.0,
        \ 'width': l:w,
        \ 'height': l:h,
        \ 'preview_enabled': l:preview_enabled,
        \ 'preview_layout': l:preview_layout,
        \ 'preview_delay': get(l:options, 'preview_delay', g:myfinder_preview_delay),
        \ 'preview_winid': 0,
        \ 'preview_timer': -1,
        \ 'quit': function('s:Quit'),
        \ 'update_res': function('s:CtxUpdateRes'),
        \ 'save_t_ve': '',
        \ 'save_guicursor': '',
        \ 'default_actions': {
        \     'esc': function('s:ESC'), 
        \     'open': function('s:GenericOpen'),
        \     'open_with_new_tab': function('s:GenericOpenTab'),
        \     'open_horizontally': function('s:GenericOpenHorizontally'),
        \     'open_vertically': function('s:GenericOpenVertically'),
        \     'bs': function('s:BS'),
        \     'clear': function('s:Clear'),
        \     'delete_a_word': function('s:DeleteAWord'),
        \     'select_up': function('s:SelectUp'),
        \     'select_down': function('s:SelectDown'),
        \     'preview_once': function('s:PreviewOnce'),
        \     'copy_path': function('s:CopyPath'),
        \     },
        \ }
  
  " Default key mappings
  let l:default_keys = {
        \ "\<Esc>": 'esc',
        \ "\<C-c>": 'esc',
        \ "\<BS>": 'bs',
        \ "\<Del>": 'bs',
        \ "\<C-h>": 'bs',
        \ "\<C-w>": 'delete_a_word',
        \ "\<C-u>": 'clear',
        \ "\<C-j>": 'select_down',
        \ "\<C-n>": 'select_down',
        \ "\<Down>": 'select_down',
        \ "\<C-k>": 'select_up',
        \ "\<Up>": 'select_up',
        \ "\<CR>": 'open',
        \ "\<C-x>": 'open_horizontally',
        \ "\<C-]>": 'open_vertically',
        \ "\<C-t>": 'open_with_new_tab',
        \ "\<C-p>": 'preview_once',
        \ "\<C-d>": 'delete',
        \ "\<C-y>": 'copy_path',
        \ "\<Tab>": 'select_action',
        \ }
  
  " Default action shortcuts for menu (action -> char)
  let l:ctx.action_shortcuts = {
        \ 'open': 'o',
        \ 'open_with_new_tab': 't',
        \ 'open_horizontally': 'x',
        \ 'open_vertically': ']',
        \ 'delete': 'd',
        \ 'preview_once': 'p',
        \ 'copy_path': 'y',
        \ }

  " Merge user defined mappings
  let l:user_mappings = get(g:, 'myfinder_mappings', {})
  let l:user_keys = {}

  " Support:
  " 1. key:action
  " 2. action:key
  " 3. action:[key, menu_shortcut]
  for [l:k, l:v] in items(l:user_mappings)
    let l:action = ''
    let l:key = ''
    let l:menu_shortcut = ''
    
    if type(l:v) == v:t_list && len(l:v) >= 2
        " Case 3: action:[key, menu_shortcut]
        let l:action = l:k
        let l:key = l:v[0]
        let l:menu_shortcut = l:v[1]
    elseif has_key(l:ctx.default_actions, l:k) || has_key(l:ctx.actions, l:k)
        " Case 2: action:key
        let l:action = l:k
        let l:key = l:v
    else
        " Case 1: key:action
        let l:key = l:k
        let l:action = l:v
    endif

    if !empty(l:key) && !empty(l:action)
        let l:user_keys[l:key] = l:action
        if !empty(l:menu_shortcut)
            let l:ctx.action_shortcuts[l:action] = l:menu_shortcut
        endif
    endif
  endfor
  
  " Check for duplicates in user_keys before merging (warn only)
  for [l:k, l:v] in items(l:user_keys)
    if has_key(l:default_keys, l:k)
        " User is overriding default key
    endif
  endfor

  let l:ctx.key_map = extend(copy(l:default_keys), l:user_keys)
  
  " Merge finder specific mappings
  let l:finder_mappings = get(l:options, 'mappings', {})
  let l:finder_keys = {}
  for [l:k, l:v] in items(l:finder_mappings)
    let l:action = ''
    let l:key = ''
    let l:menu_shortcut = ''

    if type(l:v) == v:t_list && len(l:v) >= 2
        " Case 3: action:[key, menu_shortcut]
        let l:action = l:k
        let l:key = l:v[0]
        let l:menu_shortcut = l:v[1]
    elseif has_key(l:ctx.default_actions, l:k) || has_key(l:ctx.actions, l:k)
        " Case 2: action:key
        let l:action = l:k
        let l:key = l:v
    else
        " Case 1: key:action
        let l:key = l:k
        let l:action = l:v
    endif
    
    if !empty(l:key) && !empty(l:action)
        let l:finder_keys[l:key] = l:action
        if !empty(l:menu_shortcut)
            let l:ctx.action_shortcuts[l:action] = l:menu_shortcut
        endif
    endif
  endfor
  
  " Extend with finder keys (overriding user keys if conflict, or we can choose policy)
  " Usually finder specific mappings should have higher priority or just merge.
  call extend(l:ctx.key_map, l:finder_keys)
  
  " Reserve lines for Prompt (1), Separator (1)
  let l:ctx.render_limit = l:ctx.height - 2
  let l:ctx.col_spans = []
        
  call s:HideCursor(l:ctx)
        
  " Prepare initial matches (all items)
  let l:ctx.matches = copy(a:items)
  
  let l:attr = {
        \ 'minwidth': l:ctx.width,
        \ 'maxwidth': l:ctx.width,
        \ 'minheight': l:ctx.height,
        \ 'maxheight': l:ctx.height,
        \ 'highlight': 'Normal',
        \ 'border': [1,1,1,1],
        \ 'borderchars': g:myfinder_popup_borders,
        \ 'borderhighlight': ['FinderSeparator'],
        \ 'padding': [0,0,0,0],
        \ 'cursorline': 1,
        \ 'filter': function('s:FinderFilter'),
        \ 'callback': function('s:FinderCallback'),
        \ 'mapping': 0,
        \ }
  
  let l:ctx.winid = popup_create([], l:attr)
  call win_execute(l:ctx.winid, 'setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile')
  call s:BuildContent(l:ctx)
  
  " Store context in script-local dictionary
  let s:finders[l:ctx.winid] = l:ctx
  
  call s:ApplyHighLights(l:ctx)
  
  " Select first item (line 3)
  call win_execute(l:ctx.winid, "normal! 3G")
  call s:TriggerPreview(l:ctx)

  if l:ctx.preview_enabled
    call s:CreatePreviewWindow(l:ctx)
  endif
  
  return l:ctx
endfunction

function! s:CreatePreviewWindow(ctx) abort
  if !a:ctx.preview_enabled
    return
  endif
  let l:gap = 1
  let l:preview_w = a:ctx.width
  let l:preview_h = a:ctx.height
  if a:ctx.preview_layout ==# 'column'
    let l:group_w = a:ctx.width * 2 + l:gap
    let l:group_h = a:ctx.height
    let l:start_col = max([1, float2nr((&columns - l:group_w) / 2.0)])
    let l:start_line = max([1, float2nr((&lines - l:group_h) / 2.0)])
    " Move main popup to the computed start position
    call popup_move(a:ctx.winid, {'line': l:start_line, 'col': l:start_col})
    " Preview to the right
    let l:preview_col = l:start_col + a:ctx.width + l:gap
    let l:preview_line = l:start_line
  else
    let l:group_w = a:ctx.width
    let l:group_h = a:ctx.height * 2 + l:gap
    let l:start_col = max([1, float2nr((&columns - l:group_w) / 2.0)])
    let l:start_line = max([1, float2nr((&lines - l:group_h) / 2.0)])
    " Move main popup to the computed start position
    call popup_move(a:ctx.winid, {'line': l:start_line, 'col': l:start_col})
    " Preview below
    let l:preview_line = l:start_line + a:ctx.height + l:gap
    let l:preview_col = l:start_col
  endif
  let l:attr = {
        \ 'pos': 'topleft',
        \ 'line': l:preview_line,
        \ 'col': l:preview_col,
        \ 'minwidth': l:preview_w,
        \ 'maxwidth': l:preview_w,
        \ 'minheight': l:preview_h,
        \ 'maxheight': l:preview_h,
        \ 'highlight': 'Normal',
        \ 'border': [1,1,1,1],
        \ 'borderchars': g:myfinder_popup_borders,
        \ 'borderhighlight': ['FinderSeparator'],
        \ 'padding': [0,0,0,1],
        \ 'cursorline': 0,
        \ 'mapping': 0,
        \ }
  let a:ctx.preview_winid = popup_create(['Preview Disabled'], l:attr)
  call win_execute(a:ctx.preview_winid, 'setlocal nonumber norelativenumber signcolumn=no foldcolumn=0 nofoldenable nolist bufhidden=wipe nobuflisted noswapfile')
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
  let l:cols = a:ctx.display
  let l:cnum = len(l:cols)
  let l:align_cnt = a:ctx.align_columns
  if l:align_cnt > l:cnum
    let l:align_cnt = l:cnum
  endif
  let l:widths = repeat([0], l:align_cnt)
  for i in range(l:limit)
    let l:item = a:ctx.matches[i]
    for j in range(l:align_cnt)
      let l:val = get(l:item, l:cols[j], '')
      let l:w = strdisplaywidth(l:val)
      if l:w > l:widths[j]
        let l:widths[j] = l:w
      endif
    endfor
  endfor
  let a:ctx.col_spans = []
  for i in range(l:limit)
    let l:item = a:ctx.matches[i]
    let l:row_spans = []
    let l:line = ''
    let l:byte_pos = 1
    for j in range(l:cnum)
      let l:val = get(l:item, l:cols[j], '')
      let l:textw = strdisplaywidth(l:val)
      let l:pad = 0
      if j < l:align_cnt
        let l:pad = l:widths[j] - l:textw
      endif
      let l:seg = l:val
      let l:text_byte_start = l:byte_pos
      if j == 0 && get(g:, 'myfinder_enable_icon', 1) && has_key(l:item, 'path')
        let l:ic = myfinder#icons#get(l:item.path)
        if !empty(l:ic)
          let l:seg = l:ic . ' ' . l:seg
          let l:text_byte_start = l:byte_pos + strlen(l:ic . ' ')
        endif
      endif
      let l:seg_padded = l:seg . repeat(' ', l:pad)
      call add(l:row_spans, [l:text_byte_start, strlen(l:val)])
      let l:line .= l:seg_padded
      if j < l:cnum - 1
        let l:line .= '  '
        let l:byte_pos += strlen(l:seg_padded) + 2
      else
        let l:byte_pos += strlen(l:seg_padded)
      endif
    endfor
    call add(a:ctx.col_spans, l:row_spans)
    call add(l:list_content, l:line)
  endfor
  if empty(l:list_content)
    call add(l:content, 'No matches')
  else
    call extend(l:content, l:list_content)
  endif

  call popup_settext(a:ctx.winid, l:content)
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
  call win_execute(a:ctx.winid, 'highlight link FinderMatch Search')
  call win_execute(a:ctx.winid, 'highlight link FinderCursor CursorIM')
  call win_execute(a:ctx.winid, 'highlight link FinderStatus Type')
  call win_execute(a:ctx.winid, 'highlight link FinderDir Directory')
  call win_execute(a:ctx.winid, 'highlight link FinderFile String')
  call win_execute(a:ctx.winid, 'highlight link FinderNumber Number')
  call win_execute(a:ctx.winid, 'highlight link FinderStatusAlt WarningMsg')
  call win_execute(a:ctx.winid, 'highlight link FinderNone ErrorMsg')
  call win_execute(a:ctx.winid, 'highlight link FinderHash Identifier')

  call win_execute(a:ctx.winid, 'highlight link PopupSelected CursorLine')
  
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
  
  if !empty(get(a:ctx, 'columns_hl', [])) && !empty(a:ctx.matches)
    let l:max_hl_cols = min([len(a:ctx.matches), a:ctx.render_limit])
    let l:col_cmds = []
    for i in range(l:max_hl_cols)
      for j in range(len(a:ctx.columns_hl))
        let l:grp = a:ctx.columns_hl[j]
        if !empty(l:grp)
          if i < len(a:ctx.col_spans) && j < len(a:ctx.col_spans[i])
            let l:start = a:ctx.col_spans[i][j][0]
            let l:len = a:ctx.col_spans[i][j][1]
            if l:len > 0
              call add(l:col_cmds, "call matchaddpos('" . l:grp . "', " . string([[i + 3, l:start, l:len]]) . ")")
            endif
          endif
        endif
      endfor
    endfor
    if !empty(l:col_cmds)
      call win_execute(a:ctx.winid, l:col_cmds)
    endif
  endif
  
  if empty(a:ctx.filter) || empty(a:ctx.matches)
    if !get(a:ctx, 'dynamic_search', 0)
      return
    endif
  endif
  
  let l:max_hl = min([len(a:ctx.matches), a:ctx.render_limit])
  let l:cmds = []
  
  for i in range(l:max_hl)
    let l:item = a:ctx.matches[i]
    let l:line_num = i + 3
    let l:midx = index(a:ctx.display, get(a:ctx, 'match_item', ''))
    let l:offset = 0
    if l:midx != -1 && i < len(a:ctx.col_spans) && l:midx < len(a:ctx.col_spans[i])
      let l:offset = a:ctx.col_spans[i][l:midx][0] - 1
    endif
    
    if has_key(l:item, 'highlights')
      let l:hl_positions = []
      for l:hl in l:item.highlights
        " hl is [col, len]
        " Ensure we don't go out of bounds or invalid values
        if l:hl[0] > 0 && l:hl[1] > 0
          call add(l:hl_positions, [l:line_num, l:hl[0] + l:offset, l:hl[1]])
        endif
      endfor
      if !empty(l:hl_positions)
        call add(l:cmds, "call matchaddpos('FinderMatch', " . string(l:hl_positions) . ")")
      endif
    endif

    if has_key(a:ctx, 'match_positions')
      let l:pos_list = a:ctx.match_positions[i]
      let l:hl_positions = []
      for l:byte_idx in l:pos_list
          call add(l:hl_positions, [l:line_num, l:byte_idx + 1 + l:offset, 1])
      endfor
      
      if !empty(l:hl_positions)
         call add(l:cmds, "call matchaddpos('FinderMatch', " . string(l:hl_positions) . ")")
      endif
    endif
  endfor
    
  if !empty(l:cmds)
    call win_execute(a:ctx.winid, l:cmds)
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
    if empty(a:selected) && index(['open', 'open_with_new_tab', 'open_vertically', 'delete'], a:action) != -1
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

function! s:TriggerPreview(ctx, ...) abort
  let l:Preview = get(a:ctx.actions, 'preview', '')
  if empty(l:Preview)
    let l:Preview = get(a:ctx.default_actions, 'preview', '')
  endif

  if a:ctx.preview_enabled
    let l:d = get(a:000, 0, a:ctx.preview_delay)
    if a:ctx.preview_timer != -1
      call timer_stop(a:ctx.preview_timer)
      let a:ctx.preview_timer = -1
    endif
    if l:d > 0
      let a:ctx.preview_timer = timer_start(l:d, {-> s:DoPreview(a:ctx, l:Preview)})
    else
      call s:DoPreview(a:ctx, l:Preview)
    endif
  else
    if !empty(l:Preview)
      let l:line = line('.', a:ctx.winid)
      let l:index = l:line - 3
      if l:index >= 0 && l:index < len(a:ctx.matches)
        let a:ctx.selected = a:ctx.matches[l:index]
        call call(l:Preview, [], a:ctx)
      endif
    endif
  endif
endfunction

function! s:GuessFiletype(path) abort
  let l:ext = tolower(fnamemodify(a:path, ':e'))
  let l:map = {
        \ 'vim': 'vim',
        \ 'tex': 'tex',
        \ 'vue': 'vue',
        \ 'lua': 'lua',
        \ 'js': 'javascript',
        \ 'ts': 'typescript',
        \ 'json': 'json',
        \ 'py': 'python',
        \ 'go': 'go',
        \ 'rs': 'rust',
        \ 'java': 'java',
        \ 'sh': 'sh',
        \ 'md': 'markdown',
        \ 'yaml': 'yaml',
        \ 'yml': 'yaml',
        \ }
  return get(l:map, l:ext, 'text')
endfunction

function! myfinder#core#GuessFiletype(path) abort
  return s:GuessFiletype(a:path)
endfunction

function! s:DoPreview(ctx, Preview) abort
  " Determine selection
  let l:line = line('.', a:ctx.winid)
  let l:index = l:line - 3
  if l:index < 0 || l:index >= len(a:ctx.matches)
    return
  endif
  let a:ctx.selected = a:ctx.matches[l:index]
  " If custom preview is provided and preview window exists, let finder handle it
  if !empty(a:Preview)
    call call(a:Preview, [], a:ctx)
    return
  endif
  if a:ctx.preview_winid == 0
    return
  endif
  " Generic file preview via buffer
  let l:path = ''
  if has_key(a:ctx.selected, 'path')
    let l:path = a:ctx.selected.path
  elseif has_key(a:ctx.selected, 'file')
    let l:path = a:ctx.selected.file
  endif
  if empty(l:path) || !filereadable(l:path)
    call popup_settext(a:ctx.preview_winid, ['No preview available'])
    return
  endif
  let l:lines = readfile(l:path, '', 500)
  if empty(l:lines)
    let l:lines = ['']
  endif
  call popup_settext(a:ctx.preview_winid, l:lines)
  let l:ft = s:GuessFiletype(l:path)
  call win_execute(a:ctx.preview_winid, 'setlocal filetype=' . l:ft)
endfunction

function! s:BS() dict
  let self.filter = strcharpart(self.filter, 0, strchars(self.filter) - 1)
  call self.update_res()
endfunction

function! s:Clear() dict
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

function! s:GenericOpenHorizontally() dict
  call self.quit()
  execute 'split'
  call s:OpenItem(self.selected, 'edit')
endfunction

function! s:GenericOpenVertically() dict
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
    execute a:cmd . ' ' . fnameescape(a:item.file)
    if has_key(a:item, 'line')
      call cursor(a:item.line, get(a:item, 'col', 1))
      normal! zz
    endif
    return
  endif
  
  " Handle path
  if has_key(a:item, 'path')
    execute a:cmd . ' ' . fnameescape(a:item.path)
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
    " Check if we scrolled past the first visible line (which is prompt)
    " We want to keep lines 1 and 2 (prompt and separator) visible
    let l:topline = getwininfo(self.winid)[0].topline
    if l:topline > 1
        " Scroll back up to keep prompt visible
        call win_execute(self.winid, "normal! " . l:topline . "G2kzt")
        " Restore cursor position
        call win_execute(self.winid, "normal! " . (l:lnum + 1) . "G")
    endif
    call s:TriggerPreview(self, 0)
  endif
endfunction

function! s:SelectUp() dict
  let l:lnum = line('.', self.winid)
  if l:lnum > 3
    call win_execute(self.winid, "normal! k")
    call s:TriggerPreview(self, 0)
  endif
endfunction

function! s:FinderFilter(winid, key) abort
  let l:ctx = get(s:finders, a:winid, {})
  if empty(l:ctx)
    return 0
  endif

  let l:action = get(l:ctx.key_map, a:key, '')

  if l:action ==# 'select_action'
    let l:line = line('.', a:winid)
    if l:line < 3
      let l:line = 3
    endif
    let l:index = l:line - 3
    if l:index < len(l:ctx.matches)
      let l:ctx.selected = l:ctx.matches[l:index]
    else
      let l:ctx.selected = {}
    endif
    call s:ShowActions(l:ctx)
    return 1
  endif

  if empty(l:action) && a:key =~ '^\p$'
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

function! s:PreviewOnce() dict
  if self.preview_enabled
    call s:TriggerPreview(self, 0)
    return
  endif
  let self.preview_enabled = 1
  " Recompute dimensions to split equally
  if self.preview_layout ==# 'column'
    let self.width = float2nr(self.width / 2)
  else
    let self.height = float2nr(self.height / 2)
  endif
  let self.render_limit = self.height - 2
  " Resize and re-render main popup
  call popup_setoptions(self.winid, {
        \ 'minwidth': self.width,
        \ 'maxwidth': self.width,
        \ 'minheight': self.height,
        \ 'maxheight': self.height
        \ })
  call s:BuildContent(self)
  call s:ApplyHighLights(self)
  " Create and center preview window next to main
  call s:CreatePreviewWindow(self)
  call s:TriggerPreview(self, 0)
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

function! s:CopyPath() dict
  let l:path = ''
  if has_key(self.selected, 'path')
    let l:path = self.selected.path
  elseif has_key(self.selected, 'file')
    let l:path = self.selected.file
  endif
  
  if !empty(l:path)
    let l:abs_path = fnamemodify(l:path, ':p')
    call setreg('+', l:abs_path)
    call setreg('*', l:abs_path)
    call myfinder#core#echo('Copied: ' . l:abs_path, 'success')
  else
    call myfinder#core#echo('No path to copy', 'warn')
  endif
endfunction

function! s:ShowActions(ctx) abort
  let l:actions = []
  
  " Use shortcuts from context (populated during initialization)
  let l:shortcuts = a:ctx.action_shortcuts
  
  " Collect available actions
  let l:avail = keys(a:ctx.actions)
  
  " Add defaults ONLY if they make sense for the current item
  let l:has_path = has_key(a:ctx.selected, 'path') || has_key(a:ctx.selected, 'file')
  
  " File/Path related actions
  if l:has_path
    for l:a in ['open', 'open_with_new_tab', 'open_horizontally', 'open_vertically', 'copy_path', 'preview_once']
        if index(l:avail, l:a) == -1
            call add(l:avail, l:a)
        endif
    endfor
  else
    " For non-path items, we might still support 'open' if the finder provides a custom 'open' callback
    " But we should NOT blindly add tab/split/copy_path unless the finder explicitly supports them.
    " However, 'preview_once' might be supported if 'preview' callback is present.
    if has_key(a:ctx.actions, 'preview') && index(l:avail, 'preview_once') == -1
         call add(l:avail, 'preview_once')
    endif
  endif
  
  " Filter out 'preview' if 'preview_once' is present or vice-versa to avoid duplication
  " Usually 'preview' is the internal action name for automatic preview, 
  " while 'preview_once' is the manual toggle.
  " If 'preview' is in the list, it might be a custom action that does something different,
  " but typically we only want one way to trigger preview in the menu.
  " Let's remove 'preview' if 'preview_once' exists.
  let l:p_idx = index(l:avail, 'preview')
  if l:p_idx != -1 && index(l:avail, 'preview_once') != -1
    call remove(l:avail, l:p_idx)
  endif
  
  " Sort actions by name length (shortest first)
  call sort(l:avail, {a, b -> len(a) - len(b)})

  let l:lines = []
  let l:action_map = {}
  
  let l:used_keys = values(l:shortcuts)
  
  for l:act in l:avail
    " Skip preview if already enabled
    if l:act ==# 'preview_once' && get(a:ctx, 'preview_enabled', 0)
        continue
    endif

    let l:key = get(l:shortcuts, l:act, '')
    if empty(l:key)
        " Auto-assign key
        let l:c = tolower(l:act[0])
        if index(l:used_keys, l:c) == -1
             let l:key = l:c
        else
             " Try to find an unused letter a-z
             for l:i in range(char2nr('a'), char2nr('z'))
                let l:k = nr2char(l:i)
                if index(l:used_keys, l:k) == -1
                    let l:key = l:k
                    break
                endif
             endfor
        endif
    endif
    
    if empty(l:key)
        continue
    endif

    call add(l:used_keys, l:key)
    call add(l:lines, printf('%s %s', l:key, l:act))
    let l:action_map[l:key] = l:act
  endfor
  
  if empty(l:lines)
    return
  endif

  " Create a small popup in the center of the finder
  let l:w = 30
  let l:h = len(l:lines)
  let l:row = a:ctx.height / 2 - l:h / 2
  let l:col = a:ctx.width / 2 - l:w / 2
  
  " Absolute position based on finder window
  let l:pos = popup_getpos(a:ctx.winid)
  let l:line = l:pos.line + l:row
  let l:col_abs = l:pos.col + l:col

  let l:attr = {
        \ 'line': l:line,
        \ 'col': l:col_abs,
        \ 'minwidth': l:w,
        \ 'maxwidth': l:w,
        \ 'minheight': l:h,
        \ 'maxheight': l:h,
        \ 'border': [1,1,1,1],
        \ 'borderchars': g:myfinder_popup_borders,
        \ 'padding': [0,0,0,0],
        \ 'mapping': 0,
        \ 'filter': function('s:ActionMenuFilter'),
        \ 'zindex': 1000,
        \ }
  
  let l:winid = popup_create(l:lines, l:attr)
  
  " Add highlighting for shortcuts
  " Match the first character (shortcut) of the line
  call win_execute(l:winid, 'syntax match MyFinderActionKey /^\s*\zs.\ze\s/ contained')
  call win_execute(l:winid, 'syntax match MyFinderActionLine /.*/ contains=MyFinderActionKey')
  call win_execute(l:winid, 'highlight default link MyFinderActionKey Special')

  " Store context for the menu
  let s:action_menus[l:winid] = {
        \ 'winid': l:winid,
        \ 'parent_ctx': a:ctx,
        \ 'action_map': l:action_map,
        \ }
endfunction

function! s:ActionMenuFilter(winid, key) abort
  let l:ctx = get(s:action_menus, a:winid, {})
  if empty(l:ctx)
    call popup_close(a:winid)
    return 0
  endif

  if a:key == "\<Esc>"
    call popup_close(a:winid)
    if has_key(s:action_menus, a:winid)
      unlet s:action_menus[a:winid]
    endif
    return 1
  endif
  
  if has_key(l:ctx.action_map, a:key)
    let l:act = l:ctx.action_map[a:key]
    call popup_close(a:winid)
    if has_key(s:action_menus, a:winid)
      unlet s:action_menus[a:winid]
    endif
    
    " Execute action on parent
    let l:pctx = l:ctx.parent_ctx
    " We invoke HandleCallback.
    call s:HandleCallback(l:pctx, a:key, l:act, l:pctx.selected)
    return 1
  endif
  
  return 1
endfunction
