---
title: 类的继承和构造过程
categories: Swift入门
tags: [Swift]
---

类里面的所有存储型属性——包括所有继承自父类的属性——都必须在构造中设置初始值。

Swift 提供了两种类型的类构造器来确保所有类实例中存储属性都能获得初始值，它们分别是指定构造器和遍历构造器。

<!-- more -->

### 指定构造器和便利构造器
指定构造器是类中最主要的构造器。一个指定构造器将初始化类中提供的所有属性，并根据父类链往上调用父类的构造器来实现父类的初始化。

每一个类都必须拥有至少一个指定构造器。在某些情况下，许多类通过继承了父类中的指定构造器而满足了这个条件。

便利构造器是类中比较次要的、辅助型的构造器。可以定义便利构造器来调用同一个类中的指定构造器，并为其参数提供默认值。也可以定义便利构造器来创建一个特殊用途或特定输入的实例。

应当只在必要的时候为类提供便利构造器，比方说某种情况下通过使用便利构造器来快捷调用某个指定构造器，能够节省更多开发时间并让类的构造过程更加清晰明了。

构造器：

```swift
init(parameters) { ... }
```

便利构造器：

```swift
convenience init(parameters) { ... }
```

### 类的构造器代理规则
为了简化指定构造器和便利构造器之间的调用关系，Swift 采用一下三条规则来限制构造器之间的代理调用：

1. 指定构造器必须调用其直接父类的指定构造器。
2. 便利构造器必须调用同意类中定义的其它构造器。
3. 便利构造器必须最终以调用一个指定构造器结束。

更方便的记忆是：

* 指定构造器必须总是向上代理
* 便利构造器必须总是横向代理

