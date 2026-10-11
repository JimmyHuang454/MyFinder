" Files changed by a commit: status, +added -deleted lines, with a diff preview.
" <CR> opens a two-window diff (left: parent, right: commit) in the shared diff
" tab (see myfinder#difftab) while this finder stays alive. In the diff tab
" ]f / [f jump to the next / previous changed file; q / gF / :q leave diff mode
" and return to this finder.
"
" Uses plain git; vim-fugitive is optional (used for the revision under the
" cursor in fugitive buffers, and for the diff buffers if it is installed).
"
" Customize ]f / [f with:
"   let g:myfinder_git_diff_keys = {'next': ']f', 'prev': '[f'}
" (q / gF belong to the diff tab: g:myfinder_difftab_keys)

let s:pending = {}

function! s:Highlight() abort
  highlight default MyFinderDiffStat guifg=#e5c07b ctermfg=3
  highlight default MyFinderDiffAdd  guifg=#98c379 ctermfg=2
  highlight default MyFinderDiffDel  guifg=#e06c75 ctermfg=1
  highlight default link MyFinderDiffIdx  Title
  highlight default link MyFinderDiffFile Directory
  highlight default link MyFinderDiffSha  Comment
endfunction

" parts: [[text, highlight group], ...]
function! s:EchoLater(idx, parts, timer) abort
  if exists('t:myfinder_git_diff') && t:myfinder_git_diff.idx == a:idx
    call s:Echo(a:parts)
  endif
endfunction

function! s:Echo(parts) abort
  redraw
  echo ''
  try
    for [l:text, l:grp] in a:parts
      execute 'echohl ' . l:grp
      echon l:text
    endfor
  finally
    echohl None
  endtry
endfunction

function! s:Git(root, args) abort
  let l:cmd = 'git -C ' . shellescape(a:root) . ' -c core.quotepath=false '
        \ . join(map(copy(a:args), 'shellescape(v:val)'), ' ')
  let l:out = systemlist(l:cmd)
  return v:shell_error ? [] : l:out
endfunction

function! s:Root() abort
  if exists('*FugitiveWorkTree') && FugitiveWorkTree() !=# ''
    return FugitiveWorkTree()
  endif
  let l:dir = expand('%:p:h')
  if l:dir ==# '' || !isdirectory(l:dir)
    let l:dir = getcwd()
  endif
  let l:res = s:Git(l:dir, ['rev-parse', '--show-toplevel'])
  return empty(l:res) ? '' : l:res[0]
endfunction

" Revision under the cursor: fugitive object > hash in the current line > word
function! s:RevAtCursor() abort
  if exists('*FugitiveParse') && expand('%') =~# '^fugitive://'
    let l:m = matchstr(FugitiveParse()[0], '^\x\{7,40}\ze\%(:\|$\)')
    if l:m !=# ''
      return l:m
    endif
  endif
  let l:m = matchstr(getline('.'), '\v<\x{7,40}>')
  if l:m !=# ''
    return l:m
  endif
  let l:w = expand('<cword>')
  return l:w =~# '^\x\{7,40}$' ? l:w : ''
endfunction

function! s:ParseFiles(lines) abort
  " raw:     :100644 100644 aaaaaaa bbbbbbb M<TAB>path
  " numstat: 12<TAB>3<TAB>path   (binary: -<TAB>-<TAB>path)
  let l:by_path = {}
  let l:order = []
  for l:line in a:lines
    if l:line[0] ==# ':'
      let l:parts = split(l:line, "\t", 1)
      let l:path = join(l:parts[1:], "\t")
      let l:by_path[l:path] = {'file': l:path, 'status': l:parts[0][-1:], 'add': '-', 'del': '-'}
      call add(l:order, l:path)
    else
      let l:m = matchlist(l:line, '^\(\d\+\|-\)\t\(\d\+\|-\)\t\(.*\)$')
      if !empty(l:m) && has_key(l:by_path, l:m[3])
        let l:by_path[l:m[3]].add = l:m[1]
        let l:by_path[l:m[3]].del = l:m[2]
      endif
    endif
  endfor
  return map(l:order, 'l:by_path[v:val]')
