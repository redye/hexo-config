---
title: 从 Urllib 开始
categories: Python爬虫训练
tags: [Python]
---

`urllib` 是 Python 内置的 HTTP 请求库，无需安装，直接使用。

<!--more-->

`urllib` 主要分为四个大的模块：

* urllib.request 请求模块
* urllib.error 异常处理模块
* urllib.parse 解析模块
* urllib.robotparser robot.txt 文件解析模块

### urllib.request

首先我们来看一个例子：

```python
import urllib.request

response = urllib.request.urlopen('http://www.baidu.com')
print(response.read().decode('utf-8'))
```

执行这段代码，看控制台的输出，百度把源码返回给我们了。

#### urlopen

`request` 的 `urlopen` 方法可以传入的参数主要有三个：

```python
urllib.request.urlopen(url, data=None, [timeout,]*)
```

* 参数 `url`：请求的链接
* 参数 `data`：给 post 请求携带参数，这里的 data 的值需要用 byte 类型传递
* 参数 `timeout`：设置请求的超时时间

这就是 `request` 的 `urlopen` 的主要用法了。

#### Request

如果我们需要欺骗服务器，假装我们是浏览器或者手机请求呢？这个时候我们就需要添加请求头信息，也就是我们所说的 request header 信息。

那么此时，我们就需要用到 `request` 模块中的 `Request` 方法了：

```python
urllib.request.Request(url, data=None, headers={}, methond=None)
```

* 参数 `url`：请求链接
* 参数 `data`：请求参数
* 参数 	`headers`：请求头信息
* 参数 `method`：请求方式

`urlopen` 默认是 `Get` 请求，当我们传入参数就是 `Post` 请求了。而 `Request` 可以让我们自己定义请求方式，这样我们就可以使用 `Request` 来封装我们的请求信息。

我们来模拟登录 [「豆瓣」](https://www.douban.com/) 玩一下：

在网站登录，在开发者工具查看接口相关信息：

![](https://pic.imgdb.cn/item/6391876db1fccdcd36a11999.png)

离了个大谱，密码竟然是明文的！！！
