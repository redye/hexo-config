---
title: OC-Runtime：iOS 的消息转发实例篇
categories: 工具代码
tags: [iOS, Runtime, objc]
---

[OC-Runtime：iOS 的消息转发流程篇](https://redye.github.io/2019/04/22/objc_msgForward/) 讲述了消息在发送阶段的转发流程，这里会结合实例，更直观的看一下消息转发的流程。

<!-- more -->

在 `ViewController.m` 文件里调用一个不存在的消息

```objc
- (void)viewDidLoad {
    [super viewDidLoad];
    
    SEL sel = NSSelectorFromString(@"cus_test:desc:");
    [self performSelector:sel withObject:@"1" withObject:@"2"];
}
```

### 动态添加方法的实现

可以在 ViewController.m 里重写 `resolveInstanceMethod:`，给对应 selector 动态添加实现，不要忘了导入运行时库。

```objc
#import <objc/runtime.h>

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    // 动态添加方法的实现, 如果所有方法都动态添加方法实现，会影响到系统方法
    // 这里的设想是给所有自定义方法动态添加，这就需要用户在自定义方法的时候与系统方法能很容易的区别开来，如添加前缀等
    NSLog(@"--------1.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(sel));
    NSString *selName = NSStringFromSelector(sel);
    if ([selName hasPrefix:forwardPrefix]) {

        SEL newSel = NSSelectorFromString(@"catchException");
        Method method = class_getInstanceMethod(NSClassFromString(@"ExceptionHandler"), newSel);
        IMP imp = method_getImplementation(method);
        const char *type = method_getTypeEncoding(method);
        class_addMethod(self, sel, imp, type);
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}
```
ExceptionHandler.m 类

```objc
// ExceptionHandler.m
- (void)catchException {
    NSString *selName = NSStringFromSelector(_cmd);
    NSString *className = NSStringFromClass([self class]);
    NSLog(@"Catch exception with [%@] of [%@]", selName, className);
}
```
	
运行查看输出

```
--------1.-----------[ViewController] - [cus_test:desc:]
Catch exception with [cus_test:desc:] of [ViewController]
```

这这里有几点需要注意：

* 根据 selector 区别方法，只对用户自定义方法动态添加，如果不加以区分的话，会影响到系统方法，如 `setStoryboard:`、`setValue:forKey:`
* 方法的实现可以在本类提供，也可以在其他类提供。这里的 `ExceptionHandler` 里的 `catchException` 方法会打印出调用者和方法名。
* 官方示例文档上面解释说当给接受者成功添加实现的时候返回 YES，否则返回 NO。
 
  > Returns
  >
  > YES if the method was found and added to the receiver, otherwise NO.
  
网上几乎所有的资料都解释说返回 YES 的时候，消息转发不会在继续后面的流程。但是在实验的阶段，动态添加方法成功的同时返回 NO，消息转发同样没有继续后面的流程了。这里还蛮疑惑的，我试着看会不会走到父类的 `forwardingTargetForSelector:`，同样的也是没有的。在 `return NO` 的地方单步调试
  
![call_stack](https://i.loli.net/2019/04/25/5cc15f767cdb3.jpg)
  
从调用栈来看，在判断是否 `resolveInstanceMethod` 之后又进行了一次查找方法的 IMP 的操作，第二次会找到对应 IMP ，虽然这里有二次寻找，但是这个 IMP 是否有被执行呢？结合 Runtime 的源码
  
```c
static void _class_resolveInstanceMethod(Class cls, SEL sel, id inst)
{
    if (! lookUpImpOrNil(cls->ISA(), SEL_resolveInstanceMethod, cls, 
                         NO/*initialize*/, YES/*cache*/, NO/*resolver*/)) 
    {
        // Resolver not implemented.
        return;
    }
	
    BOOL (*msg)(Class, SEL, SEL) = (typeof(msg))objc_msgSend;
    bool resolved = msg(cls, SEL_resolveInstanceMethod, sel);
	
    // Cache the result (good or bad) so the resolver doesn't fire next time.
    // +resolveInstanceMethod adds to self a.k.a. cls
    // 这里就是上图二次寻找 IMP 的地方
    IMP imp = lookUpImpOrNil(cls, sel, inst, 
                             NO/*initialize*/, YES/*cache*/, NO/*resolver*/);
	
    if (resolved  &&  PrintResolving) {
        ...
    }
}
```
  
但是这似乎并不能解释 IMP 为什么会被执行。在一步一步的调试中发现，最后都是到寄存器执行 IMP 的，在 x86_64s 的架构上都是到 r11 寄存器上的
  
`_objc_msgSend_uncached` 的汇编代码
  
```c
// r10 is already the class to search
MethodTableLookup NORMAL	// r11 = IMP
jmp	*%r11			// goto *imp
```

此时的 IMP 就是上面动态添加的方法实现。

调用栈是这样的
![call_stack2](https://i.loli.net/2019/04/26/5cc26cbb6f46e.jpg)
 
结合看 `lookUpImpOrForward` 和 `_class_lookupMethodAndLoadCache3` 的源码
 
objc-runtime.new.mm
 
```c
IMP _class_lookupMethodAndLoadCache3(id obj, SEL sel, Class cls)
{
    return lookUpImpOrForward(cls, sel, obj, 
                              YES/*initialize*/, NO/*cache*/, YES/*resolver*/);
}
```
 
objc-runtime.new.mm
 
```c
IMP lookUpImpOrForward(Class cls, SEL sel, id inst, 
                   bool initialize, bool cache, bool resolver)
{
    IMP imp = nil;
    bool triedResolver = NO;
	
    runtimeLock.assertUnlocked();
	
    // Optimistic cache lookup
    if (cache) {
        imp = cache_getImp(cls, sel);
        if (imp) return imp;
    }
    ...
	
 retry:    
    runtimeLock.assertLocked();
	
    // Try this class's cache.
	
    imp = cache_getImp(cls, sel);
    if (imp) goto done;
	
    ...
	
    // No implementation found. Try method resolver once.
    if (resolver  &&  !triedResolver) {
        runtimeLock.unlock();
        _class_resolveMethod(cls, sel, inst);
        runtimeLock.lock();
        // Don't cache the result; we don't hold the lock so it may have 
        // changed already. Re-do the search from scratch instead.
        triedResolver = YES; 
        goto retry; // ①
    }
	
    // No implementation found, and method resolver didn't help. 
    // Use forwarding.
	
    imp = (IMP)_objc_msgForward_impcache;
    cache_fill(cls, sel, imp, inst);
	
 done:
    runtimeLock.unlock();
	
    return imp;
}
```
 
注意看上面标出的 ①，这里会再次尝试去寻找 IMP，当然这里是找到 IMP 的，程序继续回到 `_objc_msgSend_uncached` 的寄存器上执行。
	
从这些可以看出，`+ resolveInstanceMethod:` 的返回值并没有影响到消息转发的流程。

### 转发到新的对象
在 `+ resolveInstanceMethod:` 方法里不动态添加方法的实现，消息转发会 走`_objc_msgForward` 转发到自定义对象。

`- forwardingTargetForSelector:` 是第一个被调用的方法。引用官方的摘要：

#### forwardingTargetForSelector
> **Summary**
> 
> Returns the object to which unrecognized messages should first be directed.

意思就是把这个不识别的消息转发到一个新的对象去执行。这个需要我们返回一个已经实现了对应 selector 的实例对象。

```objc
- (id)forwardingTargetForSelector:(SEL)aSelector {
    // 重定向到新的 target 执行
    NSLog(@"--------2.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(aSelector));
    ExceptionHandler *handler = [[ExceptionHandler alloc] init];
    if ([handler respondsToSelector:aSelector]) {
        return handler;
    }

    return [super forwardingTargetForSelector:aSelector];
}
```

在 ExceptionHandler.m 需要实现方法

```objc
- (NSInteger)cus_test:(NSString *)msg desc:(NSString *)desc {
    NSLog(@"test message: %@; %@", msg, desc);
    return 0;
}
```

结合 Runtime，当没有找到 IMP 的时候，在 objc-runtime.new.mm 的 `lookUpImpOrForward` 函数会返回 `_objc_msgForward_impcache`，首先通过 `objc_msgSend`执行

  
```c
// r10 is already the class to search
MethodTableLookup NORMAL	// r11 = IMP
jmp	*%r11			// goto *imp
```

此时的 IMP 就是 `_objc_msgForward_impcache`，然后跳转到 `_objc_msgForward_impcache` 去执行，就是👇


> `id _objc_msgForward(id self, SEL _cmd,...);`
>
> `_objc_msgForward` and `_objc_msgForward_stret` are the externally-callable functions returned by things like method_getImplementation().
>
> `_objc_msgForward_impcache` is the function pointer actually stored in
 method caches.


```c
STATIC_ENTRY __objc_msgForward_impcache
// Method cache version

// THIS IS NOT A CALLABLE C FUNCTION
// Out-of-band condition register is NE for stret, EQ otherwise.

jne	__objc_msgForward_stret
jmp	__objc_msgForward

END_ENTRY __objc_msgForward_impcache
	
ENTRY __objc_msgForward
// Non-stret version

movq	__objc_forward_handler(%rip), %r11
jmp	*%r11

...
```

首先会判断是否实现了 `forwardingTargetForSelector:` 方法，然后调用 `forwardingTargetForSelector:`。再然后用其返回的对象调用方法，就是正常的消息分发流程了。

运行查看输出

```
--------1.-----------[ViewController] - [cus_test:desc:]
--------2.-----------[ViewController] - [cus_test:desc:]
test message: 1; 2
```

#### forwardInvocation
当 `forwardingTargetForSelector:` 返回为 `nil` 的时候，消息转发会继续到 `methodSignatureForSelector:` 方法，获取方法签名，成功获取到方法签名会继续下面的流程。

```objc
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSLog(@"--------3.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(aSelector));
    ExceptionHandler *handler = [[ExceptionHandler alloc] init];
    if ([handler respondsToSelector:aSelector]) {
        return [handler methodSignatureForSelector:aSelector];
    }
    return [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    NSLog(@"--------4.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(anInvocation.selector));
    NSString *selName = NSStringFromSelector(anInvocation.selector);
    if ([selName hasPrefix:forwardPrefix]) {
        id target = [[ExceptionHandler alloc] init];
        [anInvocation invokeWithTarget:target];
    } else {
        [super forwardInvocation:anInvocation];
    }
}
```

运行查看输出

```
--------1.-----------[ViewController] - [cus_test:desc:]
--------2.-----------[ViewController] - [cus_test:desc:]
--------3.-----------[ViewController] - [cus_test:desc:]
--------1.-----------[ViewController] - [_forwardStackInvocation:]
--------4.-----------[ViewController] - [cus_test:desc:]
test message: test2; 2
```

这里出现了一次 `resolveInstanceMethod:`的打印， 对应 `_forwardStackInvocation:` 方法，是内部调用的私有方法，这里可以忽略掉。

当 `methodSignatureForSelector:` 返回为 `nil` 的时候，会到 `doesNotRecognizeSelector:`，程序 crash。

```objc
- (void)doesNotRecognizeSelector:(SEL)aSelector {
    NSLog(@"--------5.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(aSelector));
    [super doesNotRecognizeSelector:aSelector];
}
```

运行查看输出

```
--------1.-----------[ViewController] - [cus_test:desc:]
--------2.-----------[ViewController] - [cus_test:desc:]
--------3.-----------[ViewController] - [cus_test:desc:]
--------5.-----------[ViewController] - [cus_test:desc:]
-[ViewController cus_test:desc:]: unrecognized selector sent to instance 0x7f9b36c07790
```

### 总结与思考
从消息从调用到执行的整个流程来看，大致可以分为两个阶段：第一阶段就是执行 `objc_msgSend` 阶段，这个阶段在主要通过 `lookUpImpOrNil` 来找到方法对应的 IMP 去执行，如果没找到，提供一次动态添加方法实现的机会；如果最终没有 IMP，会走 `_objc_msgForward` 进行消息转发给新的 target 去实现。

#### 专门的异常处理
`resolveInstanceMethod` 动态给方法添加实现，在这里处理的好处是，你可以统一将没有实现的方法都抛给一个专门处理这类异常的类去处理，例如上面的 `ExceptionHandler`。

#### 方法签名与参数修改
在消息转发阶段，被转发的对象都需要实现同名的方法。一般都是在 `forwardInvocation:` 处理消息转发，在这里处理的好处是可以通过 `NSInvocation` 类拿到所有的参数，你也可以在这里修改参数。

* 在实践过程中，`methodSignatureForSelector:` 生成方法签名的时候，也可以直接通过字符串而不通过某个具体的类生成，这个时候需要你保证 [Type Encodings](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100-SW1) 是对应上的，虽然没有对应上也能成功，但是会对 `forwardInvocation:` 有影响。

	```objc
	 - (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
		    NSLog(@"--------3.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(aSelector));
		//    ExceptionHandler *handler = [[ExceptionHandler alloc] init];
		//    if ([handler respondsToSelector:aSelector]) {
		//        return [handler methodSignatureForSelector:aSelector];
		//    }
		    NSString *selName = NSStringFromSelector(aSelector);
		    if ([selName hasPrefix:forwardPrefix]) {
		        return [NSMethodSignature signatureWithObjCTypes:"v@:@@"];
		    }
		    return [super methodSignatureForSelector:aSelector];
		}
	```
* 在 `forwardInvocation:` 中可以对入参进行修改。
* 关于为什么入参的下标从 2 开始，OC 方法里默认有 `self` 和 `_cmd` 两个参数，方法的入参从第三个开始，即下标为 2 开始。`NSInvocation`的参数传递与方法签名对应，所以虽然方法签名可以通过字符串生成，但是最好还是要和方法对应上。
	 
	```objc		
	- (void)forwardInvocation:(NSInvocation *)anInvocation {
	    NSLog(@"--------4.-----------[%@] - [%@]", NSStringFromClass([self class]), NSStringFromSelector(anInvocation.selector));
	    NSString *selName = NSStringFromSelector(anInvocation.selector);
	    if ([selName hasPrefix:forwardPrefix]) {
	        id target = [[ExceptionHandler alloc] init];
	        NSInteger numberOfArguments = anInvocation.methodSignature.numberOfArguments;
	        if (numberOfArguments > 2) {
	            for (int i = 2; i < numberOfArguments; i ++) {
	                const char *argumentType = [anInvocation.methodSignature getArgumentTypeAtIndex:i];
	                if (strcmp(argumentType, "@") == 0) {
	                    NSString *argument = [NSString stringWithFormat:@"test%d", i];
	                    [anInvocation setArgument:&argument atIndex:i];
	                } else if (strcmp(argumentType, "i") == 0) {
	                    [anInvocation setArgument:&i atIndex:i];
	                }
	            }
	        }
	        [anInvocation invokeWithTarget:target];
	    } else {
	        [super forwardInvocation:anInvocation];
	    }
	}
	```
	 
	运行查看输出
	
	```
	test message: test2; test3
	```

### 应用
现在比较流行的切面编程(AOP)--Aspects 就是依赖 [Method Swizzling](https://redye.github.io/2019/04/22/method-swizzling/) 和 `_objc_msgForward` 实现的。

Demo 在[这里](https://github.com/redye/MsgForwardDemo/tree/master)。