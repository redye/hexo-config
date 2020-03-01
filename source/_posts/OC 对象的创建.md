---
title: 对象的创建
categories: iOS源码探究
tags: [iOS, objc]
---

一个程序在运行的过程中，离不开对象的创建，那么对象究竟是怎么创建的呢？OC 作为一门高级语言，对象在底层又是怎么实现的，对象的本质又是什么呢？带着这些疑问，开启我们的探索旅程。

<!-- more -->

在开启我们的探索之旅之前，我们需要做一些准备工作。首先我们需要下载 `objc` 的[源码](https://opensource.apple.com/source/objc4/)，配置到工程中，以便于我们跟踪对象创建的过程。

### 对象的创建

#### 创建对象的两种方法：
在 `OC` 中，我们一般有两种方法创建对象：

* `[[cls alloc] init]`
* `new`

#### 通过 [[cls alloc] init] 创建对象
我们首先来看 `[[cls alloc] init]` 是怎么创建对象的：

```objc
+ (id)alloc {
    return _objc_rootAlloc(self);
}

// Base class implementation of +alloc. cls is not nil.
// Calls [cls allocWithZone:nil].
id
_objc_rootAlloc(Class cls)
{
    return callAlloc(cls, false/*checkNil*/, true/*allocWithZone*/);
}
```

```objc
// Replaced by CF (throws an NSException)
+ (id)init {
    return (id)self;
}

- (id)init {
    return _objc_rootInit(self);
}

id
_objc_rootInit(id obj)
{
    // In practice, it will be hard to rely on this function.
    // Many classes do not properly chain -init calls.
    return obj;
}
```
从这几个方法中，可以看出：

* 对象创建在 `alloc` 方法中
* `init` 中只是简单的返回了已创建好的对象

	那么 `init` 方法存在的理由是什么呢？

	这个方法就是 **工厂模式** 的应用了。

	* `alloc` 方法一般都是系统准备好的用来创建对象的，作为用户（也就是各位程序员小哥哥小姐姐了）是接触不到的。

	* 但是作为用户，我们有时又必须在对象创建的时候做一些事情（如成员变量的初始化、赋值等），这个时候 `init` 方法就派上用场了。这个时候是不是对我们平时写的 `init` 方法有了更深的认识。

#### 通过 new 创建对象
对象可以通过 `new` 方法来创建：

```objc
+ (id)new {
    return [callAlloc(self, false/*checkNil*/) init];
}
```

看到源码，是不是发现了什么：`new` = `alloc` + `init`

`new` 方法本质上是 `alloc` 和 `init` 的结合体。

#### 创建对象
归根结底，对象创建都是通过`alloc`方法来实现的，那么就以此为起点，跟踪对象创建的过成。

```objc
SMPerson *person = [SMPerson alloc];
```

我们在这行添加一个端点，然后进行 `step into`:

![step-into.png](https://i.loli.net/2019/12/28/5HGq9iXzwIrClOV.png)

然后来到 

```objc
id objc_alloc(Class cls)
{
    return callAlloc(cls, true/*checkNil*/, false/*allocWithZone*/);
}
```

我们一步步跟踪，最后来到：

```objc
id _class_createInstanceFromZone(Class cls, size_t extraBytes, void *zone, 
                              bool cxxConstruct = true, 
                              size_t *outAllocatedSize = nil)
{
    if (!cls) return nil;

    assert(cls->isRealized());

    // Read class's info bits all at once for performance
    bool hasCxxCtor = cls->hasCxxCtor();
    bool hasCxxDtor = cls->hasCxxDtor();
    bool fast = cls->canAllocNonpointer();

    size_t size = cls->instanceSize(extraBytes);
    if (outAllocatedSize) *outAllocatedSize = size;

    id obj;
    if (!zone  &&  fast) {
        obj = (id)calloc(1, size);
        if (!obj) return nil;
        obj->initInstanceIsa(cls, hasCxxDtor);
    } 
    else {
        if (zone) {
            obj = (id)malloc_zone_calloc ((malloc_zone_t *)zone, 1, size);
        } else {
            obj = (id)calloc(1, size);
        }
        if (!obj) return nil;

        // Use raw pointer isa on the assumption that they might be 
        // doing something weird with the zone or RR.
        obj->initIsa(cls);
    }

    if (cxxConstruct && hasCxxCtor) {
        obj = _objc_constructOrFree(obj, cls);
    }

    return obj;
}
```

根据整个流程，我们可以画出对象创建的流程图：

<div style="text-align: center;"><img src="https://i.loli.net/2019/12/28/BEACOhb6Umjekui.png" width="50%"></div>

从流程图结合代码调试，对象创建的实质其实就是：

 * [计算对象实例所占空间的大小](https://redye.github.io/2020/01/04/%E5%AF%B9%E8%B1%A1%E5%AE%9E%E4%BE%8B%E7%9A%84%E7%A9%BA%E9%97%B4%E5%A4%A7%E5%B0%8F/)
 * [开辟内存空间](https://redye.github.io/2020/01/04/%E5%BC%80%E8%BE%9F%E5%86%85%E5%AD%98%E7%A9%BA%E9%97%B4/)
 * [关联 isa](https://redye.github.io/2020/01/04/%E5%85%B3%E8%81%94%20isa/)

### 调试技巧
补充一些调试的小技巧 😉

#### 方法跳转到声明
当我们调试到某个方法，`cmd + space` 即 `jump to definition` 时，只能看到方法声明而没有实现时：

* 通过 `step into`
* 借助控制台输出真正的方法实现

	![debug-skill.png](https://i.loli.net/2019/12/28/qgDMvGJCLjARi9P.png)

#### 当某个方法里代码很长时
我们可以将一些分支代码折叠：

`Xcode->Perferences->Text Editing -> 勾选 Coding folding ribbon`

然后在需要地方：

* 折叠 `option + cmd + ◀︎`
* 展开 `option + cmd + ▶︎`

### 常用数据类型占用内存
| data type | ILP32 size | ILP32 alignment | ILP64 size | ILP64 alignment | 
| :-- | :-- | :-- | :-- | :-- |
| char | 1 byte | 1 byte | 1 byte | 1 byte |
| bool | 1 byte | 1 byte | 1 byte | 1 byte |
| short | 2 byte | 2 byte | 2 byte | 2 byte |
| int | 4 byte | 4 byte | 4 byte | 4 byte |
| long | 4 byte | 4 byte | 8 byte | 8 byte |
| long long | 8 byte | 4 byte | 8 byte | 8 byte |
| NSInteger | 4 byte | 4 byte | 8 byte | 8 byte |
| CF_index | 8 byte | 4 byte | 8 byte | 8 byte |
| pointer | 4 byte | 4 byte | 8 byte | 8 byte |

### OS X以及iOS中与硬件环境相关的预定义宏
| 宏定义 | bits | 架构 |
| :-- | :-- | :-- |
| \_\_i386\_\_ | 32 |  x86 |
| \_\_x86_64\_\_ | 64 |  x86 |
| \_\_arm\_\_ | 32 |  ARM |
| \_\_arm64\_\_  | 64 |  ARM |

`__LP64__`: 表示指针长度为64位，即地址长度以64位长度来表示。

### lldb 命令

| 命令 | 描述 | 例子 |
| :--- | :--- | :--- |
| po | 输出对应值 | `po obj` |
| p | 输出值+值类型+引用名+内存地址 | `p obj` |
| p/x | 常量的进制转换：十六进制 | `p/x 100` | 
| p/d | 常量的进制转换：十进制 | `p/d obj` |
| p/t | 常量的进制转换：二进制 | `p/t obj` | 
| x | 十六进制打印内存对象地址 | `x obj` | 
| x/nxg | 16 字节打印对象内存地址，打印 `n` 段 | `x/4xg obj` |
| bt [n] | 打印调用栈，可以指定帧数 | `bt 10` |

