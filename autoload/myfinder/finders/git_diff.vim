" Changed files with a diff preview: status, +added -deleted lines.
"
"   :FinderGitDiff [commit]    files changed by a commit (default: the commit
"                              under the cursor, otherwise ask)
"   :FinderGitDiff staged      staged changes   (HEAD     vs index)
"   :FinderGitDiff unstaged    unstaged changes (index    vs work tree)
"   :FinderGitStatus           staged + unstaged + untracked, tagged S / U / ?
"
" <CR> opens a two-window diff (left: old, right: new) in the shared diff tab
" (see myfinder#difftab) while this finder stays alive. In the diff tab
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

function! s:StatText(f) abort
  if a:f.add ==# '?'
    return ['   new', '']
  endif
  return [printf('%6s', a:f.add ==# '-' ? 'bin' : '+' . a:f.add),
        \ printf('%6s', a:f.del ==# '-' ? 'bin' : '-' . a:f.del)]
endfunction

" Objects of both sides of the diff of one file ('' = no such side,
" 'worktree' = the file on disk, otherwise <rev>:<path> for git / fugitive)
function! s:Sides(kind, sha, has_parent, f) abort
  let l:file = a:f.file
  let l:st = a:f.status
  if a:kind ==# 'commit'
    return [(l:st ==# 'A' || !a:has_parent) ? '' : a:sha . '^:' . l:file,
          \ l:st ==# 'D' ? '' : a:sha . ':' . l:file]
  elseif a:kind ==# 'staged'
    return [l:st ==# 'A' ? '' : 'HEAD:' . l:file, l:st ==# 'D' ? '' : ':0:' . l:file]
  elseif a:kind ==# 'unstaged'
    return [l:st ==# 'A' ? '' : ':0:' . l:file, l:st ==# 'D' ? '' : 'worktree']
  endif
  return ['', 'worktree']
endfunction

function! s:Collect(root, kind) abort
  let l:args = a:kind ==# 'staged' ? ['diff', '--cached'] : ['diff']
  return s:ParseFiles(s:Git(a:root, l:args + ['--raw', '--numstat', '--no-renames', '--no-color']))
endfunction

" arg: '' (cursor / ask), 'staged', 'unstaged', 'status' or a commit
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

  let l:arg = a:0 > 0 ? a:1 : ''
  let l:sha = ''
  let l:files = []
  let l:name = ''
  if l:arg =~# '^\%(staged\|cached\)$'
    let l:mode = 'staged'
    let l:name = 'Staged changes'
    let l:files = map(s:Collect(l:root, 'staged'), 'extend(v:val, {"kind": "staged", "stage": "S"})')
  elseif l:arg ==# 'unstaged'
    let l:mode = 'unstaged'
    let l:name = 'Unstaged changes'
    let l:files = map(s:Collect(l:root, 'unstaged'), 'extend(v:val, {"kind": "unstaged", "stage": "U"})')
  elseif l:arg =~# '^\%(status\|worktree\)$'
    let l:mode = 'status'
    let l:name = 'Working tree'
    let l:files = map(s:Collect(l:root, 'staged'), 'extend(v:val, {"kind": "staged", "stage": "S"})')
    call extend(l:files, map(s:Collect(l:root, 'unstaged'), 'extend(v:val, {"kind": "unstaged", "stage": "U"})'))
    for l:path in s:Git(l:root, ['ls-files', '--others', '--exclude-standard'])
      call add(l:files, {'file': l:path, 'status': '?', 'add': '?', 'del': '?', 'kind': 'untracked', 'stage': '?'})
    endfor
  else
    let l:mode = 'commit'
    let l:rev = l:arg
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
    let l:name = get(s:Git(l:root, ['log', '-1', '--format=%h %s', l:sha]), 0, l:sha)
    let l:files = map(s:ParseFiles(s:Git(l:root, ['show', '--raw', '--numstat', '--format=',
          \ '--no-renames', '-m', '--first-parent', '--no-color', l:sha])),
          \ 'extend(v:val, {"kind": "commit", "stage": ""})')
  endif
  if empty(l:files)
    call myfinder#utils#echo('No changes: ' . (l:arg ==# '' ? l:sha[:6] : l:arg), 'warn')
    return
  endif

  call s:Highlight()
  let l:has_parent = l:sha ==# '' ? 1 : !empty(s:Git(l:root, ['rev-parse', '--verify', '-q', l:sha . '^']))
  let s:pending = {
        \ 'sha': l:sha,
        \ 'label': l:sha ==# '' ? l:name : l:sha[:6],
        \ 'root': l:root,
        \ 'gitdir': exists('*FugitiveGitDir') ? FugitiveGitDir() : '',
        \ 'files': l:files,
        \ }

  let l:items = []
  for l:i in range(len(l:files))
    let l:f = l:files[l:i]
    let l:f.sides = s:Sides(l:f.kind, l:sha, l:has_parent, l:f)
    let l:stat = s:StatText(l:f)
    call add(l:items, {
          \ 'text': l:f.file,
          \ 'idx': l:i,
          \ 'stage': l:f.stage,
          \ 'status': l:f.status,
          \ 'stat_add': l:stat[0],
          \ 'stat_del': l:stat[1],
          \ })
  endfor

  let l:display = ['status', 'stat_add', 'stat_del', 'text']
  let l:hl = ['MyFinderDiffStat', 'MyFinderDiffAdd', 'MyFinderDiffDel', '']
  if l:mode ==# 'status'
    let l:display = ['stage'] + l:display
    let l:hl = ['MyFinderDiffIdx'] + l:hl
  endif
  call myfinder#core#start(l:items, {
        \ 'open': function('s:Open'),
        \ 'open_with_new_tab': function('s:Open'),
        \ 'open_vertically': function('s:Open'),
        \ 'open_horizontally': function('s:Open'),
        \ 'preview': function('s:Preview'),
        \ }, {
        \ 'name': l:name,
        \ 'display': l:display,
        \ 'columns_hl': l:hl,
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
  let l:ft = 'diff'
  if l:f.kind ==# 'commit'
    let l:lines = s:Git(s:pending.root, ['show', '--format=', '--no-renames', '-m',
          \ '--first-parent', '--no-color', s:pending.sha, '--', l:f.file])
  elseif l:f.kind ==# 'staged'
    let l:lines = s:Git(s:pending.root, ['diff', '--cached', '--no-renames', '--no-color', '--', l:f.file])
  elseif l:f.kind ==# 'unstaged'
    let l:lines = s:Git(s:pending.root, ['diff', '--no-renames', '--no-color', '--', l:f.file])
  else
    " untracked: show the file itself
    let l:path = s:pending.root . '/' . l:f.file
    let l:lines = filereadable(l:path) ? readfile(l:path, '', 300) : []
    let l:ft = ''
  endif
  call popup_settext(self.preview_winid, empty(l:lines) ? ['No preview available'] : l:lines)
  call popup_setoptions(self.preview_winid, {'title': ' ' . l:f.file . ' '})
  call win_execute(self.preview_winid, 'setlocal filetype=' . l:ft)
endfunction

" Open one side of the diff in the current window. obj: see s:Sides().
" With fugitive it is a regular fugitive:// buffer, otherwise a scratch buffer.
function! s:Edit(state, obj, file) abort
  if a:obj ==# 'worktree'
    execute 'silent edit ' . fnameescape(a:state.root . '/' . a:file)
    return
  endif
  if exists('*FugitiveFind') && a:state.gitdir !=# ''
    execute 'silent edit ' . fnameescape(FugitiveFind(a:obj, a:state.gitdir))
    return
  endif
  enew
  call setline(1, s:Git(a:state.root, ['show', a:obj]))
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodifiable
  execute 'file ' . fnameescape(substitute(a:obj, '^\(\x\{7}\)\x*', '\1', ''))
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

" Build the diff windows in the current (diff) tab: left = old, right = new
function! s:Setup(state, idx) abort
  let l:f = a:state.files[a:idx]
  let [l:left, l:right] = l:f.sides
  let t:myfinder_git_diff = {'state': a:state, 'idx': a:idx}

  if l:left ==# ''
    call s:Edit(a:state, l:right, l:f.file)
  elseif l:right ==# ''
    call s:Edit(a:state, l:left, l:f.file)
  else
    call s:Edit(a:state, l:right, l:f.file)
    diffthis
    leftabove vertical new
    call s:Edit(a:state, l:left, l:f.file)
    diffthis
    wincmd l
    silent! normal! gg]czz
  endif

  let l:stat_grp = get({'A': 'MyFinderDiffAdd', 'D': 'MyFinderDiffDel', '?': 'MyFinderDiffAdd'}, l:f.status, 'MyFinderDiffStat')
  let l:dir = fnamemodify(l:f.file, ':h')
  let l:stat = s:StatText(l:f)
  let l:parts = [
        \ [printf('[%d/%d] ', a:idx + 1, len(a:state.files)), 'MyFinderDiffIdx'],
        \ [l:f.stage ==# '' ? '' : l:f.stage . ' ', 'MyFinderDiffIdx'],
        \ [l:f.status . '  ', l:stat_grp],
        \ [l:dir ==# '.' ? '' : l:dir . '/', 'MyFinderDiffSha'],
        \ [fnamemodify(l:f.file, ':t'), 'MyFinderDiffFile'],
        \ ['  ', 'None'],
        \ [trim(l:stat[0]), 'MyFinderDiffAdd'],
        \ [' ', 'None'],
        \ [trim(l:stat[1]), 'MyFinderDiffDel'],
        \ ['   ' . a:state.label, 'MyFinderDiffSha'],
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
