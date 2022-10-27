---
title: 第一行 python 
categories: python入门
tags: [python]
---

一般我们在写一个 python 文件的时候，开头都有两行注释：

<!-- more -->

```python
#!/usr/bin/python3
# -*- coding: utf-8 -*-
```

### \#!/opt/homebrew/bin/python3 的作用

#### Linux 系统
Linux 系统下，根据文件开头（首行）的标记来判断文件类型，通过文件所指定的程序来运行。`#!/opt/homebrew/bin/python3` 是告诉操作系统调用 `/opt/homebrew/bin` 下的 python3 解释器来执行这个脚本。例如，我们编写了 login.py 脚本，执行是需要输入命令： `python login.py`。因为有了这行声明，接可以直接用 `./login.py` 来执行了。

```
$ ./login.py 
zsh: permission denied: ./login.py

$ chmod +x ./login.py 

$ ./login.py
...success
```

如果去掉第一行直接运行的时候会报错：

```
$ ./login.py
./login.py: line 3: import: command not found
...
```

`# !/opt/homebrew/bin/python3` 这一句有可能会不同，这一句不只是指定程序，而且也指定了路径，例如在 mac 系统下已经默认安装好了 python2.7，但是你希望使用已安装的 python3。当系统看到这一行的时候，首先会到环境变量设置里查找 python 的安装路径，在调用对应路径下的解释器开始执行。

#### Windows 系统
Windows 系统用文件名的后缀（扩展名）来判断类型，只要是 `.py` 后缀的就关联到 python 程序执行。因此，`# !/opt/homebrew/bin/python3` 在 Windows 系统下相当于普通注释，没有意义。

### \# -\*- coding: utf-8 -*-

#### 作用

在Linux下指定文件的编码方式，用于支持中文。

python2需要在首行写 `# -*- coding:utf-8 -*-` 才能支持中文，python3 开始默认支持中文了，就可以省去这行注释。python2 中，不声明，默认ASCII码编码；python3中，不声明，默认Unicode编码。

如果是在 Windows 的 Python3 下运行你的程序，你完全可以不去写前两行注释的，但是出于好习惯，也为了方便跨平台以及兼容，写一写还是好的。

#### 写法

常用的三种写法：

```
# coding=utf-8
# coding:utf-8
# -*- coding:utf-8 -*-
```

这三种写法都可以，只要符合以下正则表达式：

```
^[ \t\f]*#.*?coding[:=][ \t]*([-_.a-zA-Z0-9]+)
```

这三种中经常使用的是 `# -*- coding:utf-8 -*-`，这是因为 Emacs 等编辑器使用这种方式进行编码声明。这样写可以支持多种编辑器，移植性好。