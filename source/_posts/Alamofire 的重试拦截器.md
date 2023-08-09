---
title: Alamofire 的重试拦截器
categories: Almofire 
tags: [iOS, Swift]
---

Alamofire 提供了一个重试拦截器 RetryPolicy，可以针对特定状态码重试，还可以限制重试次数。
多次重试时，并不是失败了就立即重试，而是有一个指数延迟算法。

<!-- more -->

### RetryPolicy 使用流程

首先看 RetryPolicy 的初始化方法：

```swift
/// retryLimit： 重试次数
/// exponentialBackoffBase： 指数基数，必须大于等于2(为1每次都是相等时间间隔)，默认为2
/// exponentialBackoffScale：指数规模，默认为 0.5
/// retryableHTTPMethods：请求方式，如 get、post、put 等
/// retryableHTTPStatusCodes：状态码，如果 401
/// retryableURLErrorCodes： 错误码，这里提供了一组默认错误码
public init(retryLimit: UInt = RetryPolicy.defaultRetryLimit,
            exponentialBackoffBase: UInt = RetryPolicy.defaultExponentialBackoffBase,
            exponentialBackoffScale: Double = RetryPolicy.defaultExponentialBackoffScale,
            retryableHTTPMethods: Set<HTTPMethod> = RetryPolicy.defaultRetryableHTTPMethods,
            retryableHTTPStatusCodes: Set<Int> = RetryPolicy.defaultRetryableHTTPStatusCodes,
            retryableURLErrorCodes: Set<URLError.Code> = RetryPolicy.defaultRetryableURLErrorCodes) {
    precondition(exponentialBackoffBase >= 2, "The `exponentialBackoffBase` must be a minimum of 2.")

    self.retryLimit = retryLimit
    self.exponentialBackoffBase = exponentialBackoffBase
    self.exponentialBackoffScale = exponentialBackoffScale
    self.retryableHTTPMethods = retryableHTTPMethods
    self.retryableHTTPStatusCodes = retryableHTTPStatusCodes
    self.retryableURLErrorCodes = retryableURLErrorCodes
}
```

重试 retry 方法

```swift
open func retry(_ request: Request,
                    for session: Session,
                    dueTo error: Error,
                    completion: @escaping (RetryResult) -> Void) {
    // 先判断是否可以重试：未达到次数限制，并且符合重试规则
    if request.retryCount < retryLimit, shouldRetry(request: request, dueTo: error) {
        // 每次间隔时间是次数的指数，例如：第1次为 2^(1 * 0.5) ，第2次为 2^(2 * 0.5)
        completion(.retryWithDelay(pow(Double(exponentialBackoffBase), Double(request.retryCount)) * exponentialBackoffScale))
    } else {
        completion(.doNotRetry)
    }
}

/// 返回当前是否可重试
open func shouldRetry(request: Request, dueTo error: Error) -> Bool {
    // 请求不合法时不重试
    guard let httpMethod = request.request?.method, retryableHTTPMethods.contains(httpMethod) else { return false }
    // 符合指定状态码时重试
    if let statusCode = request.response?.statusCode, retryableHTTPStatusCodes.contains(statusCode) {
        return true
    } else {
        let errorCode = (error as? URLError)?.code
        let afErrorCode = (error.asAFError?.underlyingError as? URLError)?.code
        // 没有错误码时不重试（本地校验错误类）
        guard let code = errorCode ?? afErrorCode else { return false }
        // 符合指定错误码时重试
        return retryableURLErrorCodes.contains(code)
    }
}
```

如果需要自己定义重试方式，可以继承字 RetryPolicy，重写 retry 方法。

### 验证请求

其中需要注意一点的是，如果要针对 http 状态码重试，需要设置 Request 的 validate：

```swift
extension DataRequest {
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        validate { [unowned self] _, response, _ in
            self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
}

public class DataRequest: Request {
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validator: () -> Void = { [unowned self] in
            guard self.error == nil, let response = self.response else { return }
 
            let result = validation(self.request, response, self.data)
 
            if case let .failure(error) = result { self.error = error.asAFError(or: .responseValidationFailed(reason: .customValidationFailed(error: error))) }
 
            self.eventMonitor?.request(self,
                                       didValidateRequest: self.request,
                                       response: response,
                                       data: self.data,
                                       withResult: result)
        }
 
        $validators.write { $0.append(validator) }
 
        return self
    }
}
```

在请求完成时，如果未发生错误，会针对 validators 验证，验证不通过会抛出错误。
当有错误抛出时，才会继续走重试流程。
如果结合使用 Moya 的话，指定成功验证类型即可：

```swift
extension TargetType {
    var validationType: ValidationType {
        return .successCodes
    }
}
```

```swift
func sendRequest(_ target: Target, request: URLRequest, callbackQueue: DispatchQueue?, progress: Moya.ProgressBlock?, completion: @escaping Moya.Completion) -> CancellableToken {
    let interceptor = self.interceptor(target: target)
    let initialRequest: DataRequest = session.requestQueue.sync {
        let initialRequest = session.request(request, interceptor: interceptor)
        setup(interceptor: interceptor, with: target, and: initialRequest)
 
        return initialRequest
    }
    // 获取 target 指定的验证码
    let validationCodes = target.validationType.statusCodes
    // 如果验证码不为空，则给 request 添加验证
    let alamoRequest = validationCodes.isEmpty ? initialRequest : initialRequest.validate(statusCode: validationCodes)
    return sendAlamofireRequest(alamoRequest, target: target, callbackQueue: callbackQueue, progress: progress, completion: completion)
}
```

### 请求的验证过程

![请求的验证过程](https://pic.imgdb.cn/item/64d1f1b91ddac507ccb73b43.jpg)
