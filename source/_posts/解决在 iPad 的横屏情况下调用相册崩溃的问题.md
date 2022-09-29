---
title: 解决在 iPad 的横屏情况下调用相册崩溃的问题
categories: 疑难杂症
tags: [iOS]
---

在最近的项目中，因为要给设置头像，需要访问到相册，本来觉得这是一个很简单的问题，直接调用 UIImagePickerController 从相册选择照片就可以了，一直以来也是这么做的，但是以前都是在 iPhone 上实现的，这次是在 iPad 上实现，并且我们的项目是只支持横屏的，所以在调用相册的时候，程序直接就 crash 了，这是让我没有想到的，错误原因是：

<!--more-->

Supported orientations has no common orientation with the application, and [PUUIAlbumListViewController shouldAutorotate] is returning YES

在网上查阅到的解决办法大都是该 UIImagePickerViewController 添加一个类别，重写它的设备方向的方法，下面是一个 stack overflow 上面的[答案](http://stackoverflow.com/questions/12540597/supported-orientations-has-no-common-orientation-with-the-application-and-shoul?lq=1)

![nonrotating.png](https://s2.loli.net/2021/12/24/vGgILsO34Vye16K.png)

在程序中我试过这种方法，然而并没有什么用。

同时在这个答案的下面还有另外一种方法，是可以解决程序崩溃的，但是这种呈现的效果，好吧，我不想吐槽 ╮(╯▽╰)╭

将图片的取景框放在当前的视图上，sourceRect 决定放的位置，直接截取了

![popover.png](https://s2.loli.net/2021/12/24/xOiTmZ4ScAgUVdW.png)

这种呈现的效果就是像 `UIPopoverController` 的效果。

但是的但是，这并不是我要的效果，难道就没有其他的解决办法了吗，哦，my god .

被这个问题困扰了挺长一段时间的，但是庆幸，后来还是解决了，先给自己赞一个  (*^__^*)

还是受 stack overflow 上面的解决办法的启发，既然相册不支持横屏，那就是说在调用相册的时候让设备支持所有方向就好了，当取消相册的时候在让设备又只支持横屏好了，当时只是在调用相册的那个 viewController 中重写设备支持方法，结果自然是没有什么卵用，后来尝试在入口类里重写方法

```
- (NSUInteger)application:(UIApplication*)application supportedInterfaceOrientationsForWindow:(UIWindow*)window {        
	returnUIInterfaceOrientationMaskAll;  
}
```

这样自然是可以的，但是这样造成的问题就是，当取消相册的时候，设备并没能切回只支持横屏，到了这一步，能想到的是就是当调用和取消调用相册的时候通知设备应该支持哪些方向，设置头像的 `viewController` 层次比较深，本来准备使用通知，但是并没有成功，具体的原因有些忘记了，⊙﹏⊙b汗

正在冥思苦想的时候，突然意识到我在项目里有运用到 单例类，就想说我是不是能给单例类一个标识，用来标识是否在调用相册，最后的结果是这样的

![photo.png](https://s2.loli.net/2021/12/24/jfJwPO61kRCbAuy.png)

实验的结果自然是成功的，切回当前程序的时候，旋转屏幕，并没有发生 UI 离开位置的情况，但使用过程中，还有一个地方不是很好，就是调用相册的时候，相册显示是以竖屏的状态呈现的，用户在使用的时候要先旋转屏幕到竖屏，切回程序的时候又要旋转回横屏，使用起来不是很舒服，最后想到的解决办法是给 UIImagePickerController 指定支持的方向为 横屏方向

![non.png](https://s2.loli.net/2021/12/24/MDY591n6kK3lIWj.png)

总结了一下，每次调用一个 视图控制器 的时候，都会调用指定支持屏幕的方法 `- (UIInterfaceOrientationMask)application:(UIApplication*)application supportedInterfaceOrientationsForWindow:(UIWindow *)window` 同时在一个视图控制器显示的时候，会调用自己的 支持屏幕方向`supportedInterfaceOrientations`的方法，所以才能在`UIImagePickerController`显示的时候通过指定支持方向来改变 其在用户面前展现的方向。