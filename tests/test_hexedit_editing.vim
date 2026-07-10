" Interactive overwrite-editing tests for modes/hexedit.vim.
"
" NOTE: headless `-es` batch execution does not fire CursorMoved /
" CursorMovedI (verified empirically -- these events depend on Vim's
" normal interactive main-loop cycle, which batch mode never enters).
" So instead of `:normal!` keystrokes, these tests call the mode's event
" hooks directly (hexedit#OnCursorMoved() / registry#Dispatch(...)) in the
" same sequence the real autocmds would, which exercises the exact same
" code path a real interactive edit does.

function! Test_HexeditEditing_OverwriteHexByte_MirrorsAscii() abort
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s ABCDEFGH > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)

    " First hex digit cell is at column 11: "00000000: " is 10 chars.
    call cursor(1, 11)
    call hexedit#OnCursorMoved()
    for l:ch in ['9', 'a']
        let v:char = l:ch
        call hexedit#registry#Dispatch('OnInsertCharPre')
        call hexedit#registry#Dispatch('OnCursorMovedI')
    endfor

    call assert_match('^00000000: 9a42 4344 4546 4748', getline(1))
    call assert_match('| \.BCDEFGH$', getline(1))

    let l:model = hexedit#registry#CurrentModel()
    let [l:ok, l:m2] = hexedit#modes#hexedit#Get().ViewToBinary(getline(1, '$'), l:model)
    call assert_equal(1, l:ok)
    call assert_equal('9a42434445464748', l:m2.plain_hex)

    bwipeout!
    call delete(l:path)
endfunction

function! Test_HexeditEditing_OverwriteAsciiByte_MirrorsHex() abort
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s ABCDEFGH > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)

    let l:line = getline(1)
    let l:pipe = stridx(l:line, '| ')
    " 2nd ascii character ('B'): 0-indexed pipe+3, Vim column pipe+4.
    call cursor(1, l:pipe + 4)
    call hexedit#OnCursorMoved()
    call assert_equal('B', getline('.')[col('.') - 1])

    let v:char = 'Z'
    call hexedit#registry#Dispatch('OnInsertCharPre')
    call hexedit#registry#Dispatch('OnCursorMovedI')

    " byte0 (0x41) unchanged, byte1 (0x42='B') -> 0x5a='Z', same group -> "415a"
    call assert_match('^00000000: 415a 4344 4546 4748', getline(1))
    call assert_match('| AZCDEFGH$', getline(1))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_HexeditEditing_InvalidHexDigitFallsBackToZero() abort
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s ABCDEFGH > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)

    call cursor(1, 11)
    call hexedit#OnCursorMoved()
    let v:char = 'z'  " not a hex digit
    call hexedit#registry#Dispatch('OnInsertCharPre')
    call hexedit#registry#Dispatch('OnCursorMovedI')

    " invalid input is coerced to '0' rather than accepted verbatim
    call assert_match('^00000000: 0142', getline(1))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_HexeditEditing_FirstKeystrokeWithoutPriorCursorMoved() abort
    " Regression test for the bug found during manual smoke-testing: typing
    " immediately after activation (before any CursorMoved has ever fired
    " for this buffer) must still overwrite correctly, not silently no-op
    " or fall through to a plain insert.
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s ABCDEFGH > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)

    call cursor(1, 11)
    " Deliberately do NOT call hexedit#OnCursorMoved() here.
    let v:char = 'f'
    call hexedit#registry#Dispatch('OnInsertCharPre')
    call hexedit#registry#Dispatch('OnCursorMovedI')

    call assert_match('^00000000: f142', getline(1))

    bwipeout!
    call delete(l:path)
endfunction

function! Test_HexeditEditing_FBar_JumpsToAsciiColumn() abort
    " Regression test for the documented "f|" tip: native Vim `f|` lands the
    " cursor on the separator character itself (classified 'hex-sepa' by
    " s:ColumnType), and the cursor-constraint logic (fixCursor, driven by
    " OnCursorMoved) then redirects it to the first ascii column -- this is
    " a deliberate interaction inherited from the pre-refactor plugin, not
    " a new feature, but it's easy to break silently in future refactors of
    " the column-geometry math, hence this test.
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s ABCDEFGH > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)

    call cursor(1, 11)
    call hexedit#OnCursorMoved()

    normal! f|
    " Headless batch mode does not fire CursorMoved automatically (verified
    " empirically); simulate what the real autocmd would do next.
    call hexedit#OnCursorMoved()

    let l:line = getline(1)
    let l:pipe = stridx(l:line, '| ')
    call assert_equal(l:pipe + 3, col('.'))
    call assert_equal('A', getline('.')[col('.') - 1])

    bwipeout!
    call delete(l:path)
endfunction
