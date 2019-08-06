---
title: JavaScriptCore
categories: 工具代码
tags: [iOS, JavaScriptCore]
---

JavaScriptCore 为原生编程语言 Objective-C、Swift 提供调用 JavaScript 程序的动态能力，也能为 JavaScript 提供原生能力来弥补前端欠缺的能力。

<!--more-->

正是因为 JavaScriptCore 的这种桥梁作用，出现了很多使用 JavaScriptCore 开发 APP 的框架，比如 React-Native、Weex、小程序、Web Hybrid 等框架。

### JavaScriptCore 背景

JavaScriptCore，原本是 WebKit 中用来解释执行 JavaScript 代码的核心引擎。解释执行 JavaScript 代码的引擎自 JavaScript 诞生起就有，不断演进，一直发展到今天，如今苹果公司有 JavaScriptCore 引擎、谷歌有 V8 引擎、Mozilla 有 SpiderMonkey。

iOS7 之前，苹果没有开放 JavaScriptCore 引擎。如果你想使用 JavaScriptCore 的话，需要手动的从开源 WebKit 中编译出来，其接口都是 C 语言，这对于 iOS 开发者来说非常不友好。

从 iOS7 开始，苹果将 JavaScriptCore 框架引入 iOS 系统，将其作为系统级的框架提供给开发者使用。框架名是 JavaScriptCore.framework。

### JavaScriptCore 框架

