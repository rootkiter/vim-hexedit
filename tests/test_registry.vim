" Tests for autoload/hexedit/registry.vim, using small fake mode objects so
" the registry's own logic is exercised independently of the real modes.

function! s:FakeName() dict abort
    return self.name
endfunction

function! s:FakeFileType() dict abort
    return self.ft
endfunction

function! s:FakeBinaryToView(model) dict abort
    return ['RENDERED:' . a:model.plain_hex]
endfunction

function! s:FakeViewToBinary(lines, model) dict abort
    if a:lines[0] !~# '^RENDERED:'
        return [0, 'not rendered by this fake mode']
    endif
    let l:m2 = copy(a:model)
    let l:m2.plain_hex = a:lines[0][len('RENDERED:') :]
    return [1, l:m2]
endfunction

function! s:MakeFakeMode(name, ft, editable) abort
    let l:obj = {'name': a:name, 'ft': a:ft}
    let l:obj.Name = function('s:FakeName')
    let l:obj.FileType = function('s:FakeFileType')
    let l:obj.BinaryToView = function('s:FakeBinaryToView')
    if a:editable
        let l:obj.ViewToBinary = function('s:FakeViewToBinary')
    endif
    return l:obj
endfunction

function! s:ReregisterRealModes() abort
    call hexedit#registry#Register('hexedit', hexedit#modes#hexedit#Get())
    call hexedit#registry#Register('hexstr', hexedit#modes#hexstr#Get())
    call hexedit#registry#Register('c_view', hexedit#modes#c_view#Get())
    call hexedit#registry#Register('py_view', hexedit#modes#py_view#Get())
    call hexedit#registry#Register('format_parse', hexedit#modes#format_parse#Get())
endfunction

function! Test_Registry_RegisterGetNames() abort
    call hexedit#registry#Register('fake_a', s:MakeFakeMode('fake_a', 'text', 1))
    call hexedit#registry#Register('fake_b', s:MakeFakeMode('fake_b', 'text', 0))
    call assert_true(index(hexedit#registry#Names(), 'fake_a') >= 0)
    call assert_true(index(hexedit#registry#Names(), 'fake_b') >= 0)
    call assert_equal(1, hexedit#registry#IsEditable(hexedit#registry#Get('fake_a')))
    call assert_equal(0, hexedit#registry#IsEditable(hexedit#registry#Get('fake_b')))
    call assert_equal(v:null, hexedit#registry#Get('does_not_exist'))
endfunction

function! Test_Registry_Reset_Isolated() abort
    call hexedit#registry#Reset()
    call assert_equal([], hexedit#registry#Names())
    call s:ReregisterRealModes()
    call assert_true(index(hexedit#registry#Names(), 'hexedit') >= 0)
endfunction

function! Test_Registry_ActivateSwitchDeactivate() abort
    call hexedit#registry#Register('fk1', s:MakeFakeMode('fk1', 'text', 1))
    call hexedit#registry#Register('fk2', s:MakeFakeMode('fk2', 'text', 1))
    new
    let l:m = hexedit#model#FromPlainHex('4142')
    call assert_equal(0, hexedit#registry#IsActive())
    call assert_equal(1, hexedit#registry#Activate('fk1', l:m))
    call assert_equal(1, hexedit#registry#IsActive())
    call assert_equal('fk1', hexedit#registry#CurrentModeName())
    call assert_equal(['RENDERED:4142'], getline(1, '$'))
    call assert_equal('text', &l:filetype)

    call setline(1, 'RENDERED:41424344')
    call assert_equal(1, hexedit#registry#Switch('fk2'))
    call assert_equal('fk2', hexedit#registry#CurrentModeName())
    call assert_equal('41424344', hexedit#registry#CurrentModel().plain_hex)
    call assert_equal(['RENDERED:41424344'], getline(1, '$'))

    call hexedit#registry#Deactivate()
    call assert_equal(0, hexedit#registry#IsActive())
    bwipeout!
endfunction

function! Test_Registry_Switch_ValidationFailureAborts() abort
    call hexedit#registry#Register('fk1', s:MakeFakeMode('fk1', 'text', 1))
    call hexedit#registry#Register('fk2', s:MakeFakeMode('fk2', 'text', 1))
    new
    call hexedit#registry#Activate('fk1', hexedit#model#FromPlainHex('4142'))
    call setline(1, 'not rendered by fk1 at all')
    call assert_equal(0, hexedit#registry#Switch('fk2'))
    call assert_equal('fk1', hexedit#registry#CurrentModeName())
    call hexedit#registry#Deactivate()
    bwipeout!
endfunction

function! Test_Registry_Switch_WithoutActiveStateFails() abort
    new
    call assert_equal(0, hexedit#registry#IsActive())
    call assert_equal(0, hexedit#registry#Switch('fk1'))
    bwipeout!
endfunction

function! Test_Registry_ReadOnlyModeSetsNomodifiable() abort
    call hexedit#registry#Register('fk_ro', s:MakeFakeMode('fk_ro', 'text', 0))
    new
    call hexedit#registry#Activate('fk_ro', hexedit#model#FromPlainHex('41424344'))
    call assert_equal(0, &l:modifiable)
    call hexedit#registry#Deactivate()
    bwipeout!
endfunction

function! Test_Registry_SwitchBackFromReadOnlyRestoresModifiable() abort
    call hexedit#registry#Register('fk1', s:MakeFakeMode('fk1', 'text', 1))
    call hexedit#registry#Register('fk_ro', s:MakeFakeMode('fk_ro', 'text', 0))
    new
    call hexedit#registry#Activate('fk1', hexedit#model#FromPlainHex('4142'))
    call assert_equal(1, &l:modifiable)
    call hexedit#registry#Switch('fk_ro')
    call assert_equal(0, &l:modifiable)
    call hexedit#registry#Switch('fk1')
    call assert_equal(1, &l:modifiable)
    call hexedit#registry#Deactivate()
    bwipeout!
endfunction

let s:dispatch_calls = []
function! s:FakePing(x) dict abort
    call add(s:dispatch_calls, a:x)
endfunction

function! Test_Registry_Dispatch() abort
    let s:dispatch_calls = []
    let l:obj = s:MakeFakeMode('fk_dispatch', 'text', 0)
    let l:obj.Ping = function('s:FakePing')
    call hexedit#registry#Register('fk_dispatch', l:obj)
    new
    call hexedit#registry#Activate('fk_dispatch', hexedit#model#FromPlainHex(''))
    call hexedit#registry#Dispatch('Ping', 'hello')
    call assert_equal(['hello'], s:dispatch_calls)
    " no-op (not an error) when inactive or event unimplemented
    call hexedit#registry#Deactivate()
    call hexedit#registry#Dispatch('Ping', 'ignored')
    call assert_equal(['hello'], s:dispatch_calls)
    bwipeout!
endfunction

call s:ReregisterRealModes()
