---
title: 崩溃日志符号化
categories: 工具代码
tags: [iOS]
---

最近项目中经常遇到 app 莫名卡住不动的情况，也没有 crash，但就是不给你一点反应。而且也只在真机上出现。最开始一直以为可能是自己手机太年长的缘故(6s表示这个锅我不背🙅‍♂️)，直到则测试小姐姐那亲眼目睹了同样的情况/(ㄒoㄒ)/~~

想到自己集成了 bugly，就上去瞅了瞅，嗯，很干净，why??

app 页面卡住不动，主线程被阻塞了？

仔细想来，好像并没有什么阻塞主线程的情况 ┑(￣Д ￣)┍

因为手机上也遇到类似的情况，那就去看看手机上的崩溃日志吧。

虽然 bugly 并没有捕捉到这些 crash，但是手机上的崩溃日志是诚实的，他们都好好的待在他们该在的地方，等着你 (╯﹏╰)

打开崩溃日志，你以为你会看到完整的崩溃调用栈？oh，你真是太天真了

<!-- more -->

当然了，你能看到 crash 的类型，和原因，就类似于下面这种 

```
Exception Type:  EXC_BREAKPOINT (SIGTRAP)
Exception Codes: 0x0000000000000001, 0x000000019d0df774
Termination Signal: Trace/BPT trap: 5
Termination Reason: Namespace SIGNAL, Code 0x5
Terminating Process: exc handler [8199]
Triggered by Thread:  0
```

当你接着去看触发线程的调用栈的时候，你会发现，除了系统提供的 API 被符号化出来之外，你自己的代码只能看到十六进制的符号和地址，参考下面

![carsh callee](https://i.loli.net/2019/04/10/5cadcea9b1a63.jpg)


Excuse me？我兴致勃勃的来，你就给我看这个？

好吧，尽管你虐我千百遍，我还是会待你如初恋，那我要怎样揭开挡在眼前的面纱呢，答案就是对他进行 **符号化**

进行符号化之前，我们需要准备几样东西

* .crash 文件，就是崩溃日志，这个简单，直接导出就好
* .dSYM 文件，打包 app 时生成的，.xcarchive 文件包内容
* .app 文件，ipa 包解压后
* 符号化工具 symbolicatecrash

#### 符号化工具 symbolicatecrash

符号化工具位置在

```
/Applications/Xcode.app/Contents/SharedFrameworks/DVTFoundation.framework/Versions/A/Resources/symbolicatecrash
```

你也可以通过下面的命令找到他

```
find /Applications/Xcode.app -name symbolicatecrash -type f
```

拿到 `symbolicatecrash` 后，复制到你进行符号化的目录下即可。

在进行符号化之前，要确保 .crash 文件和 .dSYM 文件对应的 UUID 是否一致。你可以通过下面的命令看到 .dSYM 的 UUID

```
dwarfdump --uuid xxx.app.dSYM
```

输出

```
UUID: FA7B0745-5ED4-3CF0-A985-AD96EC8A557B (armv7) HocDev.app.dSYM/Contents/Resources/DWARF/xxx
UUID: 39F50F1D-560B-3D0B-9FA7-45BE60FFFA3A (arm64) HocDev.app.dSYM/Contents/Resources/DWARF/xxx
```

崩溃日志的UUID位于日志中Binary Images第一行尖括号内。

![uuid](https://i.loli.net/2019/04/10/5cadcf31c8404.jpg)

四件套准备齐全后，就可以愉快的进行我们的符号化啦

```
./symbolicatecrash xxx.crash xxx.app.dSYM xxx.app > crash.cransh
```

你可能会遇到 

```
Error: "DEVELOPER_DIR" is not defined at ./symbolicatecrash line 69.
```

这个时候就需要你配置环境变量 `DEVELOPER_DIR`

```
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
```

后面在执行上面的符号化命令就可以了。

![symbol.crash](https://i.loli.net/2019/04/10/5cadcf345eeac.jpg)