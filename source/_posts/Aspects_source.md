---
title: OC-Runtime：Aspects 解读篇
categories: 工具代码
tags: [iOS, Runtime, objc]
---

切面编程 [Aspects](https://github.com/steipete/Aspects) 就是利用 Method Swizzling 与 `_objc_msgForward` 的典型实例。下面就对 Aspects 做一个深度的解读。

<!-- more --> 

### Aspects 的 hook 过程
首先我们来看 `Aspects.h` 文件。他是一个 `NSObject` 的类别，这样所有 OC 对象就都可以调用他提供的方法了。他提供了两个入口方法，方法名和参数都相同，区别在于他们一个是类方法，一个是实例方法。他们的返回值都是实现了 `AspectToken` 协议的 `id` 类型对象。

```objc
+ (id<AspectToken>)aspect_hookSelector:(SEL)selector
                      withOptions:(AspectOptions)options
                       usingBlock:(id)block
                            error:(NSError **)error;
```

在 `Aspects.m` 我们可以看到，里面的实现都是通过静态方法实现。hook 的入口方法

```objc
static id aspect_add(id self, SEL selector, AspectOptions options, id block, NSError **error) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);
    NSCParameterAssert(block);

    __block AspectIdentifier *identifier = nil;
    aspect_performLocked(^{
        if (aspect_isSelectorAllowedAndTrack(self, selector, options, error)) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, selector);
            identifier = [AspectIdentifier identifierWithSelector:selector object:self options:options block:block error:error];
            if (identifier) {
                [aspectContainer addAspect:identifier withOptions:options];

                // Modify the class to allow message interception.
                aspect_prepareClassAndHookSelector(self, selector, error);
            }
        }
    });
    return identifier;
}
```

这个方法做了很多工作，可以用流程图来加深理解。

![aspects_hook](https://i.loli.net/2019/04/30/5cc81ae585991.jpg)

在分析之前，我们需要理解几个类以及他们的作用。

**AspectTracker**

记录被 hook 的类对象。记录该类被 hook 的方法和类层级关系的 topmost，防止被重复 hook。保存在全局字典 `swizzledClassesDict` 中，key 是当前类对象。

**AspectIdentifier**

记录单个被 hook 方法的信息。其中会对传入的 block 进行签名:

* block 参数个数必须小于等于方法的参数个数；
* block 的参数大于 1 个时，第 1 个参数类型必须是 SEL 或 `id<AspectInfo>` 类型；第 0 个参数类型是 self/block
* block 的参数大于 2 时，block 参数类型必须与 方法参数类型一致

**AspectsContainer** 

记录被 Hook 方法的方式。被关联到 self 上，并以别名作为被关联的 key。

AspectsContainer 有三个数组，分别记录不同 `AspectOptions` 下的 AspectIdentifier。


#### hook 的4个条件
在 hook 之前，会先判断这个方法是否被允许 hook。判断的条件有4个

* 不在 `retain`、`release`、`autorelease`、`forwardInvocation` 之列
* 如果是 `dealloc`，只支持 `AspectPositionBefore` 方式，即 hook 的方法要在原方法之前执行。
* 方法必须有实现。
* 如果传入是类对象，该方法在类与类的继承链上只能被 hook 一次。同时会被 [AspectTracker] 跟踪。tracker 被加到 `swizzledClassesDict` 全局字典里，key 是 类名。实现还是挺妙的。
	
	```objc
	// Search for the current class and the class hierarchy IF we are modifying a class object
	if (class_isMetaClass(object_getClass(self))) {
	    Class klass = [self class];
	    NSMutableDictionary *swizzledClassesDict = aspect_getSwizzledClassesDict();
	    Class currentClass = [self class];
	    do {
	        AspectTracker *tracker = swizzledClassesDict[currentClass];
	        if ([tracker.selectorNames containsObject:selectorName]) {
	
	            // Find the topmost class for the log.
	            if (tracker.parentEntry) {
	                AspectTracker *topmostEntry = tracker.parentEntry;
	                while (topmostEntry.parentEntry) {
	                    topmostEntry = topmostEntry.parentEntry;
	                }
	                NSString *errorDescription = [NSString stringWithFormat:@"Error: %@ already hooked in %@. A method can only be hooked once per class hierarchy.", selectorName, NSStringFromClass(topmostEntry.trackedClass)];
	                AspectError(AspectErrorSelectorAlreadyHookedInClassHierarchy, errorDescription);
	                return NO;
	            }else if (klass == currentClass) {
	                // Already modified and topmost!
	                return YES;
	            }
	        }
	    }while ((currentClass = class_getSuperclass(currentClass)));
	
	    // Add the selector as being modified.
	    currentClass = klass;
	    AspectTracker *parentTracker = nil;
	    do {
	        AspectTracker *tracker = swizzledClassesDict[currentClass];
	        if (!tracker) {
	            tracker = [[AspectTracker alloc] initWithTrackedClass:currentClass parent:parentTracker];
	            swizzledClassesDict[(id<NSCopying>)currentClass] = tracker;
	        }
	        [tracker.selectorNames addObject:selectorName];
	        // All superclasses get marked as having a subclass that is modified.
	        parentTracker = tracker;
	    }while ((currentClass = class_getSuperclass(currentClass)));
	}
	```

* 如果传入是实例对象，始终被允许。

#### hook 类
* baseClass 如果包含 `_Aspects_` 后缀，说明已经被 hook
* baseClass 如果不包含 `_Aspects_` 后缀，并且是元类，则去 hook 类
* baseClass 如果不包含`_Aspects_` 后缀，并且不是元类，并且 statedClass 与 baseClass 不相等（被 KVO 的对象/swizzle 类/swizzle 元类），则去 hook
* 以上条件都不满足（如传入对象是实例对象），则拼接`_Aspects_` 后缀生成子类 hook

```objc
static Class aspect_hookClass(NSObject *self, NSError **error) {
    NSCParameterAssert(self);
	Class statedClass = self.class;
	Class baseClass = object_getClass(self);
	NSString *className = NSStringFromClass(baseClass);

    // Already subclassed
	if ([className hasSuffix:AspectsSubclassSuffix]) {
		return baseClass;

        // We swizzle a class object, not a single object.
	}else if (class_isMetaClass(baseClass)) {
        return aspect_swizzleClassInPlace((Class)self);
        // Probably a KVO'ed class. Swizzle in place. Also swizzle meta classes in place.
    }else if (statedClass != baseClass) {
        return aspect_swizzleClassInPlace(baseClass);
    }

    // Default case. Create dynamic subclass.
	const char *subclassName = [className stringByAppendingString:AspectsSubclassSuffix].UTF8String;
	Class subclass = objc_getClass(subclassName);

	if (subclass == nil) {
		subclass = objc_allocateClassPair(baseClass, subclassName, 0);
		if (subclass == nil) {
            NSString *errrorDesc = [NSString stringWithFormat:@"objc_allocateClassPair failed to allocate class %s.", subclassName];
            AspectError(AspectErrorFailedToAllocateClassPair, errrorDesc);
            return nil;
        }
		// hook 子类
		aspect_swizzleForwardInvocation(subclass);
		// hook 完成后将 subclass 和其元类 的 isa 都指向 statedClass。
		aspect_hookedGetClass(subclass, statedClass);
		aspect_hookedGetClass(object_getClass(subclass), statedClass);
		// 注册刚刚创建的子类
		objc_registerClassPair(subclass);
	}

	// 将 self 的 isa 指向 subclass
	object_setClass(self, subclass);
	return subclass;
}
```

> object_getClass: 当传入对象是个实例对象时，返回类对象；当传入对象是类对象时，返回元类
> +[self class] 与 -[self class]: 返回类对象

hook 类时，先判断该类是否已经 hook 过，hook 过的类的类名添加到全局集合 `swizzledClasses `中。未 hook 过的类，是将 `- forwardInvocation:` 的实现替换为 `__ASPECTS_ARE_BEING_CALLED__`。并添加方法`__aspects_forwardInvocation`，IMP 指向 originIMP。

```objc
static Class aspect_swizzleClassInPlace(Class klass) {
    NSCParameterAssert(klass);
    NSString *className = NSStringFromClass(klass);

    _aspect_modifySwizzledClasses(^(NSMutableSet *swizzledClasses) {
        if (![swizzledClasses containsObject:className]) {
            aspect_swizzleForwardInvocation(klass);
            [swizzledClasses addObject:className];
        }
    });
    return klass;
}

static NSString *const AspectsForwardInvocationSelectorName = @"__aspects_forwardInvocation:";
static void aspect_swizzleForwardInvocation(Class klass) {
    NSCParameterAssert(klass);
    // If there is no method, replace will act like class_addMethod.
    IMP originalImplementation =
    class_replaceMethod(klass, @selector(forwardInvocation:), (IMP)__ASPECTS_ARE_BEING_CALLED__, "v@:@");
    if (originalImplementation) {
        class_addMethod(klass, NSSelectorFromString(AspectsForwardInvocationSelectorName), originalImplementation, "v@:@");
    }
    AspectLog(@"Aspects: %@ is now aspect aware.", NSStringFromClass(klass));
}
```

#### hook 方法

* 首先获取 selector 的实现，判断是否是 `_objc_msgForward`
* 生成方法别名 `aspects_selectorName`
* 判断类是否实现方法 `aspects_selectorName`， 未实现时将 `aspects_selectorName` 的实现指向 selector 的实现
* 将 `selector` 的实现指向 `_objc_msgForward` 或者 `_objc_msgForward_stret`，后面在调用 selector 方法就会直接走到消息转发的流程

```objc
static void aspect_prepareClassAndHookSelector(NSObject *self, SEL selector, NSError **error) {
    NSCParameterAssert(selector);
    Class klass = aspect_hookClass(self, error);
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (!aspect_isMsgForwardIMP(targetMethodIMP)) {
        // Make a method alias for the existing method implementation, it not already copied.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        if (![klass instancesRespondToSelector:aliasSelector]) {
            __unused BOOL addedAlias = class_addMethod(klass, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
            NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);
        }

        // We use forwardInvocation to hook in.
        class_replaceMethod(klass, selector, aspect_getMsgForwardIMP(self, selector), typeEncoding);
        AspectLog(@"Aspects: Installed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }
}
```

那么在调用之前的 hook 过程就完成了。

### Aspected 的调用过程
从上面的 Hook 过程我们可以知道，Aspects 在调用 selector 的时候，会直接到 `_objc_msgForward` 走消息转发的流程，最后会调用到 `- forwardInvocation:` 方法。就是我们 swizzled 后的 `__ASPECTS_ARE_BEING_CALLED__` 方法。

```objc
static void __ASPECTS_ARE_BEING_CALLED__(__unsafe_unretained NSObject *self, SEL selector, NSInvocation *invocation) {
    NSCParameterAssert(self);
    NSCParameterAssert(invocation);
    SEL originalSelector = invocation.selector;
	SEL aliasSelector = aspect_aliasForSelector(invocation.selector);
    invocation.selector = aliasSelector;
    // 实例对象 hook 时 objectContainer 不为 nil
    AspectsContainer *objectContainer = objc_getAssociatedObject(self, aliasSelector);
    // 类对象 hook 时 classContainer 不为 nil
    AspectsContainer *classContainer = aspect_getContainerForClass(object_getClass(self), aliasSelector);
    // 生成 AspectInfo，记录数据
    AspectInfo *info = [[AspectInfo alloc] initWithInstance:self invocation:invocation];
    NSArray *aspectsToRemove = nil;

    // Before hooks.
    // Before 类型的 hook，先执行传入 block
    aspect_invoke(classContainer.beforeAspects, info);
    aspect_invoke(objectContainer.beforeAspects, info);

    // Instead hooks. Instead 类型的 hook 不执行 orginImp
    BOOL respondsToAlias = YES; // 记录改方法是否被 hook
    if (objectContainer.insteadAspects.count || classContainer.insteadAspects.count) {
        aspect_invoke(classContainer.insteadAspects, info);
        aspect_invoke(objectContainer.insteadAspects, info);
    }else {
    	// 执行 origimImp
        Class klass = object_getClass(invocation.target);
        do {
            if ((respondsToAlias = [klass instancesRespondToSelector:aliasSelector])) {
                [invocation invoke];
                break;
            }
        }while (!respondsToAlias && (klass = class_getSuperclass(klass)));
    }

    // After hooks.
    // After 类型的 hook，后执行传入 block
    aspect_invoke(classContainer.afterAspects, info);
    aspect_invoke(objectContainer.afterAspects, info);

    // If no hooks are installed, call original implementation (usually to throw an exception)
    // 若方法没有被 hook，说明该方法没有被实现，则调用 -forwardInvocation: 的 originImp，走系统的消息转发流程
    if (!respondsToAlias) {
        invocation.selector = originalSelector;
        SEL originalForwardInvocationSEL = NSSelectorFromString(AspectsForwardInvocationSelectorName);
        if ([self respondsToSelector:originalForwardInvocationSEL]) {
            ((void( *)(id, SEL, NSInvocation *))objc_msgSend)(self, originalForwardInvocationSEL, invocation);
        }else {
            [self doesNotRecognizeSelector:invocation.selector];
        }
    }

    // Remove any hooks that are queued for deregistration.
    // 移除 AspectOptionAutomaticRemoval 类型的 hook
    [aspectsToRemove makeObjectsPerformSelector:@selector(remove)];
}
```
aspect_invoke 是一个宏定义，执行两个动作

* 执行 - invokeWithInfo:
* 把 `AspectOptionAutomaticRemoval` 类型的 aspect 加入到数组中
 
```objc
#define aspect_invoke(aspects, info) \
for (AspectIdentifier *aspect in aspects) {\
    [aspect invokeWithInfo:info];\
    if (aspect.options & AspectOptionAutomaticRemoval) { \
        aspectsToRemove = [aspectsToRemove?:@[] arrayByAddingObject:aspect]; \
    } \
}
```

### Aspected 的移除过程

* 首先获取到 aspectContainer ，移除对应数组的 aspects
* aspect_cleanupHookedClassAndSelector 恢复被 hook 的类和方法

```objc
static BOOL aspect_remove(AspectIdentifier *aspect, NSError **error) {
    NSCAssert([aspect isKindOfClass:AspectIdentifier.class], @"Must have correct type.");

    __block BOOL success = NO;
    aspect_performLocked(^{
        id self = aspect.object; // strongify
        if (self) {
            AspectsContainer *aspectContainer = aspect_getContainerForObject(self, aspect.selector);
            success = [aspectContainer removeAspect:aspect];

            aspect_cleanupHookedClassAndSelector(self, aspect.selector);
            // destroy token
            aspect.object = nil;
            aspect.block = nil;
            aspect.selector = NULL;
        }else {
            NSString *errrorDesc = [NSString stringWithFormat:@"Unable to deregister hook. Object already deallocated: %@", aspect];
            AspectError(AspectErrorRemoveObjectAlreadyDeallocated, errrorDesc);
        }
    });
    return success;
}
```

`aspect_cleanupHookedClassAndSelector` 做了三件事情：

* 恢复 selector 的 IMP 指向 `_objc_msgFoward`，则将 IMP 指针指向 originIMP
* 在全局 `swizzledClassesDict` 字典获取对应类对象 tracker，移除对应被 hook 的 selector，当该类没有被 hook 的方法时，移除该 tracker
* 检查 container 中是否还有 aspect，当没有的时候，移除该 container 的关联属性；当该类含有 `_Aspects_` 后缀时，获取 originClass(去除后缀)，将 self 的 isa 指针指向 originClass；如果没有后缀但是是元类时，将该类的 `- forwardInvocation:` 的 IMP 指向 originIMP，并在全局集合 `swizzledClasses` 中移除该类名

```objc
static void aspect_cleanupHookedClassAndSelector(NSObject *self, SEL selector) {
    NSCParameterAssert(self);
    NSCParameterAssert(selector);

	Class klass = object_getClass(self);
    BOOL isMetaClass = class_isMetaClass(klass);
    if (isMetaClass) {
        klass = (Class)self;
    }

    // Check if the method is marked as forwarded and undo that.
    Method targetMethod = class_getInstanceMethod(klass, selector);
    IMP targetMethodIMP = method_getImplementation(targetMethod);
    if (aspect_isMsgForwardIMP(targetMethodIMP)) {
        // Restore the original method implementation.
        const char *typeEncoding = method_getTypeEncoding(targetMethod);
        SEL aliasSelector = aspect_aliasForSelector(selector);
        Method originalMethod = class_getInstanceMethod(klass, aliasSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        NSCAssert(originalMethod, @"Original implementation for %@ not found %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), klass);

        class_replaceMethod(klass, selector, originalIMP, typeEncoding);
        AspectLog(@"Aspects: Removed hook for -[%@ %@].", klass, NSStringFromSelector(selector));
    }

    // Deregister global tracked selector
    aspect_deregisterTrackedSelector(self, selector);

    // Get the aspect container and check if there are any hooks remaining. Clean up if there are not.
    AspectsContainer *container = aspect_getContainerForObject(self, selector);
    if (!container.hasAspects) {
        // Destroy the container
        aspect_destroyContainerForObject(self, selector);

        // Figure out how the class was modified to undo the changes.
        NSString *className = NSStringFromClass(klass);
        if ([className hasSuffix:AspectsSubclassSuffix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:AspectsSubclassSuffix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            object_setClass(self, originalClass);
            AspectLog(@"Aspects: %@ has been restored.", NSStringFromClass(originalClass));

            // We can only dispose the class pair if we can ensure that no instances exist using our subclass.
            // Since we don't globally track this, we can't ensure this - but there's also not much overhead in keeping it around.
            //objc_disposeClassPair(object.class);
        }else {
            // Class is most likely swizzled in place. Undo that.
            if (isMetaClass) {
                aspect_undoSwizzleClassInPlace((Class)self);
            }
        }
    }
}
```
