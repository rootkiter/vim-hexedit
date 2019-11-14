# HexEdit

该插件基于 xxd 实现，辅助修正字符区域/行号区域的更改和变化。  
默认情况下 HexEdit 将把 [ \*.bin,\*.dat,\*.o ] 类型的文件视为二进制文件，并以 HexEdit 模式打开。   
其次，也可以通过  vim -b 1.txt 的方式强制将 1.txt 文件视为二进制文件。

由于插件用法相对简单，此处将先介绍用法，再介绍安装。

# 如何进行 Hex 编辑

## HexEdit 模式

这是 HexEdit 的主模式，在该模式下，可通过替换或追加的方式对文件进行修改。下面是一个编辑模式的展示样例：  

```
  00000000: 4865 6c6c 6f20 5669 6d53 6372 6970 740a  | Hello VimScript.  
  00000010: 4865 6c6c 6f20 5669 6d53 6372 6970 740a  | Hello VimScript.  
  00000020: 4865 6c6c 6f20 5669 6d53 6372 6970 740a  | Hello VimScript.  
  00000030: 4865 6c6c 6f20 5669 6d53 6372 6970 740a  | Hello VimScript.  
  00000040: 4865 6c6c 6f20 5669 6d53 6372 6970 740a  | Hello VimScript.  
```

该区域的编辑规则如下：

    1. 可供编辑的区域有两个，分别为Hex 区域，和字符区域。这两个区域外的区域，光标将无法停留，以避免误操作修改了错误的位置。  
    2. 当修改了 Hex 区域时，字符区域也会随之更新，反之亦然。  
    3. 在各区域的末尾插入字符时，将视为文件追加，`:w` 保存后，文件也将随之更新。  

**PS:** 快速定位光标到字符区域，只需输入 `f|` 即可。这是基于规则 1 实现的, 当搜索竖线字符时，由于竖线位置无法停留光标，
自发修正到了字符区域，算是个使用中的小 trick 吧。

## Hex 搜索

在 HexEdit 模式下，可以通过 `:Hexsearch 6c6c` 指令搜索 `ll` 字符，并以 `n` 依次定位下一个搜索结果。

需要注意的是该操作中重定向了 `n` 的功能，需要通过 `:HexsearchClean` 清除搜索任务。以避免干扰 VIM 的默认搜索结果。

## 插入 Hex 字符( Hexkeep 模式 )

在 HexEdit 模式下我们只能替换文件内容，而无法插入内容。当需要插入内容时，可以通过 `:Hexkeep` 指令进入 Hexkeep 模式。   

下面是一个展示样例：

```
   48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a  
   48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a  
   48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a  
   48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a  
   48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a  
```

可以看到在 Hexkeep 模式下，只保留了 Hex 区域的内容，你可以任意的增加或删改这个区域的内容，当修改到满意后，再次输入 `:Hexkeep` 便可回到 HexEdit 模式。

# 转化输出

大部分的 Hex 编辑是服务于程序编写的。现阶段，可支持两种格式的导出，分别是 “C格式” 和 “Python格式”, 其他的格式后续会陆续追加。

## 以 C格式 导出

当编辑完成后，可以通过 `:Hex2C` 指令得到 C格式 导出结果，效果如下：

```
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x56, 0x69, 0x6d, 0x53, 0x63, 0x72, 0x69, 0x70, 0x74, 0x0a,  // Hello VimScript.  
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x56, 0x69, 0x6d, 0x53, 0x63, 0x72, 0x69, 0x70, 0x74, 0x0a,  // Hello VimScript.  
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x56, 0x69, 0x6d, 0x53, 0x63, 0x72, 0x69, 0x70, 0x74, 0x0a,  // Hello VimScript.  
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x56, 0x69, 0x6d, 0x53, 0x63, 0x72, 0x69, 0x70, 0x74, 0x0a,  // Hello VimScript.  
  0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x56, 0x69, 0x6d, 0x53, 0x63, 0x72, 0x69, 0x70, 0x74, 0x0a,  // Hello VimScript.  
```

在该状态中无法进入插入模式，以免误操作。

再次输入 `:Hex2C` 后，便可回到 HexEdit 模式。

## 以 Python格式 导出

如需以 Python格式 导出，可通过 `:Hex2Py` 指令得到，效果如下：

```
  print (  
    " 48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a" + ### Hello VimScript.  
    " 48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a" + ### Hello VimScript.  
    " 48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a" + ### Hello VimScript.  
    " 48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a" + ### Hello VimScript.  
    " 48 65 6c 6c 6f 20 56 69 6d 53 63 72 69 70 74 0a"   ### Hello VimScript.  
  ).replace(' ', '').decode('hex')
```

在该状态中无法进入插入模式，以免误操作。

再次输入 `:Hex2Py` 后，仍可回到 HexEdit 模式。

# 安装

## 空白环境安装

如果你的 vim 没有任何配置，则直接将项目克隆到家目录的 .vim 目录即可使用。

```
    $ cd ~  
    $ git clone https://github.com/rootkiter/vim-hexedit.git ~/.vim
```

## Pathogen 管理下的安装

如果你是用 Pathogen 管理 VIM 插件的，直接将项目克隆到 ~/.vim/bundle 目录即可。

```
    $ git clone https://github.com/rootkiter/vim-hexedit.git ~/.vim/bundle/vim-hexedit
```
