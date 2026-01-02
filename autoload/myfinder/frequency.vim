let s:freq_file = expand('~/.vim_myfinder_frequency.json')
let s:frequency = {}
let s:loaded = 0
let s:max_entries = 1000 " Limit the number of stored entries

function! s:IsEnabled() abort
  return get(g:, 'myfinder_enable_frequency', 0)
endfunction

function! s:Load() abort
  if !s:IsEnabled()
    return
  endif
  if s:loaded
    return
  endif
  
  if !filereadable(s:freq_file)
    let s:frequency = {}
    let s:loaded = 1
    return
  endif

  try
    let l:content = join(readfile(s:freq_file), "\n")
    let s:frequency = json_decode(l:content)
  catch
    let s:frequency = {}
  endtry
  
  " Clean up non-existent files during load
  call s:Cleanup()
  
  let s:loaded = 1
endfunction

function! s:Cleanup() abort
  let l:changed = 0
  let l:keys = keys(s:frequency)
  for l:key in l:keys
    if !filereadable(l:key)
      call remove(s:frequency, l:key)
      let l:changed = 1
    endif
  endfor
  
  " Enforce limit
  if len(s:frequency) > s:max_entries
    let l:sorted = sort(items(s:frequency), {a, b -> b[1] - a[1]})
    let s:frequency = {}
    for l:i in range(s:max_entries)
      let s:frequency[l:sorted[l:i][0]] = l:sorted[l:i][1]
    endfor
    let l:changed = 1
  endif
  
  return l:changed
endfunction

function! myfinder#frequency#save() abort
  if !s:IsEnabled()
    return
  endif
  if !s:loaded
      return
  endif
  call s:Cleanup()
  call writefile([json_encode(s:frequency)], s:freq_file)
endfunction

function! myfinder#frequency#get(path) abort
  if !s:IsEnabled()
    return 0
  endif
  call s:Load()
  let l:key = fnamemodify(a:path, ':p')
  return get(s:frequency, l:key, 0)
endfunction

function! myfinder#frequency#increase(path) abort
  if !s:IsEnabled()
    return
  endif
  call s:Load()
  let l:key = fnamemodify(a:path, ':p')
  let l:count = get(s:frequency, l:key, 0)
  let s:frequency[l:key] = l:count + 1
endfunction
