---
title: OC-Runtime：iOS 的消息转发流程篇
categories: 工具代码
tags: [iOS, Runtime, objc]
---

我们知道 OC 是一门动态的编程语言，即我们可以在程序编译运行后改变其结构。而这项功能依赖于其强大的 Runtime 机制。那么在 iOS 中，我们是通过什么样的方式来调用一个方法的呢，当方法没有实现时，有没有别的方法来防止程序崩溃呢？答案当然是有的。

<!-- more -->

### 消息发送 -- objc_msgSend
首先，我们需要了解在 iOS 中的方法是怎样调用和执行的。当我们在通过 `[target selector]` 的方式调用方法的时候，最终都会转换成

```
objc_msgSend(target, selector)
```

`objc_msgSend` 的工作就是用来做消息发送的。他首先是在类的调度表中找到要执行的函数(消息)，如果找到了，到相应的 IMP 执行。

关于 `objc_msgSend`，已经有大神提供了 [C语言版本的源码](https://gist.github.com/vagase/5037737)

下面我们用一张图来说明

![objc_msgSend](https://i.loli.net/2019/04/24/5cc0102a29b44.jpg)


### 消息转发 -- objc_msgFoward
通过 `[target selector]` 调用方法的时候，如果没有找到方法的实现 IMP，按照正常流程走的话，程序是会崩溃的，也就是我们经常碰到的一种 crash：

```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[Person say]: unrecognized selector sent to instance 0x600000542f70'
*** First throw call stack:
(
	0   CoreFoundation                      0x000000010a1ce1bb __exceptionPreprocess + 331
	1   libobjc.A.dylib                     0x0000000109291735 objc_exception_throw + 48
	2   CoreFoundation                      0x000000010a1ecf44 -[NSObject(NSObject) doesNotRecognizeSelector:] + 132
	3   CoreFoundation                      0x000000010a1d2ed6 ___forwarding___ + 1446
	4   CoreFoundation                      0x000000010a1d4da8 _CF_forwarding_prep_0 + 120
	5   MsgForwardDemo                      0x0000000108974745 -[ViewController viewDidLoad] + 117
	6   UIKitCore                           0x000000010d3c44e1 -[UIViewController loadViewIfRequired] + 1186
	...
```

那么，当消息发送的时候没有找到方法的实现的时候，有没有什么途径是可以用来做补救措施的呢？从 `objc_msgSend` 一图中，当没有找到 IMP 的时候，会调用 `_objc_msgForward`，他就是用来做消息转发的。

关于消息转发，官方文档上有解释 [Message Forwarding](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtForwarding.html#//apple_ref/doc/uid/TP40008048-CH105-SW1)。

> Sending a message to an object that does not handle that message is an error. However, before announcing the error, the runtime system gives the receiving object a second chance to handle the message.

消息在没有找到 IMP 后会经历几个阶段:

```objc
1. + (BOOL)resolveInstanceMethod:(SEL)sel;
2. - (id)forwardingTargetForSelector:(SEL)aSelector;
3. - (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;
4. - (void)forwardInvocation:(NSInvocation *)anInvocation;
5. - (void)doesNotRecognizeSelector:(SEL)aSelector;
```

消息转发时，会在本类依次调用上述5个方法。我们可以重写 `NSObject` 的前4个方法，来避免程序 crash。

调用顺序可以用下面的流程图帮助理解

![_objc_msgForward](https://i.loli.net/2019/04/26/5cc2ca589ab8a.jpg)

当消息在 `objc_msgSend` 没有找到对应 selector 的实现的时候，消息会通过 `_objc_msgForward` 进行消息转发。一般分为四个阶段：

#### 阶段一
调用 `resolveInstanceMethod:` 尝试解析方法，在这里允许我们动态的给方法添加实现，在官方文档里也有示例。按严格来说，这一阶段并不能算在消息转发里，具体会在下篇说明。

#### 阶段二
如果在 `resolveInstanceMethod:` 中找到方法的实现，则执行。若没有找到，则会继续到 `forwardingTargetForSelector:`，这个方法允许我们将消息转发给另一个可能实现了对应 selector 的对象。

#### 阶段三
`forwardingTargetForSelector:`没能转发到一个新的对象来处理方法，则会到 `forwardInvocation:` 继续转发，但在调用这个方法之前，会调用 `methodSignatureForSelector:` 得到一个合适的方法签名，若方法签名返回为 `nil`，会直接到阶段四。`forwardInvocation:` 将消息转发到实现了对应 selector 的对象，并根据方法签名进行参数传递，在这一步我们也可以根据方法签名，修改参数。

#### 阶段四
`doesNotRecognizeSelector:` 消息转发阶段都没有完成补救措施，则程序 crash。

