---
title: 私有库打包 framework
categories: 工具代码
tags: [iOS, Cocoapods]
---

制作一个 framework 除了使用 Xcode 创建一个 framework 的工程外，还有没有别的办法呢？这里既然是一个 CocoaPods 的教程，那么我们自然是希望能通过 cocoapods 来完成。
cocoapods 提供了一个插件来帮助你。

<!-- more -->

[CocoaPods-Packager](https://github.com/CocoaPods/cocoapods-packager)

### CocoaPods-Packager 安装与使用

接下来就是，使用下面的命令安装它

```
sudo gem install cocoapods-packager
```

安装完成后，使用下面的命令打包 framework

```ruby
pod package WFRFoundation.podspec [--force] [--library] [--verbose] ...
```

命令后面的参数说明：

``` 
# 强制覆盖之前已经生成过的二进制库
--force 

# 生成嵌入式 .framework (静态 framework)
--embedded 

# 生成静态 .a 
--library 

# 生成动态 .framework 
--dynamic 

# 动态 .framework 是需要签名的，所以只有生成动态库的时候需要这个 BundleId 
--bundle-identifier

# 不包含依赖的符号表，生成动态库的时候不能包含这个命令
# 动态库一定需要包含依赖的符号表。 
--exclude-deps

# 表示生成的库是 debug 还是 release，默认是 release
# --configuration=Debug 
--configuration

# 表示不使用 name mangling 技术，pod package 默认是使用这个技术的。
# * 我们能在用 pod package 生成二进制库的时候会看到终端有输出 Mangling symbols 和 Building mangled framework，表示使用了这个技术。
# * 如果你的 pod 库没有其他静态库(*.a/*.framework)依赖的话，那么不使用这个命令也不会报错。
# * 但是如果有其他静态库依赖，不使用 --no-mangle 这个命令的话，那么你在工程里使用生成的二进制库的时候就会报错：Undefined symbols for architecture x86_64。
--no-mangle

# 如果你的 pod 库有 subspec，那么加上这个命名表示只给某个或几个 subspec 生成二进制库
# * --subspecs=subspec1,subspec2
# * 生成的库的名字就是你 podspec 的名字，如果你想生成的库的名字跟 subspec 的名字一样，那么就需要修改 podspec 的名字。 
# * 这个脚本就是批量生成 subspec 的二进制库
--subspecs

# 一些依赖的 source
# * 如果你有依赖是来自于私有库的，那就需要加上那个私有库的 source
# * 默认是 cocoapods 的 Specs 仓库。
# * --spec-sources=private,https://github.com/CocoaPods/Specs.git。
--spec-sources
```

**注意，在 `pod package` 之前，你需要将代码提交到远程，并且打上 tag，因为 pod package 是通过git 的 commit 索引或者 tag 来找源码的.因此对外发布时候一定要在 s.version 中指定tag 的标签，在 git 中给定的 commit 打上 tag。**

🌰🌰🌰

```ruby
pod package WFRFoundation.podspec --force
```
在这个过程中还是无法避免踩到坑，编译执行后会报了如下错误

```
Undefined symbols for architecture x86_64:
  "_OBJC_CLASS_$_ASIdentifierManager", referenced from:
      objc-class-ref in WFRFoundation(WFRXxx.o)
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```
原谅此处的我 o((⊙﹏⊙))o
大家看到这个错误，是不是都有一种很熟悉的感觉，基本上每个做过 iOS 开发的小伙伴应该都遇到过，特别是开发过程中涉及到第三方库或框架的时候。

从错误来看，他说不支持 x86_64 的架构，那好，换成真机再试一次，这次换成不支持 arm64 的架构了...

pod package 真的这么蠢的吗，相信我，做为一个经过时间检验的工具不会这么 low 的，错的还是自己

用如下命令查看 framework 支持的架构

```
lipo -info WFRFoundation.framework/WFRFoundation
```
输出的结果很正常，模拟器、手机架构都支持

```
Architectures in the fat file: WFRFoundation.framework/WFRFoundation are: armv7 armv7s i386 x86_64 arm64 
```
那为什么还会出现这种错误呢，首先我们查看下 framework 是静态的还是动态的，cd 到 WFRFoundation.framework 目录下，`file WFRFoundation` 查看库文件

```
WFRFoundation: Mach-O universal binary with 5 architectures: [arm_v7:current ar archive] [arm64]
WFRFoundation (for architecture armv7):	current ar archive
WFRFoundation (for architecture armv7s):	current ar archive
WFRFoundation (for architecture i386):	current ar archive
WFRFoundation (for architecture x86_64):	current ar archive
WFRFoundation (for architecture arm64):	current ar archive
```
有 dynamically 标识着是动态库，反之则是静态库。

从这里看出来，`pod package` 默认打包静态库。

既然不是指令集的问题，那就应该是链接静态库的时候出问题了，按照大多数的解决办法，只需要在 Linked Frameworks and Libraries 中添加指定的静态库。但是这里会不一样，这根 CocoaPods 的运行原理有关，我们可以在 Build Phases 处看到，要以来的 framework 是存在的，那么为什么还是会报错呢？

最后注意到 **`_ASIdentifierManager`**，因为这里有引用到 `AdSupport` 的库，而静态库在使用的时候，需要手动导入静态库所有依赖的其他类库（当然也包括系统类库啦，这真是一件悲伤的事情 😭），知道了原因就好说了，解决办法有三个：

1. 在 Build Phases -> Linked Frameworks and Libraries 下面添加 AdSupport.framework，这样就失去了使用 cocoapods 的优势了啊喂👎
2. 在 podspecs 中加入系统类库的依赖

	```
	# 这里我顺便把 Foundation 的依赖也加进去了
	# * 为什么 Foundation 没加之前没报错呢
	# * iOS 工程是离不开 Foundation 的，会自动引入
	s.frameworks = 'AdSupport', 'Foundation'
	```
3. 使用动态类库

	```ruby
	pod package WFRFoundation.podspec --force --dynamic
	```
	
打包完成后，我们可以在本地先测试一下，修改 Podfile 文件

```ruby
# pod 'WFRFoundation', :path => '../'
pod 'WFRFoundation', :path => '../WFRFoundation-0.1.0/'
```
`pod install` 或者 `pod update` 都是通过 podspec 文件来进行读取的，所以 `path =>` 指定的路径即 podspec 文件所在的路径，`pod package` 在打包完成后会帮我们生成自己的 podspec 文件，我们只需要正确指定这个路径就可以了

需要注意的是，`pod package` 生成的 podspec 文件里并没有我们指定的需要的依赖，需要我们手动加上

在 `pod update` 后，我们可以看到我们的 framework 被正确的引入进来了，so happy~

这里有个小技巧，直接执行 `pod update` 会默认先去更新 Cocoapods 的 repo 仓库，遇上网速渣的时候，那就呵呵了🙃。这里我们是直接从本地的 path 链接 framework，是不需要更新的，带上下面的参数

```ruby
pod update --no-repo-update
```
这样，pod 更新的速度很快，咻~

现在，需要我们修改我们的 podspec 文件了，我们只需要正确的链接 framework

```ruby
s.ios.deployment_target    = '8.0'
# s.ios.vendored_frameworks   = 'WFRFoundation-0.1.0/ios/WFRFoundation.framework'
s.ios.vendored_frameworks = "#{s.name}-#{s.version.to_s}/ios/#{s.name}.framework"
s.frameworks = 'AdSupport', 'Foundation'
s.dependency 'CocoaLumberjack', '>=3.2.0'
s.dependency 'YYModel'
```
这里我是使用的变量的方式，来引入 framework 的，仔细看 **`s.ios.vendored_framework = "..."`** 这里必须要使用 **双引号**， 这个是 ruby 的语法，单引号的话，表示的字符串，会原样输出里面的内容 🤷‍♀️。可以打印看看结果 

```ruby
puts '#{s.name}-#{s.version.to_s}/ios/#{s.name}.framework'
```

现在，需要我们做的工作都做完了，那我们就愉快的将 podspec 文件 push 的 spec 仓库试试吧

```ruby
pod repo push specName WFRFoundation.podspec --allow-warnings --use-libraries --verbose
```
在 push  操作之前，还可以验证下我们的 podspec（一般我们会允许警告的😈），当然，不验证也没关系，push 阶段还是会先帮你验证它的，不通过验证，是推送不成功的。

```ruby
pod lib lint WFRFoundation.podspec --allow-warnings --verbose
```
虽然我们很愉快的尝试 push，但是很可惜

```
- ERROR | [iOS] file patterns: The `vendored_frameworks` pattern did not match any file.
```
这句话的意思是指定的第三方 framework 找不到匹配的文件。这是为什么呢

在验证 podspec 文件时，同样是根据 podspec 文件里面 git 的 tag 来查找源码的，而我们的 pod package 也是在 tag 之后才进行的，那么我们提交的 framework 就不在这个 tag 下
![commit](https://i.loli.net/2018/09/29/5baf282dc3a1c.png)

这种情况应该如何解决呢？

我能想到的解决办法是，重新打 tag，并推送到远程覆盖之前的标签，这种方法不知道是不是有点傻，但是我还是没有想到更好的解决办法 😂

```
git tag -d 0.1.0  # 删除本地标签
git tag 0.1.0	   # 新的标签
git push origin --delete tag 0.1.0 # 删除远程标签
git push origin --tags  # 推送标签到远程
```
![commit](https://i.loli.net/2018/09/29/5baf282fc137b.png)
重新验证，通过了 🎉🎉🎉

**另外一种解决办法**

我们知道 pod package 是根据 podspec 里面 source 所在 tag 下载源码的，我们可以尝试先将 source 改成本地的

> s.source是工程地址。可以是本地路径，svn，zip包，或者是git上的代码。只是写法不一样。

```ruby
// 本地文件
s.source = { :path => '~/Document/WFRFoundation', :tag => s.version.to_s }    
	
// git
s.source = { :git => 'https://github.com/redye/wfrfoundation.git', :tag => s.version.to_s }    
	
// zip 
s.source = { :http=> 'http://xxx.zip', :tag => "1.0.0" }
	
// svn
s.source = { :svn=> 'http://path', :tag => "1.0.0" }
	
```

很可惜，pod package 并不支持 path 的方式

```ruby
Unsupported download strategy `{:path=>"~/Documents/WFRFoundation", :tag=>"0.1.0"}`.
```

### use_frameworks!
如果不使用 `use_frameworks!`，Pods 项目最终会编译成一个名为 libPods-ProjectName.a 的文件，主项目只需要依赖这个 .a 文件即可。

使用 `use_frameworks!`，Pods 项目最终会编译成一个名为 Pods-ProjectName.framework 的文件，主项目只需要依赖这个 .framework 文件即可。

在 Swift 项目中是不支持静态库的，所以在 Swift 项目，CocoaPods 提供了动态 Framework 的支持，通过 use_frameworks! 选项控制。

### 问题
#### 静态库传递问题
```
target has transitive dependencies that include static binaries
```
场景：
> libB dependency libA <br />
> use_frameworks! <br />
> libA 是一个静态 framework

原因：

在不使用 `use_frameworks!` 标记时，嵌套的第三方库直接通过 `-l` 的方式链接到项目中，而 B 库只编译自己的部分，所以所有的互相传递的依赖的静态库都能最终被导入。但是在使用 `use_frameworks!`，打包的 framework 可能会包含 `vendored_libraries ` 或者 `vendored_frameworks ` 库中的内容，所以这里就有一个符号冲突的问题了。而 CocoaPods 对于这种问题，统一通过报错来拒绝这种情况。

静态库链接的三种方式

* -ObjC
* -all_load
* -force_load

参考 [组件化-动态库实战](https://www.valiantcat.cn/index.php/2017/04/24/45.html#menu_index_7)

解决方法：

第一种：libA 打包成动态 framework。这是最简单和快速的方法了。但是一般并不推荐打包成动态 framework 。至于为什么不推荐，[iOS 开发中的『库』](https://github.com/Damonvvong/DevNotes/blob/master/Notes/framework2.md)

> 能否动态库的方式来动态更新AppStore上的版本呢？
> 
> * 原本是打算国庆的时候试一试 AppStore 上到底行不行的，结果还是托 [@Casa Taloyum 大神](https://weibo.com/casatwy?display=0&retcode=6102) 老司机的福，他已经踩过这个坑了，他的结论是：使用动态库的方式来动态更新只能用在 in house 和develop 模式却但不能在使用到 AppStore。
> 
> * 因为在上传打包的时候，苹果会对我们的代码进行一次 Code Singing，包括 app 可执行文件和所有Embedded 的动态库。因此，只要你修改了某个动态库的代码，并重新签名，那么 MD5 的哈希值就会不一样，在加载动态库的时候，苹果会检验这个 hash 值，当苹果监测到这个动态库非法时，就会造成 Crash。

第二种：首先，强行设置在运行时动态查找符号

```ruby
s.pod_target_xcconfig = {
    'OTHER_LDFLAGS' => '$(inherited) -undefined dynamic_lookup'
}
```

然后设置CocoaPods不要检查静态库嵌套依赖 (static_framework_transitive_dependencies)。

在自己项目的 Podfile 中添加 pre_install 脚本：

```ruby
pre_install do |installer|
    # workaround for https://github.com/CocoaPods/CocoaPods/issues/3289
    def installer.verify_no_static_framework_transitive_dependencies; end
end
```

但是在实践过程中，遇到头文件 not found 的问题，原因在于 framework 的连接路径，需要指定

```ruby
s.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) ${PODS_ROOT}/WFRFoundation/WFRFoundation-0.1.0/ios',
    'OTHER_LDFLAGS' => '$(inherited) -undefined dynamic_lookup'
}
```
这里的路径即 WFRFoundation.framework 所在的路径，这里还有一点需要注意的是上面的路径里面包含了 WFRFoundation 的版本，但是我们我们在 libB 里面并不关心版本(其实依赖最新版本，并不能知道当前是哪个版本 ☹️)，我们可以在 libA framework 的路径上简单一点，上面是因为直接使用了 pod package 打包时的路径。

参考

[iOS 7 & Dynamic Frameworks](https://github.com/CocoaPods/CocoaPods/issues/2926)

[Static Transitive Dependencies](https://github.com/qiuxiang/react-native-amap3d/issues/370)

#### pod package 时依赖库传递问题

```ruby
[!] Unable to find a specification for `WFRFoundation` depended upon by `WFRXxx/Core`
```

场景：
> B dependency A <br />
> pod package <br />

原因：找不到依赖的私有库

解决方法：指定私有库地址

```ruby
pod package WFRFoundation.podspec --force --spec-sources=https://github.com/redye/YHSpecs.git,https://github.com/CocoaPods/Specs.git
```

#### pod repo push 时依赖库传递问题

```ruby
Encountered an unknown error (Unable to find a specification for `WFRFoundation` depended upon by `WFRXxx`
```

添加依赖库所在私有库地址

```ruby
pod repo push YHSpecs WFRFoundation.podspec --allow-warnings --sources=https://github.com/redye/YHSpecs.git,https://github.com/CocoaPods/Specs.git
```

#### 私有库相互依赖时的导入问题

```
Include of non-modular header inside framework module 'WFRXxx.WFXxxMacros': '~/WFRXxx/Example/Pods/WFRFoundation/WFRFoundation-Framework/ios/WFRFoundation.embeddedframework/WFRFoundation.framework/Headers/WFRFoundation.h'
```

原因：

在使用 `use_frameworks!` 时，因为链接方式是通过 embeded framework，Framework 中都包涵了一个自动生成的 Module 和一个 umbrella 文件，Module 文件在工程中是不可见的，是在编译时生成的一个文件，我们可以在生成的.framework文件中找到module.modulemap这个文件，就是前面我们所说的 Module。依赖第三方静态库时，第三方的静态库 Framework 并没有使用 Module，在 .h 文件中直接引入，在进行Framework 化的过程中，一旦引用了这样的 Framework，就会报错。

解决方法：

* 不使用 `use_frameworks!` 。
* 在 Build Settings 设置 Allow Non-modular Includes In Framework Modules 为 yes，允许我们忽略掉这个错误则可以在 Framework 中使用模块外的 Include，这种方法过于粗暴，而且只针对于在目标工程中，而不是我们现在正要打包的 WFRXxx 库。
* 需要升级 Cocoapods 和 cocoapods-packager，在 2.7 版本以上修复了 modulemap 的问题。

参考 [让CocoaPods static library支持Module](https://www.jianshu.com/p/a1d2d148fdd3)

#### 依赖静态库时打包错误

```ruby
[!] podspec has binary-only depedencies, mangling not possible.
```

场景： 
依赖了第三方的静态库

解决方法：

加上 `--no-mangle` 选项，表示有依赖。

加上 `--exclude-deps` 选项，表示在打包的时候排除依赖库的符号表，如果没有这个选项，同样会报错 `Undefined symbols for architecture x86_64` 。

即 `--no-mangle` 与 `--exclude-deps` 需要同时使用。

### 常用命令

#### 清除缓存

```ruby
pod cache clean WFFoundation
```

### 参考
[Cocoa​Pods](https://nshipster.cn/cocoapods/)

[Pod二进制化](https://www.zybuluo.com/qidiandasheng/note/595740)

[iOS经典错误Undefined symbols for architecture XXX](https://www.jianshu.com/p/a243b62b2e72)

[iOS里的动态库和静态库](https://www.zybuluo.com/qidiandasheng/note/603907)

[iOS开发基于Objective-C的Framework中使用CommonCrypto](http://www.skyfox.org/ios-framework-commoncrypto.html)
