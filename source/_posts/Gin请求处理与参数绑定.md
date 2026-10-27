---
title: Gin 请求处理与参数绑定
categories: Go入门
tags: [Go, Gin]
---

上一篇我们认识了 Go 项目的入口、目录结构和路由注册。接下来挑一条 HTTP 请求，看看 Gin 如何把请求交给处理函数，以及处理函数怎样读取参数、返回响应。

我们先从项目里比较简单的健康检查路由观察 Controller 与业务逻辑的调用关系，再用一个独立的小例子学习 `gin.Context`、参数绑定和 JSON 响应。示例中的路径和数据都是为了学习而编写，不包含真实项目的接口信息。

<!-- more -->

### 一次请求会经过哪些步骤

在 Gin 中，路由会把 HTTP 方法和 URL 路径映射到一个处理函数。请求到来后，大致经过下面的过程：

```text
客户端请求
  → Gin 中间件
  → 路由匹配
  → 处理函数读取并校验参数
  → 调用需要的业务逻辑
  → 写入 HTTP 响应
```

处理函数通常接收一个 `*gin.Context`：

```go
func handleRequest(c *gin.Context) {
	// 读取当前请求，或写入响应
}
```

`gin.Context` 是 Gin 为当前 HTTP 请求提供的上下文对象。它既能访问底层请求，也提供了路由参数读取、数据绑定、设置响应等方法。通常一个请求对应一个 Context，不要把它保存起来供请求结束后继续使用。

### `gin.Context` 和 `context.Context` 不一样

这两个类型名字相似，但职责不同：

* `*gin.Context` 提供 Gin 的 HTTP 请求处理能力，例如 `Param`、`Query`、`ShouldBindJSON` 和 `JSON`。
* `context.Context` 是 Go 标准库类型，用于在调用链中传递取消信号、截止时间和请求范围内的数据。

在 Gin 处理函数中，可以通过 `c.Request.Context()` 取得当前 HTTP 请求的标准库 Context。调用下游 HTTP 服务或数据库时，应按对应 API 传递这个请求 Context，让客户端断开连接或请求超时时，相关操作有机会及时结束。不要把 `*gin.Context` 当成标准库的 `context.Context` 使用。

### 读取不同位置的参数

请求数据可能来自 URL 路径、查询字符串、请求头或请求体。读取方式要与接口定义的数据位置相匹配。

#### 路径参数

注册 `/users/:id` 后，可以使用 `Param` 读取 `id`：

```go
router.GET("/users/:id", func(c *gin.Context) {
	userID := c.Param("id")
	c.JSON(http.StatusOK, gin.H{"id": userID})
})
```

请求 `/users/42` 时，`userID` 的值是字符串 `"42"`。如果后续逻辑需要整数，还要将它解析成数字并处理解析错误。

#### 查询参数

查询参数写在 URL 的 `?` 后面，例如 `/search?q=gin&page=2`：

```go
query := c.Query("q")
page := c.DefaultQuery("page", "1")
```

`Query` 在参数不存在时返回空字符串；`DefaultQuery` 可以在参数不存在时提供默认值。具体参数是否必填、默认值是什么，应该由接口契约决定。

#### JSON 请求体

对于 JSON 请求体，可以定义一个 Go 结构体，再使用 `ShouldBindJSON` 解析：

```go
type GreetingRequest struct {
	Name string `json:"name" binding:"required"`
}

func createGreeting(c *gin.Context) {
	var req GreetingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Hello, " + req.Name})
}
```

这里有两个常见的结构体标签：

* `json:"name"` 指定 JSON 字段名与 Go 字段之间的映射关系。
* `binding:"required"` 要求该字段在绑定时有非零值；Gin 会在绑定过程中执行校验。

`ShouldBindJSON` 接收结构体指针，并把解析或校验错误返回给调用方。示例中绑定失败后写入错误响应并立即 `return`，避免继续执行业务逻辑或重复写响应。实际接口不应把内部错误细节不加判断地直接返回给客户端。

