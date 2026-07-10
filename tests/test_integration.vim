" End-to-end tests driving the real :Hedit/:Hex/:H2C/:H2Py/:HexLoad/:HexDump
" Ex commands, as a user would.

function! Test_Integration_SmallFile_FullCycle() abort
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s ABCD > ' . shellescape(l:path)])

    execute 'edit ' . fnameescape(l:path)
    call assert_equal(1, hexedit#registry#IsActive())
    call assert_equal('hexedit', hexedit#registry#CurrentModeName())
    call assert_equal('vhex', &l:filetype)
    call assert_equal(1, &l:modifiable)

    Hex
    call assert_equal('hexstr', hexedit#registry#CurrentModeName())
    call assert_equal('keephex', &l:filetype)

    H2C
    call assert_equal('c_view', hexedit#registry#CurrentModeName())
    call assert_equal('c', &l:filetype)
    call assert_equal(0, &l:modifiable)

    H2Py
    call assert_equal('py_view', hexedit#registry#CurrentModeName())
    call assert_equal('python', &l:filetype)
    call assert_equal(0, &l:modifiable)

    Hedit
    call assert_equal('hexedit', hexedit#registry#CurrentModeName())
    call assert_equal('vhex', &l:filetype)
    call assert_equal(1, &l:modifiable)
    call assert_equal('41424344', hexedit#registry#CurrentModel().plain_hex)

    HexDump
    call assert_equal(0, hexedit#registry#IsActive())
    call assert_equal(1, len(getline(1, '$')))
    call assert_equal('4142 4344', getline(1))
    call assert_equal(0, &l:binary)

    bwipeout!
    call delete(l:path)
endfunction

function! Test_Integration_HexLoad_EntersStateMachine() abort
    new
    call setline(1, '41 42 43 44')
    HexLoad
    call assert_equal(1, hexedit#registry#IsActive())
    call assert_equal('hexedit', hexedit#registry#CurrentModeName())
    call assert_equal('41424344', hexedit#registry#CurrentModel().plain_hex)
    call hexedit#registry#Deactivate()
    bwipeout!
endfunction

function! Test_Integration_HexLoad_RejectsInvalidHex() abort
    new
    call setline(1, 'not hex at all!!')
    HexLoad
    call assert_equal(0, hexedit#registry#IsActive())
    bwipeout!
endfunction

" ---- HexLoad write_mode confirmation (REQUIREMENTS 6.3) --------------------

let s:prompt_calls = []
function! s:RecordPrompt(msg) abort
    call add(s:prompt_calls, a:msg)
    return 1
endfunction

function! Test_Integration_HexLoad_UnnamedBuffer_NeverPrompts() abort
    new
    call setline(1, '41 42 43 44')
    let s:prompt_calls = []
    call hexedit#HexLoad({'confirm_fn': function('s:RecordPrompt')})
    call assert_equal([], s:prompt_calls)
    call assert_equal('binary', hexedit#registry#CurrentModel().write_mode)
    call assert_equal('', hexedit#registry#CurrentModel().path)
    call hexedit#registry#Deactivate()
    bwipeout!
endfunction

function! Test_Integration_HexLoad_NamedBuffer_ChoosesBinary() abort
    let l:path = tempname() . '.txt'
    call writefile(['41 42 43 44'], l:path)
    execute 'edit ' . fnameescape(l:path)

    call hexedit#HexLoad({'confirm_fn': {msg -> 1}})
    call assert_equal('binary', hexedit#registry#CurrentModel().write_mode)
    call assert_equal(fnamemodify(l:path, ':p'), hexedit#registry#CurrentModel().path)

    let l:model = hexedit#registry#CurrentModel()
    let l:model.plain_hex = '5a425a44'
    let b:hexedit_state.model = l:model
    call hexedit#registry#RenderCurrent()
    write

    call assert_equal('ZBZD', system(['cat', l:path]))
    bwipeout!
    call delete(l:path)
endfunction

function! Test_Integration_HexLoad_NamedBuffer_ChoosesText() abort
    let l:path = tempname() . '.txt'
    call writefile(['41 42 43 44'], l:path)
    execute 'edit ' . fnameescape(l:path)

    call hexedit#HexLoad({'confirm_fn': {msg -> 2}})
    call assert_equal('text', hexedit#registry#CurrentModel().write_mode)

    let l:model = hexedit#registry#CurrentModel()
    let l:model.plain_hex = '5a425a44'
    let b:hexedit_state.model = l:model
    call hexedit#registry#RenderCurrent()
    write

    " written back as hex-string TEXT, not decoded binary
    call assert_equal(['5a42 5a44'], readfile(l:path))
    bwipeout!
    call delete(l:path)
endfunction

function! Test_Integration_HexDump_WorksFromReadOnlyMode() abort
    " HexDump works from ANY active mode, not just Hex Edit mode. A
    " read-only mode (c_view here) has no editable buffer text, so the
    " existing model (unchanged, since c_view can't edit it) is dumped.
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s AB > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)
    H2C
    HexDump
    call assert_equal(0, hexedit#registry#IsActive())
    call assert_equal('4142', getline(1))
    bwipeout!
    call delete(l:path)
endfunction

function! Test_Integration_HexDump_WorksFromHexstrMode() abort
    " HexDump from an editable non-hexedit mode (Hex string) parses the
    " buffer text via that mode's own ViewToBinary before dumping.
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s AB > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)
    Hex
    call setline(1, '4343')
    HexDump
    call assert_equal(0, hexedit#registry#IsActive())
    call assert_equal('4343', getline(1))
    bwipeout!
    call delete(l:path)
endfunction

function! Test_Integration_SaveWritesFile() abort
    let l:path = tempname() . '.dat'
    call system(['sh', '-c', 'printf %s AAAA > ' . shellescape(l:path)])
    execute 'edit ' . fnameescape(l:path)
    " overwrite first byte's hex digits in-place: line is like
    " "00000000: 4141 4141  | AAAA" -- flip to 42 (B) via the model directly
    " to keep this test independent of exact column math already covered
    " by the cursor/keystroke tests.
    let l:model = hexedit#registry#CurrentModel()
    let l:model.plain_hex = '42424242'
    let b:hexedit_state.model = l:model
    call hexedit#registry#RenderCurrent()
    write
    call assert_equal('BBBB', system(['cat', l:path]))
    bwipeout!
    call delete(l:path)
endfunction

function! Test_Integration_NonHexeditBufferWriteUnaffected() abort
    let l:path = tempname() . '.txt'
    new
    execute 'write ' . fnameescape(l:path)
    call assert_equal('', system(['cat', l:path]))
    bwipeout!
    call delete(l:path)
endfunction
