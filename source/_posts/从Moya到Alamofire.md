---
title: 从 Moya 到 Alamofire
categories: iOS源码探究
tags: [iOS, Swift, Moya, Alamofire]
---

如今 `Moya + Alamofire` 可以说是 `Swift` 工程必备框架了，今天我们就来聊聊是怎么通过 `Moya` 发起 `Alamofire` 请求的。

### 从 Moya 到 Alamofire

#### Moya 网络请求与响应
Moya 通过 MoyaProvider 这个类来完成网络请求与响应。MoyaProvider 初始化方法：

```swift
/// Initializes a provider.
public init(endpointClosure: @escaping EndpointClosure = MoyaProvider.defaultEndpointMapping,
            requestClosure: @escaping RequestClosure = MoyaProvider.defaultRequestMapping,
            stubClosure: @escaping StubClosure = MoyaProvider.neverStub,
            callbackQueue: DispatchQueue? = nil,
            session: Session = MoyaProvider<Target>.defaultAlamofireSession(),
            plugins: [PluginType] = [],
            trackInflights: Bool = false) {

    self.endpointClosure = endpointClosure
    self.requestClosure = requestClosure
    self.stubClosure = stubClosure
    self.session = session
    self.plugins = plugins
    self.trackInflights = trackInflights
    self.callbackQueue = callbackQueue
}
```

这里看一下这几个参数：

* endpointClosure

	* 负责把 Target 转换成 Endpoint。
	* 默认转换方式： defaultEndpointMapping。
	* endpoin 携带了 request 需要的信息，包括 url、mehod、task(任务类型)、http header（请求头信息）、sampleResponseClosure（样本数据，数据由 Target 提供），并且提供方法修改任务类型和添加更多的请求头信息。提供生成 request 的方法。
	
	```swift
	static func endpointsClosure<T>() -> (T) -> Endpoint where T: TargetType {
	    return { target in
	        let endpoint = MoyaProvider.defaultEndpointMapping(for: target)
	        // 可以在这里添加请求头信息等
	        // endpoint.add(httpHeaderFields: ["auth": "..."])
	        return endpoint
	    }
	}
	```

* requestClosure

	* 负责把 endpoint 转换成 Request。
	* 默认转换方式： defaultRequestMapping。

* stubClosure
  	* .never 从网络请求数据，即进行真正的网络请求
  	* 本地提供样本数据，可以模拟及时和延时两种方式
  
* callbackQueue
回调队列，如果为 nil 的话，就是用 alamofire 的默认队列

* session
	
	* 实际请求的 alamofire 的 session。
	* 提供默认参数 defaultAlamofireSession。

- plugins: 一组插件，用于日志记录、网络活动指示器或凭据。
	
- trackInflights
  	* 防止重复请求
	
		```swift
		if trackInflights {
		    // inflightRequests 是一个计算属性，返回 internalInflightRequests
		    var inflightCompletionBlocks = self.inflightRequests[endpoint]
		    inflightCompletionBlocks?.append(pluginsWithCompletion)
		    self.internalInflightRequests[endpoint] = inflightCompletionBlocks
		    // 当前 endPoint 已经存在，则直接返回这个请求
		    if inflightCompletionBlocks != nil {
		        return cancellableToken
		    } else {
		        self.internalInflightRequests[endpoint] = [pluginsWithCompletion]
		    }
		}
		```

  	* 追踪记录
  
  		```swift
  		let networkCompletion: Moya.Completion = { result in
		  if self.trackInflights {
		    self.inflightRequests[endpoint]?.forEach { $0(result) }
		    self.internalInflightRequests.removeValue(forKey: endpoint)
		  } else {
		    pluginsWithCompletion(result)
		  }
		}
  		```

Provider 创建完成后，就可以发起请求了：

```swift
extension MoyaProviderType {
    func startRequest(_ target: Target, callbackQueue: DispatchQueue? = nil, progress: Moya.ProgressBlock? = nil) {
        self.request(token, callbackQueue: callbackQueue, progress: progress) { result in
             // 这里针对 response 做一些统一处理：例如根据 code 判断接口是否成功
             ...  
        }
    }
}
```

总的来说，Moya 就是在 Alamofire 的基础上再封装了一层。让我们能够更直观的看到我们的请求，也能更简单的编写单元测试。

来一张官方解释图：

