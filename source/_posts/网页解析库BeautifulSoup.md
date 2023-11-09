---
title: 网页解析库 BeautifulSoup
categories: Python爬虫训练
tags: [Python]
---

利用正则表达式提取信息太麻烦了，所有就有了 BeautifulSoup。BeautifulSoup 是一个搞笑的网页解析库，是一个可以从 HTML 或 XML 文件中提取数据的 Python 库。

<!-- more -->

### 安装 BeautifulSoup

```
pip install beautifulsoup4
```

BeautifulSoup 支持不同的解析器：

| 解析器 | 使用方法 | 优势 | 劣势 |
| :-- | :-- | :-- | :-- |
| Python 标准库  | `BeautifulSoup(markup, 'html.parse')` | <li> python 的内置标准库</li> <li> 执行速度适中</li> <li> 文档容错能力强</li> | <li> Python 2.7.3 或者 3.2.2 前的版本中文档容错能力差</li> |
| lxml HTML 解析器 | `BeautifulSoup(markup, 'lxml')` | <li>速度快</li> <li>文档容错能力强</li> | <li> 需要安装 C 语言库</li> |
| lxml XML 解析器 | `BeautifulSoup(markup, 'xml')` | <li>速度快</li> <li>文档容错</li><li>唯一支持 XML 的解析器</li> | <li> 需要安装 C 语言库</li> |
| html5lib | `BeautifulSoup(markup, 'html5lib')` | <li>最好的容错性</li> <li>以浏览器的方式解析文档</li><li>生成 HTML5 格式的文档</li> | <li>速度慢</li><li>不能依赖外部扩炸</li> |

一般情况下使用的比较多的是 lxml 解析器:

```
pip install lxml
```

### 使用 BeautifulSoup

```python
from bs4 import BeautifulSoup

html = '''
    <html>
        <head><title>标题</title></head>
        <body>
            <p class="title"><b>网页解析库 BeautifulSoup </b></p>
            <p class="story">故事发生在一个所有哺乳类动物和谐共存的美好世界中，兔子朱迪（金妮弗·古德温 Ginnifer Goodwin 配音）从小就梦想着能够成为一名惩恶扬善的刑警，凭借着智慧和努力，朱迪成功的从警校中毕业进入了疯狂动物城警察局，殊不知这里是大型肉食类动物的领地，作为第一只，也是唯一的小型食草类动物，朱迪会遇到怎样的故事呢？</p>
            <p><a href="https://movie.douban.com/subject/25662329/" id="link1">疯狂动物城</a></p>
            <a href="https://movie.douban.com/subject/2131459/" id="link2">机器人总动员 WALL·E</a>

            ...
        </body>
    </html>
'''

soup = BeautifulSoup(html, 'lxml')

print('获取标题内容: ', soup.title.string)

print('获取 p 标签的内容: ', soup.p.string)

print('获取 title 的父级标签: ', soup.title.parent.name)

print('获取超链接: ', soup.a)

print('获取所有超链接: ', soup.find_all('a'))

print('获取 id 为 link2 的超链接: ', soup.find(id='link2'))

print('获取网页中所有的内容: ', soup.get_text())

print('============================== \n\n')

print(soup.select('title'))

print(soup.select('body a'))

print(soup.select('p > #link1'))
```

![](https://pic.imgdb.cn/item/6544b42cc458853aefee4716.png)

### BeautifulSoup 爬取豆瓣 Top250 电影

```
pip install xlwt
```

```python
import requests
from bs4 import BeautifulSoup
import xlwt

def request_douban(url):
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36'
        }
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.text
    except requests.RequestException:
        return None

def parse_result(html):
    if html == None:
        return None
    
    soup = BeautifulSoup(html, 'lxml')
    list  = soup.find(class_='grid_view').find_all('li')

    for item in list:
        item_name = item.find(class_='title').string
        item_img = item.find('a').find('img').get('src')
        item_index = item.find(class_='pic').find('em').string
        item_score = item.find(class_='rating_num').string
        item_director = item.find(class_='bd').find('p').text.strip()
        item_intro = ''
        if item.find(class_='inq') != None:
            item_intro = item.find(class_='inq').string
        
        # print('电影： ' + item_index + ' | ' + item_name +  ' | ' + item_score  + ' | ' + item_intro)
        yield {
            'name': item_name,
            'img': item_img,
            'index': item_index,
            'score': item_score,
            'director': item_director,
            'intro': item_intro
        }

def save_to_excel(items, start, sheet):
    if items == None:
        return
    
    i = start
    for item in items:
        sheet.write(i, 0, item['name'])
        sheet.write(i, 1, item['img'])
        sheet.write(i, 2, item['index'])
        sheet.write(i, 3, item['score'])
        sheet.write(i, 4, item['director'])
        sheet.write(i, 5, item['intro'])
        i = i + 1
    

    book.save(u'豆瓣最受欢迎的250部电影.xlsx')

def main(page, sheet):
    url = 'https://movie.douban.com/top250?start='+ str(page*25)+'&filter='
    html = request_douban(url)
    items = parse_result(html)
    save_to_excel(items, page*25+1, sheet)


if __name__ == '__main__':

    book = xlwt.Workbook(encoding='utf-8', style_compression=0)
    sheet = book.add_sheet('豆瓣电影Top250', cell_overwrite_ok=True)
    sheet.write(0, 0, '名称')
    sheet.write(0, 1, '图片')
    sheet.write(0, 2, '排名')
    sheet.write(0, 3, '评分')
    sheet.write(0, 4, '导演')
    sheet.write(0, 5, '简介')

    for i in range(0, 10):        
        main(i, sheet) 
    
    book.save(u'豆瓣最受欢迎的250部电影.xlsx')
    print('查询结束~')
```