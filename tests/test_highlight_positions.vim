set encoding=utf-8
set runtimepath^=.

let s:decorated = '▸ [    ]' . nr2char(7) . 'nested-subdir/'
let s:positions = matchfuzzypos(
      \ [{'text': s:decorated}], 'nested', {'key': 'text'})[1][0]
let s:spans = map(copy(s:positions),
      \ 'myfinder#core#_match_byte_span(s:decorated, v:val)')
call assert_equal(
      \ [[14, 1], [15, 1], [16, 1], [17, 1], [18, 1], [19, 1]],
      \ s:spans)

let s:icon_position = matchfuzzypos(
      \ [{'text': s:decorated}], '', {'key': 'text'})[1][0][0]
call assert_equal(
      \ [7, strlen('')],
      \ myfinder#core#_match_byte_span(s:decorated, s:icon_position))

let s:wide = '前缀目录'
let s:wide_positions = matchfuzzypos(
      \ [{'text': s:wide}], '目录', {'key': 'text'})[1][0]
let s:wide_spans = map(copy(s:wide_positions),
      \ 'myfinder#core#_match_byte_span(s:wide, v:val)')
call assert_equal([[6, 3], [9, 3]], s:wide_spans)

let s:combined = "e\u0301x"
let s:combined_position = matchfuzzypos(
      \ [{'text': s:combined}], 'x', {'key': 'text'})[1][0][0]
call assert_equal(
      \ [3, 1],
      \ myfinder#core#_match_byte_span(s:combined, s:combined_position))

if !empty(v:errors)
  echoerr join(v:errors, "\n")
  cquit
endif
quit
