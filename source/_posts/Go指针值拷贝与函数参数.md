---
title: Go 指针、值拷贝与函数参数
categories: Go入门
tags: [Go]
---

上一篇我们用结构体描述请求与响应，也使用了 `*bool` 区分可选开关的不同状态。这一篇继续理解几个已经见过的写法：`&req` 为什么能让 JSON 解码器填入数据，`*req.Notify` 为什么要先判断是否为 `nil`，以及 `*gin.Context` 中的星号表示什么。

理解这些写法，需要先弄清楚变量的值、指向变量的指针，以及函数调用时发生的拷贝。下面继续用独立的学习示例观察这些行为，完整程序可以在 Go 1.24.13 下运行。

<!-- more -->

### 先区分变量的值和地址

先声明一个整数，再取得它的地址：

```go
count := 1
p := &count

fmt.Println(count)
fmt.Println(*p)
```

`count` 中保存的是整数 `1`。`&count` 取得变量的地址，`p` 保存这个地址，它的类型是 `*int`，也就是指向整数的指针。

表达式 `*p` 表示访问指针所指向的值，这个操作叫解引用。上面两次打印都会输出 `1`。如果通过指针修改这个值：

```go
*p = 2
fmt.Println(count)
```

`count` 就会变成 `2`，因为 `p` 指向的正是这个变量。

几种常见写法可以放在一起对照：

| 写法 | 含义 |
| --- | --- |
| `User` | 一个结构体类型 |
| `*User` | 指向 `User` 的指针类型 |
| `&user` | 取得变量 `user` 的地址 |
| `*p` | 访问指针 `p` 所指向的值 |

星号位于类型前面时描述类型，位于表达式前面时执行解引用。它们的上下文不同。

### 函数参数始终按值传递

