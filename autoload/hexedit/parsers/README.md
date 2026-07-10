# 格式解析器占位目录

对应 REQUIREMENTS.md 4.5 节。本次重构不在此目录下实现任何具体的文件格式解析器，
仅保留目录位置，供未来格式解析模式（`autoload/hexedit/modes/format_parse.vim`）
正式立项时使用。

设想中的解析器接口（未实现，仅供参考）：

```vim
" 输入: model.plain_hex（Canonical Model 的原始字节，见 autoload/hexedit/model.vim）
" 输出: 字段标注列表，写回 model.annotations，每项形如：
"   {'offset': 0, 'length': 4, 'name': 'magic', 'semantic': '文件魔数', 'hlgroup': 'HexEditFieldMagic'}
function! hexedit#parsers#xxx#Parse(model) abort
    " ...
endfunction
```

解析器应作为独立文件放在本目录下（如 `elf.vim`、`png.vim`），并在加载时通过某种
注册机制（留待该模式立项时设计）挂接到 `format_parse.vim`，不需要修改
`registry.vim`、`model.vim` 或其他模式的代码。