endfunction

function! myfinder#finders#git_diff#start(...) abort
  let l:start_time = reltime()
  if !executable('git')
    call myfinder#utils#echo('Git is not executable', 'error')
    return
  endif
  let l:root = s:Root()
  if l:root ==# ''
    call myfinder#utils#echo('Not a git repository', 'error')
    return
  endif

  let l:rev = a:0 > 0 ? a:1 : ''
  if l:rev ==# ''
    let l:rev = s:RevAtCursor()
  endif
  if l:rev ==# ''
    let l:rev = input('Commit: ', 'HEAD')
  endif
  let l:sha = s:Git(l:root, ['rev-parse', '--verify', '-q', l:rev . '^{commit}'])
  if empty(l:sha)
    call myfinder#utils#echo('Not a commit: ' . l:rev, 'error')
    return
  endif
  let l:sha = l:sha[0]

  let l:files = s:ParseFiles(s:Git(l:root, ['show', '--raw', '--numstat', '--format=',
        \ '--no-renames', '-m', '--first-parent', '--no-color', l:sha]))
  if empty(l:files)
    call myfinder#utils#echo('No changed files in ' . l:rev, 'warn')
    return
  endif

  call s:Highlight()
  let s:pending = {
        \ 'sha': l:sha,
        \ 'root': l:root,
        \ 'gitdir': exists('*FugitiveGitDir') ? FugitiveGitDir() : '',
        \ 'has_parent': !empty(s:Git(l:root, ['rev-parse', '--verify', '-q', l:sha . '^'])),
        \ 'files': l:files,
        \ }

  let l:items = []
  for l:i in range(len(l:files))
    let l:f = l:files[l:i]
    call add(l:items, {
          \ 'text': l:f.file,
          \ 'idx': l:i,
          \ 'status': l:f.status,
          \ 'stat_add': printf('%6s', l:f.add ==# '-' ? 'bin' : '+' . l:f.add),
          \ 'stat_del': printf('%6s', l:f.del ==# '-' ? 'bin' : '-' . l:f.del),
          \ })
  endfor

  call myfinder#core#start(l:items, {
        \ 'open': function('s:Open'),
        \ 'open_with_new_tab': function('s:Open'),
        \ 'open_vertically': function('s:Open'),
        \ 'open_horizontally': function('s:Open'),
        \ 'preview': function('s:Preview'),
        \ }, {
        \ 'name': get(s:Git(l:root, ['log', '-1', '--format=%h %s', l:sha]), 0, l:sha),
        \ 'display': ['status', 'stat_add', 'stat_del', 'text'],
        \ 'columns_hl': ['MyFinderDiffStat', 'MyFinderDiffAdd', 'MyFinderDiffDel', ''],
        \ 'status': 'Git',
        \ 'start_time': l:start_time,
        \ })
endfunction

" The finder is not closed: its popup belongs to the current tab, so it is
" hidden while the diff tab is shown and comes back when that tab is closed.
function! s:Open() dict
  if self.preview_timer != -1
    call timer_stop(self.preview_timer)
    let self.preview_timer = -1
  endif
  call s:Show(s:pending, self.selected.idx, self)
endfunction

function! s:Preview() dict
  if self.preview_winid == 0 || empty(s:pending)
    return
  endif
  let l:f = s:pending.files[self.selected.idx]
  let l:lines = s:Git(s:pending.root, ['show', '--format=', '--no-renames', '-m',
        \ '--first-parent', '--no-color', s:pending.sha, '--', l:f.file])
  call popup_settext(self.preview_winid, empty(l:lines) ? ['No preview available'] : l:lines)
  call popup_setoptions(self.preview_winid, {'title': ' ' . l:f.file . ' '})
  call win_execute(self.preview_winid, 'setlocal filetype=diff')
