---
title: 强大的 Clang
categories: 工具代码
tags: [iOS, Static-Analyze, Clang]
---

苹果公司早期使用 GCC 作为编译器。GCC 最初是作为 GNU(GNU是“GNU is Not Unix”)操作系统的编译器编写的，是一套由 GNU 开发的编程语言编译器，不属于苹果维护也不能完全控制开发进程，Apple为 Objective-C 增加许多新特性，但是 GCC 开发者对这些支持却不友好，效率和性能都没有办法达到苹果公司的要求，而且还难以推动 GCC 团队。

<!-- more -->

于是，苹果公司决定给自己来账务编译相关的工具链，将天才克里斯·拉特纳（Chris·Lattner）赵茹麾下后开发了 LLVM 工具套件，将 GCC 全面替换成了 LLVM。

Clang 是基于 C++ 开发的。 Clang 是 LLVM 的一个编译前端。在 Xcode 编译 iOS 项目的时候，都是使用的LLVM，其实在编写代码以及调试的时候都在接触LLVM提供的功能，例如：代码的亮度（Clang）、实时代码检查（Clang）、代码提示（Clang）、debug断点调试（LLDB）。

### Xcode 编译器发展史

* Xcode3 以前： GCC；
* Xcode3： 增加LLVM，GCC(前端) + LLVM(后端)；
* Xcode4.2： 出现Clang - LLVM 3.0成为默认编译器；
* Xcode4.6： LLVM 升级到4.2版本；
* Xcode5： GCC被废弃，新的编译器是LLVM 5.0，从GCC过渡到Clang-LLVM的时代正式完成

### 编译过程
LLVM 与 GCC 一样，都是采用的三相设计（编译前端-中间代码IR-编译后端），前端 Clang 负责解析，验证和诊断输入代码中的错误，然后将解析的代码转换为 LLVM IR，后端 LLVM 编译把IR通过一系列改进代码的分析和优化过程提供，然后被发送到代码生成器以生成本机机器代码。

### Clang 的工作
Clang 作为编译前端，首先预编译 -> 词法分析 -> 语法分析。

这里首推《程序员的自我修养》一书，虽然还没有啃完。

### Clang 的基础设施
#### LibClang
提供稳定的高级 C 接口，Xcode 使用的就是 LibClang。

LibClang 可以访问 Clang 的上层高级抽象的能力，比如获取所有 Token、遍历语法树、代码补全等。API 很稳定，Clang 版本更新对其影响不大。并不能完全访问到 Clang AST 信息。

#### Clang Plugins
Clang Plugins 可以让你在 AST 上做些操作，这些操作能集成到编译中，称为编译的一部分。插件是在运行时由编译器加载的动态库，方便集成到构建系统中。

#### LibTooling
LibTooling 是一个 C++ 接口，通过 LibTooling 能够编写独立运行的语法检查和代码和代码重构工具。

### Clang 搭建开发环境

#### 安装 CMake
CMake 是一个跨平台的构建生成器工具。 CMake 不构建项目，它生成构建工具（GNU make，Visual Studio等）所需的文件，用于构建LLVM。

[下载地址](https://cmake.org/download/)

* [源码安装](https://cmake.org/install)
* 安装包安装
* 通过 Homebrew 安装

	```
	brew install cmake
	```

#### 下载 LLVM 源码

[Getting Started with the LLVM System](http://llvm.org/docs/GettingStarted.html#checkout-llvm-from-subversion)

* 下载 llvm 源码
	* git clone https://github.com/llvm/llvm-project.git
	
* 配置并构建 llvm 和 clang
	* cd llvm-project
	* mkdir build
	* cmake -G <generator> [options] ../llvm
	
		```
		cmake -G Xcode -DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi" ../llvm
		```
		

### 参考
[结构化编译器前端 Clang 介绍](https://www.ibm.com/developerworks/cn/opensource/os-cn-clang/)

[打造基于Clang LibTooling的iOS自动打点系统CLAS](https://www.jianshu.com/p/01c988cae897)