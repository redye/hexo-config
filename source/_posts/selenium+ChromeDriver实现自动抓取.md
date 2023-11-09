---
title: selenium + ChromeDriver 实现自动抓取
categories: Python爬虫训练
tags: [Python]
---

之前我们利用 python 的网络库模拟浏览器的请求，需要额外设置如 user-agent 的请求头，那么我们可不可以只负责写代码，让它自己打开浏览器自己去请求网站呢？

答案是肯定的，selenium 应运而生。

selenium 是一个自动化测试工具，支持各种主流浏览器。只有 selenium 还不够，我们还需要下载浏览器驱动。

<!-- more -->

### 安装 selenium

```
pip install selenium
```

### 安装 ChromeDriver

[下载地址](https://sites.google.com/chromium.org/driver/downloads)

注意与浏览器版本需要匹配。

1. 下载完成后解压 zip 文件，将 chromedriver 移动到目录 `/usr/local/bin` 下，这里可以放到任何你想要放的目录，只需要保证在设置环境变量的时候保持一致即可

2. 设置环境变量
	
	1. 打开 zshrc 文件：`vi .zshrc`
	2. 在文件末尾新增：`export PATH=/usr/local/bin:$PATH`
	3. 保存文件并使其生效：`source .zshrc`

3. 测试 ChromeDriver 生效

```
$ chromedriver --version
ChromeDriver 114.0.5735.90 (386bc09e8f4f2e025eddae123f36f6263096ae49-refs/branch-heads/5735@{#1052})

```

### 模拟百度搜索

```python
from selenium import webdriver
from selenium.webdriver.common.by import By

print('开始')

driver = webdriver.Chrome()

driver.get('https://www.baidu.com')

input = driver.find_element(by=By.CSS_SELECTOR, value="#kw")
input.send_keys('豆瓣排名前250的电影')

button = driver.find_element(by=By.CSS_SELECTOR, value="#su")
button.click()

print('链接：', driver.current_url)
print('cookies：', driver.get_cookies())
print('源代码：', driver.page_source)

print('完成')
```

### PhantomJS 实现无痕浏览

上面提到的 webdriver 需要打开浏览器，使用 PhantomJS 就不需要打开浏览器就能自动抓取我们想要的数据了。

#### 安装 PhantomJS
1. 下载 [PhantomJS](https://phantomjs.org/download.html)
2. 配置环境变量
	1. 将可执行文件复制到目录 `/usr/local/bin`
	2. 环境变量：`export PATH=/usr/local/bin:$PATH`

