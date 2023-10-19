---
title: iOS 对 SDK不支持模拟器调试适配
categories: 疑难杂症
tags: [iOS]
---

开发中，偶尔会遇到部分SDK不支持模拟器，于是，我们需要进行一些适配工作。

<!--more-->

首先，在Target -> BuildSettings -> Excluded Source FileNames -> Debug、Release 中添加一行，key选择 Any iOS Simulator SDK，value 中添加报错中提示的 SDK的目录，如下图

![](https://pic.imgdb.cn/item/64f6974d661c6c8e548f5427.png)


然后，在项目中，引用对应 SDK 头文件，以及使用 SDK 方法的地方添加如下代码判断

```objc
#if !TARGET_IPHONE_SIMULATOR
#import <xxx/xxx.h>
#endif
```

```swift
#if !targetEnvironment(simulator)
    ....
#endif
```