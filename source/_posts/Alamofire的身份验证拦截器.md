---
title: Alamofire 的身份验证拦截器
categories: Almofire 
tags: [iOS, Swift]
---

Alamofire 提供了一个身份验证的拦截器 `AuthenticationInterceptor`。

<!-- more -->

### 身份验证拦截器使用的正确方式

#### 凭证，自定义刷新策略

```swift
struct TokenModel: HandyJson {
    var accessToken: String?
    var refreshToken: String?
    var expiresAt: Date?
}

extension TokenModel: AuthenticationCredential {
    var requiresRefresh: Bool {
        // 还有5分钟失效
        let willExpires = Date(timeIntervalSinceNow: 60 * 5) > expiresAt
        return willExpires       
    }
}
```

#### 授权中心，凭证应用与刷新

```swift
class SMAuthenticator: Authenticator {
    func apply(_ credential: Credential, to urlRequest: inout URLRequest) {
        // 一般都是将凭证放到请求头, 这里也可以使用自定义的 header 头，
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
    }
    
    func refresh(_ credential: Credential, for session: Session, completion: @escaping (Result<Credential, Error>) -> Void) {
        // 凭证刷新逻辑, 在 OAuth2 体系中，可以使用 refreshToken 去刷新凭证
        if true {
            completion(Credential)
        } else {
            completion(Error)
        }
    }
    
    func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: Error) -> Bool {
        // 判断接口失败是否鉴权问题
        return response.statusCode == 401
    }
    
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool {
        // 判断接口是否认证了凭证,
        // 这里的 baereToken 也可以是上面自定义的 header 名称，保持一致即可
        let baereToken = HTTPHeader.authorization(bearerToken: credential.accessToken)
        let requestToken = urlRequest.headers["Authorization"]
        return requestToken == baereToken
    }
}
```

#### 初始化 Session 的时候添加拦截器

```swift
private func customSessionConfiguration() -> Session {
    // 凭证可以根据业务来，例如用户中心持久化的 accessToken
    let credential = TokenModel()
    let authentor = SMAuthenticator()
    // 默认刷新窗口时长为 30s, 最大次数为 5 次
    let authIntetception = AuthenticationInterceptor(authenticator: authentor, refreshWindow: RefreshWindow())
    let interception = Interceptor(adapters: [], retriers: [], interceptors: [authIntetception])
    let configuration = URLSessionConfiguration.default
    configuration.headers = .default
    let session = Session(
        configuration: configuration,
        startRequestsImmediately: false,
        interceptor: interception)
    return session
}
```

### 拦截器的两个方法

1. adapt：在发送请求前拦截，对请求适配处理，如果处理成功，则返回一个新的请求继续执行，处理失败，则抛出错误，取消请求。拦截器会在这个方法中应用凭证或进行刷新操作。

2. retry：在请求发生失败时，返回重试策略给到 session 重新发送请求。拦截器会在该方法中对失败云因进行判断是否是因凭证失败导致。必要时会对凭证进行刷新。

下面是整个 `AuthenticationInterceptor` 的实现：

