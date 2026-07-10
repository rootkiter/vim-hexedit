" hexedit#model - Canonical Model (REQUIREMENTS.md 2.2, section 5)
"
" A "model" dict is the single source of truth every mode renders from and
" (if editable) parses back into. Raw binary bytes are NEVER held in a Vim
" String/List variable in this file -- only ever as `plain_hex` (a
" continuous lowercase/uppercase hex-digit string, always even length) or
" transiently inside external processes' stdin/stdout. This sidesteps
" Vim's well-known NUL-byte-in-String pitfalls.
"
" Fields of a model dict:
"   path            absolute path to the backing file, '' if none yet
"                    (brand new file / :HexLoad from typed text)
"   total_size      size in bytes of the whole backing file (0 if path=='')
"   window_offset   absolute byte offset of this model's window in the file
"   window_length   number of bytes this model represents (== len(plain_hex)/2)
"   is_windowed     1 if this model is a partial view of a larger file
"   plain_hex       continuous hex text, no spaces/newlines
"   group_octets_num, octets_per_line, low_up   rendering options
"   annotations     list of {offset,length,name,semantic,hlgroup} (reserved
"                    for the future format-parse mode, REQUIREMENTS 4.5;
"                    carried through opaquely, not otherwise touched here)
"   write_mode      'binary' (default) or 'text' -- decided once at
"                    :HexLoad time when binding to a real file (see
"                    hexedit#HexLoad); controls how Save() below writes to
"                    `path`. Always 'binary' for models that were never
"                    offered that choice (regular binary-file editing).

function! s:DefaultOpts() abort
    return {
                \ 'group_octets_num': get(g:, 'group_octets_num', 2),
                \ 'octets_per_line': get(g:, 'octets_per_line', 16),
                \ 'low_up': get(g:, 'hexedit_low_up', 'lower'),
                \ }
endfunction

function! s:NewBase(opts) abort
    let l:defaults = s:DefaultOpts()
    return {
                \ 'path': '',
                \ 'total_size': 0,
                \ 'window_offset': 0,
                \ 'window_length': 0,
                \ 'is_windowed': 0,
                \ 'plain_hex': '',
                \ 'group_octets_num': get(a:opts, 'group_octets_num', l:defaults.group_octets_num),
                \ 'octets_per_line': get(a:opts, 'octets_per_line', l:defaults.octets_per_line),
                \ 'low_up': get(a:opts, 'low_up', l:defaults.low_up),
                \ 'annotations': get(a:opts, 'annotations', []),
                \ 'write_mode': get(a:opts, 'write_mode', 'binary'),
                \ }
endfunction

" ---- Constructors --------------------------------------------------------

function! hexedit#model#FromPlainHex(hexstr, ...) abort
    let l:opts = a:0 > 0 ? a:1 : {}
    let l:m = s:NewBase(l:opts)
    let l:clean = substitute(a:hexstr, '\_s', '', 'g')
    let l:m.plain_hex = l:clean
    let l:m.window_length = len(l:clean) / 2
    let l:m.total_size = l:m.window_length
    return l:m
endfunction

function! hexedit#model#Empty(...) abort
    let l:opts = a:0 > 0 ? a:1 : {}
    return hexedit#model#FromPlainHex('', l:opts)
endfunction

" Load the entire file as the model (small/non-windowed path).
function! hexedit#model#FromWholeFile(path, ...) abort
    let l:opts = a:0 > 0 ? a:1 : {}
    let l:m = s:NewBase(l:opts)
    let l:m.path = fnamemodify(a:path, ':p')
    let l:m.total_size = getfsize(l:m.path)
    if l:m.total_size < 0
        let l:m.total_size = 0
    endif
    let l:m.window_offset = 0
    let l:m.is_windowed = 0
    if l:m.total_size ==# 0
        let l:m.plain_hex = ''
    else
        let l:m.plain_hex = join(systemlist(['xxd', '-p', l:m.path]), '')
    endif
    let l:m.window_length = len(l:m.plain_hex) / 2
    return l:m
endfunction

