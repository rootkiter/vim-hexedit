syn match adr_area "^\x*"
syn match hex_area ":[ 0-9a-fA-F]*"hs=s+1,he=e-1 contains=vhexSep
syn match vhexSep  /:/ contained 
syn match vhexLine /|/ contained
syn match chr_area "| .*$"hs=s+1 contains=vhexLine

hi link adr_area SpecialChar
hi link hex_area Number
hi link chr_area PreCondit
hi link vhexSep  Label
hi link vhexLine Label
