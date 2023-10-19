---
title: RxSwift 序列的销毁
categories: iOS源码探究
tags: [iOS, Swift, RxSwift]
---

### 序列销毁的两种方式

在前两篇我们注意到，我们在创建一个序列（不论是 Observable 还是 Single 序列）的实现时，都需要返回一个 `Disposable` 实例。我们已 Observable 序列为例：

<!-- more -->

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
        
        // 返回一个 Disposables 实例
        return Disposables.create()
    }

    // 2. 订阅
    let observer = ob.subscribe(onNext: { (text) in
                print("订阅到: \(text)")
            }, onError: { (error) in
                print("error: \(error)")
            }, onCompleted: {
                print("完成")
            }) {
                print("销毁")
            }
            
    observer.dispose()
}
```

![](https://pic.imgdb.cn/item/652f910bc458853aefde1927.png)

![](https://pic.imgdb.cn/item/652f910cc458853aefde1a06.png)

观察上面两幅图，序列销毁有两种方式：

1. 发送一个 completed 或者 一个 error 信号，这种可以看成是事件正常结束或者发生异常
2. 调用 dispose 主动销毁，在销毁后事件发送的信号将不会在接收

接下来我们再继续看序列在事件发送信号的过程中做了哪些操作，或者主动销毁又是怎么操作的。

首先下面是一个类图：

![](https://pic.imgdb.cn/item/652f9183c458853aefdf42ec.jpg)

Disposables 是一个工厂类，根据不同的需要创建对应的 disposable，在序列发出完成或者产生错误时，销毁

```swift
extension Disposables {
 
    /// Creates a disposable with the given disposables.
    public static func create(_ disposable1: Disposable, _ disposable2: Disposable) -> Cancelable {
        BinaryDisposable(disposable1, disposable2)
    }
}

extension Disposables {
 
    /// Constructs a new disposable with the given action used for disposal.
    ///
    /// - parameter dispose: Disposal action which will be run upon calling `dispose`.
    public static func create(with dispose: @escaping () -> Void) -> Cancelable {
        AnonymousDisposable(disposeAction: dispose)
    }
}
```

### 序列发送 error 事件或者 completed 事件

![](https://pic.imgdb.cn/item/652f91d7c458853aefe0230a.jpg)

```swift
func on(_ event: Event<Element>) {
    #if DEBUG
        self.synchronizationTracker.register(synchronizationErrorMessage: .default)
        defer { self.synchronizationTracker.unregister() }
    #endif
    switch event {
    case .next:
        // 接收到 next 事件，首先判断当前序列状态，已停止则不在进行事件转发
        if load(self.isStopped) == 1 {
            return
        }
        self.forwardOn(event)
    case .error, .completed:
        // 当接收到是 error 或 completed 事件，查询并修改状态
        // 注意这里的 isStoped，他是一个 AtomicInt 类型
        // AtomicInt 是一个类，fetchOr 返回原值，并赋新值
        // 在 RxSwift 中，AtomicInt 有大量应用
        if fetchOr(self.isStopped, 1) == 0 {
            self.forwardOn(event)
            self.dispose()
        }
    }
}
```

通过发送 .error 或者 .completed 事件结束序列，核心的处理方法就是在 AnonymousObservableSink 的 on 方法里，如果是这两个事件，在执行完成后就堵住这个管道，后序如果在接收到事件，就不在进行转发了。

在 dispose 方法里，更新 disposed 值，并销毁 sink 和 创建序列时的 subscribtion，即改变他们 disposed 状态。

### 调用 dispose 方法销毁序列

![](https://pic.imgdb.cn/item/652f921fc458853aefe0dfe8.jpg)

Dispose 方法改变的是 disposed 的状态，在事件转发过程中，会判断当前是否被销毁：

```swift
final func forwardOn(_ event: Event<Observer.Element>) {
    #if DEBUG
        self.synchronizationTracker.register(synchronizationErrorMessage: .default)
        defer { self.synchronizationTracker.unregister() }
    #endif
    // 判断当前状态，若已销毁则不在继续转发事件
    if isFlagSet(self.disposed, 1) {
        return
    }
    self.observer.on(event)
}
```

### DisposedBag

Dispose 还有另外一种使用方法：

![](https://pic.imgdb.cn/item/652f9617c458853aefeb93d4.png)

![](https://pic.imgdb.cn/item/652f9618c458853aefeb9526.png)

观察上面两幅图，导致这种结果的原因在于 disposeBag 的作用域。当 disposeBag 被释放时，销毁序列。

这一点从 DisposeBag 的实现中也可以看出来：

```swift
extension Disposable {
    /// 1. 将序列加入到回收袋
    public func disposed(by bag: DisposeBag) {
        bag.insert(self)
    }
}

public final class DisposeBag: DisposeBase {
    
    private var lock = SpinLock()
    // state
    private var disposables = [Disposable]()
    private var isDisposed = false
    
    /// Constructs new empty dispose bag.
    public override init() {
        super.init()
    }
 
    /// 2. 当回收袋将要释放时销毁序列
    public func insert(_ disposable: Disposable) {
        self._insert(disposable)?.dispose()
    }
    
    
    private func _insert(_ disposable: Disposable) -> Disposable? {
        self.lock.performLocked {
            /// 当前回收袋已经被回收，则直接回收序列
            if self.isDisposed {
                return disposable
            }
            /// 存储序列
            self.disposables.append(disposable)
 
            return nil
        }
    }
 
    /// 4. 销毁这个回收袋里的所有可回收序列
    private func dispose() {
        let oldDisposables = self._dispose()
 
        for disposable in oldDisposables {
            disposable.dispose()
        }
    }
 
    private func _dispose() -> [Disposable] {
        self.lock.performLocked {
            let disposables = self.disposables
            
            self.disposables.removeAll(keepingCapacity: false)
            self.isDisposed = true
            
            return disposables
        }
    }
    
    /// 3. 对象被释放时，开始销毁序列
    deinit {
        self.dispose()
    }
}
```

一般情况下，我们都需要使用 disposeBag，我们不希望序列被立即销毁。想象一下，我们在一个页面中发出请求序列，我们希望拿到 response 时在去处理。但当页面被释放的时候，我们需要销毁队列（否则有可能会造成内存泄露等问题），这个时候我们就可以让 controller 持有这个 bag，controller 被释放的时候释放 bag，从而销毁序列。

### 总结

从代码层面可以看出来，销毁序列都是通过阻断事件转发来实现的，即订阅者不再继续接收事件。即对于被订阅者来说，还是可以继续发送事件，只是没有接收对象了。