" Load only [offset, offset+length) of the file (large-file windowed path).
function! hexedit#model#FromFileWindow(path, offset, length, ...) abort
    let l:opts = a:0 > 0 ? a:1 : {}
    let l:m = s:NewBase(l:opts)
    let l:m.path = fnamemodify(a:path, ':p')
    let l:m.total_size = getfsize(l:m.path)
    if l:m.total_size < 0
        let l:m.total_size = 0
    endif
    let l:offset = max([0, min([a:offset, l:m.total_size])])
    let l:length = max([0, min([a:length, l:m.total_size - l:offset])])
    let l:m.window_offset = l:offset
    let l:m.is_windowed = 1
    if l:length ==# 0
        let l:m.plain_hex = ''
    else
        let l:m.plain_hex = join(systemlist(
                    \ ['xxd', '-s', string(l:offset), '-l', string(l:length), '-p', l:m.path]), '')
    endif
    let l:m.window_length = len(l:m.plain_hex) / 2
    return l:m
endfunction

function! hexedit#model#ByteLength(model) abort
    return len(a:model.plain_hex) / 2
endfunction

function! hexedit#model#IsValidHex(text) abort
    let l:clean = substitute(a:text, '\_s', '', 'g')
    if len(l:clean) % 2 !=# 0
        return 0
    endif
    return l:clean =~# '^\x*$'
endfunction

" ---- Rendering helpers (shared by modes) ---------------------------------

function! s:XxdCaseFlag(model) abort
    return a:model.low_up ==# 'upper' ? ' -u' : ''
endfunction

function! s:XxdExtraFlag() abort
    let l:extra = get(g:, 'hexedit_xxd_options', '')
    return l:extra ==# '' ? '' : ' ' . l:extra
endfunction

" Renders the model as classic "offset: hex | ascii" lines (Hex 编辑模式).
function! hexedit#model#ToHexDumpLines(model) abort
    if a:model.plain_hex ==# ''
        let l:addr_width = 8
        return [printf('%0' . l:addr_width . 'x: ', a:model.window_offset) . '| ']
    endif
    let l:pipeline = 'xxd -r -p | xxd -c ' . a:model.octets_per_line
                \ . ' -g ' . a:model.group_octets_num
                \ . ' -o ' . a:model.window_offset
                \ . s:XxdCaseFlag(a:model)
                \ . s:XxdExtraFlag()
    let l:lines = systemlist(['sh', '-c', l:pipeline], a:model.plain_hex)
    " Insert the '| ' separator before the ascii column, in pure Vimscript
    " (no dependency on sed).
    let l:hex_area_size = a:model.octets_per_line * 2
                \ + (a:model.octets_per_line / a:model.group_octets_num)
                \ + ((a:model.octets_per_line % a:model.group_octets_num) > 0 ? 1 : 0)
                \ - 1
    let l:out = []
    for l:line in l:lines
        let l:idx = stridx(l:line, ': ')
        if l:idx < 0
            call add(l:out, l:line)
            continue
        endif
        let l:addr = l:line[0 : l:idx - 1]
        let l:rest = l:line[l:idx + 2 :]
        let l:hexpart = l:rest[0 : l:hex_area_size - 1]
        let l:asciipart = l:rest[l:hex_area_size :]
        " xxd separates hex/ascii with two spaces; strip the leading ones
        " already present in asciipart before re-adding our own marker.
        let l:asciipart = substitute(l:asciipart, '^\s*', '', '')
        call add(l:out, l:addr . ': ' . l:hexpart . '  | ' . l:asciipart)
    endfor
    return l:out
endfunction

" Parses "offset: hex | ascii" lines back into plain hex text.
" Returns [ok(0/1), plain_hex_or_errmsg]
function! hexedit#model#ParseHexDumpLines(lines) abort
    let l:hex = ''
    for l:line in a:lines
        let l:sep = stridx(l:line, '| ')
        if l:sep < 0
            let l:sep = stridx(l:line, '|')
        endif
        if l:sep < 0
            continue
        endif
        let l:left = l:line[0 : l:sep - 1]
        let l:colon = stridx(l:left, ':')
        if l:colon < 0
            continue
        endif
        let l:hexarea = l:left[l:colon + 1 :]
        let l:hex .= substitute(l:hexarea, '\_s', '', 'g')
    endfor
    if !hexedit#model#IsValidHex(l:hex)
        return [0, 'Hex edit area contains invalid characters or has the wrong length']
    endif
    return [1, tolower(l:hex)]