```swift
public protocol AuthenticationCredential {
    /// 决定当前凭证是否需要刷新。当凭证已过期或将要过期时返回 true
    /// 例如当凭证还有5分钟即将过期时，进行凭证刷新，可以保证后端服务凭证不会过期
    var requiresRefresh: Bool { get }
}
public protocol Authenticator: AnyObject {
    // 关联类型，凭证需要实现 AuthenticationCredential 类型的对象
    associatedtype Credential: AuthenticationCredential
 
    /// 应用凭证: 将 access token 添加到请求头
    func apply(_ credential: Credential, to urlRequest: inout URLRequest)
 
    /// 刷新凭证，当刷新完成后执行回调。这个方法可能由 requiresRefresh 返回 true 触发，也可能应为请求因为鉴权失败触发
    /// 当刷新接口请求完成时，返回一个新的凭证或者错误
    /// 通常，当刷新失败并返回鉴权服务特定的状态码(一般是 401)，应该让用户重新登录
    /// 注意这只是一般情况，还是需要结合团队的服务具体指定自己的认证流程
    func refresh(_ credential: Credential, for session: Session, completion: @escaping (Result<Credential, Error>) -> Void)
 
    /// 判断是否鉴权造成请求失败
    /// OAuth2 体系中，http 状态码 401 表示鉴权失败
    /// 重要的是你要理解你们自己团队的鉴权流程，确保正确授权不会循环刷新
    /// 返回 true 表示服务失败是因为鉴权
    func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: Error) -> Bool
 
    /// 请求是否认证了凭证
    /// 在 OAuth2 体系中，请求头 header 的 Bearer token 与凭证的 accessToken 匹配表示已认证
    /// 返回 true 表示该请求使用了该凭证
    func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: Credential) -> Bool
}

public enum AuthenticationError: Error {
    /// 凭证缺失
    case missingCredential
    /// 凭证在一个刷新窗口中刷新太多次
    case excessiveRefresh
}
public class AuthenticationInterceptor<AuthenticatorType>: RequestInterceptor where AuthenticatorType: Authenticator {

    public typealias Credential = AuthenticatorType.Credential
 
    /// 刷新窗口，可以在一个刷新窗口内最多可重试的次数
    public struct RefreshWindow {
        /// 刷新窗口的时长
        public let interval: TimeInterval
 
        /// 一个刷新窗口内最多可重试的次数
        public let maximumAttempts: Int
 
        public init(interval: TimeInterval = 30.0, maximumAttempts: Int = 5) {
            self.interval = interval
            self.maximumAttempts = maximumAttempts
        }
    }
 
    /// 适配操作对象，用来缓存请求的适配操作
    private struct AdaptOperation {
        let urlRequest: URLRequest
        let session: Session
        let completion: (Result<URLRequest, Error>) -> Void
    }
    /// 适配结果
    private enum AdaptResult {
        // 立即适配
        case adapt(Credential)
        // 不适配，并返回错误
        case doNotAdapt(AuthenticationError)
        // 适配延时
        case adaptDeferred
    }
    /// 用来记录请求的状态，刷新状态，保存适配延时适配的操作和重试处理
    private struct MutableState {
        var credential: Credential?
 
        var isRefreshing = false
        var refreshTimestamps: [TimeInterval] = []
        var refreshWindow: RefreshWindow?
 
        var adaptOperations: [AdaptOperation] = []
        var requestsToRetry: [(RetryResult) -> Void] = []
    }
    // 记录凭证
    public var credential: Credential? {
        get { $mutableState.credential }
        set { $mutableState.credential = newValue }
    }
 
    let authenticator: AuthenticatorType
    let queue = DispatchQueue(label: "org.alamofire.authentication.inspector")
 
    @Protected
    private var mutableState: MutableState
 
    public init(authenticator: AuthenticatorType,
                credential: Credential? = nil,
                refreshWindow: RefreshWindow? = RefreshWindow()) {
        self.authenticator = authenticator
        mutableState = MutableState(credential: credential, refreshWindow: refreshWindow)
    }

    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        // 适配处理
        let adaptResult: AdaptResult = $mutableState.write { mutableState in
            // 检查是否正在刷新
            guard !mutableState.isRefreshing else {
                // 当前正在刷新时，先暂存适配逻辑，等待刷新完成后再继续执行
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                return .adaptDeferred
            }
 
            // 检查是否缺失凭证
            guard let credential = mutableState.credential else {
                // 凭证缺失，适配失败
                let error = AuthenticationError.missingCredential
                return .doNotAdapt(error)
            }
 
            // 检查凭证是否过期
            guard !credential.requiresRefresh else {
                // 凭证已过期，暂存适配逻辑，开始刷新凭证
                let operation = AdaptOperation(urlRequest: urlRequest, session: session, completion: completion)
                mutableState.adaptOperations.append(operation)
                refresh(credential, for: session, insideLock: &mutableState)
                return .adaptDeferred
            }
            // 正常适配凭证
            return .adapt(credential)
        }
 
        switch adaptResult {
        case let .adapt(credential):
            // 适配凭证，将凭证应用到请求上
            var authenticatedRequest = urlRequest
            authenticator.apply(credential, to: &authenticatedRequest)
            // 适配成功，返回适配后的请求
            completion(.success(authenticatedRequest))
 
        case let .doNotAdapt(adaptError):
            // 适配失败，返回错误，结束请求
            completion(.failure(adaptError))
 
        case .adaptDeferred:
            // 正在适配过程中，不做处理
            break
        }
    }
 
    public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // 没有请求和返回时不重试
        guard let urlRequest = request.request, let response = request.response else {
            completion(.doNotRetry)
            return
        }
 
        // 检查是否凭证认证失败，如果不是则不重试（例如状态码为 401）
        guard authenticator.didRequest(urlRequest, with: response, failDueToAuthenticationError: error) else {
            completion(.doNotRetry)
            return
        }
 
        // 检查是否缺失凭证，凭证缺失不重试，返回错误
        guard let credential = credential else {
            let error = AuthenticationError.missingCredential
            completion(.doNotRetryWithError(error))
            return
        }
 
        // 检查当前凭证是否被认证，没有被认证则直接重试
        guard authenticator.isRequest(urlRequest, authenticatedWith: credential) else {
            completion(.retry)
            return
        }
        
        $mutableState.write { mutableState in
            // 暂存重试完成处理逻辑，防止多个请求同时触发调用多次刷新
            mutableState.requestsToRetry.append(completion)
            // 当前正在刷新
            guard !mutableState.isRefreshing else { return }
            // 刷新凭证
            refresh(credential, for: session, insideLock: &mutableState)
        }
    }
 
    private func refresh(_ credential: Credential, for session: Session, insideLock mutableState: inout MutableState) {
        // 判断是否已刷新超阈值
        guard !isRefreshExcessive(insideLock: &mutableState) else {
            // 已超阈值，则失败处理
            let error = AuthenticationError.excessiveRefresh
            handleRefreshFailure(error, insideLock: &mutableState)
            return
        }
        // 本次刷新的时间戳
        mutableState.refreshTimestamps.append(ProcessInfo.processInfo.systemUptime)
        mutableState.isRefreshing = true
 
        // 队列异步跳出同步锁
        queue.async {
            // 刷新
            self.authenticator.refresh(credential, for: session) { result in
                // 刷新完成
                self.$mutableState.write { mutableState in
                    switch result {
                    case let .success(credential):
                        // 成功拿到新的凭证，成功处理
                        self.handleRefreshSuccess(credential, insideLock: &mutableState)
                    case let .failure(error):
                        // 发生错误，失败处理
                        self.handleRefreshFailure(error, insideLock: &mutableState)
                    }
                }
            }
        }
    }
 
    /// 检查在一个刷新窗口是否超出阈值
    private func isRefreshExcessive(insideLock mutableState: inout MutableState) -> Bool {
        // 未配置刷新窗口，则刷新不限制次数
        guard let refreshWindow = mutableState.refreshWindow else { return false }
        // 本次刷新窗口的开始时间
        let refreshWindowMin = ProcessInfo.processInfo.systemUptime - refreshWindow.interval
        // 本次刷新窗口中已刷新的次数
        let refreshAttemptsWithinWindow = mutableState.refreshTimestamps.reduce(into: 0) { attempts, refreshTimestamp in
            guard refreshWindowMin <= refreshTimestamp else { return }
            attempts += 1
        }
        // 刷新次数是否已达阈值
        let isRefreshExcessive = refreshAttemptsWithinWindow >= refreshWindow.maximumAttempts
 
        return isRefreshExcessive
    }
 
    private func handleRefreshSuccess(_ credential: Credential, insideLock mutableState: inout MutableState) {
        // 保存新的凭证
        mutableState.credential = credential
        // 取出暂存的适配逻辑和重试回调逻辑
        let adaptOperations = mutableState.adaptOperations
        let requestsToRetry = mutableState.requestsToRetry
        // 清空本次刷新窗口的适配数组和重试回调数据
        mutableState.adaptOperations.removeAll()
        mutableState.requestsToRetry.removeAll()
        // 更新刷新状态
        mutableState.isRefreshing = false
 
        // Dispatch to queue to hop out of the mutable state lock
        queue.async {
            // 适配暂存的请求，适配请求，继续执行
            adaptOperations.forEach { self.adapt($0.urlRequest, for: $0.session, completion: $0.completion) }
            // 重试回调，逐个重试
            requestsToRetry.forEach { $0(.retry) }
        }
    }
 
    private func handleRefreshFailure(_ error: Error, insideLock mutableState: inout MutableState) {
        // 取出暂存的适配逻辑和重试回调逻辑
        let adaptOperations = mutableState.adaptOperations
        let requestsToRetry = mutableState.requestsToRetry
        // 清空数组
        mutableState.adaptOperations.removeAll()
        mutableState.requestsToRetry.removeAll()
        // 更新刷新状态
        mutableState.isRefreshing = false
 
        // Dispatch to queue to hop out of the mutable state lock
        queue.async {
            // 暂存的请求都发出失败回调，取消请求
            adaptOperations.forEach { $0.completion(.failure(error)) }
            // 暂存的重试回调都返回不重试和错误
            requestsToRetry.forEach { $0(.doNotRetryWithError(error)) }
        }
    }
}
```

### 鉴权流程图

![Alamofire鉴权流程图](https://pic.imgdb.cn/item/64d1ebee1ddac507cca8c08b.jpg)

### 参考

* [Alamofire - 使用拦截器优雅的对接口进行授权](https://juejin.cn/post/7035816989444538399)
* [Alamofire 中的线程安全](https://juejin.cn/post/6962915495892762638)