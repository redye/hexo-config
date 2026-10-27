---
title: Go 版本升级后程序启动报错的排查记录
date: 2026-09-30
categories: Go入门
tags: [Go, macOS]
---

本文记录一次 macOS Apple Silicon 环境下 Go 程序构建和启动失败的排查过程。排查过程中先后遇到可执行文件签名异常，以及升级 Go 后的链接错误。最终将本机 Go 版本切换到 1.24.13 后，程序可以正常运行。

<!-- more -->

### 问题环境

排查时使用的是 macOS ARM64 环境。Xcode 从 26.4 升级到 26.6 后，使用 Go 1.21.13 构建的程序出现了启动异常。之后尝试升级 Go，问题又表现为不同的链接错误。

这里需要注意，GoLand 只是调用 Go 工具链构建和启动程序。判断问题时，应同时确认实际使用的 Go 版本、GOROOT、依赖版本和链接器错误，不能只根据 IDE 显示的退出码判断原因。

### 最初遇到的签名和启动异常

最初运行程序时出现过以下错误：

```text
dyld: missing LC_UUID load command
signal: abort trap
```

另一次构建后，使用 `codesign --verify` 检查生成的二进制文件时，得到 `invalid signature`；GoLand 运行程序也曾以退出码 137（`SIGKILL`）结束。

### 为什么签名验证会失败

macOS 可执行文件的代码签名用于校验二进制代码是否与签名时记录的内容一致。`codesign --verify` 返回 `invalid signature (code or signature have been modified)`，表示系统校验到代码内容与签名数据不匹配；在 Apple Silicon 上运行时，系统可能因此拒绝执行并终止进程。

本次检查确认 Go 1.21.13 生成的 arm64 二进制确实无法通过签名校验。对二进制副本执行 ad-hoc 重签后，校验可以通过，说明问题落在构建产物的签名完整性上，而不是应用缺少某个开发者证书。

