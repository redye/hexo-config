---
title: Go 项目的创建
categories: Go入门
tags: [Go]
---

接下来我们将从一个真实的 Go 项目开始，逐步开启 Go 的学习之旅。

学习一个新的编程语言，第一步通常不是马上去看语法，而是先把开发环境和项目创建起来。只有能够亲手运行代码，后面的学习才会更加直观。

<!-- more -->

### Go 版本的选择

我们先看一下当前安装的 Go 版本：

```bash
go version
```

输出类似：

```
go version go1.21.13 darwin/arm64
```

选择 Go 版本时，需要区分两种情况。

#### 新项目选择 Go 版本

如果是一个全新的项目，通常选择 Go 官方当前的稳定版本即可。Go 官方下载页面会提供各个平台的安装包，目前最新稳定版本可以在[官方发布页面](https://go.dev/dl/)查看。

但是也不能只看 Go 版本本身，还需要看项目依赖的框架要求。例如当前 Gin 的最新版本要求 Go 1.25 或更高版本，那么使用 Gin 最新版本时，Go 版本也不能太老。

一般可以按照下面的顺序选择：

* 优先选择 Go 的稳定版本，不使用实验版本。
* 查看项目依赖的最低 Go 版本。
* 查看公司项目、部署环境和 CI 使用的 Go 版本。
* 在开发、测试和生产环境中尽量保持 Go 的大版本一致。

#### 学习已有项目时选择 Go 版本

这次我们学习的是一个真实的 Go 项目。打开项目根目录下的 `go.mod` 文件，可以看到：

```go
module example.com/internal-service

go 1.21
```

这里的 `go 1.21` 是这个模块声明的 Go 版本。它告诉我们这个项目至少按照 Go 1.21 的模块和语言规则来构建。

因此，在学习这个项目时，我们先以 Go 1.21 为基线，不要一开始就修改项目的 Go 版本。版本升级不仅可能影响语法，还可能影响依赖版本、测试结果和构建环境。

这也是实际开发中经常遇到的情况：

* 新项目可以选择当前稳定版本。
* 已有项目优先遵循项目声明的版本。
* 如果要升级版本，需要同时检查依赖、测试、构建和部署环境。

### 创建第一个 Go 项目

我们先创建一个单独的学习目录，不直接修改原项目：

```bash
mkdir go-learning
cd go-learning
```

使用 `go mod init` 创建 Go 模块：

```bash
go mod init github.com/redye/go-learning
```

执行完成后，目录下会生成一个 `go.mod` 文件：

```go
module github.com/redye/go-learning

go 1.21
```

模块名称以后会作为其他 Go 代码导入当前项目时使用的路径。

如果项目只是公司内部使用，也可以使用公司的模块路径。例如原项目使用的是类似下面的内部模块名：

```go
module example.com/internal-service
```

如果项目以后要发布到 GitHub，模块路径通常应该和代码仓库地址保持一致。

### 需要选择什么技术框架

Go 本身已经提供了 `net/http` 标准库，可以直接编写 HTTP 服务，不一定需要额外的 Web 框架。

例如，使用标准库可以这样启动一个服务：

```go
package main

import (
	"fmt"
	"net/http"
)

func main() {
	http.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello, Go")
	})

	if err := http.ListenAndServe(":8080", nil); err != nil {
		panic(err)
	}
}
```

标准库的优点是依赖少，适合学习 HTTP 服务的基本原理。

但是，我们这次要学习的真实项目是一个面向 App 的 HTTP 接口服务，项目中使用了 Gin：

```go
require (
	github.com/gin-gonic/gin v1.10.1
)
```

Gin 提供了路由、路由分组、中间件、参数绑定、JSON 响应和异常恢复等能力，比较适合 REST API 和 BFF 服务。这个项目中的路由、中间件和请求处理，也都是围绕 Gin 的 `gin.Engine` 和 `gin.Context` 展开的。

所以这次的选择是：

* 先了解 Go 标准库，知道 HTTP 服务是怎么工作的。
* 实际项目练习使用 Gin，逐步理解框架如何封装标准库。
* 暂时不额外引入数据库 ORM、日志框架等依赖，真正用到时再安装。

### 安装 Gin 依赖

创建模块后，我们安装和目标项目保持一致的 Gin 版本：

```bash
go get github.com/gin-gonic/gin@v1.10.1
```

安装完成后，`go.mod` 会增加依赖：

```go
require github.com/gin-gonic/gin v1.10.1
```

同时通常会生成或更新 `go.sum`。这个文件记录依赖模块的校验信息，用来保证每次下载到的依赖内容是一致的。

Go 官方推荐使用 Go Modules 管理依赖。模块的核心文件有两个：

* `go.mod`：记录模块名称、Go 版本和依赖版本。
* `go.sum`：记录依赖包的校验值。

它们都应该提交到 Git 仓库中。

### 编写第一个 Gin 程序

#### 编写第一个 Gin 程序

在当前目录创建 `main.go`：

```go
package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	r.GET("/hello", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Hello, Go",
		})
	})

	if err := r.Run(":8080"); err != nil {
		panic(err)
	}
}
```

这里有几个新的内容：

* `gin.Default()` 创建一个带有日志和异常恢复中间件的路由器。
* `r.GET("/hello", ...)` 注册一个 GET 请求。
* `*gin.Context` 表示当前 HTTP 请求的上下文。
* `c.JSON` 将数据以 JSON 格式返回给客户端。
* `gin.H` 本质上是一个方便构造 JSON 对象的 map。

运行程序：

```bash
go run .
```

打开另一个终端发送请求：

```bash
curl http://localhost:8080/hello
```

可以看到返回结果：

```json
{"message":"Hello, Go"}
```

到这里，一个最简单的 Go Web 项目就运行起来了。

#### macOS 下的 `missing LC_UUID` 错误

如果在较新的 macOS 上运行较旧 Go 版本编译的程序，可能会遇到下面的错误：

```
dyld: missing LC_UUID load command
signal: abort trap
```

这是因为旧版 Go 的内部链接器生成的 macOS 可执行文件可能没有 `LC_UUID`，而系统加载程序 `dyld` 需要这个信息。程序可能已经编译成功，但在启动时被系统拒绝加载。

如果暂时不能升级 Go，可以尝试让 Go 使用 macOS 的外部链接器运行程序：

```bash
CGO_ENABLED=1 go run -ldflags="-linkmode=external" .
```

这种方式需要安装 Xcode Command Line Tools，其中包含 `clang`。可以用下面的命令检查：

```bash
xcode-select -p
clang --version
```

如果提示找不到 C 编译器，可以先安装 Command Line Tools：

```bash
xcode-select --install
```

外部链接可以作为临时绕过方式；条件允许时，升级到较新的 Go 版本会省去这项额外参数。

#### 在 GoLand 中配置

如果平时通过 GoLand 运行程序，可以把相同的参数添加到运行配置中：

1. 打开 `Run` → `Edit Configurations...`，选择当前的 Go 运行配置。
2. 在 `Go tool arguments` 中填写：

   ```text
   -ldflags=-linkmode=external
   ```

3. 在 `Environment variables` 中添加 `CGO_ENABLED=1`。
4. 保存配置后重新运行程序。

注意，参数要填写在 `Go tool arguments` 中，而不是 `Program arguments`。前者传给 Go 工具，后者会作为参数传给编译后的程序。

#### 升级 Go 版本

外部链接是一种临时绕过方式。Go 1.24 起，Go 链接器默认会在 macOS 可执行文件中生成 `LC_UUID`。如果可以升级 Go，可以安装 Go 1.24 或更新版本：

如果当前 Go 是通过 Homebrew 安装的，可以运行：

```bash
brew update
brew upgrade go
```

也可以从 [Go 官方下载页面](https://go.dev/dl/)下载安装包。安装后重新打开终端或 IDE，并检查当前实际使用的 Go 版本：

```bash
which go
go version
```

如果电脑上安装了多个 Go 版本，`which go` 可以帮助确认命令行当前找到的是哪一个。升级本机工具链不代表必须同步修改 `go.mod` 中的 `go` 指令；是否调整该版本应结合项目要求和依赖情况决定。

### Go Modules 常用命令

#### 添加或升级依赖

使用 `go get` 添加依赖或指定依赖版本：

```bash
go get github.com/gin-gonic/gin@v1.10.1
```

升级到指定版本：

```bash
go get github.com/gin-gonic/gin@v1.10.2
```

不要为了“更新一下依赖”就直接对所有依赖执行升级。大型项目中，一个依赖的升级可能会同时升级它的间接依赖，应该先查看变更再进行测试。

#### 整理依赖

```bash
go mod tidy
```

`go mod tidy` 会根据项目源码和测试代码检查依赖：

* 添加缺少的依赖。
* 删除没有使用的依赖。
* 更新 `go.sum`。
* 保持 `go.mod` 和实际代码一致。

通常在新增、删除或调整 import 后执行一次。

#### 下载依赖

```bash
go mod download
```

这个命令会提前把模块下载到本地缓存，但不会替我们判断项目到底使用了哪些依赖。整理依赖主要使用 `go mod tidy`，提前下载依赖才使用 `go mod download`。

#### 查看依赖

查看当前模块的直接依赖：

```bash
go list -m
```

查看完整的模块依赖关系：

```bash
go list -m all
```

查看某个依赖为什么会被引入：

```bash
go mod why github.com/gin-gonic/gin
```

### 私有依赖和目标项目

真实项目除了 Gin、Apollo 等公开依赖，还使用了公司内部的 GitLab 模块，例如：

```go
example.com/company/go-agent
```

这类依赖通常需要登录权限，不能像公开模块一样直接从公共代理下载。公司项目一般需要配置 `GOPRIVATE`，让 Go 知道哪些模块属于私有模块：

```bash
go env -w GOPRIVATE=example.com/company/*
```

具体的 GitLab 访问方式还要遵循公司的开发环境和凭证配置。学习阶段的公开依赖不需要配置这一项。

### 小结

这一篇我们完成了一个 Go 项目的最小闭环：

1. 查看并选择 Go 版本。
2. 使用 `go mod init` 创建模块。
3. 选择标准库或 Gin Web 框架。
4. 使用 `go get` 安装固定版本的 Gin。
5. 使用 `go.mod` 和 `go.sum` 管理依赖。
6. 使用 `go run .` 启动第一个 HTTP 服务。

下一篇开始学习 `main.go` 文件，从 `package main`、`import`、函数和 `gin.Context` 开始，逐步理解这个程序是如何运行起来的。

### 参考

[Go 官方下载页面](https://go.dev/dl/)

[Go Modules 官方文档](https://go.dev/ref/mod)

[Gin 官方仓库](https://github.com/gin-gonic/gin)

[Go issue：macOS 上 Go 链接器生成的程序缺少 LC_UUID](https://github.com/golang/go/issues/68678)

[Go 1.24 发布说明](https://go.dev/doc/go1.24)

[GoLand 运行/调试配置](https://www.jetbrains.com/help/go/run-debug-configuration.html)
