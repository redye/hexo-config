---
title: Single 序列的创建与订阅
categories: iOS源码探究
tags: [iOS, Swift, RxSwift]
---

创建一个简单的 single 序列：

```swift
func createSingleTest() {
    let single = Single<String>.create { single -> Disposable in
        single(.success("1"))
        
        return Disposables.create()
    }
    
    let _ = single.subscribe { text in
        print("订阅到: \(text)")
    } onFailure: { error in
        print("失败")
    } onDisposed: {
        print("销毁")
    }
}
```

<!-- more -->

首先看一个别名定义，所以一个 Single 序列即一个 PrimitiveSequence：

```swift
public enum SingleTrait { }
public typealias Single<Element> = PrimitiveSequence<SingleTrait, Element>
```

![](https://pic.imgdb.cn/item/652f8ca3c458853aefd27369.jpg)

![序列创建于订阅](https://pic.imgdb.cn/item/652f8ca3c458853aefd27402.jpg)

与 Observable 唯一不同的地方在于，当接收到一个成功或失败信号后，序列就会被回收。即只发出一个元素或者产生一个 error 事件，不能发出 complete 事件。