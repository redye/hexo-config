---
title: RxSwift 冷信号转换成热信号
categories: iOS源码探究
tags: [iOS, Swift, RxSwift]
---

Cold Observable 和观察者是一对一的关系，也就是每次产生订阅时，都会是一个新的资料流。而 Hot Observable 和观察者是一对多的关系，也就是每次产生订阅时，都会使用 「同一份资料流」，将 Cold Observable 转换成 Hot Observable 的过程，就是将原来的资料流公用。

<!-- more -->

### multicast

Cold Observable 每次订阅只会对应一个观察者，因此也可以说成将资料播放给唯一的观察者，因此也称为单播，而 multicast 就是将 Observable 变成多播的情况。

在 multicast 内必须指定一个产生 Hot Observable 的工厂方法，也就是建立 Subject、BehaviorSubject 等逻辑。

```swift
func cold2Hot() {
    let ob = Observable<String>.create { observer -> Disposable in

        logDebug("开始发送信号")
        observer.onNext("1")
        
        observer.onNext("2")
        
        observer.onNext("3")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            observer.onNext("4")
        }

        return Disposables.create()
    }.multicast(PublishSubject<String>())
    
    logDebug("add observer 1")
    let _ = ob.subscribe { event in
        logDebug("o1: \(String(describing: event.element))")
    }
    
    logDebug("connect...")
    let _ = ob.connect()

    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        logDebug("add observer 2")
        let _ = ob.subscribe { event in
            logDebug("o2: \(String(describing: event.element))")
        }
    }
    
    logDebug("add observer 3")
    let _ = ob.subscribe { event in
        logDebug("o3: \(String(describing: event.element))")
    }
}
```

```swift
2022-10-21 16:49:22.050847+0800 RxDemo[87512:4847046] add observer 1
2022-10-21 16:49:22.052584+0800 RxDemo[87512:4847046] connect...
2022-10-21 16:49:22.054300+0800 RxDemo[87512:4847046] 开始发送信号
2022-10-21 16:49:22.058999+0800 RxDemo[87512:4847046] o1: Optional("1")
2022-10-21 16:49:22.059369+0800 RxDemo[87512:4847046] o1: Optional("2")
2022-10-21 16:49:22.059418+0800 RxDemo[87512:4847046] o1: Optional("3")
2022-10-21 16:49:22.061188+0800 RxDemo[87512:4847046] add observer 3
2022-10-21 16:49:22.610973+0800 RxDemo[87512:4847046] add observer 2
2022-10-21 16:49:23.161118+0800 RxDemo[87512:4847046] o1: Optional("4")
2022-10-21 16:49:23.168742+0800 RxDemo[87512:4847046] o3: Optional("4")
2022-10-21 16:49:23.168950+0800 RxDemo[87512:4847046] o2: Optional("4")
```

当使用 multicast 时，新的 Observable 是一个 `ConnectableObservable`，和一般的 Observable 的差别在于 ConnectableObservable 是多播的，而且必须调用 connect 方法，才会开始进行多播操作。

看上面的例子，也可看出只有在 connect 后才开始发送信号。

![](https://pic.imgdb.cn/item/652f8f28c458853aefd919c1.jpg)

转换过程：

![](https://pic.imgdb.cn/item/652f8f28c458853aefd91950.jpg)


### shareReplay

```swift
public func share(replay: Int = 0, scope: SubjectLifetimeScope = .whileConnected) -> Observable<Element> {
    switch scope {
    case .forever:
        switch replay {
        case 0: return self.multicast(PublishSubject()).refCount()
        default: return self.multicast(ReplaySubject.create(bufferSize: replay)).refCount()
        }
    case .whileConnected:
        switch replay {
        case 0: return ShareWhileConnected(source: self.asObservable())
        case 1: return ShareReplay1WhileConnected(source: self.asObservable())
        default: return self.multicast(makeSubject: { ReplaySubject.create(bufferSize: replay) }).refCount()
        }
    }
}
```

shareReplay 的返回值是一个 `Observable<Element>，那么他转换成的热信号，就存在冷信号的特点 -- 只有在被订阅后才开始发送信号。

但同时，他已经转换成了热信号，那么他就也有热信号的特点：当有新的订阅者时，并不会从头开始发送信号 -- 只有在被第一次订阅时，从头开始发送信号，新的订阅者只能接收到在其订阅后发送的信号。

scope == .forever 时实现的核心逻辑在 RefCountSink 的 run 方法中：

```swift
// 只有当第一次被订阅时
if self.parent.count == 0 {
    self.parent.count = 1
    // 执行 connect，开发发送信号
    self.parent.connectableSubscription = self.parent.source.connect()
}
else {
    self.parent.count += 1
}
```

当 scope == .whileConnected 时，replay 的次数为 0 或 1 时做了特殊处理，但是他们发送信号的处理逻辑是一样的：在 ShareWhileConnected 或者 ShareReplay1WhileConnected 的 subscribe 方法中：

```swift
override func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
    self.lock.lock()
    let connection = self.synchronized_subscribe(observer)
    let count = connection.observers.count

    let disposable = connection.synchronized_subscribe(observer)
    self.lock.unlock()
    
    // 只有第一次被订阅时 connect，开始发送信号
    if count == 0 {
        connection.connect()
    }

    return disposable
}
```

### publish 与 replay 

publish 与 replay 都是对multicast 的封装，使用了不同的热信号类型进行转换。

```swift
public func publish() -> ConnectableObservable<Element> {
    self.multicast { PublishSubject() }
}

public func replay(_ bufferSize: Int) -> ConnectableObservable<Element> {
    self.multicast { ReplaySubject.create(bufferSize: bufferSize) }
}
```