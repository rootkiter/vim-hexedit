" Dependency-free test runner. Usage:
"   nvim --headless -u NONE -c "source tests/run.vim"
" (or vim in place of nvim on a real Vim 8.1+/Neovim install)
"
" Do NOT invoke this with `-es -S` (Ex silent batch mode): that mode has a
" confirmed quirk where, after a BufReadCmd handler replaces buffer content
" via deletebufline()+setline() (exactly what this plugin's mode rendering
" does), :edit leaves the cursor on the LAST line instead of line 1 -- only
" under `-es`, not under plain `--headless -c "..."` invocation, and not in
" real interactive use. Several large-file/search tests rely on the cursor
" actually starting at line 1, so they will spuriously fail under `-es`.
"
" Discovers every Test_* function defined by tests/test_*.vim and runs it,
" using Vim's built-in assert_*() functions (failures accumulate in
" v:errors). Exits with a non-zero status (via :cquit) if anything failed,
" so this is CI-friendly. Also writes tests/.last_run.log since headless
" mode does not reliably surface `:echom` output on stdout.

set nocompatible
let s:root = expand('<sfile>:p:h:h')
let s:logfile = s:root . '/tests/.last_run.log'
let s:log = []

function! s:Log(msg) abort
    call add(s:log, a:msg)
    call writefile(s:log, s:logfile)
endfunction

execute 'set runtimepath+=' . fnameescape(s:root)
runtime! plugin/hexedit.vim

let s:test_files = sort(globpath(s:root . '/tests', 'test_*.vim', 0, 1))
if empty(s:test_files)
    call s:Log('No test_*.vim files found under tests/')
    cquit
endif

for s:f in s:test_files
    try
        execute 'source ' . fnameescape(s:f)
    catch
        call s:Log('SOURCE ERROR in ' . s:f . ': ' . v:exception . ' @ ' . v:throwpoint)
        cquit
    endtry
endfor

" Discover Test_* functions.
redir => s:funclist
silent function /^Test_
redir END

let s:funcs = []
for s:line in split(s:funclist, "\n")
    let s:m = matchstr(s:line, 'Test_\w\+')
    if s:m !=# '' && index(s:funcs, s:m) < 0
        call add(s:funcs, s:m)
    endif
endfor
call sort(s:funcs)
call s:Log(printf('Discovered %d Test_* functions', len(s:funcs)))

let s:passed = 0
let s:total = 0
let s:failures = []

for s:fn in s:funcs
    let s:total += 1
    let v:errors = []
    try
        call call(s:fn, [])
    catch
        call add(v:errors, 'EXCEPTION: ' . v:exception . ' @ ' . v:throwpoint)
    endtry
    if len(v:errors) ==# 0
        let s:passed += 1
        call s:Log('PASS ' . s:fn)
    else
        call s:Log('FAIL ' . s:fn)
        for s:e in v:errors
            call s:Log('    ' . s:e)
            call add(s:failures, s:fn . ': ' . s:e)
        endfor
    endif
endfor

call s:Log(repeat('-', 40))
call s:Log(printf('%d/%d passed', s:passed, s:total))

if len(s:failures) > 0
    cquit
else
    quit
endif
