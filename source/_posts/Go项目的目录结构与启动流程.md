---
title: Go 项目的目录结构与启动流程
categories: Go入门
tags: [Go]
---

上一篇我们创建了第一个 Go 程序，并用 Gin 注册了一个 HTTP 接口。接下来不急着继续增加接口，先学会读一个已有的 Go 项目：程序从哪里启动、路由在哪里注册、一次请求又是怎样进入业务代码的。

下面以真实项目中常见的 Go + Gin 结构为例，隐去项目名称和业务信息，只关注 Go 语言和项目组织方式。

<!-- more -->

### 从 `package main` 和 `func main` 找入口

Go 源文件开头会声明自己属于哪个包。例如：

```go
package main
```

如果一个包要编译成可执行程序，它需要是 `main` 包，并且声明一个没有参数、也没有返回值的 `main` 函数：

```go
func main() {
	// 程序从这里开始执行
}
```

程序启动时，会先初始化它依赖的包，然后调用 `main` 包中的 `main` 函数。`main` 是入口函数的名称；源文件本身不一定要叫 `main.go`。

在有 `go.mod` 的项目根目录中，常见的启动方式是：

```bash
go run .
```

这里的 `.` 表示当前目录对应的 Go 包。`go run .` 会构建这个包，再运行生成的程序。如果使用 `go run file1.go file2.go` 这种写法，则是显式指定参与构建的源文件；多文件项目应遵循项目已有的启动命令，避免漏掉同属入口包的文件。

### 同一个目录里的多个 Go 文件

Go 通常按目录组织包。同一目录下、声明相同 `package` 名称的 Go 源文件会共同组成一个包。它们可以直接使用包内其他文件声明的函数、类型和变量，不需要互相 `import`。

例如，一个可执行包可以把入口和路由注册拆成两个文件：

```text
项目根目录/
├── go.mod
├── 启动入口.go
└── 路由注册.go
```

两个文件都声明 `package main`，入口文件中的 `main` 函数就可以调用路由文件中的注册函数。拆分文件只是为了让代码更容易阅读；它们仍属于同一个包。

需要区分几个概念：

* `go.mod` 中的 `module` 路径用于标识模块和导入其他目录中的包。
* Go 源文件中的 `package` 声明表示文件所属的包。
* 目录帮助组织包；目录名与 `package` 名通常相近，但不要求完全相同。

### 先认识项目中的核心目录

Go 语言没有强制要求每个项目都使用同一套目录结构。当前学习的项目采用分层组织，可以先从这些目录开始：

```text
项目根目录/
├── go.mod、go.sum
├── 启动入口和路由注册文件
├── apiConfig/    运行配置
├── controller/   HTTP 请求处理
├── business/     业务逻辑编排
├── service/      下游服务调用
├── foundation/   日志、缓存等基础能力
├── viewmodel/    接口使用的数据结构
└── gen/、protobuf/ 生成代码
```

这些目录是该项目的组织约定，不是 Go 语言规定。学习时先理解各层职责和依赖方向，不要看到目录名就假设所有项目都必须照此布局。

在这个项目中，主要调用关系可以先记成：

```text
controller → business → service → 下游服务
```

`controller` 处理 HTTP 边界，例如读取请求、调用业务逻辑和组织响应；`business` 编排业务规则；`service` 封装与下游服务的交互。这样逐层阅读，比一开始搜索整个仓库更容易建立上下文。

### Gin 路由如何接上处理函数

程序入口创建 Gin 的 `Engine` 后，会把中间件和路由注册到它上面。项目使用 `gin.New()` 创建路由器，再按需要添加恢复、日志和其他中间件；`gin.Default()` 则会默认附带 Logger 和 Recovery 中间件。

简化后的代码结构如下：

```go
router := gin.New()
router.Use(gin.Recovery())
registerRoutes(router)
```

路由注册函数通常会用 `Group` 按路径前缀或功能分组，再通过 `GET`、`POST` 等方法把请求路径映射到处理函数：

```go
api := router.Group("/api")
health := api.Group("/health")
health.GET("/ready", readinessHandler)
```

上例中，最终路径是 `GET /api/health/ready`。调用 `Group` 不会启动服务，它只是组织路由；实际接收 HTTP 请求的是 Gin 路由器背后的 HTTP Server。

### 从启动流程到请求流程

读入口文件时，可以先把复杂初始化归纳成下面几步：

```text
包初始化 → main() → 加载配置并初始化基础依赖
         → 创建 Gin Engine → 注册中间件和路由
         → 启动 HTTP Server → 等待请求或退出信号
```

真实服务在创建路由器前，可能还要初始化远程配置、缓存、日志和链路追踪等基础组件；启动后也可能运行指标服务或后台任务。阅读时先识别这些阶段，不必立刻理解每个依赖的内部实现。

一条 HTTP 请求进入服务后的主要路径则是：

```text
客户端 → Gin 中间件 → 路由对应的 controller
       → business → service → 下游服务
```

响应会沿调用链返回。实际项目中不同路由的处理方式可能不同，因此应从路由注册处跟进具体处理函数，而不是仅凭目录结构推测调用关系。

与入门示例中直接调用 `router.Run()` 相比，实际服务常使用 `http.Server` 配置监听地址和超时，并在收到退出信号时调用 `Shutdown`。这可以让服务在退出前完成正在处理的请求，属于服务部署时需要考虑的生命周期管理。

### 推荐的阅读顺序

第一次阅读大型项目时，可以按这个顺序进行：

1. 找到 `package main` 和 `func main`，标出启动初始化的几个阶段。
2. 找到 Gin `Engine` 创建的位置，以及注册路由的函数。
3. 选择一个简单的健康检查或演示接口，从 HTTP 方法和路径找到处理函数。
4. 沿着处理函数继续阅读 `controller`、`business`、`service` 的调用关系。
5. 遇到暂时看不懂的基础组件时，先记录它的输入、输出和职责，不要立即展开阅读整个实现。

下一步我们可以挑选一个简单接口，沿着这条请求链继续学习 Gin 的 `Context`、参数绑定和响应处理。

### 官方参考

* [Go 语言规范：程序初始化与执行](https://go.dev/ref/spec#Program_execution)
* [Go 命令：`go run`](https://go.dev/cmd/go/#hdr-Compile_and_run_Go_program)
* [Gin：路由分组](https://gin-gonic.com/en/docs/routing/grouping-routes/)
* [Gin：中间件](https://gin-gonic.com/en/docs/middleware/using-middleware/)
