---
title: Go 结构体与 JSON 数据映射
categories: Go入门
tags: [Go, JSON]
---

上一篇我们通过 Gin 读取请求参数，并把 JSON 请求体绑定到 Go 结构体中。这一篇继续看看这个结构体：字段为什么通常以大写字母开头，`json` 标签如何决定接口字段名，以及缺少参数时字段会是什么值。

真实项目中的请求和响应模型经常包含嵌套结构体、列表和可选字段。理解这些写法后，再阅读项目中的 `viewmodel`，就能把 Go 类型和接口实际收发的数据对应起来。本文示例使用 Go 1.24.13 的 `encoding/json` 标准库。

<!-- more -->

### 结构体把相关数据放在一起

Go 使用 `struct` 定义结构体。每个字段都有自己的名称和类型：

```go
type User struct {
	Name string
	Age  int
}
```

`type User struct` 定义了一个名为 `User` 的类型。`Name` 是字符串字段，`Age` 是整数字段。创建值时，可以按字段名赋值，再通过 `.` 读取或修改字段：

```go
user := User{
	Name: "Go",
	Age:  18,
}

fmt.Println(user.Name)
user.Age = 19
```

`:=` 会声明变量并根据右侧的值推断类型，这里的 `user` 是一个 `User` 值。按字段名初始化，能让我们清楚看到每个值的用途，不必依赖字段排列顺序。

### 字段为什么要大写

Go 中，名称以大写字母开头的标识符可以被导出。对于结构体字段，这意味着其他包可以访问它。

标准库的 JSON 编码通常也只处理导出字段。例如：

```go
type User struct {
	Name string `json:"name"`
	note string
}
```

`Name` 会参与 JSON 编码，普通的未导出字段 `note` 不会。即使给 `note` 添加 `json` 标签，也不能让这个普通字段变成导出字段。

因此，Go 中的字段可以叫 `UserID`，对外 JSON 字段仍然可以叫 `userId`。两种命名通过标签联系起来，不需要把 Go 字段改成小写。

### `json` 标签控制字段映射

结构体字段类型后面的反引号字符串叫作标签（tag）。Go 允许库读取这些信息；不同库使用不同的标签键。

上一节使用过这样的定义：

```go
type GreetingRequest struct {
	Name string `json:"name" binding:"required"`
}
```

这里的两种标签分别控制 JSON 映射与 Gin 校验：

| 写法 | 含义 |
| --- | --- |
| `json:"name"` | JSON 中的字段名为 `name` |
| `json:"nickname,omitempty"` | 编码时，如果该字段为空，则省略 `nickname` |
| `json:"-"` | 标准 JSON 编码和解码时忽略该字段 |
| `binding:"required"` | Gin 绑定时执行必填校验 |

如果不写 `json` 标签，标准库默认使用导出字段的 Go 名称作为编码后的键。接口已经约定使用 `userId` 时，建议明确写出对应标签，保持对外字段稳定。

