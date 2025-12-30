
command! FinderLine call myfinder#line#start()
command! FinderBuffer call myfinder#buffer#start()
command! FinderWindow call myfinder#window#start()
command! FinderMark call myfinder#mark#start()
command! FinderMRU call myfinder#mru#start()
command! FinderFiles call myfinder#files#start()
command! FinderGitLog call myfinder#git#log()
command! FinderColorscheme call myfinder#colorscheme#start()
command! Finder call myfinder#master#start()

nnoremap mm :call myfinder#mark#add()<CR>
nnoremap mn :call myfinder#mark#remove()<CR>

function! s:ReloadMyFinder() abort
  let l:plugin_root = fnamemodify(expand('<sfile>'), ':p:h:h')
  let l:autoload_files = glob(l:plugin_root . '/autoload/myfinder/*.vim', 0, 1)
  
  for l:file in l:autoload_files
    execute 'source ' . l:file
  endfor
  
  execute 'source ' . expand('<sfile>')
  echo 'MyFinder reloaded!'
endfunction

nnoremap <leader>r :call <SID>ReloadMyFinder()<CR>:Finder<CR>
