---
title: RxSwift 序列的创建与订阅
categories: iOS源码探究
tags: [iOS, Swift, RxSwift]
---

创建一个最简单的序列：

```swift
func createRxTest() {
    // 1. 创建
    let ob = Observable<String>.create { observer -> Disposable in
        
        // 3. 发送信号
        observer.onNext("1")
        observer.onCompleted()
        
        return Disposables.create()
    }

    // 2. 订阅
    let _ = ob.subscribe(onNext: { (text) in
                print("订阅到: \(text)")
            }, onError: { (error) in
                print("error: \(error)")
            }, onCompleted: {
                print("完成")
            }) {
                print("销毁")
            }
}
```

首先来看几个类与接口之间的关系图：

![](https://pic.imgdb.cn/item/652f8b57c458853aefcf18b6.jpg)

从创建序列到订阅序列流程图：

![](https://pic.imgdb.cn/item/652f8bb6c458853aefd01443.jpg)

1. 创建序列时，真正创建的是一个 AnonymousObservable 对象 A，如果不订阅这个序列，在作用域内不会被执行
2. 订阅对象时，创建一个 AnonymousObserver 对象 B，然后开始执行序列 A
3. 执行 A 时，会创建一个 Sink 对象，即管道。将订阅者和被订阅者连接起来，监听到 A 的事件，然后将事件 forward 给 B

由上图能够看出，序列只有被订阅的时候，才会被真正的执行。