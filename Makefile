.PHONY: test

# Starts Vim with the current directory added to runtime path.
# Also adds a mapping <leader>r to reload the plugin.
test:
	vim -c "set rtp+=." \
	    -c "source plugin/line_finder.vim" \
	    -c "nnoremap <leader>r :source plugin/line_finder.vim<CR>:echo 'Plugin reloaded!'<CR>" \
	    -c "echo 'Press <leader>r to reload plugin'"
