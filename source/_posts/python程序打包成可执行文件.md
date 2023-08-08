---
title: Python 程序打包成可执行文件
categories: Python入门
tags: [Python]
---

我们可以使用 Pyinstaller 来将我们的小程序打包成一个可执行文件，然后再没有安装 python 环境的情况下也可以执行。

<!--more-->

### 安装 Pyinstaller

通过 pip 安装 Pyinstaller

```
pip install pyinstaller
```

pyinstaller 安装是，会一同安装其它依赖包，安装成功时，会提示：

```
Successfully installed altgraph-0.17.3 macholib-1.16.2 pyinstaller-5.6.2 pyinstaller-hooks-contrib-2022.13
```

### Pyinstaller 参数说明

| 参数| 说明 |
|:---|:---|:---|
| -F, --onefile | 创建单个可执行文件 |
| -D, --onedir | 产生一个目录（包含多个文件）作为可执行程序（默认参数） |
| -p DIR, --paths DIR | 添加搜索路径，让其找到对应的库，可以为多个值 |
| --distpath DIR | 生成文件的路径，默认为 ./dist |
| --clean | 打包之前，删除之前打包的目录 | 

### 打包可执行程序

#### 打包成单个文件

执行命令:

```
pyinstall -F xxx.py --clean
```

命令目录下将生成如下文件和文件夹：

* `__pycache__`：缓存目录，存储 pyc 格式的编译后的程序，有 python 和依赖包环境，可以直接执行
* `build`：打包过程的目录，其中存储了打包过程的相关日志和配置
* `dist`：打包结果目录，对应生成的可执行程序
* `xxx.spec`：打包配置文件，可手动编写，通过其它方式打包

文件夹 `dist` 中存储了打包生成的可执行文件，命名和主 python 脚本的名字一致。

如 python 程序有其它 **依赖配置文件**，需手动将配置文件拷贝的 **可执行文件** 目录下，直接发布到其它环境执行即可。

#### 指定包路径

打包文件时，可手动指定 python 的本地安装依赖包的路径：

```
pyinstaller -F -p "/opt/homebrew/lib/python3.9/site-packages;" xxx.py
```

打包生成结果，仍然为单个可执行文件。

#### 生成一个执行目录

执行命令：

```
pyinstaller xxx.py
```

或 

```
pyinstaller -D xxx.py
```

执行完毕后，生成的目录 dist 中，将生成一个 **入口执行脚本同名的文件夹 xxx**，文件夹内，扔有一个脚本同名的可执行文件。双击即可执行。发布项目时，**需要将整个文件夹拷贝到执行环境中**。

同样的，如果有 外部配置等文件，也需要一同拷贝。

[参考](https://www.jianshu.com/p/825397df4aa0)。

