
command! FinderLine call myfinder#line#start()
command! FinderBuffer call myfinder#buffer#start()
command! FinderWindow call myfinder#window#start()
command! FinderMark call myfinder#mark#start()
command! FinderMRU call myfinder#mru#start()
command! FinderFiles call myfinder#files#start()
command! FinderGitLog call myfinder#git#log()
command! FinderColorscheme call myfinder#colorscheme#start()
command! FinderHistory call myfinder#history#start()
command! FinderCocDiagnostics call myfinder#coc#diagnostics()
command! FinderCocCommands call myfinder#coc#commands()
command! FinderCocExtensions call myfinder#coc#extensions()
command! FinderCocSymbols call myfinder#coc#symbols()
command! FinderCocWorkspaceSymbols call myfinder#coc#workspace_symbols()
command! Finder call myfinder#master#start()

nnoremap mm :call myfinder#mark#toggle()<CR>
nnoremap mj :call myfinder#mark#next()<CR>
nnoremap mk :call myfinder#mark#prev()<CR>

function! g:ReloadMyFinder() abort
  let l:plugin_root = fnamemodify(expand('<sfile>'), ':p:h:h')
  let l:autoload_files = glob(l:plugin_root . '/autoload/myfinder/*.vim', 0, 1)
  
  for l:file in l:autoload_files
    execute 'source ' . l:file
  endfor
  
  execute 'source ' . expand('<sfile>')
  call myfinder#core#echo('MyFinder reloaded!', 'success')
endfunction

" nnoremap <leader>r :call g:ReloadMyFinder()<CR>:Finder<CR>

command! FinderTogglePreview call myfinder#core#toggle_preview()
command! -nargs=1 FinderPreviewLayout call myfinder#core#set_preview_layout(<q-args>)

augroup MyFinderMarks
  autocmd!
  autocmd BufEnter * call myfinder#mark#restore_signs_for_buffer()
augroup END
