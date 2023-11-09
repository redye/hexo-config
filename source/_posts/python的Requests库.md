---
title: Requests 库
categories: Python爬虫训练
tags: [Python]
---

Requests 是在 urllib 的基础上建立起来的，我们可以用更少的代码模拟浏览器的操作。

<!-- more -->

### 安装 Requests 库

```
pip install requests
```

### Requests 库的使用 

```python
import requests

r = requests.get('https://api.github.com/events')

print(r.text)
```

#### 一行代码 Get 请求

```
r = requests.get('https://api.github.com/events')
```

#### 一行代码 Post 请求

```
r = requests.post('https://www.xxx.xxx/post', data={'key':'value'})
```

#### 其它的请求

```python
r = requests.put('https://www.xxx.xxx/put', data = {'key':'value'})

r = requests.delete('https://www.xxx.xxx/delete')

r = requests.head('https://www.xxx.xxx/head')

r = requests.options('https://www.xxx.xxx/options')
```

#### 携带请求参数

```python
params = {"key1": "value1", "key2": "value2"}

r = requests.get('https://www.xxx.xxx/get', params=params)
```

#### 假装自己是浏览器

```python
url = "https://api.github.com/some/endpoint"

headers = {"user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36"}

r = requests.get(url, headers= headers)
```

#### 获取服务器响应文本、编码、内容、状态码等

```python
import requests

r = requests.get('https://api.github.com/events')

# 文本
print("文本：", r.text)

# 编码
print("编码：", r.encoding)

# 内容
print("内容：", r.content)

# 状态码
print("状态码：", r.status_code)

# 响应头
print("响应头：", r.headers)

# json 响应内容
print("json 响应内容：", r.json())
```

#### 后去流响应内容

```python
>>> import requests
>>> r = requests.get('https://api.github.com/events', stream=True)
>>> r.raw
<urllib3.response.HTTPResponse object at 0x103fda3a0>
>>> r.raw.read(10)
b'\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\x03'
```

#### 上传文件

```python
url = 'https://xxx.xxx.xx'

files = {'file': open('report.xls', 'rb')}

r = requests.post(url, file=files)

print(r.text)
```

#### 获取 cookie 信息

```python
url = 'https://api.github.com/events'

r = requests.get(url)

print(r.cookies['example_cookie_name'])
```

#### 发送 cookie 信息

```python
url = 'https://xxx.xxx.xxx'

cookies = dict(cookies_are='working')

r = request.get(url, cookies=cookies)

print(r.text)
```

#### 设置超时

```python
url = 'https://github.com'

r = request.get(url, timeout=30)

print(r.text)
```

### Post 请求

#### 一个键里面多个参数

```python
tuples = [('key1': 'value1'), ('key1': 'value2')]

r1 = requests.get('https://xxx.xxx.xxx/post', data=tuples)

dict = {'key1': ['value1', 'value2']}

r2 = requests.get('https://xxx.xxx.xxx/post', data=dict)
```

#### 请求的时候用 json 做参数

```python
url = 'https://api.github.com/events'

data = {'key': 'value'}

r = requests.post(url, json=data)
```

