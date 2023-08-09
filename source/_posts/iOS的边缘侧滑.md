---
title: UIScrollView 动画过程中视图不响应 touch 事件
categories: 疑难杂症
tags: [iOS]
---

iOS7 之前，滑动返回这个事儿是不被官方支持的，开发者需要自己实现，进入 iOS7 时代，苹果为了提升用户体验，增加了**边缘侧滑**的手势。注意这里的**边缘**，如果需要实现**全屏**滑动返回 还是需要开发者自己来实现的。

<!-- more -->

注意侧滑返回在以下几种情况下是会失效的：

1. 隐藏导航栏： `isNavigationBarHidden = true`
2. 隐藏返回按钮： `navigationItem.hidesBackButton = true`
3. 自定义了： `leftBarButtonItem 或者 leftBarButtonItems`

### 基于自定义导航栏下解决边缘侧滑失效的问题

我们知道，侧滑返回 的实现基于 `UINavigationController` 的手势 `interactivePopGestureRecognizer`，我们可以通过代理这个手势达到我们的目的。

#### 边缘侧滑返回

首先自定义一个继承字 `UINavigationController` 的子类：

```swift
class SMNavigationViewController: UINavigationController { 
    override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
        isNavigationBarHidden = true
    }
}
```

然后实现手势的代理协议：

```swift
extension SMNavigationViewController: UIGestureRecognizerDelegate {
 
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 这里限制了当导航栈里元素的数量，只有大于1个的情况下才支持侧滑返回
        return viewControllers.count > 1
    }
}
```

到这里，我们已经实现了边缘侧滑返回的功能了。
当然，上面这种基本适用于因为导航栏导致的侧滑失效的问题了，但并不排除还有其他的解决办法。
例如返回按钮，可以自定义返回按钮等。
例如 `TZScrollViewPopGesture` 这个库，他不仅支持了边缘侧滑返回，更主要的是他解决了因为 scrollView 导致边缘侧滑失效的问题。
还有 `FDFullscreenPopGesture` 这个库，主要是实现了**全屏侧滑**的功能。

#### 灵活控制侧滑功能

如果我们还想灵活控制某些页面不支持侧滑返回的话，可以自定义一个协议：

```swift
protocol SMPopGestureDelegate: NSObjectProtocol {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
}
 
extension UIViewController:  SMPopGestureDelegate{
    // 给每个控制器一个默认实现，默认支持侧滑
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
```

在不需要侧滑返回的控制器：

```swift
extension XxController:  SMPopGestureDelegate{
    // 给每个控制器一个默认实现，默认支持侧滑
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}
```

然后在 interactivePopGestureRecognizer 的代理方法：

```swift
extension SMNavigationViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let topController = self.topViewController as? SMPopGestureDelegate {
            return topController.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        return viewControllers.count > 1
    }
}
```

### 当手势冲突时边缘侧滑返回失效的问题

在解决因手势冲突造成的侧滑返回失效的问题之前，我们先来了解下手势的优先级以及 UIGestureRecognizerDelegate 的几个方法。

#### 手势优先级

如果有两个手势，我们需要设置优先级的时候，就会调用方法：

```swift
func require(toFail otherGestureRecognizer: UIGestureRecognizer)
```

这个方法的作用就是在两个有可能冲突的手势之间创建一个关系，只有当 otherGestureRecognizer 手势失败的时候，才响应手势，例如同时添加的单击手势和双击手势的时候，当双击手势响应失败的时候才响应单击手势：

```swift
let singalTap = UITapGestureRecognizer(target: self, action: #selector(onSingalTap))
let doubleTap = UITapGestureRecognizer(target: self, action: #selector(onDoubleTap))
doubleTap.numberOfTapsRequired = 2
singalTap.require(toFail: doubleTap)
```

#### 一些手势代理方法

一般手势识别：

```swift
// 开始进行手势识别时调用的方法，返回 false 则结束，不再触发手势
func gestureRecognizerShouldBegin(UIGestureRecognizer) -> Bool 

// ① 是否接收 touch，返回 false 则不在继续手势识别、方法触发等。
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                         shouldReceive touch: UITouch) -> Bool
// ② 是否接收 press，返回 false 则阻止继续手势识别、方法触发等               
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                         shouldReceive press: UIPress) -> Bool
// 是否接收手势事件，返回 false 则不在响应手势。在方法 ①② 之前调用
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
                         shouldReceive event: UIEvent) -> Bool
```
手势同时识别：

```
// 是否允许同时识别两个手势，默认返回 false, 返回 true 表示这两个手势同时识别
// 返回 true 时能保证两个手势同时识别, 手势被传递给接受者处理
// 返回 false 不能保证不被同时识别，因为另一个手势代理可能返回 true
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
```

失败控制：

```swift
// 当同时识别到另一个手势时，是否要求该手势失败
// 返回 true，第一个会失效, 默认返回 false
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
         shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool

// 当同时识别到另一个手势时，是否要求另一个手势失败
// 返回 true, 第二个手势会失效, 默认返回 false
func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, 
       shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool
```

#### 侧滑冲突的解决办法

什么情况下边缘侧滑会因为手势冲突时失效呢？这很好回答：

* `Web Controller· 失效，webView 页面比较特殊，不仅右滑返回会失效，自定义的手势也会全部失效，因为 `WebView` 中已经内部集成了点击、滑动等多个手势，上面的方法在 ·UIWebView· 中并没有作用，解决办法是允许多个手势并发的代理方法，即

	```swift
	extension WebViewController {
	    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
	        return true
	    }
	}
	```
	
* 当使用 `UIScrollView` 、`UITableView` 、`UICollectionView` 等滑动视图的左右滑动时，滑动手势就会和右滑返回的手势冲突，右滑返回就会失效。

针对上述第二种的解决办法：

1. 因为侧滑手势的优先级最大，所以可以在 NavigationController 中：

	```swift
	extension SMNavigationViewController: UIGestureRecognizerDelegate {    
	    // 侧滑优先级最大，当手势冲突时，直接让另一个手势失败，优先响应侧滑返回
	    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
	        return true
	    }
	}
	```
当然，具体的情况可能还需要结合自己的业务来决定。
2. 针对这种情况，有一种是直接在 controller 设置手势的优先级：

	```swift
	if let gesture = self.navigationController?.interactivePopGestureRecognizer {
	    scrollView.panGestureRecognizer.require(toFail: gesture)
	}
	```
但是我并没有获得成功，原因暂未可知 o(╥﹏╥)o

3. 使用 `TZScrollViewPopGesture` 库，主要思路是实现一个自己的侧滑手势
4. 还有另外一种奇淫技巧：
	> 在 vc 的 view 的左侧贴一层宽 10 长 view 长度的透明 view 
	
但是这种我并没有实验，有兴趣的可以试试 (*￣︶￣)

### 参考

* [手势优先级](https://www.jianshu.com/p/10f6c8b1844c)
* [手势滑动返回](https://juejin.cn/post/6860656306630590477#heading-2)
* [一行代码，让你的应用中UIScrollView的滑动与侧滑返回并存](https://www.jianshu.com/p/8170fea174da)