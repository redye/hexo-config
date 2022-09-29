---
title: UIScrollView 动画过程中视图不响应 touch 事件
categories: 疑难杂症
tags: [iOS]
---

首先这是一个使用`UIView`完成的循环动画:
     
```   
[UIView animateWithDuration:kCarouselViewAnimationDuration delay:kCarouselViewAnimationDelay options:UIViewAnimationOptionCurveLinear animations:^{
    CGPoint offset = self.scrollView.contentOffset;
    self.scrollView.contentOffset = CGPointMake(offset.x + kCarouselViewWidth, offset.y);
} completion:^(BOOL finished) {
    [self updateUI];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self animation];
    });
}];
```

<!--more-->

在动画过程中，`scrollView` 暂时失去了他的滑动事件，并且添加在上面的 `tap` 事件也没有响应。
自己寻找原因无果，在 stackoverflow 找到[答案](http://stackoverflow.com/questions/3614116/uiscrollview-touch-events-during-animation-not-firing-with-animatewithduration)。
另外 cocoachina 上也有[讨论](http://www.cocoachina.com/bbs/read.php?tid-67717.html)。

> 在使用 options 动画过程中，默认是不响应事件的，可以使用 
`UIViewAnimationOptionAllowUserInteraction`响应事件。

```
[UIView animateWithDuration:kCarouselViewAnimationDuration delay:kCarouselViewAnimationDelay options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{
    CGPoint offset = self.scrollView.contentOffset;
    self.scrollView.contentOffset = CGPointMake(offset.x + kCarouselViewWidth, offset.y);
} completion:^(BOOL finished) {
    [self updateUI];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self animation];
    });
}];
```

