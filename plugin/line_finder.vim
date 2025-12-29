
command! LineFinder call myfinder#line#start()
command! BufferFinder call myfinder#buffer#start()
command! WindowFinder call myfinder#window#start()
command! MarkFinder call myfinder#mark#start()
command! MRUFinder call myfinder#mru#start()
command! FilesFinder call myfinder#files#start()
command! GitFilesFinder call myfinder#gitfiles#start()
command! GitLogFinder call myfinder#git#log()
command! ColorschemeFinder call myfinder#colorscheme#start()
command! Finder call myfinder#master#start()
nnoremap mm :call myfinder#mark#add()<CR>
nnoremap <leader>r :source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/core.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/line.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/buffer.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/window.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/mark.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/master.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/mru.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/files.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/gitfiles.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/git.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/autoload/myfinder/colorscheme.vim<CR>:source /Users/qwe/Desktop/my/project/myfinder/plugin/line_finder.vim<CR>:echo 'Plugin reloaded!'<CR>:Finder<CR>