![diagram.png](https://s2.loli.net/2022/09/29/xh3AVKDz5amrUcO.png)


#### Moya 的插件功能
Moya 提供插件功能，插件必须实现 PluginType 协议。协议提供了四个方法，并且都提供了默认实现：

```swift
public protocol PluginType {
    /// Called to modify a request before sending.
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest
 
    /// Called immediately before a request is sent over the network (or stubbed).
    func willSend(_ request: RequestType, target: TargetType)
 
    /// Called after a response has been received, but before the MoyaProvider has invoked its completion handler.
    func didReceive(_ result: Result<Moya.Response, MoyaError>, target: TargetType)
 
    /// Called to modify a result before completion.
    func process(_ result: Result<Moya.Response, MoyaError>, target: TargetType) -> Result<Moya.Response, MoyaError>
}
```

插件的意义在于：无论发送或接收请求，Moya 插件都会接收回调以执行副作用。

Moya 内置了一些插件 AccessTokenPlugin、CredentialsPlugin、NetworkActivityPlugin、NetworkLoggerPlugin

使用过程：在创建 Alamofire Request 时，创建一个拦截器 MoyaRequestInterceptor，绑定到 request 上。请求过程中通过拦截器执行插件的 prepare 和 willSend 方法，请求完成时通过回调执行 didReceive 和 process 方法。

执行顺序为：prepare -> willSend -> didReceive -> process

#### 从 target 转换到 request 的过程：

![UML 图.jpg](https://s2.loli.net/2022/09/29/XP6GRmWvNAJwZC2.jpg)

#### Moya 发送请求流程图

![moya.jpg](https://s2.loli.net/2022/09/29/sGIzRvEhpSCQY7O.jpg)

### Alamofire

#### 拦截器
Alamofire 的拦截器，实现 RequestInterceptor 协议，RequestInterceptor 继承 RequestAdapt 和 RequestRetrier：

* RequestAdapt：检查并在必要时以某种方式地调整“URLRequest”，对请求进行适配。
* RequestRetrier：用于确定请求在被指定的会话管理器执行并遇到错误后是否应重试

所以实现拦截器时，需要实现这两个协议的方法。

在使用拦截器的有两种方式：

* 在创建 DataRequest 的时候给 request 绑定拦截器。例如 moya 的插件就是通过这种方式实现的
* 以 session 拦截器的方式，即在初始化 session 的时候绑定。

拦截器的执行也分两种方式：

* 在接口创建完成时执行，会结合 Request 的拦截器和 Session 上的拦截器，依次调用（先执行 request 绑定的拦截器）。执行 RequestAdapt 协议的部分。

	```swift
	private func adapt(_ urlRequest: URLRequest,
                   using state: RequestAdapterState,
                   adapters: [RequestAdapter],
                   completion: @escaping (Result<URLRequest, Error>) -> Void) {
	    var pendingAdapters = adapters
	
	    // 当前已经没有适配器了，则调用成功回调，结束本地递归
	    guard !pendingAdapters.isEmpty else { completion(.success(urlRequest)); return }
	
	    let adapter = pendingAdapters.removeFirst()
	
	    adapter.adapt(urlRequest, using: state) { result in
	        switch result {
	        case let .success(urlRequest):
	            // 递归调用，直至所有适配器都执行完成
	            self.adapt(urlRequest, using: state, adapters: pendingAdapters, completion: completion)
	        case .failure:
	            // 只要有一个适配器发生错误，则调用失败回调，结束本次递归
	            completion(result)
	        }
	    }
	}
	```
* 在接口请求完成并且发生错误的时候执行，同样也会结合 Request 和 Session 的拦截器，依次调用。这里主要执行的是 RequestRetrier 协议的方法。

	```swift
	private func retry(_ request: Request,
                   for session: Session,
                   dueTo error: Error,
                   using retriers: [RequestRetrier],
                   completion: @escaping (RetryResult) -> Void) {
	    var pendingRetriers = retriers
	
	    // 当前没有重试器了，则调用不重试回调，结束本次递归
	    guard !pendingRetriers.isEmpty else { completion(.doNotRetry); return }
	
	    let retrier = pendingRetriers.removeFirst()
	
	    retrier.retry(request, for: session, dueTo: error) { result in
	        switch result {
	        case .retry, .retryWithDelay, .doNotRetryWithError:
	            // 当决定重试，或者发生多无时，均不在继续下一个重试器，结束本地递归
	            completion(result)
	        case .doNotRetry:
	            // 当不重试且没有错误发生时继续执行下一个重试器
	            self.retry(request, for: session, dueTo: error, using: pendingRetriers, completion: completion)
	        }
	    }
	}
	```
	
#### 事件监视器

Session 在初始化的时候，可以传入一组 eventMonitors。Session 内部还提供了一组默认的 defaultEventMonitors， 然后将这一组 eventMonitors 和默认提供的 defaultEventMonitors  合成成一个 CompositeEventMonitor，统一处理。

事件监视器们都需要实现 EventMonitor 协议。监听请求发起到结束这段时间内的各种回调以及状态变化。

Alamofire 内部提供并实现了一个 AlamofireNotifications 的监视器，通过通知将 request 的各个阶段抛出。

```swift
public final class AlamofireNotifications: EventMonitor {
    public func requestDidResume(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didResumeNotification, with: request)
    }
 
    public func requestDidSuspend(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didSuspendNotification, with: request)
    }
 
    public func requestDidCancel(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didCancelNotification, with: request)
    }
 
    public func requestDidFinish(_ request: Request) {
        NotificationCenter.default.postNotification(named: Request.didFinishNotification, with: request)
    }
 
    public func request(_ request: Request, didResumeTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didResumeTaskNotification, with: request)
    }
 
    public func request(_ request: Request, didSuspendTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didSuspendTaskNotification, with: request)
    }
 
    public func request(_ request: Request, didCancelTask task: URLSessionTask) {
        NotificationCenter.default.postNotification(named: Request.didCancelTaskNotification, with: request)
    }
 
    public func request(_ request: Request, didCompleteTask task: URLSessionTask, with error: AFError?) {
        NotificationCenter.default.postNotification(named: Request.didCompleteTaskNotification, with: request)
    }
}
```

#### Alamofire 失败认定

请求失败认定分为两个过程：

1. 在本次 session 任务过程中发生错误，由客户端一侧造成的原因，例如无法解析主机(域名或者路径错误)或者网络原因导致链接不上等。

	```swift
	// session 代理方法
	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
	```
2. 在任务过程中，没有发生错误并且成功拿到接口响应时，对 response 进行验证，验证方法有两种：
  
  	* 对状态码进行验证：只有在指定的 http 状态码范围内，才算成功，否则返回一个状态码错误
  	* 对返回的数据类型进行验证：数据为空时返回成功；当返回数据不为空时，验证 response 的 contentType

3. 当请求认定为失败时，会继续重试逻辑。

#### Alamofire 的重试流程

重试流程分为两个阶段：

1. 当请求认定为失败时，询问是否进行重试流程。
	* 没有拦截器时不重试
  	* 询问拦截器重试策略：
    	* doNotRetry， doNotRetryWithError 不重试
    	* retry 或 retryWithDelay 重试

2. 开始重试流程
  1. 重试前的准备工作：记录重试次数 -> 重置所有与任务和响应序列化程序相关的状态 -> 响应数据清空 -> 事件监听器分发状态
  2. 执行请求

#### Alamofire 主流程

![alamofire.jpg](https://s2.loli.net/2022/09/29/RxWKpjvnt4SrAX3.jpg)

### 代码阅读

#### dispatchPrecondition

用于在当前执行上下文中进行断言，用于验证一个闭包是否在预期的队列中被执行

```swift
func performDataStreamRequest(_ request: DataStreamRequest) {
    // dispatchPrecondition： 检查当前线程是否你希望的线程
    dispatchPrecondition(condition: .onQueue(requestQueue))
 
    performSetupOperations(for: request, convertible: request.convertible)
}
```

#### 队列调度与 targetQueue

以下代码，为什么会保证 `setup` 在 `performSetupOperations` 之前执行（这里保证能够执行到Moya 插件的 prepare 和 willSend 回调）。

```swift
let initialRequest: DataRequest = session.requestQueue.sync {
    // 在创建 request 时，会在 requestQueue 异步执行 performSetupOperations
    let initialRequest = session.request(request, interceptor: interceptor)
    setup(interceptor: interceptor, with: target, and: initialRequest)

    return initialRequest
}
```

原因在于 sesstion 初始化时，创建的队列：

rootQueue 是串行队列，负责所有内部回调和状态更新。

requestQueue 用来异步创建 request，默认情况下是以 rootQueue 为 target 的队列。

```swift
// Retarget the incoming rootQueue for safety, unless it's the main queue, which we know is safe.
let serialRootQueue = (rootQueue === DispatchQueue.main) ? rootQueue : DispatchQueue(label: rootQueue.label,
                                                                                     target: rootQueue) 
self.requestQueue = requestQueue ?? DispatchQueue(label: "\(rootQueue.label).requestQueue", target: rootQueue)
```

```swift
public convenience init(label: String, qos: DispatchQoS = .unspecified, 
    attributes: DispatchQueue.Attributes = [], 
    autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency = .inherit, 
    target: DispatchQueue? = nil)
```

requestQueue 是以 rootQueue 为 targetQueue 的串行队列。

设置队列的 targetQueue，向队列提交的任务，都会被放到它的目标队列来执行。串行队列的 targetQueue 是一个支持 overcommit 的全局队列，而全局队列的底层则是一个线程池[【深入浅出 GCD】](https://xiaozhuanlan.com/topic/7193856240)。

你创建的任何队列都包含一个目标队列。默认情况下，这些队列的目标队列是优先级为`DISPATCH_QUEUE_PRIORITY_DEFAULT `的全局队列。

自定义队列里每一个准备好要执行的block，将会被重新加入到这个队列的目标队列里去执行。

> 因为所有自己创建的队列（包括串行队列）都会把默认优先级的全局并发队列当做目标队列，全局并发队列不会被阻塞，等待工作都是在提交的队列中的，一旦轮到执行，就会被提交到目标队列中，并立刻开始执行。所以除非是你自定义目标队列，否则你完全可以抽象的认为任务就是在你提交的队列中开始执行的。

> 只有全局并发队列和主队列才能执行block。所有其他的队列都必须以这两种队列中的一种为目标队列。

指定一个串行队列作为目标队列，其实核心思想就是说，不管有多少独立的线程在竞争资源，同一时刻我们只做一件事[【GCD Target Queues】](https://www.jianshu.com/p/bd2609cac26b)。

下图是队列示意图，由此图，requestQueue 队列的任务最终会放到 Default Priority Queue 的队列执行。

![queue-target.png](https://s2.loli.net/2022/09/29/V2Po5hjAueyU8KR.png)