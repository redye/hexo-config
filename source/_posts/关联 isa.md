---
title: 关联 isa
categories: iOS源码探究
tags: [iOS, objc, isa]
---

现在对象在内存中已经分配好内存空间了，但对象和类是怎么关联上的呢，这就是 `isa` 的工作了。

<!-- more -->

### isa 联合体
我们可以看一下对象的表现形式：

```c
struct objc_object {
private:
    isa_t isa;
}
```
所以每一个对象必然有一个 `isa`。

然后我们看一下 `isa` 的结构：

```objc
union isa_t {
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    uintptr_t bits;
#if defined(ISA_BITFIELD)
    struct {
        ISA_BITFIELD;  // defined in isa.h
    };
#endif
};
```

可以看到，`isa` 是一个 [联合体](https://redye.github.io/2020/01/02/%E8%81%94%E5%90%88%E4%BD%93%E4%B8%8E%E4%BD%8D%E5%9F%9F/) 。

### isa 的结构
首先我们来分析一下 `isa` 的结构：

`isa` 有三个成员：`Class` 、 `bits` 和一个结构体。

以下以 64 位架构为例分析：

#### `Class`
	
```c
typedef struct objc_class *Class;
```
	
`Class` 是一个结构体指针，所以 `Class` 占 8 字节。

#### `bits`

```c
typedef unsigned long           uintptr_t;
```
	
`bits` 是一个无符号长整形，占 8 个字节。
	
#### 结构体

```
struct {
    ISA_BITFIELD;  // defined in isa.h
};
```
	
结构体的内容是一个宏定义，宏定义在编译时替换成定义好的内容，这样就可以区分不同架（如 `__x86_64__` 与 `__arm64__`）。
	
![isa.png](https://i.loli.net/2020/01/03/6gtPkl1zfsCnvyK.png)
	
其实这里的实现，就是上面我们提到的位域。
	
从图中我们可以看出，两个架构上结构体的字段相同，只是分布不同。
	
结构体的大小为 8 字节，即 `64 bit`。
 
 * `arm64` : 1 + 1 + 1 + 33 + 6 + 1 + 1 + 1 + 19 = 64
 * `__x86_64__` : 1 + 1 + 1 + 44 + 6 + 1 + 1 + 1 + 8 &nbsp;= 64



下面给出`isa`图解：

![isa_bits.png](https://i.loli.net/2020/01/04/HcoP8unSNFAlkrb.png)

### 关联 isa
现在我们来看一下关联 `isa` 的代码实现：

```objc
inline void 
objc_object::initIsa(Class cls, bool nonpointer, bool hasCxxDtor) 
{ 
    assert(!isTaggedPointer()); 
    
    if (!nonpointer) {
        isa.cls = cls;
    } else {
        assert(!DisableNonpointerIsa);
        assert(!cls->instancesRequireRawIsa());

        isa_t newisa(0);

#if SUPPORT_INDEXED_ISA
        ...
#else
        newisa.bits = ISA_MAGIC_VALUE;
        // isa.magic is part of ISA_MAGIC_VALUE
        // isa.nonpointer is part of ISA_MAGIC_VALUE
        newisa.has_cxx_dtor = hasCxxDtor;
        newisa.shiftcls = (uintptr_t)cls >> 3;
#endif
        isa = newisa;
    }
}
```

代码稍微精简了一下。注意这里的 **`SUPPORT_INDEXED_ISA`** 宏：

```objc
#if __ARM_ARCH_7K__ >= 2  ||  (__arm64__ && !__LP64__)
#   define SUPPORT_INDEXED_ISA 1
#else
#   define SUPPORT_INDEXED_ISA 0
#endif
```

查阅到 [资料](https://www.jianshu.com/p/d23334e7cb35)，`__ARM_ARCH_7K__ >= 2` 应该是表示手表的宏。

`__ARM_ARCH_7K__` 架构上的 `isa` 的位域结构体具体的字段有所不同，分布也不同，这里就不在展开了。

在 `isa` 的实现代码里，一般继承 `NSObject` 的类都支持 `isa` 指针优化，如果不支持，`isa` 的 `64` 位都用来保存 `class` 或者 `metaclass` 的内存地址。

支持指针优化的 `isa`：

* `isa` 作为一个联合体，对 `bits` 赋值后，`isa` 的值为(程序运行在模拟器，所以是基于 `__x86_64__` 的架构):
	
	```c
	newisa.bits = ISA_MAGIC_VALUE;
	/** 
	 * 0x				  	 0b
	 * 0x001d800000000001ULL 0b0000000000011101100000000000000000000000000000000000000000000001
	 */
	```
	此时位域的最低位即 `nonpointer` 为 `1`，表示支持指针优化。
	
* `hasCxxDtor` 放在联合体位域的 `has_cxx_dtor`，此时此处指为 `false`，所以值为 `0`

	```c
	newisa.has_cxx_dtor = hasCxxDtor;
	/**
	 * 0x 					 0b
	 * 0x001d800000000001ULL 0b0000000000011101100000000000000000000000000000000000000000000001
	 */
	```

* `cls` 的内存地址放在 `isa` 的 `shiftcls` 区间

	```c
	newisa.shiftcls = (uintptr_t)cls >> 3;  // 此处 cls 的值为 0x00000001000029f0
	/** 
	 * 0x				  0b
	 * 0x001d8001000029f1 0b0000000000011101100000000000000100000000000000000010100111110001
	 */
	```
	注意此时的 `shiftcls` 对 `cls` 的地址进行了右移 `3` 位的计算，所以后面再去的时候，也是需要计算的。
	
	或许在这里你会有个疑问，地址经过计算之后，存储的地址不会发现变化吗？
	
	这就是实现精妙的地方了 -- 还记得上面讲的字节对齐吗，OC 对象的内存地址首先进行了 `8` 字节的对齐，那么对象的内存地址肯定是 `8` 的倍数。虽然针对的是对象，但是类和元类在编译时创建同样也是经过了 `8` 字节对齐的。所以内存地址也是 `8` 的倍数。
	
	`8` 的 二进制表示为 `0b1000`，右移`3位`之后位 `0b1`，所以后面再取值的时候，在左移`3位`补齐后面的 `0`就能得到真正的地址。
	
	我们二进制计算一下：

	```c
	(lldb) p/t 0x00000001000029f0
	(long) $0 = 0b0000000000000000000000000000000100000000000000000010100111110000
	(lldb) p/t $0 >> 3
	(long) $1 = 0b0000000000000000000000000000000000100000000000000000010100111110
	(lldb) p/t $1 << 3
	(long) $2 = 0b0000000000000000000000000000000100000000000000000010100111110000
	(lldb) po $0 == $2
	true
	```
	现在 `cls` 的地址已经放到 `isa` 的 `shiftcls` 段里面了，在 `arm64` 里面占了 `33` 位，但是 `cls` 的地址是 `64` 位能存下吗？
	
	类和元类只需要创建一个，而且是在编译时期就已经完成了的(我们可以从 `machO` 文件中看到这些类信息，所以他们在编译时期就已经确定了)。但是从实际问题出发，真的需要这么多的类吗？`shiftcls` 在 `arm64` 架构下有 `33` 为，加上右移的 `3` 位，所以分配的内存空间为 `2^34 bit = 2 * 2^33 G = 2G`，我们的程序类信息(代码段)一般都不会这么大(我们打包完的程序还包含其他一下资源文件)，所以是完全足够的。
	
	接下来就是如何将 `cls` 的地址如何从 `shiftcls` 中取出来了。上面的分析都是依据  `arm64`的，下面的我们从程序中跑一下，犹如我们是在模拟器上运行的，`shiftcls` 取的 `44`位。
	
	取出 `cls` 地址的方法有两种:
	
	* 利用掩码 `ISA_MASK` 进行 与运算： 
	
		```c
		define ISA_MASK        0x00007ffffffffff8ULL
		```
		![isa__.png](https://i.loli.net/2020/01/04/IpXe8xl6jUToQh2.png)
	
		```c
		(lldb) p/t 0x00007ffffffffff8ULL
		(unsigned long long) $0 = 0b0000000000000000011111111111111111111111111111111111111111111000
		```
		也就是取 `64` 后面的 `47` 位，也就是 `cls` 的值。
		
	* 位运算：`shiftcls` 存在 `3~46` 位上，所以可以做如下运算：
	
		![isa_cal.png](https://i.loli.net/2020/01/04/W8vRmtV9J26ufGF.png)
		
		也就是取中间的 `44` 的值，然后在后面补 `3` 个`0`之后就是 `cls` 的地址了。
		
`cls` 的地址已经存放到 `isa` 里面了，后面我们就可通过 `isa` 找到类，然后进行方法的调用等动作了。

### isa 的走位
是时候来一张经典的 `isa` 走位图了：

<div style="text-align: center;"><img src="https://i.loli.net/2020/01/04/1JUZOVfivDSKawh.png" width="50%"></div>

这张图怎么理解呢？我们先来看一个例子：

![isa_examp.png](https://i.loli.net/2020/01/08/89LGyPbQrZCk5sR.png)

在 OC 的继承链中，万物皆对象，所以他们都有 `isa` 指针，而 `isa` 的存储的值，就是上面走位图中虚线的走向：

* 对象的 `isa` -> 类
* 类的 `isa` -> 元类
* 元类的 `isa` -> 根元类
* 根元类的 `isa` -> 根元类
 
其中比较特殊的点在于 `NSObject`，`NSObject`因为是 OC 对象的根类的原因:

* `NSObject` 对象的 `isa` 指向 `NSObject` 类
* `NSObject` 类的 `isa` 指向 `NSObject` 元类
* `NSObject` 元类的 `isa` 指向自己，即根元类的 `isa` 指向自己

上面的图中还要另外一条线，即 `superclass` 的继承链：

* 类的继承，`superclass` 指向父类
* 元类的继承，`superclass` 指向父元类
* 根类`NSObject`的 `superclass` 指向 nil
* 根元类的 `superclass` 指向根类

根据这个有个很有意思的面试题：

![isa_test.png](https://i.loli.net/2020/01/05/ji75Gw3YkqS6zQn.png)

这里考察的就是对 `isa` 的理解：

首先我们看下 `isKindOfClass` 和 `isMemberOfClass` 的源码：

```objc
+ (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = object_getClass((id)self); tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)cls {
    for (Class tcls = [self class]; tcls; tcls = tcls->superclass) {
        if (tcls == cls) return YES;
    }
    return NO;
}
```

```objc
+ (BOOL)isMemberOfClass:(Class)cls {
    return object_getClass((id)self) == cls;
}

- (BOOL)isMemberOfClass:(Class)cls {
    return [self class] == cls;
}
```

这两个方法的实现都不复杂，`isKindOfClass` 里面有一个循环，会通过 `superclass` 一直找到 `NSObject`。

上面的面试题中：

* `re1, re2, re3, re4` 考察的是类与元类，根元类与根类之间的关系
* `re5, re6, re7, re8` 考察的是对象与类之间的关系