endfunction

" Renders grouped hex-string lines (Hex 字串模式), e.g. "4141 4242 ...".
function! hexedit#model#ToHexStringLines(model) abort
    let l:hex = a:model.low_up ==# 'upper' ? toupper(a:model.plain_hex) : a:model.plain_hex
    let l:cellsize = a:model.group_octets_num * 2
    let l:cells = []
    let l:i = 0
    while l:i < len(l:hex)
        call add(l:cells, l:hex[l:i : l:i + l:cellsize - 1])
        let l:i += l:cellsize
    endwhile
    let l:cells_per_line = a:model.octets_per_line / a:model.group_octets_num
    if l:cells_per_line <= 0
        let l:cells_per_line = len(l:cells) > 0 ? len(l:cells) : 1
    endif
    if empty(l:cells)
        return ['']
    endif
    let l:out = []
    let l:i = 0
    while l:i < len(l:cells)
        call add(l:out, join(l:cells[l:i : l:i + l:cells_per_line - 1], ' '))
        let l:i += l:cells_per_line
    endwhile
    return l:out
endfunction

" Returns [ok(0/1), plain_hex_or_errmsg]
function! hexedit#model#ParseHexStringLines(lines) abort
    let l:hex = substitute(join(a:lines, ''), '\_s', '', 'g')
    if !hexedit#model#IsValidHex(l:hex)
        return [0, 'Hex string content must have even length and contain only 0-9a-fA-F']
    endif
    return [1, tolower(l:hex)]
endfunction