![构造器代理图](https://pic1.imgdb.cn/item/635bb52816f2c2beb142af2d.jpg)

### 两段式构造过程
第一个阶段：每个存储属通过引入它们的类的构造器来设置初始值。当每一个存储属性值被确定后，开启第二阶段；

第二阶段：给每个类一次机会在新实例准备使用之前进一步定制它们的存储属性。

两段式构造过程的使用让构造过程更安全，同时在整个类层级中给予了每个类完全的灵活性。两段式构造过程可以防止属性值在初始化之前被访问；也可以防止属性被另外一个构造器意外的赋予不同的值。

Swift 编译器将执行4种有效的安全检查，以确保两段式构造过程能顺利完成：

1. 指定构造器必须保证它**所在类引入**的所有属性都必须初始化完成，之后才能将其它构造任务向上代理给父类中的构造器。即一个对象的内存只有在其所有存储属性确定之后才能完全初始化。为了满足这一规则，指定构造器必须保证它所在类引入的属性在它往上代理之前完成初始化。

2. 指定构造器必须先向上代理调用父类构造器，然后再为**继承**的属性设置新值。如果没这么做，指定构造器赋予的新值将被父类中的构造器锁覆盖。

3. 便利构造器必须先代理调用同一类中的其它构造器，然后再为任意属性赋新值。如果没这做，便利构造器赋予的新值将被同一类中的其它指定构造器锁覆盖。

4. 构造器在第一阶段构造完成之前，不能调用任何实例方法、不能读取任何实例属性的值，self 的值不能被引用。

#### 阶段一

* 类的某个指定构造器或便利构造器被调用。
* 完成类的新实例内存的分配，但此时内存还没有被初始化。
* 指定构造器确保其所在类引入的所有存储型属性都已赋初值。存储型属性所属的内存完成初始化。
* 指定构造器切换到父类的构造器，对其存储属性完成相同的任务。
* 这个过程沿着类的继承链一直往上执行，直到到达继承链的最顶部。
* 当到达了继承链最顶部，而且继承链的最后一个类已确保所有的存储型属性都已经赋值，这个实例的内存被认为已经完全初始化。此时阶段 1 完成。

#### 阶段二
 * 从继承链顶部往下，继承链中每个类的指定构造器都有机会进一步自定义实例。构造器此时可以访问 self、修改它的属性并调用实例方法等等。
* 最终，继承链中任意的便利构造器有机会自定义实例和使用 self。

下图展示了在假定的子类和父类之间的构造阶段 1：

![构造过程阶段1](https://docs.swift.org/swift-book/_images/twoPhaseInitialization01_2x.png)

在这个例子中，构造过程从对子类中一个便利构造器的调用开始。这个便利构造器此时还不能修改任何属性，它会代理到该类中的指定构造器。

如安全检查一所示，指定构造器将确保所有子类的属性都有值。然后它将调用父类的指定构造器，并沿着继承链一直往上完成父类的构造过程。

父类中的指定构造器确保所有父类的属性都有值。由于没有更多的父类需要初始化，也就无需继续向上代理。

一旦父类中所有属性都有了初始值，实例的内存被任务是完全初始化，阶段一完成。

以下展示了相同构造过程的阶段 2：

![构造过程阶段2](https://docs.swift.org/swift-book/_images/twoPhaseInitialization02_2x.png)

父类中的指定构造器现在有机会进一步自定义实例（尽管这不是必须的）。

一旦父类中的指定构造器完成调用，子类中的指定构造器可以执行更多的自定义操作（这也不是必须的）。

最终，一旦子类的指定构造器完成调用，最开始被调用的便利构造器可以执行更多的自定义操作。

### 构造器的继承和重写

与 Objectitve-C 中的子类不同，Swift 中的子类不会默认继承父类的构造器（可以防止一个父类的简单的构造器被一个更专业的子类继承，并被错误的用来创建子类的实例）。

当你在编写一个和父类中指定构造器相匹配的子类构造器时，你实际上是在重写父类的这个指定构造器。需要加上 `override` 关键字。

如果子类的构造器没有在阶段 2 过程中做自定义操作，并且父类有一个无参数的指定构造器，你可以在所有子类的存储属性赋值之后省略 `super.init()` 的调用。

```swift
class Vehicle {
    var numberOfWheels = 0
    var description: String {
        return "\(numberOfWheels) wheel(s)"
    }
}

class Hoverboard: Vehicle {
    var color: String
    init(color: String) {
        self.color = color
        // super.init() 在这里被隐式调用
    }
    override var description: String {
        return "\(super.description) in a beautiful \(color)"
    }
}
```

> **注意**

> 子类可以在构造过程修改继承来的变量属性，但是不能修改继承来的常量属性。

### 构造器的自动继承

如上所述，子类在默认情况下不会继承父类的构造器。但是如果满足特定条件，父类构造器是可以被自动继承的。事实上，这意味着对于许多常见场景你不必重写父类的构造器，并且可以在安全的情况下以最小的代价继承父类的构造器。

#### 规则1
如果子类没有定义任何指定构造器，它将自动继承父类所有的指定构造器。

#### 规则2
如果子类提供了所有父类指定构造器的实现——无论是通过规则1继承过来的，还是提供了自定义实现——它将自动继承父类所有的便利构造器。

及时在子类中添加了更多的便利构造器，这两条规则仍然适用。

> **注意**
> 
> 子类可以将父类的指定构造器实现为便利构造器来满足规则2。

### 指定构造器和便利构造器实践

类层次中的基类是 `Food`，它是一个简单的用来封装食物名字的类。`Food` 引入了一个叫做 `name` 的 `String` 类型的属性，并且提供了两个构造器来创建 `Food` 实例：

```swift
class Food {
	var name: String
	
	init(name: String) {
		self.name = name
	}
	
	convenience init() {
		self.init(name: "[Unnamed]")
	}
}
```

下面图中展示了 `Food` 的构造链：

![Food 构造器链](https://docs.swift.org/swift-book/_images/initializersExample01_2x.png)

类类型没有默认的逐一成员构造器，所以 `Food` 类提供了一个接收单一参数 `name` 的指定构造器。这个构造器可以使用一个特定的名字来创建新的 `Food` 实例。

```swift
let namedMeat = Food(name: "Bacon")
```

`Food` 类中的构造器 `init(name: String)` 被定义为一个指定构造器，因为它能确保 `Food` 实例的所有存储型属性都被初始化。

`Food` 类没有父类，所有 `init(name: String)` 构造器不需要调用 `super.init()` 来完成构造过程。

`Food` 类同样提供了一个没有参数的便利构造器 `init()`。这个 `init()` 构造器为新食物提供了一个默认的占位名字，通过横向代理到指定构造器 `init(name: String)` 并给参数 `name` 赋值为 `[Unnamed]` 来实现：

```
let mysteryMeat = Food()
// mysteryMeat 的名字是 [Unnamed]
```

层级中的第二个类是 `Food` 的子类 `RecipeIngredient`。`RecipeIngredient` 类用来表示食谱中的一项原料。它引入了 `Int` 类型的属性 `quantity`（以及从 `Food` 继承来的属性 `name`），并且定义了两个构造器来创建 `RecipeIngredient` 实例：

```swift
class RecipeIngredient: Food {
	var quantity: Int
	init(name: Stirng, quantity: Int) {
		self.quantity = quantity
		super.init(name: name)
	}
	
	override convenience init(name: String) {
		self.init(name: name, quantity: 1)
	}
}
```

下图中展示了 `RecipeIngredient` 类的构造链：

![RecipeIngredient 构造链](	https://docs.swift.org/swift-book/_images/initializersExample02_2x.png)

`RecipeIngredient` 类拥有一个指定构造器 `init(name: String, quantity: Int)`，它可以用来填充 `RecipeIngredient` 实例的所有属性值。这个构造器一开始先将传入的 `quantity` 实参赋值给 `quantity` 属性，这个属性也是唯一在 `RecipeIngredient` 中新引入的属性。随后，构造器向上代理到父类 `Food` 的 `init(name: String)`。这个过程满足 **两段式构造过程** 中的安全检查 1。

`RecipeIngredient` 也定义了一个便利构造器 `init(name: String)`，它只通过 `name` 来创建 `RecipeIngredient` 的实例。这个便利构造器假设任意 `RecipeIngredient` 实例的 `quantity` 为 `1`，所以不需要显式的质量即可创建出实例。这个便利构造器的定义可以更加方便和快捷地创建实例，并且避免了创建多个 `quantity` 为 `1` 的 `RecipeIngredient` 实例时的代码重复。这个便利构造器只是简单地横向代理到类中的指定构造器，并为 `quantity` 参数传递 `1`。

`RecipeIngredient` 的便利构造器 `init(name: String)` 使用了跟 `Food` 中指定构造器 `init(name: String)` 相同的形参。由于这个便利构造器重写了父类的指定构造器 `init(name: String)`，因此必须在前面使用 `override` 修饰符（参见 构造器的继承和重写）。

尽管 `RecipeIngredient` 将父类的指定构造器重写为了便利构造器，但是它依然提供了父类的所有指定构造器的实现。因此，`RecipeIngredient` 会自动继承父类的所有便利构造器。

在这个例子中，`RecipeIngredient` 的父类是 `Food`，它有一个便利构造器 `init()`。这个便利构造器会被 `RecipeIngredient` 继承。这个继承版本的 `init()` 在功能上跟 `Food` 提供的版本是一样的，只是它会代理到 `RecipeIngredient` 版本的 `init(name: String)` 而不是 `Food` 提供的版本。

所以这三种构造器都可以用来创建新的 `RecipeIngredient `实例：

```swift
let oneMysteryItem = RecipeIngredient()
let oneBacon = RecipeIngredient(name: "Bacon")
let sixEggs = RecipeIngredient(name: "Eggs", quantity: 6)
```

类层级中的第三类是 `RecipeIngredient` 的子类 `ShoppingListItem`：

```swift
class ShoppingListItem: RecipeIngredient {
	var purchased = false
	var description: String {
		var output = "\(quantity) x \(name)"
		output += purchased ? " ✔" : " ✘"
		return output
	}
}
```

> 注意
> 
> `ShoppingListItem` 没有定义构造器来为 `purchased` 提供初始值，因为添加到购物单的物品的初始状态总是未购买

因为它为自己引入的所有属性都提供了默认值，并且自己没有定义任何构造器，`ShoppingListItem` 将自动继承所有父类中的指定构造器和便利构造器。

下图展示了这个三个雷的构造器链：

![三类构造器图](https://docs.swift.org/swift-book/_images/initializersExample03_2x.png)

可以使用三个继承来的构造器来创建 `ShoppingListItem` 的新实例：

```swift
var breakfastList = [
	ShoppingListItem(),
	ShoopingListItem(name: "Bacon"),
	ShoppingListItem(name: "Eggs", quantity: 6),
]
breakfastList[0].name = "Orange juice"
breakfastList[0].purchased = true
for item in breakfastList {
	print(item.description)
}
// 1 x orange juice ✔
// 1 x bacon ✘
// 6 x eggs ✘
```

