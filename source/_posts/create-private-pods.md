---
title: 创建私有库
categories: 工具代码
tags: [iOS, Cocoapods]
---

## 本地添加私有库
```ruby
pod repo add specsName gitURL

// example
pod repo add YHSpecs https://github.com/redye/YHSpecs.git
```

## 创建私有工程
```
pod lib create WFRFoundation // WFRFoundation 是私有工程的名称
```
在创建的时候，会去下载模板，并且会询问你一些基础的配置

<!-- more -->

```
What platform do you want to use?? [ iOS / macOS ]
 > iOS

What language do you want to use?? [ Swift / ObjC ]
 > ObjC

Would you like to include a demo application with your library? [ Yes / No ]
 > Yes

Which testing frameworks will you use? [ Specta / Kiwi / None ]
 > None

Would you like to do view based testing? [ Yes / No ]
 > No  

What is your class prefix?
 > WFR

```
接下来就等待初始化工程就好了 😊

## 私有工程的目录结构
```
|———— WFRFoundation
| 	  |———— Podspec Metadata
| 	  |———— Example for WFRFoundation
| 	  |———— Tests
| 	  |———— Frameworks
| 	  |———— Products
| 	  |———— Pods
|———— Pods
| 	  |———— Podfile
| 	  |———— Development Pods
| 	  |———— Frameworks
| 	  |———— Pods
| 	  |———— Products
| 	  |———— Targets Support Files
```
工程的目录结构与在使用 pod 工程时相似，只是在工程目录下面多了 *私有仓库* 的元数据，在 *pod* 目录下增加了 开发目录 `Development Pods`。我们在开发私有库的时候，代码就写在这个目录下面。`Example` 用于我们调试我们编写的代码。

## podspec 
在我们创作私有库的过程中，与我们平时编写代码并没有什么不同，但是我们怎么样才能将我们写的代码变成库来引用，这就需要依靠 `podspec` 文件了。

podspec 文件是 cocoapods 引入第三方代码库的配置索引文件，它是采用 ruby 编写的。

这里推荐阅读 [iOS开发之podspec文件编写](http://mo.rakuyo.cn/2018/04/23/48-iOS%E5%BC%80%E5%8F%91%E4%B9%8Bpodspec%E6%96%87%E4%BB%B6%E7%BC%96%E5%86%99/)，作者写的很清楚详细。那些前人踩过的坑，现在都变成了我们的财富，感谢~