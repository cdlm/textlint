" TODO
" - locate VM, image, launcher script
" - function to invoke textlint
" - adding / loading into the quickfix list
" - highlighting
" - toggling, options

"if exists('g:loaded_textlint') || &compatible
    "finish
"endif
"let g:loaded_textlint = 1

if !exists('g:textlint_highlight')
    let g:textlint_highlight = 1
endif

command! -nargs=? -complete=file TextLint :call s:TextLint(<f-args>)
nnoremap <leader>tl :TextLint

highlight link TextLintMatch SpellBad

let s:installDir = expand('<sfile>:p:h:h')
if has('win32')
    let s:vm = "/Windows32/pharo.exe"
elseif has('macunix')
    let s:vm = "/TextLint.tmbundle/Support/TextLint.app/Contents/MacOS/Croquet"
elseif has('unix')
    let s:vm = "/Linux32/pharo"
endif
let s:vm = s:installDir . s:vm
let s:launcher = s:installDir . "/textlint.bash"
let s:image = s:installDir . "/TextLint.tmbundle/Support/TextLint.image"

function! s:cmd(file)
    return s:launcher . ' ' . a:file . ' ' . s:vm . ' ' . s:image
endfunction

"/path/to/file.tex:L.C-L.C: explanation
"    excerpt
let s:detect_pattern = '\v[^:]+:\d+\.\d+-\d+\.\d+: .*$'
let s:message_pattern = '\v([^:]+):(\d+)\.(\d+)-(\d+)\.(\d+): (.+)$'
let s:excerpt_pattern = '\v\t(.+)$'

function! s:TextLint(...)
    let l:file = a:0 == 0 ? expand('%:p') : getcwd() . '/' . a:1
    echo 'Running TextLint on ' . l:file . '...'
    let l:textlint_output = split(system(s:cmd(l:file)), '\n')
    
    echo l:textlint_output

    let l:occurences = []
    let l:each = -1
    while l:each < len(l:textlint_output)
        " locate next lint message, break if none
        let l:each = s:nextSuggestion(l:textlint_output, l:each)
        if l:each == -1
            break
        endif
        " extract message & location info
        echo 'Suggestion at line ' . l:each
        let l:parts = matchlist(l:textlint_output[l:each], s:message_pattern)
        let l:occurence_info = {
            'file name':   l:parts[1],
            'from line':   l:parts[2],
            'from column': l:parts[3],
            'to line':     l:parts[4],
            'to column':   l:parts[5],
            'message':     l:parts[6],
            'excerpt':     matchlist(l:textlint_output[l:each + 1], s:excerpt_pattern)[1]
        }
        add(l:occurences, l:occurence_info)
        let l:occurence_pattern = s:matchPattern(l:occurence_info)
        matchadd('TextLintMatch', l:occurence_pattern)
        setqflist(s:qfItem(l:occurence_info, l:occurence_pattern), 'a')
        " continue looking on next line
        let l:each += 1
    endwhile
    copen
endfunction

" returns the index of the next suggestion in TextLint's output
function! s:nextSuggestion(lines, start_index)
    return match(a:lines, s:detect_pattern, a:start_index)
endfunction

" returns the pattern for highlighting a suggestion in the text
function! s:matchPattern(info)
    return '\%' . a:info['from line'] . 'l\%' . a:info['from column'] . 'c' . exerpt
endfunction

" builds a quickfix item
function! s:qfItem(info, pattern)
    return {
        'bufnr':     bufnr(a:info['file name'])
        'filename':  bufname(a:info['file name'])
        'pattern':   a:pattern
        'text':      a:info['excerpt'] . ': ' . a:info['message']
    }
endfunction

"function! Test_nextSuggestion()
"    call VUAssertEquals(
"                \ s:nextSuggestion(['abc','/path/to/file.tex:42.24-42.51: foo', 'def'], 0),
"                \ 1, 'First attempt')
"    call VUAssertEquals(
"                \ s:nextSuggestion(['abc','/path/to/file.tex:42.24-42.51: foo', 'def'], 1),
"                \ 1, 'Already attempted first line')
"    call VUAssertEquals(
"                \ s:nextSuggestion(['abc','/path/to/file.tex:42.24-42.51: foo', 'def'], 2),
"                \ -1, 'No more suggestions')
"endfunction
