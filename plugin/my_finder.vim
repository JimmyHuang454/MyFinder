
command! FinderLine call myfinder#finders#line#start()
command! FinderBuffer call myfinder#finders#buffer#start()
command! FinderWindow call myfinder#finders#window#start()
command! FinderMark call myfinder#finders#mark#start()
command! FinderMRU call myfinder#finders#mru#start()
command! FinderFiles call myfinder#finders#files#start()
command! FinderGitLog call myfinder#finders#git#log()
command! FinderColorscheme call myfinder#finders#colorscheme#start()
command! FinderHistory call myfinder#finders#history#start()
command! FinderCocDiagnostics call myfinder#finders#coc#diagnostics()
command! FinderCocCommands call myfinder#finders#coc#commands()
command! FinderCocExtensions call myfinder#finders#coc#extensions()
command! FinderCocSymbols call myfinder#finders#coc#symbols()
command! FinderCocWorkspaceSymbols call myfinder#finders#coc#workspace_symbols()
command! FinderCtagsFile call myfinder#finders#ctags#start('file')
command! FinderCtagsWorkspace call myfinder#finders#ctags#start('project')

command! FinderRgAllLine call myfinder#finders#rg#start('^')
command! -nargs=* FinderRg call myfinder#finders#rg#start(<q-args>)

command! Finder call myfinder#finders#master#start()

nnoremap mm :call myfinder#finders#mark#toggle()<CR>
nnoremap mj :call myfinder#finders#mark#next()<CR>
nnoremap mk :call myfinder#finders#mark#prev()<CR>
nnoremap gs :call myfinder#finders#rg#start(expand('<cword>'))<CR>

function! g:ReloadMyFinder() abort
  let l:plugin_root = fnamemodify(expand('<sfile>'), ':p:h:h')
  let l:autoload_files = glob(l:plugin_root . '/autoload/myfinder/*.vim', 0, 1)
  call extend(l:autoload_files, glob(l:plugin_root . '/autoload/myfinder/finders/*.vim', 0, 1))
  
  for l:file in l:autoload_files
    execute 'source ' . l:file
  endfor
  
  execute 'source ' . expand('<sfile>')
  call myfinder#utils#echo('MyFinder reloaded!', 'success')
endfunction

" nnoremap <leader>r :call g:ReloadMyFinder()<CR>:Finder<CR>

command! FinderTogglePreview call myfinder#core#toggle_preview()
command! -nargs=1 FinderPreviewLayout call myfinder#core#set_preview_layout(<q-args>)

augroup MyFinderMarks
  autocmd!
  autocmd BufEnter * call myfinder#finders#mark#restore_signs_for_buffer()
  autocmd VimLeave * call myfinder#frequency#save()
augroup END