Go 官方曾记录过一类相似问题：在 Apple Silicon 上使用外部链接并配合 Xcode 16 beta 时，`go build` 生成的二进制会出现无效签名并被系统终止。[相关 Go issue](https://github.com/golang/go/issues/68088) 这为“Go 工具链与 Apple 链接器共同生成的签名不兼容”提供了依据。该 issue 讨论的是 Xcode 16 beta，而本次环境是 Xcode 26.6，因此只能作为相似问题的参考，不能据此认定是同一个具体 bug。

#### 临时方案：对构建产物重新签名

可以使用 macOS 自带的 `codesign`，给本地构建产物添加 ad-hoc 签名：

```bash
go build -o /tmp/app-check .
codesign --force --sign - /tmp/app-check
codesign --verify --verbose=2 /tmp/app-check
/tmp/app-check
```

这里的 `--sign -` 表示使用 ad-hoc 签名，不需要开发者证书。它适合本机临时运行和验证，不等同于用于分发应用的 Developer ID 签名或公证。

这个方法不适合作为直接点击 GoLand「运行」按钮的常规方案：GoLand 会在运行流程中重新生成临时二进制，并立即启动它；手工签名是针对某一次生成的具体文件，重新构建后就可能失效。因此如果每次都使用 GoLand 运行，就需要对每次新生成的二进制再次签名，而且必须在启动前完成，操作较繁琐。

如需在 IDE 中使用该绕过方式，需要把构建和签名步骤串联起来，确保每次都是“先构建、再签名、最后运行”；否则更适合在终端用固定输出路径执行上述命令。对本次问题，改用 Go 1.24.13 是已经验证可正常运行的方式，不需要每次手工重签。

当时在 GoLand 运行配置中添加了 `-ldflags=-linkmode=external`，实际运行后仍以退出码 137（`SIGKILL`）结束，没有解决签名异常；构建产物的 `codesign --verify` 也仍然报无效签名。因此，显式添加外部链接参数在这次排查中没有效果，不能作为解决步骤。

结合“Xcode 升级前项目可以正常运行，升级到 26.6 后开始出现签名异常”的时间顺序，**Xcode 升级可能是触发原因**，例如它改变了 Apple 链接器生成或处理 Go 可执行文件签名的方式。后来在同一台机器、同一套 Xcode 环境下改用 Go 1.24.13，程序可以正常运行，说明 Go 工具链版本也会影响结果。由于没有回退到 Xcode 26.4、保持 Go 版本不变进行对照，这仍是基于现象的推测，不是已经单独验证的根因。

### 升级到 Go 1.27.1 后的链接错误

安装 Go 1.27.1 后，错误变成了：

```text
Undefined symbols for architecture arm64:
"_encoding/json.unquoteBytes"
```

排查项目依赖后，发现项目使用的 `github.com/bytedance/sonic v1.12.2` 在 `sonic/ast` 中通过 `//go:linkname` 引用了 `encoding/json.unquoteBytes`。这是 Go 标准库的内部符号，不是供第三方包稳定调用的公开 API。

Go 1.27 默认的 `encoding/json` 实现发生了变化，旧符号在当前构建路径中不可用，因此最终链接阶段找不到它。虽然错误在链接阶段暴露，根因仍是 Go 依赖引用了不兼容的标准库内部符号。可参阅 [Go 1.27 发布说明](https://go.dev/doc/go1.27)。

### 为什么 `GOEXPERIMENT=nojsonv2` 没有解决

为了验证是否与 Go 1.27 默认的 JSON 实现有关，尝试使用旧版 JSON 实现构建：

```bash
GOEXPERIMENT=nojsonv2 /usr/local/go/bin/go build -o /tmp/app-check .
```

这次错误变成了：

```text
link: github.com/bytedance/sonic/ast: invalid reference to encoding/json.unquoteBytes
```

这个结果说明，仅切换 JSON 实现仍不足以让 Sonic 1.12.2 使用该私有符号。`GOEXPERIMENT=nojsonv2` 不会关闭 Go 链接器对标准库内部 `linkname` 引用的检查。Go 1.23 的发布说明也记录了这项链接器限制：[Go 1.23 发布说明](https://go.dev/doc/go1.23)。因此，这个实验开关不是该依赖问题的长期修复方式。

### 最终解决方式：使用 Go 1.24.13

安装并使用 Go 1.24.13 后，程序可以正常运行。这是本次排查中实际验证成功的解决方式。项目在 `go.mod` 中声明 Go 1.23 时，使用 Go 1.24.13 构建满足该版本要求；`go` 指令并不表示本机必须安装完全相同的小版本。

检查当前命令行使用的 Go 版本和安装目录：

```bash
go version
go env GOROOT
```

如果通过 GoLand 运行，也应在 GoLand 的 Go SDK（GOROOT）设置中选择 Go 1.24.13 对应的安装目录，避免命令行和 IDE 使用不同版本。

### 后续升级建议

如果之后必须使用 Go 1.27，应先升级 Sonic 到包含 Go 1.27 支持的版本，再重新构建并运行项目测试。Sonic 官方发布记录显示，Go 1.27 支持从 v1.15.3 开始提供；升级依赖时仍需检查 `go.mod`、`go.sum` 的变化以及项目测试结果：[Sonic 发布记录](https://github.com/bytedance/sonic/releases)。

不建议长期通过 `-checklinkname=0` 绕过检查。它会放宽对标准库内部符号引用的校验，不能替代依赖对新 Go 版本的正式兼容支持。

### 排查结论

* 当前已验证可运行的组合是 Go 1.24.13 和项目现有依赖。
* Go 1.27.1 的链接错误指向旧版 Sonic 对标准库私有符号的引用，与最初的签名异常是不同阶段、不同表现的问题。
* `GOEXPERIMENT=nojsonv2` 不能修复旧 Sonic 的 `linkname` 兼容问题。
* 如果升级到 Go 1.27，应先升级 Sonic 至支持该版本的发行版，并通过项目构建和测试验证。
