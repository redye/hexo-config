---
title: Method Swizzling
categories: 工具代码
tags: [iOS, Swizzling, Runtime]
---

iOS 运行时是每一个 iOS 开发者离不开的话题。利用运行时的消息转发，能够帮助我们完成很多动作。我们熟悉的 Method Swizzling(又称黑魔法)，切面编程(AOP)、无侵入埋点等都是依靠此来完成的。

<!-- more -->

讲到 Method Swizzling，自然离不开下面几个核心方法：

* `class_addMethod`
* `class_replaceMethod`
* `method_exchangeImplementations`
* `method_setImplementation`

### class_addMethod
`class_addMethod` 是给目标类添加一个方法和方法的实现。添加成功会返回 YES，否则返回 NO（例如，如果该类已经存在这个方法）。需要注意的是，`class_addMethod` 会重写父类的实现（前提是子类没有实现父类的方法，否则也会失败）。总结下来就是 `class_addMethod` 并不会替换类已有的实现，只能添加新的实现。

### class_replaceMethod
`class_replaceMethod` 用于替换目标类给定方法的实现。可以有两种不同的使用方式：

* 如果方法在该类中不存在的时候，会添加这个方法，效果同 `class_addMethod`
* 如果方法在该类中存在的时候，会替换该方法的实现，效果同 `method_setImplementation`

所以在进行 Method Swizzling 的时候，就可以有不同的方式来实现。

### method_exchangeImplementations
`method_exchangeImplementations` 交换两个方法的实现。相当于执行了两次 `method_setImplementation` 的原子版本。

如果你只想替换某个方法的实现，就可以只调用 `method_setImplementation` 了。

```objc
IMP imp1 = method_getImplementation(m1);
IMP imp2 = method_getImplementation(m2);
method_setImplementation(m1, imp2);
method_setImplementation(m2, imp1);
```

### 这是一个例子

#### 当源方法在类中有实现时
可以直接使用 `method_exchangeImplementations` 将两个方法的实现交换。

```objc
@interface Car : NSObject
	
- (void)run;
	
@end
	
@implementation Car
	
+ (void)load {
    Class class = [self class];
	
    SEL originSelector = @selector(run);
    SEL swizzledSelector = @selector(run_slow);
	
    Method originMethod = class_getInstanceMethod(class, originSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
	
    method_exchangeImplementations(originMethod, swizzledMethod);
}
	
- (void)run {
    NSLog(@"%@ is running", NSStringFromClass([self class]));
}
	
- (void)run_slow {
    NSLog(@"%@ is running slowly", NSStringFromClass([self class]));
}
	
@end
```
	
```objc
Car *car = [[Car alloc] init];
[car run]; // Car is running slowly
```

#### 当源方法只在父类中有实现

```objc
@interface Car : NSObject
	
- (void)run;
	
@end
	
@interface Truck : Car
	
- (void)run_fast;
	
@end
	
@implementation Car
	
- (void)run {
    NSLog(@"%@ is running", NSStringFromClass([self class]));
}
	
- (void)run_slow {
    NSLog(@"%@ is running slowly", NSStringFromClass([self class]));
}
	
@end
	
	
@implementation Truck
	
+ (void)load {
    Class class = [self class];
    
    SEL originSelector = @selector(run);
    SEL swizzledSelector = @selector(run_fast);
    
    Method originMethod = class_getInstanceMethod(class, originSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
//    method_exchangeImplementations(originMethod, swizzledMethod);
//    return;
    
    IMP originImp = method_getImplementation(originMethod);
    IMP swizzledImp = method_getImplementation(swizzledMethod);
    
    BOOL didAdd = class_addMethod(class, originSelector, swizzledImp, method_getTypeEncoding(swizzledMethod));
    if (didAdd) {
        class_replaceMethod(class, swizzledSelector, originImp, method_getTypeEncoding(originMethod));
    } else {
        method_exchangeImplementations(originMethod, swizzledMethod);
    }
}
	
- (void)run_fast {
    NSLog(@"%@ is running fast", NSStringFromClass([self class]));
}
	
@end
```
	
```objc
Car *car = [[Car alloc] init];
[car run]; // Car is running
	
Truck *truck = [[Truck alloc] init];
[truck run]; // Truck is running fast
[truck run_fast]; // Truck is running
```
	
如果直接交换方法的实现，输出会变成下面这样，即执行上述代码注释部分
	
```objc
Car *car = [[Car alloc] init];
[car run]; // Car is running fast
	
Truck *truck = [[Truck alloc] init];
[truck run]; // Truck is running fast
[truck run_fast]; // Truck is running
```

仔细观察，你会发现，父类的方法实现也被交换了。