" Renders a C unsigned-char array declaration (C 语言视图模式, REQUIREMENTS 4.3).
function! hexedit#model#ToCLines(model, ...) abort
    let l:varname = a:0 > 0 ? a:1 : 'buf'
    let l:hex = a:model.plain_hex
    let l:perline = a:model.octets_per_line
    let l:out = ['unsigned char ' . l:varname . '[] = {']
    let l:nbytes = len(l:hex) / 2
    let l:i = 0
    while l:i < l:nbytes
        let l:linebytes = []
        let l:ascii = ''
        let l:j = l:i
        while l:j < min([l:i + l:perline, l:nbytes])
            let l:bytehex = l:hex[l:j * 2 : l:j * 2 + 1]
            call add(l:linebytes, '0x' . (a:model.low_up ==# 'upper' ? toupper(l:bytehex) : l:bytehex))
            let l:code = str2nr(l:bytehex, 16)
            let l:ascii .= (l:code > 31 && l:code < 127) ? nr2char(l:code) : '.'
            let l:j += 1
        endwhile
        call add(l:out, '    ' . join(l:linebytes, ', ') . ', // ' . l:ascii)
        let l:i += l:perline
    endwhile
    call add(l:out, '};')
    return l:out
endfunction

" Renders a Python3-compatible bytes.fromhex(...) expression (REQUIREMENTS 4.4).
function! hexedit#model#ToPyLines(model) abort
    let l:hexlines = hexedit#model#ToHexStringLines(a:model)
    let l:out = ['bytes.fromhex(']
    for l:idx in range(len(l:hexlines))
        let l:line = l:hexlines[l:idx]
        let l:ascii = ''
        for l:cell in split(l:line, ' ')
            let l:k = 0
            while l:k < len(l:cell)
                let l:bytehex = l:cell[l:k : l:k + 1]
                if len(l:bytehex) ==# 2
                    let l:code = str2nr(l:bytehex, 16)
                    let l:ascii .= (l:code > 31 && l:code < 127) ? nr2char(l:code) : '.'
                endif
                let l:k += 2
            endwhile
        endfor
        call add(l:out, '    "' . l:line . '"  ### ' . l:ascii)
    endfor
    call add(l:out, ')')
    return l:out
endfunction

" ---- Whole-file search (section 5.7) --------------------------------------
"
" Searches for `pattern_hex` (a continuous hex-digit string, even length)
" in the file backing `model`, starting at absolute byte offset
" `start_byte`, forward only. Deliberately does NOT convert the whole file
" up front: `tail -c +N` seeks to the start byte, `xxd -p | tr -d '\n'`
" turns the remaining bytes into a flat lowercase hex text stream (so the
" match itself is a plain ASCII substring search -- no binary-data/embedded
" -newline pitfalls), and `grep -m1` exits as soon as it finds one match,
" which lets `tr`/`xxd`/`tail` short-circuit via SIGPIPE instead of
" processing the rest of the file. Cost is therefore roughly proportional
" to "distance from start_byte to the match", not file size, except in the
" no-match (or match-near-EOF) case where it is unavoidably O(remaining
" file size) -- there is no index to do better than that.
"
" NOTE: reads from the file on disk, not from any in-memory buffer/model
" state, so it will not see unsaved edits in the currently loaded window
" until they are saved (REQUIREMENTS.md 5.7).
"
" Returns [found(0/1), match_offset, match_length_bytes].
function! hexedit#model#SearchFile(model, pattern_hex, start_byte) abort
    if a:model.path ==# '' || !filereadable(a:model.path)
        return [0, -1, 0]
    endif
    if !hexedit#model#IsValidHex(a:pattern_hex) || a:pattern_hex ==# ''
        return [0, -1, 0]
    endif
    let l:pattern = tolower(substitute(a:pattern_hex, '\_s', '', 'g'))
    let l:match_bytes = len(l:pattern) / 2
    let l:start_byte = max([0, a:start_byte])
    let l:cmd = 'tail -c +' . (l:start_byte + 1) . ' ' . shellescape(a:model.path)
                \ . ' | xxd -p | tr -d ' . shellescape("\n")
                \ . ' | grep -m1 -b -o -i -- ' . shellescape(l:pattern)
    let l:out = system(['sh', '-c', l:cmd])
    let l:out = substitute(l:out, '\n\+$', '', '')
    if l:out ==# ''
        return [0, -1, 0]
    endif
    let l:colon = stridx(l:out, ':')
    if l:colon <= 0
        return [0, -1, 0]
    endif
    let l:char_offset = str2nr(l:out[0 : l:colon - 1])
    let l:match_offset = l:start_byte + l:char_offset / 2
    return [1, l:match_offset, l:match_bytes]
endfunction

" ---- Persistence (section 5.4) -------------------------------------------

" opts.confirm_fn: optional Funcref(msg) -> 1/0, injectable for tests.
" Returns [ok(0/1), message]
function! hexedit#model#Save(model, ...) abort
    let l:opts = a:0 > 0 ? a:1 : {}
    let l:Confirm_fn = get(l:opts, 'confirm_fn', function('s:DefaultConfirm'))

    if a:model.path ==# ''
        return [0, 'no associated target file; cannot save (this content was never bound to a file via :HexLoad or similar)']
    endif

    if a:model.write_mode ==# 'text'
        " Chosen at :HexLoad time (see hexedit#HexLoad): write the hex
        " string TEXT representation of the current bytes back to `path`,
        " instead of decoding to raw binary. Always a full overwrite (text
        " has no positional "patch a byte range" concept the way the
        " binary path does), and in windowed mode this only ever covers
        " the currently loaded window -- same caveat as :HexDump.
        let l:lines = hexedit#model#ToHexStringLines(a:model)
        if writefile(l:lines, a:model.path) !=# 0
            return [0, 'failed to write text file: ' . a:model.path]
        endif
        if a:model.is_windowed
            return [1, 'wrote as text to ' . a:model.path
                        \ . ' (large-file windowed mode only writes the currently loaded window, not the whole file)']
        endif
        return [1, 'ok']
    endif

    let l:new_length = hexedit#model#ByteLength(a:model)

    if !a:model.is_windowed
        " Whole-file model: always a full overwrite, length changes are fine.
        return s:WriteWholeFile(a:model.path, a:model.plain_hex)
    endif

    if l:new_length ==# a:model.window_length
        " Fixed-length: patch just this byte range in place.
        return s:PatchWindow(a:model.path, a:model.window_offset, a:model.plain_hex)
    endif

    " Variable-length edit inside a windowed (large-file) model: this
    " requires rewriting the whole file (REQUIREMENTS 5.4) and must be
    " confirmed by the user first.
    let l:msg = printf(
                \ 'This edit changed the byte count within the window (%d -> %d); the window can no ' .
                \ 'longer be patched in place. This will fall back to reading and rewriting the whole ' .
                \ 'file, which may significantly affect read/write speed on a large file. Continue?',
                \ a:model.window_length, l:new_length)
    if !l:Confirm_fn(l:msg)
        return [0, 'save cancelled; buffer content kept, nothing written to file']
    endif
    return s:RewriteWholeFileWithWindow(a:model.path, a:model.window_offset,
                \ a:model.window_length, a:model.plain_hex)
endfunction

function! s:DefaultConfirm(msg) abort
    return confirm(a:msg, "&Yes\n&No", 2) ==# 1
endfunction

function! s:WriteWholeFile(path, plain_hex) abort
    if a:plain_hex ==# ''
        call writefile([], a:path)
        return [1, 'ok']
    endif
    let l:cmd = 'xxd -r -p > ' . shellescape(a:path)
    call system(['sh', '-c', l:cmd], a:plain_hex)
    if v:shell_error !=# 0
        return [0, 'failed to write file: ' . a:path]
    endif
    return [1, 'ok']
endfunction

function! s:PatchWindow(path, offset, plain_hex) abort
    if a:plain_hex ==# ''
        return [1, 'ok']
    endif
    let l:cmd = 'xxd -r -p | dd of=' . shellescape(a:path)
                \ . ' bs=1 seek=' . a:offset . ' conv=notrunc 2>/dev/null'
    call system(['sh', '-c', l:cmd], a:plain_hex)
    if v:shell_error !=# 0
        return [0, 'failed to write window content back to file: ' . a:path]
    endif
    return [1, 'ok']
endfunction

function! s:RewriteWholeFileWithWindow(path, offset, old_window_length, new_plain_hex) abort
    let l:tmpdir = fnamemodify(a:path, ':p:h')
    let l:prefix = tempname()
    let l:suffix = tempname()
    let l:newwin = tempname()
    let l:final = l:tmpdir . '/.hexedit.tmp.' . getpid() . '.' . localtime()

    call system(['sh', '-c', 'head -c ' . a:offset . ' ' . shellescape(a:path)
                \ . ' > ' . shellescape(l:prefix)])
    if v:shell_error !=# 0
        return [0, 'failed to read file prefix']
    endif

    let l:suffix_start = a:offset + a:old_window_length + 1
    call system(['sh', '-c', 'tail -c +' . l:suffix_start . ' ' . shellescape(a:path)
                \ . ' > ' . shellescape(l:suffix)])
    if v:shell_error !=# 0
        call delete(l:prefix)
        return [0, 'failed to read file suffix']
    endif

    if a:new_plain_hex !=# ''
        call system(['sh', '-c', 'xxd -r -p > ' . shellescape(l:newwin)], a:new_plain_hex)
        if v:shell_error !=# 0
            call delete(l:prefix)
            call delete(l:suffix)
            return [0, 'failed to decode new window content']
        endif
    else
        call writefile([], l:newwin)
    endif

    call system(['sh', '-c', 'cat ' . shellescape(l:prefix) . ' ' . shellescape(l:newwin)
                \ . ' ' . shellescape(l:suffix) . ' > ' . shellescape(l:final)
                \ . ' && mv ' . shellescape(l:final) . ' ' . shellescape(a:path)])
    let l:shell_err = v:shell_error

    call delete(l:prefix)
    call delete(l:suffix)
    call delete(l:newwin)

    if l:shell_err !=# 0
        return [0, 'failed to rewrite whole file']
    endif
    return [1, 'ok']
endfunction
