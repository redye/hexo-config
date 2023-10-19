---
title: Swift 构造器
categories: Swift入门
tags: [Swift]
---

构造过程是使用类、结构体或枚举类型一个实例的准备过程。在新实例可用前必须执行这个过程，具体操作包括设置实例中每个存储型属性的初始值和执行其他必须的设置或初始化工作。

<!-- more -->

通过定义构造器(Initializers)来实现构造过程，这些构造器可以看做是用来创建特定类型新示例的特殊方法。与 Objective-C 语言不同，Swift 构造器无需返回值，它们的主要任务是保证新实例在第一次使用前完成正确的初始化。

类的实例也可以通过定义析构器(deinitializer) 在实例释放之前执行特定的清除工作。

### 设置存储型属性的初始值
类和结构体在创建实例时，必须为所有存储属性设置合适的初始值。存储属性的值不能处于一个未知的状态。

你可以在构造器中为存储属性赋初始值，也可以在定义属性时为其设置默认值。

**当你在为存储属性设置默认值或者在构造器中为其赋值时，他们的值是被直接设置的，不会触发任何属性观察者。**

#### 构造器
构造器在创建某特定类型的新实例时调用。它的最简形式类似与一个不带任何参数的实例方法，已关键字 `init` 命名。

下面看一个例子：

```swift
struct Fahrenheit {
    var temperature: Double
    init() {
        temperature = 32.0
    }
}

“var f = Fahrenheit()
print("The default temperature is \(f.temperature)° Fahrenheit")
// 输出 "The default temperature is 32.0° Fahrenheit”

```

这个结构体定义了一个不带参数的构造器 `init`， 并在里面将存储型属性 `temperature ` 的初始化为 32.0（华摄氏度下水的冰点）。

#### 默认属性值
可以在构造器中为存储属性赋值，同样也可以在属性声明时设置默认值。

> 如果一个属性总是使用相同的初始值，那么为其设置一个默认值比每次都在构造器中赋值要好。两种方法的效果是一样的，只不过使用默认值让属性的初始化和声明结合的更紧密。使用默认值能让你的构造器更简洁、更清晰，且能通过默认值自动推导出属性的类型；同时，它也能让你充分利用默认构造器、构造器继承等特性。


```swift
struct Fahrenheit {
    var temperature = 32.0
}
```

### 自定义构造过程
通过输入参数和可选属性类型来自定义构造过程，也可以在构造过程中修改常量属性。

#### 构造参数
自定义构造过程时，可以在定义中提供构造参数，指定所需值的类型和名字。构造参数的功能和语法跟函数和方法的参数相同。

```swift
struct Celsius {
    var temperatureInCelsius: Double
    
    init(fromFahrenheit fahrenheit: Double) {
        temperatureInCelsius = (fahrenheit - 32.0) / 1.8
    }
    
    init(fromKelvin kelvin: Double) {
        temperatureInCelsius = kelvin - 273.15
    }
}

let boilingPointOfWater = Celsius(fromFahrenheit: 212.0)
// boilingPointOfWater.temperatureInCelsius 是 100.0

let freezingPointOfWater = Celsius(fromKelvin: 273.15)
// freezingPointOfWater.temperatureInCelsius 是 0.0
```

#### 参数的内部名称和外部名称

```swift
struct Color {
	let red, green, blue: Double
	init(red: Double, green: Double, blue: Double) {
		self.red = red
		self.green = green
		self.blue = blue
	}
}

let color = Color(red: 1.0, green: 1.0, blue: 1.0)
```

#### 不带外部名的构造器参数

```swift
struct Color {
	let red, green, blue: Double
	init(_ red: Double, _ green: Double, _ blue: Double) {
		self.red = red
		self.green = green
		self.blue = blue
	}
}

let color = Color(1.0, 1.0, 1.0)
```

#### 可选属性类型

```swift
struct SurverQuestion {
    var text: String
    var response: String?
    
    init(text: String) {
        self.text = text
    }
    
    func ask() {
        print(text)
    }
}

var question = SurverQuestion(text: "Do you like coffee?")
question.ask()
question.response = "Yes, I do"
```

#### 构造过程中常量属性的修改
可以在构造过程中的任意时间点修改常量属性的值，只要在构造过程结束时是一个确定的值。一旦常量属性被赋值，它将永远不可更改。

**对于类的实例来说，它的常量属性只能在定义它的类的构造过程中修改；不能在子类中修改。**

```swift
class SurverQuestion {
    let text: String
    var response: String? // 实例化时，自动赋值为空 nil
    
    init(text: String) {
        self.text = text
    }
    
    func ask() {
        print(text)
    }
}

let question = SurverQuestion(text: "Do you like coffee?")
question.ask()
question.response = "Yes, I do"
```

### 默认构造器
如果结构体和类的所有属性都有默认值，同时没有自定义的构造器，那么 Swift 会给这些结构体和类创建一个默认构造器。这个默认构造器将简单的创建一个所有属性值都为默认值的实例。

```swift
class ShoppingListItem {
	var name: String?
	var quantity = 1
	var purchased = false
}

let item = ShoppingListItem()
```
由于 `ShoppingListItem` 类中所有属性都有默认值，且它是没有父类的基类，它将自动获得一个可以为所有属性设置默认值的默认构造器。

#### 结构体的逐一成员构造器
除上面提到的默认构造器，如果结构体对所有存储属性提供了默认值且自身没有提供定制的构造器，他们能自动获得一个逐一成员构造器。

逐一成员构造器是用来初始化结构体新实例里成员属性的快捷方法。我们在调用逐一成员构造器时，通过与成员属性名相同的参数名进行传值来完成对成员属性的初始赋值。

```swift
struct Size {
	var width = 0.0, height = 0.0
}
let size = Size(width: 2.0, height: 2.0)
```

### 值类型的构造器代理
构造器可以通过调用其他构造器来完成实例的部分构造过程。这一过程称为构造器代理，它能减少多个构造器间的代码重复。

构造器代理的实现规则和形式在值类型和类类型中有所不同。值类型（结构体和枚举类型）不支持继承，所以构造器代理的过程相对简单，因为他们只能代理本身提供的其它构造器。类则不同，它可以继承自其它类，这意味着类有责任保证其所有继承的存储型属性在构造时也能正确的初始化。

对于值类型，可以使用 `self.init` 在自定义的构造器中引用其它的属于相同值类型的构造器。并且只能在构造器内部调用 `self.init`。

如果你为某个值类型定义了一个定制的构造器，将无法访问到默认构造器（如果是结构体，则无法访问逐一对象构造器）。这个限制可以防止你在为值类型定义了一个更复杂的，完成了重要准备构造器之后，别人还是错误的使用了那个自动生成的构造器。

> 假如你想通过默认构造器、逐一对象构造器以及你自己定制的构造器为值类型创建实例，我们建议你将自己定制的构造器写到扩展（extension）中，而不是跟值类型定义混在一起。

> 在扩展中提供的定制构造器，不影响提供默认构造器、逐一对象构造器，但是需要保证构造过程能够让所有实例完全初始化。

```swift
struct Size {
	var width = 0.0, height = 0.0
}

struct Point {
	var x = 0.0, y = 0.0
}

struct Rect {
	var origin = Point()
	var size = Size()
	
	/// 空函数，返回一个 Rect 实例
	init() {}

	init(origin: Point, size: Size) {
		self.origin = origin
		self.size = size
	}
	
	init(center: Point, size: Size) {
		let originX = center.x - (size.width / 2)
		let originY = center.y - (size.height / 2)
		self.init(origin: Point(x: originX, y: originY), size: size)
	}
}
```
