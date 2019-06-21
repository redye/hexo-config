---
title: Weex 初体验
categories: 工具代码
tags: [Weex, Vue]
---

最近看了一篇很赞的文章，是讲 weex、react-native 和 JSPatch 之间的对比，作为一枚 iOS 程序猿，当然了，我使用过 react-native，JSPatch 也了解过（由于苹果爸爸禁止使用 hotfix，并没有派上用场），weex 当然也有必要去体验一下。

<!-- more -->

这里先贴下[原文](http://awhisper.github.io/2016/07/22/Weex-ReactNative-JSPatch/)。

作为小白，最快了解和体验 weex 的办法，当然是寻求[weex 官方文档](https://weex.apache.org/cn/)的帮助。

Weex有一个[在线编写代码的平台](http://dotwe.org/vue/)，可以先去感受一下，weex 使用 vue 语法开发，如果你以前写过 vue，那就太棒了。

如果想要在自己的本本上感觉一下，那么就需要安装 weex 的环境了。


说起来，weex 的使用感与 vue 是基本一致的，阿里同样提供了 weex 的脚手架，这对于新手真的很友好，项目的模板与 vue 也基本一致，同样是使用 webpack 来启动服务和进行 hot reload 的，对于我这个前端小白，里面的各种 loader 真的是让人头大(╯﹏╰)。

## 使用 weex-toolkit
> weex-toolkit 是官方提供的一个脚手架命令行工具，你可以使用它进行 Weex 项目的创建，调试以及打包等功能。
>
> [使用 weex-toolkit 的文档](https://weex.apache.org/cn/tools/toolkit.html)

node 的安装这里先略过，保证 node 的版本 >= 6

```bash
node -v 			# 查看 node 的版本
node --version 		# 查看 node 的版本
```

首先是安装 weex-toolkit

```bash
npm install -g weex-toolkit
```

安装成功后，就可以愉快的去创建你的项目了

```bash
weex create weex-demo 			# 创建项目
weex platform add ios			# 添加 iOS 项目模板
weex run ios					# 运行 iOS 项目
```

顺利的话，你已经启动了你的 iOS 模拟器 ✌️

当然，你也许想要启动 weex 项目，自己修改点东西看看效果，你打开了项目的跟目录，观察了下 package.json 这个文件，项目目录下如果没有 node_modules 这个文件夹，首先需要 

```bash
npm install 			# 安装依赖包
```
安装完成后，开始启动服务

```bash
npm run serve			# 启动 serve 服务
npm run dev			# 自动编译
```

可能你在启动服务的时候会遇到一个错误

```bash
Vue packages version mismatch:

- vue@2.4.4

- vue-template-compiler@2.5.13

This may cause things to work incorrectly. Make sure to use the same version for both.

If you are using vue-loader@>=10.0, simply update vue-template-compiler.

If you are using vue-loader@<10.0 or vueify, re-installing vue-loader/vueify should bump vue-template-compiler to the latest.
```

不匹配的对象是 `vue` 和 `vue-template-compiler`。

这是由于 weex 要求他们完全匹配，但是你看了看你的 package.json，发现他们的版本号并没有什么问题，然后你把问题放到了 google 上，找到了很多同道中人，按照他们的方法试了个遍，发现依然没有解决问题，很难说这不是个悲伤的事实 ☹️

但是你并不是一无所获，有一个可能的原因 -- 在这之前你安装了全局的 vue，然后你在终端敲下了

```bash
vue -v
```
终端回应你了，他输出了 vue 的版本号，嗯，跟你的 package.json 里面并不一样...

现在有两个方式可以解决这个问题:

1. 升级全局的 vue 
2. 删除掉全局环境下的 vue

为了长远考虑，当然是删除掉全局环境下的 vue 比较靠谱，哈哈~

全局的 vue 安装在当前用户的目录下

```bash
cd ~
ls -a
```
找到 .vue 文件夹，删除他就可以了。

## 集成 WXDevtool

当然，如果为了简便，你可以直接使用 weex 提供的 playground 来体验或调试你的代码（在 app store 下载阿里爸爸 WeexPlayground），起初为了偷懒，我也是这么干的，新版的 dev tool 还是很给给力的，直接使用下面的命令就可以启动调试界面了，扫码开始调试吧，冲鸭~

```bash
weex debug 
```

虽然你满怀信心开始了你的调试之路，但是很不幸的是这条路总是容易断掉😭

看来还是自己集成 `WXDevtool` 比较靠谱哇！

weex 官方文档 - [集成 Devtools 到 iOS](https://weex.apache.org/cn/guide/integrate-devtool-to-ios.html)

使用 pod 集成

```ruby
source https://github.com/CocoaPods/Specs.git，
pod  'WXDevtool'
```

这里有个小插曲，也算是自己做的一点小贡献 😊

我直接集成的 `WXDevtool` 最新版本，按照文档集成，编译成功运行时总是内存崩溃，刚开始一直以为是自己哪里集成错误，反反复复试了很多遍，确定不是自己操作失误的话，那肯定就是代码哪里有问题了

崩溃的点在 `WXDebugDomainController` 类的 .m 文件的 `line 88`，具体可以看我的题的 [issue](https://github.com/weexteam/weex-devtool-iOS/issues/31)，现在最新版已经修复了这个问题了。

集成 `WXDevtool` 后，开启调试，模拟器会自动连接上，更方便，更快速 ✌️

但是最近在开启调试后页面直接白屏了，断点调试已经拿到页面数据了，还待进一步的研究...

## 使用 navigator 跳转页面

`navigator` 是 weex 提供的一个页面跳转模块，跟 vue 里面的 `router-view` 不同的是，他会在一个新的 `ViewController` 里面渲染页面，即 WeexSDK 里面封装的 `WXBaseViewController`。

但是在使用 `navigator` 入栈的时候，push 的 url 需要针对不同的平台需要有不同的处理，幸好，我们可以根据 `bundleUrl` 获取不同平台的 `baseUrl`:

```js
getBaseUrl: function () {
  const bundleUrl = weex.config.bundleUrl;
  let baseUrl;
  const isAndroidAssets = bundleUrl.indexOf('file://assets/') >= 0;
	
  const isiOSAssets = bundleUrl.indexOf('file:///') >= 0 && bundleUrl.indexOf('WeexDemo.app') > 0;
  if (isAndroidAssets) {
	  baseUrl = 'file://assets/dist/';
  } else if (isiOSAssets) {
	  baseUrl = bundleUrl.substring(0, bundleUrl.lastIndexOf('/') + 1);
  } else {
    let host = 'localhost:12580';
    const matches = /\/\/([^/]+?)\//.exec(bundleUrl);
    if (matches && matches.length >= 2) {
      host = matches[1];
    }
	
    // in Browser or WebView
    if (typeof window === 'object') {
      baseUrl = 'http://' + host + '/index.html?page=./dist/';
    } else {
      baseUrl = 'http://' + host + '/';
    }
  }
	
  return baseUrl;
}
```
获取 baseUrl 后拼接上目标页面的 url 就可以了

```js
getTargetUrl: function (url) {
    const baseUrl = util.getBaseUrl();
    let path = url;
    if (url.indexOf('?') > -1) {
      path = url.split('?')[0];
    }
    const newUrl = baseUrl + path;
    return newUrl;
  },
```

🌰🌰🌰

```js
navigator.push({
  url: `controllers/WebController.js?url=http://www.baidu.com`
});
```

```js
/**
 * 入栈
 * @param {Object} options 路由信息
 * @param {Function} callback 回调函数
 */
push: function (options, callback) {
  const url = options && options.url;
  if (url && url.length > 0) {
    let targetUrl = util.getTargetUrl(url);
    let query = util.parseUrlQuery(url);
    if (options.params) {
      query = Object.assign(query || {}, options.params);
    }
    console.log(`query ==> ${JSON.stringify(query)}`);
    targetUrl = targetUrl + '?' + util.formatQueryString(query);
    console.log(`targetUrl ===> ${targetUrl}`);
    configure.hideNavBar(false);
    navigator.push({
      url: targetUrl,
      params: query,
      animated: options.animated ? options.animated : 'true'
    }, callback);
  }
}
```

最后说一下 `navigator` 不同页面传参的问题，最简单的方法就是将参数拼接到 url 的后面，然后在新的页面通过 `this.$getConfig().bundleUrl` 获取 url，解析参数:

```js
created: function (event) {
	const bundleUrl = this.$getConfig().bundleUrl;
	const params = util.parseUrlQuery(bundleUrl);
	if (params && params.url) {
	  this.url = params.url;
	}
}
...
// util.js
parseUrlQuery: function (url) {
	let result = {};
	const paramstring = url.slice(url.indexOf('?') + 1);
	const params = paramstring.split('&');
	for (let i = 0; i < params.length; i++) {
	  let temp = params[i].split('=');
	  result[temp[0]] = decodeURIComponent(temp[1]);
	}
	return result;
}
```

## 打包 js 文件
在使用 `navigator` 的时候，你会发现，如果要跳转到新页面，那么新页面也是需要打包成 js 文件的。

`npm run dev` 或者 `npm run build` 都可以对 .vue 文件打包，但是他们只打包了入口文件，在 webpack.common.conf.js 文件中，可以看到

```js
const weexEntry = {
  'index': helper.root('entry.js')
}
```
这时，我们想要的 controllers 文件夹下面的 WebController.vue 并没有打包，navigator push 的 url 其实是一个 bundleUrl，需要独立打包成 js 文件才可以。

weex tool 提供了一个 命令来进行打包 

```bash
weex compile src dist -d
# weex compile	<源文件> <目标文件> [options] 
```

但是在使用这个命令的时候，只要我有导入其他组件，打包都会出错

```js
Module not found: Error: Can't resolve '@/components/Channel'
```

对于我这微薄的 webpack 认知，真的是 🤷‍♀️🤷‍♀️🤷‍♀️

weex 定义的命令路径为 `/usr/local/lib/node_modules/weex-toolkit/node_modules/weex-builder/src` 下，他定义的 entry file 是将所有的 .vue 都打包成入口文件

```js
const entrys = {};
this.source.forEach(s => {
	let file = path.relative(path.resolve(this.base), s);
	file = file.replace(/\.\w+$/, '');
	if (!this.options.web) {
	  s += '?entry=true';
	}
	entrys[file] = s;
});
```

输出结果

```json
{
    "components/Channel":"/Users/xxx/Documents/weex/Demo/src/components/Channel.vue?entry=true",
    "components/NavBar":"/Users/xxx/Documents/weex/Demo/src/components/NavBar.vue?entry=true",
    "components/SearchBar":"/Users/xxx/Documents/weex/Demo/src/components/SearchBar.vue?entry=true",
    "components/TabBar":"/Users/xxx/Documents/weex/Demo/src/components/TabBar.vue?entry=true",
    "controllers/CartController":"/Users/xxx/Documents/weex/Demo/src/controllers/CartController.vue?entry=true",
    "controllers/CategoryController":"/Users/xxx/Documents/weex/Demo/src/controllers/CategoryController.vue?entry=true",
    "controllers/HomeController":"/Users/xxx/Documents/weex/Demo/src/controllers/HomeController.vue?entry=true",
    "controllers/MineController":"/Users/xxx/Documents/weex/Demo/src/controllers/MineController.vue?entry=true",
    "controllers/TopicController":"/Users/xxx/Documents/weex/Demo/src/controllers/TopicController.vue?entry=true",
    "controllers/WebController":"/Users/xxx/Documents/weex/Demo/src/controllers/WebController.vue?entry=true",
    "index":"/Users/xxx/Documents/weex/Demo/src/index.vue?entry=true"
}
```

既然知道是这样，那么我们就可以改写 `webpack.common.conf.js` 文件，具体的实现在 `helper.js` 中新增方法

```js
const entrys = () => {
  const root = process.cwd();
  const reg = new RegExp('\\.(' + 'vue|we' + ')$');
  const source = sourcer.find(root, 'src', {
    recursive: true
  }).filter(s => reg.test(path.extname(s)));
  const base = sourcer.base('src');
  const entrys = {};
  source.forEach(s => {
    let file = path.relative(path.resolve(base), s);
    file = file.replace(/\.\w+$/, '');
    entrys[file] = s + '?entry=true';
  });
  const entry = path.join(ROOT, 'src');
  entrys.index = entry + '?entry=true';
  return entrys;
}
```

同时

```js
const weexEntry = helper.entrys();
```

这样就可以使用 `npm run dev` 或者 `npm run build` 打包啦~

但是注意这里我们使用脚手架生成的目录结构，默认的入口文件对应为 http://ip:port/index.js，对应 js 文件是 entry.js，同时 entry.js 也参与打包，所以修改我们的目录文件

```
|------ src
|------ |------ index.js  # 将 entry.js 修改成 index.js
|------ |------ app.vue   # 将 index.vue 修改成 app.vue
|------ |------ router.js
|------ |------ controllers
|------ |------ |------ WebController.vue
|------ |------ components 
|------ |------ |------ NavBar.vue
|------ |------ |------ Channel.vue
....
```

因为每个 controller 之间是独立存在的，所以我在 index.js 里面定义个 mixin 在每个不同 ViewController 里面并不能共享使用 

```js
import baseMixins from '@/mixins/baseMixins';
Vue.mixin(baseMixins);
```

顺便提一下，`import` 和 `require` 的用法

`import` 是 es6 的写法，对应 `export default baseMixins;`

`require` 是 es6 之前的写法，对应 `module.exports = baseMixins;`

写 mixin 的时候坑了好久 (；′⌒`)

## 关于启动 WebScoket 服务

```
weex run ios
```

这个命令可以帮你启动 ws 服务，选择模拟器并编译运行 iOS 代码，这个命令下面最的工作还蛮多的，但是如果你只想启动 ws 服务怎么办呢，你可以修改这个命令，或者新增一个命令（机智如你，一定会选择新增命令的😎）

weex run 的命令在 `/Users/xxx/.xtoolkit/node_modules/weexpack/lib/run`

* 复制 ios.js 文件，修改为 hot.js
* 修改 hot.js

	```js
	var runHot = function runHot(options) {
	  logger.info('npm run build');
	  utils.checkAndInstallForIosDeploy().then(utils.buildJS).then(function () {
	    return copyJsbundleAssets(process.cwd(), 'dist', 'platforms/ios/bundlejs/');
	  }).then(function () {
	    return passOptions(options);
	  }).then(prepareIOS).then(startHotReloadServer).then(registeFileWatcher).then(resolveConfig).catch(function (err) {
	    if (err) {
	      logger.error('Error:' + (err.stack || err));
	      exit(0);
	    }
	  });
	};
	
	module.exports = runHot;
	```
* 修改同级目录下的 index.js
	
	```js
	'use strict';
	
	var runAndroid = require('./android');
	var runIOS = require('./ios');
	var runWeb = require('./web');
	var runHot = require('./hot'); // 新增
	
	module.exports = {
	  runAndroid: runAndroid,
	  runIOS: runIOS,
	  runWeb: runWeb,
	  runHot: runHot // 新增
	};
	```
* 修改 ../lib 目录下的 weexpack-run.js，添加命令

	```js
	...
	const {
	  runAndroid,
	  runIOS,
	  runWeb,
	  runHot
	} = require('../lib/run');
	
	...
	
	function isValidPlatform(args) {
	  if (args && args.length) {
	    return args[0] === 'android' || args[0] === 'ios' || args[0] === 'web' || args[0] === 'hot'
	  }
	  return false
	}
	
	...
	
	function run(platform, options) {
	  switch (platform) {
	    case 'android' : runAndroid(options); break;
	    case 'ios' : runIOS(options); break;
	    case 'web' : runWeb(options); break;
	    case 'hot' : runHot(options); break;
	  }
	}
	
	```
	
好了，现在你就可以使用 `weex run hot` 命令来开启你的 ws 服务了。

代码请戳[这里](https://github.com/redye/weex-demo) O(∩_∩)O~~

## 推荐阅读

* [Weex 是如何在 iOS 客户端上跑起来的](https://halfrost.com/weex_ios/)
* [Weex & ReactNative & JSPatch](http://awhisper.github.io/2016/07/22/Weex-ReactNative-JSPatch/)
* [weex & ReactNative 对比](https://zhuanlan.zhihu.com/p/21677103)