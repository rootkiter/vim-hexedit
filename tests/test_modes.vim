" Tests for the four concrete mode objects + the format_parse placeholder.

function! Test_Mode_Hexedit_Basics() abort
    let l:mode = hexedit#modes#hexedit#Get()
    call assert_equal('hexedit', l:mode.Name())
    call assert_equal('vhex', l:mode.FileType())
    call assert_equal(1, has_key(l:mode, 'ViewToBinary'))
    let l:m = hexedit#model#FromPlainHex('41424344', {'octets_per_line': 16})
    let l:lines = l:mode.BinaryToView(l:m)
    let [l:ok, l:m2] = l:mode.ViewToBinary(l:lines, l:m)
    call assert_equal(1, l:ok)
    call assert_equal('41424344', l:m2.plain_hex)
endfunction

function! Test_Mode_Hexstr_RoundTrip() abort
    let l:mode = hexedit#modes#hexstr#Get()
    call assert_equal('hexstr', l:mode.Name())
    call assert_equal('keephex', l:mode.FileType())
    let l:m = hexedit#model#FromPlainHex('41424344',
                \ {'group_octets_num': 2, 'octets_per_line': 4})
    let l:lines = l:mode.BinaryToView(l:m)
    let [l:ok, l:m2] = l:mode.ViewToBinary(l:lines, l:m)
    call assert_equal(1, l:ok)
    call assert_equal('41424344', l:m2.plain_hex)
endfunction

function! Test_Mode_Hexstr_InvalidInputRejected() abort
    let l:mode = hexedit#modes#hexstr#Get()
    let l:m = hexedit#model#FromPlainHex('4142')
    let [l:ok, l:msg] = l:mode.ViewToBinary(['41 4g'], l:m)
    call assert_equal(0, l:ok)
endfunction

function! Test_Mode_CView_ReadOnly_And_Format() abort
    let l:mode = hexedit#modes#c_view#Get()
    call assert_equal('c_view', l:mode.Name())
    call assert_equal('c', l:mode.FileType())
    call assert_equal(0, has_key(l:mode, 'ViewToBinary'))
    call assert_equal(0, hexedit#registry#IsEditable(l:mode))
    let l:m = hexedit#model#FromPlainHex('41424344', {'octets_per_line': 16})
    let l:lines = l:mode.BinaryToView(l:m)
    call assert_equal('unsigned char buf[] = {', l:lines[0])
endfunction

function! Test_Mode_PyView_ReadOnly_And_Format() abort
    let l:mode = hexedit#modes#py_view#Get()
    call assert_equal('py_view', l:mode.Name())
    call assert_equal('python', l:mode.FileType())
    call assert_equal(0, has_key(l:mode, 'ViewToBinary'))
    let l:m = hexedit#model#FromPlainHex('41424344', {'octets_per_line': 16, 'group_octets_num': 2})
    let l:lines = l:mode.BinaryToView(l:m)
    call assert_equal('bytes.fromhex(', l:lines[0])
    call assert_equal(')', l:lines[-1])
endfunction

function! Test_Mode_FormatParse_PlaceholderIsReadOnly() abort
    let l:mode = hexedit#modes#format_parse#Get()
    call assert_equal('format_parse', l:mode.Name())
    call assert_equal(0, has_key(l:mode, 'ViewToBinary'))
    let l:m = hexedit#model#FromPlainHex('4142', {'octets_per_line': 16})
    call assert_equal(hexedit#model#ToHexDumpLines(l:m), l:mode.BinaryToView(l:m))
endfunction

function! Test_AllModesRegisteredByDefault() abort
    for l:name in ['hexedit', 'hexstr', 'c_view', 'py_view', 'format_parse']
        call assert_true(index(hexedit#registry#Names(), l:name) >= 0, 'missing mode: ' . l:name)
    endfor
endfunction