endfunction

" Open one side of the diff in the current window.
" With fugitive it is a regular fugitive:// buffer, otherwise a scratch buffer.
function! s:Edit(state, rev, file) abort
  if exists('*FugitiveFind') && a:state.gitdir !=# ''
    execute 'silent edit ' . fnameescape(FugitiveFind(a:rev . ':' . a:file, a:state.gitdir))
    return
  endif
  enew
  let l:lines = s:Git(a:state.root, ['show', a:rev . ':' . a:file])
  call setline(1, l:lines)
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodifiable
  execute 'file ' . fnameescape(substitute(a:rev, '^\(\x\{7}\)\x*', '\1', '') . ':' . a:file)
  execute 'silent! doautocmd filetypedetect BufRead ' . fnameescape(a:file)
endfunction

function! s:Maps() abort
  let l:keys = extend({'next': ']f', 'prev': '[f'}, get(g:, 'myfinder_git_diff_keys', {}))
  execute 'nnoremap <buffer><silent> ' . l:keys.next . ' :call myfinder#finders#git_diff#move(1)<CR>'
  execute 'nnoremap <buffer><silent> ' . l:keys.prev . ' :call myfinder#finders#git_diff#move(-1)<CR>'
endfunction

" Show file idx in the shared diff tab (a new one, or the current diff tab)
function! s:Show(state, idx, ctx) abort
  let l:opts = {'on_maps': function('s:Maps')}
  if !empty(a:ctx)
    let l:opts.ctx = a:ctx
  endif
  call myfinder#difftab#open(function('s:Setup', [a:state, a:idx]), l:opts)
endfunction

" Build the diff windows in the current (diff) tab: left = parent, right = commit
function! s:Setup(state, idx) abort
  let l:f = a:state.files[a:idx]
  let l:sha = a:state.sha
  let t:myfinder_git_diff = {'state': a:state, 'idx': a:idx}

  if l:f.status ==# 'D'
    call s:Edit(a:state, l:sha . '^', l:f.file)
  elseif l:f.status ==# 'A' || !a:state.has_parent
    call s:Edit(a:state, l:sha, l:f.file)
  else
    call s:Edit(a:state, l:sha, l:f.file)
    diffthis
    leftabove vertical new
    call s:Edit(a:state, l:sha . '^', l:f.file)
    diffthis
    wincmd l
    silent! normal! gg]czz
  endif

  let l:stat_grp = get({'A': 'MyFinderDiffAdd', 'D': 'MyFinderDiffDel'}, l:f.status, 'MyFinderDiffStat')
  let l:dir = fnamemodify(l:f.file, ':h')
  let l:parts = [
        \ [printf('[%d/%d] ', a:idx + 1, len(a:state.files)), 'MyFinderDiffIdx'],
        \ [l:f.status . '  ', l:stat_grp],
        \ [l:dir ==# '.' ? '' : l:dir . '/', 'MyFinderDiffSha'],
        \ [fnamemodify(l:f.file, ':t'), 'MyFinderDiffFile'],
        \ ['   ', 'None'],
        \ [l:f.add ==# '-' ? 'bin' : '+' . l:f.add, 'MyFinderDiffAdd'],
        \ [' ', 'None'],
        \ [l:f.del ==# '-' ? '' : '-' . l:f.del, 'MyFinderDiffDel'],
        \ ['   ' . l:sha[:6], 'MyFinderDiffSha'],
        \ ]
  " The finder reports "Action completed" right after its callback returns and
  " would overwrite this message, so show it a moment later.
  call timer_start(30, function('s:EchoLater', [a:idx, l:parts]))
endfunction

function! myfinder#finders#git_diff#move(step) abort
  if !exists('t:myfinder_git_diff')
    return
  endif
  let l:state = t:myfinder_git_diff.state
  let l:n = len(l:state.files)
  call s:Show(l:state, (t:myfinder_git_diff.idx + a:step + l:n) % l:n, {})
endfunction
