---
title: CAGradientLayer
categories: 工具代码
tags: [iOS]
---

`CAGradientLayer` 继承自 `CALayer`, `CALayer` 有的属性 `CAGradientLayer`都有，同时 `CAGradientLayer` 又新增了一些属性，用以实现渐变色。

<!--more-->

### GradientLayer 的用法
 关于`CAGradientLayer`的用法，网络上已经有很多优秀的文章来介绍了，这里就不多做赘述，贴上链接共参考  [CAGradientLayer的一些属性解析](http://www.tuicool.com/articles/RZBFBn)。

### 使用CAGradientLayer
#### CAGradiengLayer 的渐变方向

```
@property CGPoint startPoint;
@property CGPoint endPoint
```

大家在使用`CAGradientLayer`的过程中，肯定都用过这两个属性，见名知意，这两个属性告诉`Layer`的起点和终点（注意这里的坐标系），在深入研究就会发现，这两个属性组合在一起时可以决定渐变的**方向**的，并且这两个属性都有默认值，分别是[.5,0] 和 [.5,1]。
![gra.png](https://s2.loli.net/2021/12/24/LX9dKwzVJxsQMeo.png)

从上图中的坐标空间中也可看出，在结合着两个属性的默认值，不难发现默认的渐变方向是**竖直方向**的。要改变渐变方向，只需要对这两个属性做操作就可实现。

```objc
 typedef NS_ENUM(NSInteger, GradientOrientationStyle) {
        GradientOrientationStyleVertical = 0, //竖直方向
        GradientOrientationStyleHorizontal,   //水平方向
        GradientOrientationStyleArriswise     //对角线方向
};
```
   
下面的代码是根据方向来设置 `endPoint`
     
```objc
- (CGPoint)endPoint {
        CGFloat endX = 1 * self.ratio;
        CGFloat endY = 1 * self.ratio;
        if (self.orientationStyle == GradientOrientationStyleVertical) {
            endX = 0;
        } else if (self.orientationStyle == GradientOrientationStyleHorizontal) {
            endY = 0;
        }
        return CGPointMake(endX, endY);
}
```

![direction.gif](https://s2.loli.net/2021/12/24/XVlAs64NBIeyj8J.gif)

#### CAGradientLayer 的动画效果
中所周知 CALayer 默认是有隐士动画的，动画的持续时间是 1/4 s，但有时候你不想要这个动画怎么办呢？

 * CATransaction 可以关闭隐式动画

	```objc
	[CATransaction begin];
	[CATransaction setDisableActions:!_animated];
	[CATransaction commit];
	```

	利用空余时间写了个进度条的 demo，有个地方没有处理好，还请各路大神指导。

	![progress.gif](https://s2.loli.net/2021/12/24/zCAQ8OmVWcdnpkX.gif)

最后附上一篇[高级动画技巧](https://zsisme.gitbooks.io/ios-/content/chapter6/cagradientLayer.html)。
demo 链接请戳[这里](https://github.com/redye/Demo/tree/master/GradientDemo)，不对的地方还请多加指正。