---
title: Swift 可失败构造器
categories: Swift入门
tags: [Swift]
---

有时，定义一个构造器可失败的类，结构体或者枚举是很有用的。这里所指的“失败” 指的是，如给构造器传入无效的形参，或缺少某种所需的外部资源，又或是不满足某种必要的条件等。

<!-- more -->

为了妥善处理这种构造过程中可能会失败的情况。你可以在一个类，结构体或是枚举类型的定义中，添加一个或多个可失败构造器。其语法为在 `init` 关键字后面添加问号（`init?`）。

**注意**

> 可失败构造器的参数名和参数类型，不能与其它非可失败构造器的参数名，及其参数类型相同。

可失败构造器会创建一个类型为自身类型的可选类型的对象。通过 `return nil` 语句来表明可失败构造器在何种情况下应该 “失败”。

> 严格来说，构造器都不支持返回值。因为构造器本身的作用，只是为了确保对象能够被正确构造。因此只是用 `return nil` 表明可失败构造器事变，而不要用关键字 `return` 来表明构造成功。

```swift
struct Animal {
	let species: Stirng
	init?(species: String) {
		if species.isEmpty {
			return nil
		}
		self.sepcies = species
	}
}
```

可以通过可失败构造器来尝试构建一个 `Animal` 实例，并检查构造过程是否成功：

```swift
let someCreature = Animal(species: "Giraffe")
// someCreature 的类型是 Animal? 而不是 Animal

if let giraffe = someCreature {
    print("An animal was initialized with a species of \(giraffe.species)")
}
// 打印“An animal was initialized with a species of Giraffe”
```

如果给该可失败构造器传入一个空字符串，则会导致构造失败：

```swift
let anonymousCreature = Animal(species: "")
// anonymousCreature 的类型是 Animal?, 而不是 Animal

if anonymousCreature == nil {
    print("The anonymous creature could not be initialized")
}
// 打印“The anonymous creature could not be initialized”
```

#### 枚举类型的可失败构造器

可以通过一个带一个或多个形参的可失败构造器来获取枚举类型中特定的枚举成员。如果提供的形参无法匹配任何枚举成员，则构造失败。

例子：

```swift
enum TemperatureUnit {
	case Kelvin, Celsius, Fahrenheit
	init?(symbol: Character) {
		switch symbol {
		case "K":
			self = .Kelvin
		case "C":
			self = .Celsius
		case "F":
			self = . Fahrenheit
		default:
			return nil
		}
	}
}
```

可以利用该可失败构造器在三个枚举成员中选择合适的枚举成员，当形参不匹配时构造失败：

```swift
let fahrenheitUnit = TemperatureUnit(symbol: "F")
if fahrenheitUnit != nil {
    print("This is a defined temperature unit, so initialization succeeded.")
}
// 打印“This is a defined temperature unit, so initialization succeeded.”

let unknownUnit = TemperatureUnit(symbol: "X")
if unknownUnit == nil {
    print("This is not a defined temperature unit, so initialization failed.")
}
// 打印“This is not a defined temperature unit, so initialization failed.”
```

#### 带原始值的枚举类型的可失败构造器

带原始值的枚举类型会自带一个可失败构造器 `init?(rawValue:)`，该可失败构造器有一个合适的原始值类型的 `rawValue` 形参，选择找到的相匹配的枚举成员，找不到则构造失败。

例子：

```swift
enum TemperatureUnit: Character {
    case Kelvin = "K", Celsius = "C", Fahrenheit = "F"
}

let fahrenheitUnit = TemperatureUnit(rawValue: "F")
if fahrenheitUnit != nil {
    print("This is a defined temperature unit, so initialization succeeded.")
}
// 打印“This is a defined temperature unit, so initialization succeeded.”

let unknownUnit = TemperatureUnit(rawValue: "X")
if unknownUnit == nil {
    print("This is not a defined temperature unit, so initialization failed.")
}
// 打印“This is not a defined temperature unit, so initialization failed.”
```

#### 构造失败的传递
类、结构体、枚举的可失败构造器可以横向代理到它们自己的可失败构造器。类似的，子类的可失败构造器也能向上代理到父类的可失败构造器。

无论是向上代理还是横向代理，如果你代理到的其它可失败构造器触发构造失败，整个构造过程立即终止，接下来的任何构造代码不会在被执行。

可失败构造器也可以代理到其它的不可失败构造器。通过这种方式，可以增加一个可能的失败状态到现有的构造过程中。

```swift
class Product {
    let name: String
    init?(name: String) {
        if name.isEmpty { return nil }
        self.name = name
    }
}

class CartItem: Product {
    let quantity: Int
    init?(name: String, quantity: Int) {
        if quantity < 1 { return nil }
        self.quantity = quantity
        super.init(name: name)
    }
}
```

#### 重写一个可失败构造器

可以在子类中重写父类的可失败构造器。也可以用子类的非可失败构造器重写一个父类的可失败构造器。这使你可以定义一个不会构造失败的子类，及时父类的构造器允许失败。

当你用子类的非可失败构造器重写父类的可失败构造器时，向上代理到父类的可失败构造器的唯一方式是对父类的可失败构造器的返回值进行强制解包。

> 注意
> 
> 可以用非可失败构造器重写可失败构造器，但返回来不行。


```swift
class Document {
    var name: String?
    // 该构造器创建了一个 name 属性的值为 nil 的 document 实例
    init() {}
    // 该构造器创建了一个 name 属性的值为非空字符串的 document 实例
    init?(name: String) {
        if name.isEmpty { return nil }
        self.name = name
    }
}

class AutomaticallyNamedDocument: Document {
    override init() {
        super.init()
        self.name = "[Untitled]"
    }
    /// 重写父类的可失败构造器
    override init(name: String) {
        super.init()
        if name.isEmpty {
            self.name = "[Untitled]"
        } else {
            self.name = name
        }
    }
}

class UntitledDocument: Document {
	/// 通过强制解包父类的可失败构造器
    override init() {
        super.init(name: "[Untitled]")!
    }
}
```

#### init! 可失败构造器

通常来说我们通过在 `init` 关键字后添加问号的方式（`init?`）来定义一个可失败构造器，但你也可以通过在 `init` 后面添加感叹号的方式来定义一个可失败构造器（`init!`），该可失败构造器将会构建一个对应类型的隐式解包可选类型的对象。

你可以在 `init?` 中代理到 `init!`，反之亦然。你也可以用 `init?` 重写 `init!`，反之亦然。你还可以用 `init` 代理到 `init!`，不过，一旦 `init!` 构造失败，则会触发一个断言。

#### 必要构造器

在类的构造器添加 `required` 修饰符表明所有该类的子类必须实现该构造器：

```swift
class SomeClass {
	required init() { ... }
}
```

在子类重写父类的必要构造器时，必须在子类的构造器也加上 `required` 修饰符，表明该构造器要求也应用于继承链后面的子类。在重写父类中必要的指定构造器时，不需要添加 `override` 修饰符：

```swift
class SomeSubClass: SomeClass {
	required init() { ... }
}
```

如果子类继承的构造器能满足必要构造器的要求，则无需在子类中显示提供必要构造的实现。