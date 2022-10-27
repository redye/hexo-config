---
title: python 安装
categories: python入门
tags: [python]
---

要开始学习Python编程，首先就得把Python安装到你的电脑里。安装后，你会得到Python解释器（就是负责运行Python程序的），一个命令行交互环境，还有一个简单的集成开发环境。

<!-- more -->

### 使用 homebrew 安装 python

```
brew install python3
```

安装完成后查看安装的版本号：

```
$python --version
Python 2.7.18
```
由于 mac 的一些历史原因安装的 python2，不能删除，默认情况下 python 的命令是链接到 python2 的，如果需要使用我们刚刚安装的 python3，则需要设置别名：

使用 vi 编辑 .zshrc 文件（若使用 shell 为 Bash 则编辑 ~/.bash_profile 文件）:

```
# 设置 python3 别名
alias python='python3'
```
保存后再执行 `source .zshrc`，使改动生效。

接下来在看：

```
$ python3 --version
Python 3.9.12

$ python --version 
Python 3.9.12

$ where python
python: aliased to python3
/usr/bin/python
```
我们安装的是 python 3.9 的版本。这是符合我们预期的。

再看 python2，仍然是符合预期的结果：

```
$ where python2
/usr/bin/python2
```

但是当我们查看 python3 时：

```
$ where python3
/opt/homebrew/bin/python3
/usr/bin/python3
```

此时多了一个 python3，查看其版本号：

```
$ usr/bin/python3 --version
Python 3.8.9
```

### 多出来的 python3.8.9
那么这个 3.8.9 的版本是哪里来的呢？

这个 Python 3.8.2 来自于苹果的一套命令行开发者工具（command line developer tools），其对应目录在：

```
/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework
```

而在终端执行/usr/bin目录下的python3时，终端先根据环境变量PATH扫描是否有 Python 3.x 的可执行程序，若不存在，则调出命令行开发者工具的安装程序，引导用户安装。

命令行开发者工具并不会对从官网下载安装的 Python 有任何影响，并且也不建议开发者删除（因为这也会将git、clang、gcc、flex等工具一并删除）。

只有当并不需要额外的其他工具，并认为此确实困扰到了自己的时候，才可以将其删掉，这个 Python 3.8.2 就随之消失了，执行如下命令即可：

```
sudo rm -rf /Library/Developer/CommandLineTools
```

当我们存在两个 python3 版本的时候，为什么会优先使用的是用户安装的呢？

**原因是环境变量 PATH 默认先加载配置在最前面的路径，如果某命令已经加载完毕，则不再继续往下寻找，否则会继续寻找，直到全部加载为止，若完全找不到，当然会输出“command not found”啦。**

执行如下命令：

```
$ echo $PATH | AWK '{ gsub(/:/,"\n"); print $0}'
```

输出结果如下(这就是我的 Mac 上的 PATH 变量的设定，分行显示)：

```
/opt/homebrew/bin
/opt/homebrew/sbin
/usr/local/bin
/usr/bin
/bin
/usr/sbin
/sbin
/Library/Apple/usr/bin
```

可以看到 `/opt/homebrew/bin` 排在 `/usr/bin` 之前。

而 homebrew 安装的 Python 3.9.12 后，执行 `which python3` 可以看到，python3 命令执行的路径 在 `/opt/homebrew/bin` 目录下：

```
$ which python3
/opt/homebrew/bin/python3
```
因此系统只会加载 `/opt/homebrew/bin` 下的 python3。

针对此，我们可以在验证下：

```
type -a python3
python3 is /opt/homebrew/bin/python3
python3 is /usr/bin/python3
```

只有排在最前的会首先加载，也就是 `/opt/homebrew/bin` 下的 `python3`。

更多更详细的内容可参考某乎的[第一条回答](https://www.zhihu.com/question/420273182)。

### 一些查找的命令

* `which`: 查看可执行文件的位置。
* `where`: 查看文件位置。
* `find`: 实际搜寻硬盘查询文件名称。
* `locate`: 配合数据库查看文件位置。