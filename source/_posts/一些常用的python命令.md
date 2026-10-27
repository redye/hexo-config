---
title: 一些常用的 Python 命令
categories: Python入门
tags: [Python]
---

一些常用的 Python 命令。

<!-- more -->

### 查看已安装的 python 库

1. 安装：`pip install xxx`
2. 查看是否安装成功：`pip show xxx`

🌰

```
pip install selenium

...

pip show selenium
```
输出

```
Name: selenium
Version: 4.15.2
Summary: 
Home-page: https://www.selenium.dev
Author: 
Author-email: 
License: Apache 2.0
Location: /opt/homebrew/lib/python3.9/site-packages
Requires: certifi, trio, trio-websocket, urllib3
Required-by: 
```

3. 查看已安装的所有 python 库：`pip list`