Gin 还有 `BindJSON` 等方法。两类方法的区别在于错误处理：`Bind` 系列遇到错误时会自动中止请求并写入错误响应；`ShouldBind` 系列则把错误返回给处理函数，由代码决定如何响应。需要自定义错误格式时，通常使用 `ShouldBind` 系列。[Gin 绑定与校验说明](https://gin-gonic.com/en/docs/binding/binding-and-validation/)

### 返回 JSON 响应

`c.JSON` 接收 HTTP 状态码和要返回的数据，Gin 会将数据编码为 JSON 并写入响应：

```go
c.JSON(http.StatusOK, gin.H{"message": "Hello, Go"})
```

`http.StatusOK` 是标准库提供的 HTTP 200 状态码常量。常见的其他状态码还包括 `http.StatusBadRequest`（400）和 `http.StatusInternalServerError`（500）。返回哪种状态码，应根据接口约定和错误类型决定。

还要区分 HTTP 状态码与 JSON 响应体中的业务状态字段。有些已有系统为了兼容客户端，会始终返回 HTTP 200，而在响应体中单独提供业务错误码；阅读项目时要看它自己的响应约定，不能只看 HTTP 状态码判断业务是否成功。

### 把示例运行起来

下面将路由、参数结构体和处理函数放在同一个文件中。若上一节创建的学习项目还在，可以将内容放入 `main.go`：

```go
package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

type GreetingRequest struct {
	Name string `json:"name" binding:"required"`
}

func createGreeting(c *gin.Context) {
	var req GreetingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Hello, " + req.Name})
}

func main() {
	router := gin.Default()
	router.POST("/greetings", createGreeting)

	if err := router.Run(":8080"); err != nil {
		log.Fatal(err)
	}
}
```

在项目目录中启动：

```bash
go run .
```

另开一个终端发送请求：

```bash
curl -i -X POST http://localhost:8080/greetings \
	-H 'Content-Type: application/json' \
	-d '{"name":"Go"}'
```

成功时，响应状态为 `200`，响应体类似：

```json
{"message":"Hello, Go"}
```

再试着省略 `name` 字段：

```bash
curl -i -X POST http://localhost:8080/greetings \
	-H 'Content-Type: application/json' \
	-d '{}'
```

此时绑定校验失败，处理函数会返回 `400 Bad Request`。这能帮助我们直观看到请求数据、结构体标签、校验和响应之间的关系。

### 回到项目中继续阅读

回到项目时，可以从路由注册处选择一个简单接口，依次确认：

1. 路由使用什么 HTTP 方法和 URL。
2. 路由绑定到哪个处理函数，中间经过哪些全局或分组中间件。
3. 处理函数从哪里读取请求参数，绑定到什么结构体。
4. 参数错误和业务错误分别怎样处理。
5. 最终写出的 HTTP 状态码和响应体是什么。

项目中的健康检查路由可以用来观察“路由匹配 → Controller → 业务函数 → 统一响应”的调用链。项目还封装了统一的响应格式，因此它与上面的独立示例在响应结构上会有所不同；学习时先看懂请求链，再按项目自己的约定理解错误码和响应字段。

下一步可以继续学习 Go 结构体与 JSON 标签，理解请求、响应数据是如何映射到 Go 类型上的。

### 官方参考

* [Gin：模型绑定与校验](https://gin-gonic.com/en/docs/binding/binding-and-validation/)
* [Gin：路径参数](https://gin-gonic.com/en/docs/routing/param-in-path/)
* [Gin：查询参数](https://gin-gonic.com/en/docs/routing/querystring-param/)
* [Gin：渲染 JSON 响应](https://gin-gonic.com/en/docs/rendering/)
* [Go 标准库 `context` 包](https://pkg.go.dev/context)
* [Go 标准库 HTTP 请求 Context](https://pkg.go.dev/net/http#Request.Context)