苹果对 JavaScriptCore 框架的说明，你可以点击[这个链接](https://developer.apple.com/documentation/javascriptcore)查看。从结构上看 JavaScriptCore 框架主要有 JSVritualMachine、JSContext、JSValue 类组成。

* JSVirtualMachine 的作用，是为 JavaScript 代码的运行提供一个虚拟环境。在同一时间内，JSVirtualMachine 只能执行一个线程。如果想要多个线程执行任务，可以创建多个 JSVirtualMachine。每个 JSVirtualMachine 都有自己的 GC（Garbage Collector，垃圾回收器），以便进行内存管理，所以多个 JSVirtualMachine 之间的对象无法传递。

* JSContext 是 JavaScript 运行环境的上下文，负责原生和 JavaScript 的数据传递。

* JSValue 是 JavaScript 的值对象，用来记录 JavaScript 的原始值，并提供与原生值对象转换的接口方法。

<div align=center><img src="https://i.loli.net/2019/08/06/AqlBRvtd31TMPox.jpg" width="40%" /></div>

从图可以看出，JSVirtualMachine 包含多个 JSContext，同一个 JSContext 又包含多个 JSValue。

JSVritualMachine、JSContext、JSValue 类提供的接口，能够让原生应用执行 JavaScript 代码，访问 JavaScript 变量，访问和执行 JavaScript 函数，也能够让 JavaScript 执行原生代码，使用原生输出的类。

### JavaScriptCore 与原生交互

JavaScriptCore 想要与原生进行交互，首先需要有 JSContext，在 UIWebView 的时代，我们可以通过 KVC 的方式取得当前 UIWebView 的 JSContext，到 iOS8 WKWebView 问世之后，苹果提供了更方便的方式 -- `messageHandlers` 。 

```objc
- (JSContext *)currentContext {
    JSContext *context = [self.webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    return context;
}
```

获取到 JSContext 之后，就可以进行原生与 JavaScript 之间的交互了。

#### 原生调用 JS 
首先，原生调用 JS 的函数或变量：

在 JS 端：

```js
function getNumber(num) {
	return num * 10;
}
```

在 OC 端：

```objc
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSLog(@"web view did finished");
    
    JSContext *context = [self currentContext];
    
    JSValue *getNumber = context[@"getNumber"];
    JSValue *number = [getNumber callWithArguments:@[@(1)]];
    NSLog(@"number ==> %@", [number toNumber]); // number ==> 10
}
```
注意这里的 `JSValue *getNumber = context[@"getNumber"];` 

`getNumber` 是一个函数，然后通过 `callWithArguments` 方式传入参数执行，获得返回值，返回值同样是一个 JSValue 类型。JSValue 封装了很多类似 `toNumber` 这样转换成 OC 类型的接口。

同样，也可以获取变量的值：

```objc
[context evaluateScript:@"var i = 4 + 8;"];
NSNumber *i = [context[@"i"] toNumber];
NSLog(@"i ==> %@", i);  // i ==> 12
```

#### JS 调用原生

同样的，也可以通过 JSContext 提供方法供 JS 调用:

```objc
- (void)addMethonds:(JSContext *)context {
    __weak typeof(self) weakSelf = self;
    
    context[@"alert"] = ^(NSString *title, NSString *message) {
        [weakSelf alert:title message:message]; // ①
    };
    
    context[@"add"] = ^(int x, int y) {
        return x + y;
    };
}

- (void)alert:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{ // ②
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [controller addAction:action];
        
        [self presentViewController:controller animated:YES completion:nil];
    });
}
```
注意上面的 ① 和 ② :

① 处使用 weak self， 为了打破循环引用。JSContext 会强引用 self。

② 处切换到主线程。前面已经说过每个 JSVirtualMachine 是一个单独的线程，在这里就是一个原生的子线程，而有关于 UI 的操作都需要在主线程操作，所以这里需要切换到主线程执行。

然后在 JS 就可以直接调用 `alert` 方法了：

```js
function onClick() {
	alert('title', 'message');
}
```

当然，原生也可以同样调用这些方法:

```objc
//	JSValue *value = [context evaluateScript:@"add(4, 8)"]; // 直接执行
JSValue *add = context[@"add"];
JSValue *value = [add callWithArguments:@[@4, @8]]; // 通过传参的方式执行
NSLog(@"value ==> %@", [value toNumber]);

[context evaluateScript:[NSString stringWithFormat:@"alert('title', '%@')", [value toNumber]]];
```

#### JSExport

除了 Block 外，我们还可以通过 JSExport 协议来实现在 JS 中调用原生代码。

```objc
@protocol SMPolyfillSetJSExports <JSExport>

//- (void)alert:(NSString *)title message:(NSString *)message buttons:(NSArray *)buttons;

JSExportAs(alert, - (void)alert:(NSString *)title message:(NSString *)message buttons:(NSArray *)buttons);

JSExportAs(share, - (void)share:(NSDictionary *)shareContent);

@end

@interface SMPolyfillSet : NSObject<SMPolyfillSetJSExports>

@property (nonatomic, readonly) JSContext *context;

+ (instancetype)createWithContext:(JSContext *)context;

@end
```

在 .m 文件中实现这些协议方法：

```objc
#import "SMPolyfillSet.h"

@interface SMPolyfillSet ()

@property (nonatomic, strong) JSContext *context;

@end

@implementation SMPolyfillSet

+ (instancetype)createWithContext:(JSContext *)context {
    SMPolyfillSet *polyfillSet = [[SMPolyfillSet alloc] init];
    polyfillSet.context = context;
    return polyfillSet;
}

- (void)alert:(NSString *)title
      message:(NSString *)message
      buttons:(NSArray *)buttons {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        
        __weak typeof(self) weakSelf = self;
        [buttons enumerateObjectsUsingBlock:^(NSDictionary *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:[obj objectForKey:@"title"]
                                                             style:[[obj objectForKey:@"style"] integerValue]
                                                           handler:^(UIAlertAction * _Nonnull action) {
                                                               NSString *method = [obj objectForKey:@"callback"];
                                                               NSArray *args = @[@(idx)];
                                                               JSValue *callback = weakSelf.context[method];
                                                               [callback callWithArguments:args];
                                                           }];
            [controller addAction:action];
        }];
        [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:controller animated:YES completion:nil];
    });
}

- (void)share:(NSDictionary *)shareContent {
    NSLog(@"share ==> %@", shareContent);
}

@end

```

这里注意 `JSExportAs` 宏:

```objc
#define JSExportAs(PropertyName, Selector) \
    @optional Selector __JS_EXPORT_AS__##PropertyName:(id)argument; @required Selector
```
*PropertyName* 就是暴露给 JS 调用的方法名了。

如果不用 `JSExportAs` 同样也是可以的，但是按照 OC 方法的命名规则，暴露给 JS 调用的方法名会按照驼峰规则重新拼接。

例如上面的 `alert` 方法：

```objc
- (void)alert:(NSString *)title message:(NSString *)message buttons:(NSArray *)buttons;
```

在 JS 里面调用就会变成 `alertMessageButtons()`:

<div align=center><img src="https://i.loli.net/2019/08/06/4sxr9dzj8EpWtBa.jpg" width="75%"/></div>

这样看起来有些怪异，如果命名不规范的话，会引起各种混乱或误解。

还有一点需要注意，只有在协议中定义的方法和属性才能够在JS中被调用。

使用 `SMPolyfillSet`:

```objc
_polyfillSet = [SMPolyfillSet createWithContext:context];
context[@"PolyFill"] = _polyfillSet;
```

```js
function onAlert(title, message) {
	PolyFill.alert(title, message, [{
		title: '取消',
		style: 1,
		callback: 'log'
	}, {
		title: '确定',
		style: 0,
		callback: 'log'
	}]);
}
```

使用遵循 JSExport 协议的类来实现 JS 调用原生方法，具有很大优势：

* 不在需要在某个具体的页面添加方法。
* 可以针对不同的模块，创建不同的实体，JS 端也可以根据模块来调用方法。

案例请戳[这里](https://github.com/redye/IOSMasterProj/tree/master/IOSMasterProj/JS)。

### 推荐阅读

* [深入剖析 JavaScriptCore](https://ming1016.github.io/2018/04/21/deeply-analyse-javascriptcore/)