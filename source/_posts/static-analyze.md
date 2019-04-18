---
title: 静态分析
categories: 工具代码
tags: [iOS, Static Analyze, OCLint, Infer]
---

随着业务开发迭代速度越来越快，完全依赖人工保证工程质量也变得越来越不牢靠。所以静态分析，这种可以帮助我们在编写代码的阶段就能及时发现代码错误，从而在根上保证工程质量的技术，就成了 iOS 开发者最常用到的一种代码调试技术。

<!-- more -->

### 静态检查工具
1. Xcode 自带的静态分析工具 Analyze
2. 第三方的静态价差工具：OCLint、Infer、Clang 静态分析器等

### 三个复杂度指标

* 圈复杂度
* NPath 复杂度
* NCSS 度量

### 静态分析器的缺陷
* 需要耗费更长的时间
* 静态分析器只能检查出那些专门设计好的、可查找的错误

### OCLint
OCLint 是基于 Clang Tooling 开发的静态分析工具，主要用来发现编译器检查不到的那些潜在的关键技术问题。

#### 安装

```
brew tap oclint/formulae
brew install oclint
```

#### 使用

[官方规则说明](http://docs.oclint.org/en/stable/rules/index.html)

```
oclint Hello.m
```

```
oclint [options] <source> -- [compiler flags]
oclint -report-type html -o report.html Hello.m -- -c
```

#### OCLint 检查完整项目

在使用 OCLint 检查整个项目之前，需要 `xcodebuild `命令进行编译并把相关的日志信息输入到xcodebuild.log中。

`oclint-xcodebuild`对日志进行分析，但是它已经不再使用了，需要安装 `xcpretty`

```
$oclint-xcodebuild xcodebuild.log 

This binary is no longer under maintenance by OCLint team.
Please consider using xcpretty (https://github.com/supermarin/xcpretty) instead!
```

##### 安装 `xcpretty`
`xcpretty` 是用来格式化 `xcodebuild` 输出的工具，使用ruby开发。

###### 安装
	
```
gem install xcpretty
```
###### 使用

```
Usage: xcodebuild [options] | xcpretty
-t, --test                       Use RSpec style output
-s, --simple                     Use simple output (default)
-k, --knock                      Use knock output
    --tap                        Use TAP output
-f, --formatter PATH             Use formatter returned from evaluating the specified Ruby file
-c, --[no-]color                 Use colorized output. Default is auto
    --[no-]utf                   Use unicode characters in output. Default is auto.
-r, --report FORMAT or PATH      Run FORMAT or PATH reporter
                                   Choices: junit, html, json-compilation-database
-o, --output PATH                Write report output to PATH
    --screenshots                Collect screenshots in the HTML report
-h, --help                       Show this message
-v, --version                    Show version
```
	

`xcodebuild` 生成日志，输出到指定文件中[xcodebuild.log]中，分析日志并指定格式[json]输出到文件[compile.json]。
	
```
xcodebuild -workspace Xxx -scheme Xxx -configuration Debug -sdk iphonesimulator 
| tee xcodebuild.log 
| xcpretty -r json-compilation-database -o compile_commands.json
```

#### OCLint 的三个命令行指令
* `oclint`
* `oclint-json-compilation-database`
* `oclint-xcodebuild`[废弃]

##### oclint
基础指令。通过这个指令可以指定加载验证规则、编译代码、分析代码和生成报告。包含该了其他两个命令的功能。

🌰🌰🌰

```
oclint -report-type html -o report.html Hello.m -- clang -c -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk Hello.m
```

##### oclint-json-compilation-database
高级指令。通过这个指令可以从 compile_commands.json 文件中读取配置信息并执行  oclint。

```
usage: oclint-json-compilation-database [-h] [-v] [-debug] [-i INCLUDES]
                                        [-e EXCLUDES] [-p build-path]
                                        [oclint_args [oclint_args ...]]

OCLint for JSON Compilation Database (compile_commands.json)

positional arguments:
  oclint_args           arguments that are passed to OCLint invocation

optional arguments:
  -h, --help            show this help message and exit
  -v                    show invocation command with arguments
  -debug, --debug       invoke OCLint in debug mode
  -i INCLUDES, -include INCLUDES, --include INCLUDES
                        extract files matching pattern
  -e EXCLUDES, -exclude EXCLUDES, --exclude EXCLUDES
                        remove files matching pattern
  -p build-path         specify the directory containing compile_commands.json
```

🌰🌰🌰

```
oclint-json-compilation-database [options] -- -report-type html -o report.html
```

##### oclint-xcodebuild
从 Xcode 的 xcodebuild.log 文件导出编译选项并保存成 JSON Compilation Database 格式。然后保存到 compile_commands.json 文件中。

### Clang 静态分析器

用 C++ 开发，用来分析 C、C++ 和 Objective-C 的开源工具，是 Clang 项目的一部分，构建在 Clang 和 LLVM 之上。

#### 安装

下载 Clang 静态分析器，解压即可

卸载即删除这个解压后的目录。

#### 工具

* scan-build
* scan-view

#### 使用

* scan-build 的使用[说明](http://clang-analyzer.llvm.org/scan-build)
* checker 的官方示例代码: [MallocChecker](http://clang.llvm.org/doxygen/MallocChecker_8cpp_source.html)

#### Clang

* 列出可用的 checker

	```
	clang -cc1 -analyzer-checker-help
	```
	
* 使用指定的 checker 序分析文件
	
	```
	clang -cc1 -analyze -analyzer-checker=core.DivideZero test.c
	```	
	
### Infer

#### 安装

* 源码安装，所需时间比较长
	
	预先安装一些工具
	
	```
	brew install autoconf automake cmake opam pkg-config sqlite gmp mpfr
	brew cask install java
	```
	
	安装
	
	```
	# Checkout Infer
	git clone https://github.com/facebook/infer.git
	cd infer
	# Compile Infer
	./build-infer.sh clang
	# install Infer system-wide...
	sudo make install
	# ...or, alternatively, install Infer into your PATH
	export PATH=`pwd`/infer/bin:$PATH

	```
	
* 直接安装 binary releases

	```
	brew install infer
	```
	
#### 使用

* 单独检查某个文件

  `--` 后面可组合其他命令，之前是 infer 的 options
  
  `-c`: Only run preprocess, compile, and assemble steps
  
  `-isysroot`: Set the system root directory (usually /)

	```
	infer -- clang -c Hello.m
	```
	若遇到错误 `fatal error: 'Foundation/Foundation.h' file not found`，看👇
	
	```
	infer -- clang -c -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk Hello.m
	```
	
* 检查完整项目

	```
	infer run -- xcodebuild -target XxxApp -configuration Debug -sdk iphonesimulator
	```
	
	过滤不想扫描的文件
	
	```
	infer run --skip-analysis-in-path Pods --keep-going -- xcodebuild -workspace Xxx.xcworkspace -scheme Xxx -configuration Debug -sdk iphonesimulator
	```
	
### xcodebuild

`xcodebuild` 是苹果发布自动构建的工具。一般持续集成的时候都需要用到它。可以在终端输入`man xcodebuild` 查看用法及介绍。

[文档](https://redye.github.io/2019/04/17/xcodebuild/#more)