Go 调用函数时，会把实参的值复制给形参。即使参数是指针，复制的也是指针值；它指向的数据不会因此自动复制一份。[Go FAQ：函数参数传递](https://go.dev/doc/faq#pass_by_value)

先看一个普通结构体参数：

```go
type User struct {
	Name string
}

func renameByValue(user User) {
	user.Name = "copy"
	fmt.Println("值参数（函数内）:", user.Name)
}
```

调用时：

```go
user := User{Name: "Go"}
renameByValue(user)
fmt.Println("值参数（函数外）:", user.Name)
```

结果是函数内的名称变成了 `copy`，函数外仍然是 `Go`。参数 `user` 是调用方结构体值的一份副本，给这个副本的 `Name` 字段赋值不会修改调用方的字段。

### 通过指针修改原来的结构体

如果函数需要修改调用方的数据，可以接收结构体指针：

```go
// 调用方应传入非 nil 的指针。
func renameByPointer(user *User) {
	user.Name = "pointer"
}
```

调用时传入变量地址：

```go
user := User{Name: "Go"}
renameByPointer(&user)
fmt.Println(user.Name)
```

这次输出为 `pointer`。函数获得了指针值的副本，但它仍然指向调用方的那个 `User`，因此修改会落到同一个对象上。

对于结构体指针，Go 允许用 `user.Name` 访问字段，它相当于 `(*user).Name`。这只是字段访问语法上的简化，指针仍然需要指向一个有效对象。

### 修改指向的数据，与修改指针本身

下面的函数会给形参重新赋一个地址：

```go
func replacePointer(user *User) {
	user = &User{Name: "replacement"}
	fmt.Println("重新赋值（函数内）:", user.Name)
}
```

调用代码是：

```go
user := User{Name: "Go"}
p := &user
replacePointer(p)
fmt.Println("重新赋值（函数外）:", p.Name)
```

函数内输出 `replacement`，函数外仍然输出 `Go`。这里改变的是函数自己的形参，让它指向新对象；调用方的 `p` 没有被重新赋值。

这段代码中，两处 `user` 的名字虽然相同，却是不同的变量：`main` 中的 `user` 是原来的结构体，`replacePointer` 的形参 `user` 是一个指针。下图把原结构体标为“对象 A”，用蓝色表示调用方的 `p`，用橙色表示函数内的指针形参。

![进入函数、给指针形参重新赋值与函数返回后的指向关系](/images/go-pointer-parameter-reassignment.png)

图中的“地址 A”和“地址 B”只用于区分对象，不是真实的内存地址。刚进入函数时，`p` 和函数内的 `user` 都保存地址 A。执行 `user = &User{...}` 后，只把函数内的 `user` 改成地址 B；原对象 A 的字段没有变化。函数返回后，通过 `p` 读取的仍然是对象 A。

如果把函数里的赋值替换成 `user.Name = "changed"`，则两根箭头都不变，变化的是对象 A 内部的字段。因此，调用方通过 `p.Name` 读到的也会是 `changed`。判断修改落在哪里，可以先看等号左边：`user.Name` 是对象字段，`user` 是函数里的指针变量。

如果函数需要提供一个新对象，也可以直接返回它，再由调用方决定是否替换原变量。

### `nil` 指针还没有指向对象

指针的零值是 `nil`：

```go
var user *User
fmt.Println(user == nil)
```

这段代码输出 `true`。声明一个指针变量不会自动创建它要指向的结构体，此时读取 `user.Name` 或执行 `*user` 都会触发运行时 panic。

需要一个有效对象时，可以创建结构体并取得它的指针：

```go
user := &User{Name: "Go"}
```

也可以使用 `new(User)`，它创建一个各字段为零值的 `User` 并返回 `*User`。

如果参数允许为 `nil`，函数需要定义这种情况的含义；如果参数要求非 nil，则应保证调用方满足这个约定。本节修改字段的示例都传入了有效对象的地址。

### 为什么 JSON 解码使用 `&req`

上一节的代码先声明一个结构体变量，再把它的地址交给解码器：

```go
var req ProfileRequest
if err := json.Unmarshal(input, &req); err != nil {
	log.Fatal(err)
}
```

`req` 的类型是 `ProfileRequest`，`&req` 的类型是 `*ProfileRequest`。解码器通过这个指针，把 JSON 中的数据写入调用方提供的变量。

如果把第二个参数直接写成普通结构体值 `req`，标准库会返回 `InvalidUnmarshalError`。`json.Unmarshal` 要求传入非 nil 的指针；这也是我们必须检查返回错误的原因。[JSON 解码说明](https://pkg.go.dev/encoding/json#Unmarshal)

如果一开始就创建了非 nil 的结构体指针，可以直接传它：

```go
req := new(ProfileRequest)
if err := json.Unmarshal(input, req); err != nil {
	log.Fatal(err)
}
```

要不要写 `&`，取决于当前变量的类型以及函数要求的参数形式，不能只记成“解码时总在变量前面加 `&`”。

### 结构体拷贝不会自动复制指针指向的数据

上一篇的请求模型里包含 `*bool` 字段。这样的结构体发生拷贝时，字段中的指针值也会被拷贝，两份结构体可能仍然共享指针指向的数据。

```go
type User struct {
	Name   string
	Notify *bool
}

notify := false
original := User{Name: "original", Notify: &notify}
copied := original

copied.Name = "copy"
*copied.Notify = true
```

`copied.Name` 和 `original.Name` 可以分别赋值，但两个 `Notify` 字段都指向同一个布尔变量。所以修改 `*copied.Notify` 后，读取 `*original.Notify` 也会得到 `true`。

这种拷贝通常称为浅拷贝：结构体字段本身被复制，指针指向的内容不会递归复制。切片和 map 也有类似的共享数据问题，后面学习集合类型时会继续观察。

### 回看 `*bool` 和 `*gin.Context`

对于可选开关：

```go
if req.Notify != nil {
	notify = *req.Notify
}
```

先判断是否存在一个布尔值，再通过解引用读取它，才能保留客户端显式传入的 `false`。`nil` 与 `false` 表达的状态不同。

Gin 的处理函数则常写成：

```go
func handleRequest(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Hello, Go"})
}
```

这里的 `*gin.Context` 表示指向 Gin Context 的指针。把 `c` 传给其他函数时，仍然是复制指针值，相关函数可以访问同一个请求对象。它的具体生命周期和请求处理方法由 Gin 管理。

### 把几种情况放在一起运行

新建一个独立学习目录：

```bash
mkdir pointer-learning
cd pointer-learning
go mod init example.com/pointer-learning
```

创建 `main.go`，使用下面的完整代码。前面的代码块是局部示意，这里已经包含运行所需的类型、函数和导入：

```go
package main

import (
	"encoding/json"
	"fmt"
	"log"
)

type User struct {
	Name   string `json:"name"`
	Notify *bool  `json:"notify"`
}

func renameByValue(user User) {
	user.Name = "copy"
	fmt.Println("值参数（函数内）:", user.Name)
}

// 调用方应传入非 nil 的指针。
func renameByPointer(user *User) {
	user.Name = "pointer"
}

func replacePointer(user *User) {
	user = &User{Name: "replacement"}
	fmt.Println("重新赋值（函数内）:", user.Name)
}

func main() {
	user := User{Name: "Go"}

	renameByValue(user)
	fmt.Println("值参数（函数外）:", user.Name)

	renameByPointer(&user)
	fmt.Println("指针参数（函数外）:", user.Name)

	p := &user
	replacePointer(p)
	fmt.Println("重新赋值（函数外）:", p.Name)

	notify := false
	original := User{Name: "original", Notify: &notify}
	copied := original
	copied.Name = "copy"
	*copied.Notify = true

	fmt.Println("结构体副本:", copied.Name, *copied.Notify)
	fmt.Println("原结构体:", original.Name, *original.Notify)

	input := []byte(`{"name":"JSON","notify":false}`)
	var req User
	if err := json.Unmarshal(input, &req); err != nil {
		log.Fatal(err)
	}
	if req.Name == "" {
		log.Fatal("name is required")
	}

	fmt.Println("JSON 解码:", req.Name)
	if req.Notify != nil {
		fmt.Println("解引用开关:", *req.Notify)
	}
}
```

执行：

```bash
go run .
```

输出为：

```text
值参数（函数内）: copy
值参数（函数外）: Go
指针参数（函数外）: pointer
重新赋值（函数内）: replacement
重新赋值（函数外）: pointer
结构体副本: copy true
原结构体: original true
JSON 解码: JSON
解引用开关: false
```

可以重点对照三处：值参数修改没有传到调用方；指针字段修改能影响同一对象；给指针形参重新赋值没有替换调用方的指针。

### 动手观察几种变化

建议每次只改一处，再与上面的输出比较：

1. 将 `renameByPointer` 中的 `user.Name = "pointer"` 改成 `*user = User{Name: "whole"}`，观察原结构体被整体赋值后的名称。这个操作也会覆盖该结构体的其他字段。
2. 将 `*copied.Notify = true` 改成先声明 `other := true`，再写 `copied.Notify = &other`。观察此时 `original.Notify` 仍然指向原来的 `false`。
3. 删除 JSON 输入中的 `notify`，观察 `req.Notify` 为 `nil`，最后的“解引用开关”一行不再输出。
4. 删除 JSON 输入中的 `name`，并保留完整示例中的 `if req.Name == ""` 检查，观察程序打印 `name is required` 并以非零状态退出。这一步由显式校验触发。

阅读项目代码时，可以先确认变量是值还是指针，再看函数参数的类型，最后判断赋值修改的是形参、对象字段，还是共享的数据。下一篇继续学习切片和 map，看看接口列表及键值数据是怎样组织和传递的。

### 官方参考

* [Go 语言规范：指针类型](https://go.dev/ref/spec#Pointer_types)
* [Go 语言规范：地址操作符](https://go.dev/ref/spec#Address_operators)
* [Go FAQ：函数参数传递](https://go.dev/doc/faq#pass_by_value)
* [Go 标准库：JSON 解码](https://pkg.go.dev/encoding/json#Unmarshal)