`json` 标签本身不会检查业务必填条件。直接调用 `json.Unmarshal` 时，`binding:"required"` 不会生效；Gin 的绑定流程会另外执行相应校验。两者的职责可以分别查阅 [JSON 标准库说明](https://pkg.go.dev/encoding/json)和 [Gin 绑定与校验说明](https://gin-gonic.com/en/docs/binding/binding-and-validation/)。

### 嵌套对象与列表

结构体字段也可以是另一个结构体，或者某种类型的列表：

```go
type Profile struct {
	DisplayName string `json:"displayName"`
}

type UserResponse struct {
	UserID  string   `json:"userId"`
	Profile Profile  `json:"profile"`
	Roles   []string `json:"roles"`
}
```

`Profile` 对应一个嵌套对象，`[]string` 是字符串切片，可以先把它理解为长度可变化的字符串列表。上面的响应结构可以对应这样的 JSON：

```json
{
  "userId": "42",
  "profile": {
    "displayName": "Go learner"
  },
  "roles": ["reader", "writer"]
}
```

JSON 层级取决于字段定义和标签。阅读项目时，可以从最外层响应结构开始，逐层跟进字段类型；不需要一次读完所有模型。

### 没有赋值的字段会有零值

声明变量后，即使没有显式赋值，Go 也会给它一个零值：

```go
var user User
```

此时 `user.Name` 是空字符串，`user.Age` 是 `0`。几种常见类型的零值如下：

| 类型 | 零值 |
| --- | --- |
| `string` | `""` |
| `int` 等数值类型 | `0` |
| `bool` | `false` |
| 指针，如 `*bool` | `nil` |
| 切片，如 `[]string` | `nil` |
| 结构体 | 各字段分别为自己的零值 |

向一个新声明的结构体解码 JSON 时，输入里没有提供的字段会保留原来的零值。例如，普通 `bool` 字段遇到“不传”和“传入 `false`”，最终都可能是 `false`，单靠它的值无法判断客户端是否提供过这个参数。

这里强调“新声明的结构体”：如果复用一个已经赋值的对象，JSON 中缺少的字段通常不会自动清除旧值。处理新请求时，应使用该请求自己的参数对象。

### `omitempty` 影响输出，不代表输入可选校验

假设响应中有一个可以不返回的昵称字段：

```go
type UserResponse struct {
	Name     string `json:"name"`
	Nickname string `json:"nickname,omitempty"`
}
```

当 `Nickname` 是空字符串时，编码结果不包含 `nickname`。去掉 `omitempty` 后，则会输出 `"nickname":""`。

在本文使用的 `encoding/json` 中，`omitempty` 会省略 `false`、数值 `0`、空字符串、nil 指针，以及长度为零的切片等空值。所以给布尔字段添加它之前，要确认客户端能否接受字段缺失；如果必须明确返回 `false`，就应保留这个字段。

`omitempty` 作用于编码阶段，不会替你声明“参数必填”或“参数可以为空”的校验规则。另外，普通值类型的结构体不会仅因内部字段全为零值，就被 `omitempty` 省略；可选嵌套对象可以结合指针表示。

### 用指针区分未提供与显式关闭

对于一个可选开关，可以使用 `*bool`：

```go
type PreferencesRequest struct {
	Notify *bool `json:"notify"`
}
```

`*bool` 表示指向布尔值的指针。在每次都使用一个新声明的请求对象、并成功解码的前提下，可以观察到：

| 输入 JSON | `Notify` |
| --- | --- |
| `{}` | `nil` |
| `{"notify":null}` | `nil` |
| `{"notify":false}` | 非 nil，指向 `false` |
| `{"notify":true}` | 非 nil，指向 `true` |

如果接口约定“未提供值时默认开启”，可以这样处理：

```go
notify := true
if req.Notify != nil {
	notify = *req.Notify
}
```

读取 `*req.Notify` 前，要先确认指针不是 `nil`。这个写法保留了客户端显式传入 `false` 的意图。

普通指针能帮助区分“没有有效值”和“提供了一个值”，但上表中缺失与 `null` 都是 `nil`。如果某个更新接口还要区分这两种情况，就需要更明确的存在性记录或自定义解码，不能仅依赖 `*bool`。

### 列表里的 `null` 和 `[]`

同样是没有元素的列表，nil 切片和已初始化的空切片在 JSON 中可能不同：

```go
var nilTags []string
emptyTags := []string{}
```

对于没有 `omitempty` 的 `[]string` 字段，使用本文的标准库编码结果是：

| 字段值 | JSON 值 |
| --- | --- |
| nil 切片 | `null` |
| 非 nil 的空切片 | `[]` |
| 包含字符串的切片 | 例如 `["go"]` |

如果加上 `omitempty`，nil 切片和空切片都会导致整个字段被省略。接口约定空列表返回 `[]` 时，需要初始化切片，并保留响应中的字段。

### 用标准库运行一次完整转换

Gin 为我们提供了绑定和响应方法；单独使用标准库，也可以观察 JSON 与结构体的转换。`json.Unmarshal` 将 JSON 解码到 Go 值中，`json.Marshal` 将 Go 值编码为 JSON 字节。

可以新建一个学习目录，无需增加第三方依赖：

```bash
mkdir json-learning
cd json-learning
go mod init example.com/json-learning
```

创建 `main.go`，写入下面的代码：

```go
package main

import (
	"encoding/json"
	"fmt"
	"log"
)

type ProfileRequest struct {
	Name   string `json:"name" binding:"required"`
	Notify *bool  `json:"notify"`
}

type ProfileResponse struct {
	Name     string   `json:"name"`
	Notify   bool     `json:"notify"`
	Nickname string   `json:"nickname,omitempty"`
	Tags     []string `json:"tags"`
	Token    string   `json:"-"`
}

func main() {
	input := []byte(`{"name":"Go","notify":false}`)

	var req ProfileRequest
	if err := json.Unmarshal(input, &req); err != nil {
		log.Fatal(err)
	}
	if req.Name == "" {
		log.Fatal("name is required")
	}

	// 接口约定：未提供开关值时，默认开启。
	notify := true
	if req.Notify != nil {
		notify = *req.Notify
	}

	resp := ProfileResponse{
		Name:   req.Name,
		Notify: notify,
		Tags:   []string{},
		Token:  "internal-value",
	}

	data, err := json.Marshal(resp)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(string(data))
}
```

运行：

```bash
go run .
```

输出为：

```json
{"name":"Go","notify":false,"tags":[]}
```

这段代码同时展示了几种行为：`&req` 把目标变量的地址交给解码器；非 nil 的 `Notify` 保留了 `false`；空昵称被省略；初始化后的空切片输出为 `[]`；`Token` 因为 `json:"-"` 不参与输出。

示例中还显式检查了 `req.Name`，因为这里直接调用标准库，`binding` 标签不会自动触发校验。编码和解码都可能失败，因此要检查返回的错误；解码失败后不要继续把部分填入的结构体当成有效参数使用。

### 动手观察几种变化

可以逐次修改上面的示例，运行并对照输出：

1. 删除输入中的 `notify`，观察默认开启后输出的 `true`；再传入 `null`，比较结果。
2. 删除输入中的 `name`，观察程序在显式校验处退出。
3. 去掉 `Tags: []string{}`，观察 `tags` 变成 `null`。
4. 给 `Tags` 的 JSON 标签添加 `omitempty`，观察空列表字段被省略。
5. 为 `Nickname` 赋一个非空值，观察该字段重新出现在 JSON 中。

回到真实项目时，按“字段是否导出 → 字段类型 → JSON 标签 → 缺失或零值的含义”这个顺序阅读请求与响应模型。尤其注意可选开关、空列表和嵌套对象，它们往往决定接口边界上的实际行为。

下一篇继续学习指针、值拷贝与函数参数，弄清楚 `&req`、`*req.Notify` 和 `*gin.Context` 中的符号分别在做什么。

### 官方参考

* [Go 语言规范：结构体](https://go.dev/ref/spec#Struct_types)
* [Go 语言规范：导出的标识符](https://go.dev/ref/spec#Exported_identifiers)
* [Go 语言规范：零值](https://go.dev/ref/spec#The_zero_value)
* [Go 标准库：JSON 编码](https://pkg.go.dev/encoding/json#Marshal)
* [Go 标准库：JSON 解码](https://pkg.go.dev/encoding/json#Unmarshal)
* [Gin：模型绑定与校验](https://gin-gonic.com/en/docs/binding/binding-and-validation/)
