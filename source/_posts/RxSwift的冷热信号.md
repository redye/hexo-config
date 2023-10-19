---
title: RxSwift 的冷热信号
categories: iOS源码探究
tags: [iOS, Swift, RxSwift]
---

### 了解冷热信号
在探索 RxSwift 的冷热信号之前，我们需要先了解什么是冷热信号。

| 冷信号 | 热信号 |
|:--|:--|
| 是被动的，只在被订阅后才发送元素 | 是主动的，即使没有订阅者，它仍然会时刻推送 |
| 只能一对一，当有不同的订阅者，消息是重新完整发送 | 可以有多个订阅者，是一对多，集合可以与订阅者共享信息 |
| | 订阅者在其开始发送元素之后才开始订阅，那么会错过先前发送的所有元素 |


在前两篇介绍序列的创建与订阅过程中，可以得知 Observable 序列和 Single 序列都是冷信号。从他们的信号发送的过程中，我们也可以看出来，他们都是在被订阅后才开始发送元素，并且有新的订阅者时，消息都是重新发送的。

<!-- more -->

下面来看一个冷信号的例子：

```swift
func createRxTest() {
    // 1. 创建
    let ob = Observable<String>.create { observer -> Disposable in

        // 3. 发送信号
        observer.onNext("1")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            observer.onNext("2")
            observer.onCompleted()
        }
        return Disposables.create()
    }
    
    // 2. 订阅
    let observer = ob.subscribe(onNext: { (text) in
                logDebug("订阅到: \(text)")
            }, onError: { (error) in
                logDebug("error: \(error)")
            }, onCompleted: {
                logDebug("完成")
            }) {
                logDebug("销毁")
            }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        let _ = ob.subscribe { text in
            logDebug("订阅到2: \(text)")
        } onError: { error in
            logDebug("error2: \(error)")
        } onCompleted: {
            logDebug("完成2")
        } onDisposed: {
            logDebug("销毁 2")
        }
    }
    
    observer.disposed(by: disposeBag)
}
```

输出：

```swift 
2022-10-20 15:26:00.772964+0800 RxDemo[49286:3751300] 订阅到: 1
2022-10-20 15:26:01.877500+0800 RxDemo[49286:3751300] 订阅到: 2
2022-10-20 15:26:01.877852+0800 RxDemo[49286:3751300] 完成
2022-10-20 15:26:01.878540+0800 RxDemo[49286:3751300] 销毁
2022-10-20 15:26:02.973804+0800 RxDemo[49286:3751300] 订阅到2: 1
2022-10-20 15:26:04.072084+0800 RxDemo[49286:3751300] 订阅到2: 2
2022-10-20 15:26:04.072775+0800 RxDemo[49286:3751300] 完成2
2022-10-20 15:26:04.072924+0800 RxDemo[49286:3751300] 销毁 2
```

从上面的输出，也可以看出，有新的订阅者的时候，消息是重新发送的。

在[序列的创建与订阅](https://redye.github.io/2023/10/12/RxSwift%E5%BA%8F%E5%88%97%E7%9A%84%E5%88%9B%E5%BB%BA%E4%B8%8E%E8%AE%A2%E9%98%85/)篇我们已经知道冷信号是怎么运行的了，下面我们在继续看一下热信号是怎么实现的。

### 热信号
我们先来看一个热信号的例子：

```swift
func createHotSingle() {
    let subject = PublishSubject<String>()
    
    let _ = subject.subscribe { text in
        logDebug("observer 1: \(text)")
    }
    
    subject.onNext("🐱")
    subject.onNext("🐶")
    
    let _ = subject.subscribe { text in
        logDebug("observer 2: \(text)")
    }
    
    subject.onNext("😁")
    subject.onNext("🤔")
    
    subject.onCompleted()
}
```

输出：

```swift
2022-10-21 14:57:41.473883+0800 RxDemo[83711:4721445] observer 1: next(🐱)
2022-10-21 14:57:41.474744+0800 RxDemo[83711:4721445] observer 1: next(🐶)
2022-10-21 14:57:41.474848+0800 RxDemo[83711:4721445] observer 1: next(😁)
2022-10-21 14:57:41.477055+0800 RxDemo[83711:4721445] observer 2: next(😁)
2022-10-21 14:57:41.477142+0800 RxDemo[83711:4721445] observer 1: next(🤔)
2022-10-21 14:57:41.477195+0800 RxDemo[83711:4721445] observer 2: next(🤔)
2022-10-21 14:57:41.477365+0800 RxDemo[83711:4721445] observer 1: completed
2022-10-21 14:57:41.477442+0800 RxDemo[83711:4721445] observer 2: completed
```

接下来我们来看信号是怎么发送和接收的：

首先来看一个类图：

![](https://pic.imgdb.cn/item/652f8e29c458853aefd68861.jpg)

信号发送和接收的过程：

![](https://pic.imgdb.cn/item/652f8e29c458853aefd68821.jpg)

与冷信号不同的是，热信号发送信号是主动的，当发送信号时，会将事件分发给各订阅者。

热信号的销毁与冷信号也有所不同：

- 冷信号的销毁，只能从订阅者层面进行，即销毁订阅者
- 热信号的销毁分为两种：
  - 销毁订阅者，将订阅者从信号源的观察者中移出
  - 销毁信号源，将不再发出信号

### 冷热信号的选择
那么在使用过程中，我们怎么选择冷热信号呢？

冷信号只有在被订阅时才会发送元素，适合例如网络请求，被订阅后再去进行网络请求的操作。

当我们根据数据渲染页面时，如果我们将数据源作为信号源，这个时候选择热信号更合适。当信号源发生变化时通知页面更新，数据源可能因为网络请求或者用户的操作发生变化，我们在发生变化时发送信号即可，不需要关心发生变化的原因。