## Hexo 站点及主题配置

使用 Hexo + Github Page 的方式搭建个人网站，真的是相当友好，赞~

主题采用当下比较流行的 NexT

### 开通 Github Page
`github.io` 是基于 github 创建的，器本质是在你的 github 账户下创建一个特殊的 repo.

* 创建 repo
  * repo 的名字必须保持 `<username>.github.io` 的格式
  * 其中 `<username>` 替换成你的 github 账户名
* clone 你创建的 repo
  
  ```bash
  git clone xxx
  ```
* 编写简单的博客到首页
	
	```bash
	cd xxx.github.io
	echo "Hello World!" > index.html
	git add index.html
	git commit -m "init commit"
	git push origin master
	```
* 打开 `http://xxx.github.io`，不出意外你就可以看到你刚刚完成的 `Hello World!` 了。如果没有出现，请稍等一会刷新就好 ✧(≖ ◡ ≖✿)


### 安装 Hexo

使用 npm 安装 hexo 脚手架

```bash
npm install hexo-cli -g
hexo init blog
cd blog
npm install
```

接下来启动服务

```
hexo g # 生成静态文件，会在当前目录下生成一个新的叫做 public 文件夹
hexo s # 启动本地 web 服务，博客预览，http://localhost:4000/ 
```

常用命令

```bash
hexo new test # 新建文章
INFO  Created: ~/Documents/source/hexo/source/_posts/test.md

hexo new page test # 新建页面
INFO  Created: ~/Documents/source/hexo/source/test/index.md
```

为站点添加 分类 和 标签选项

```bash
hexo new page categories

INFO  Created: ~/Documents/source/hexo/source/categories/index.md
```

打开这个 index.md 文件，默认内容为

```
---
title: categories
date: 2019-01-10 14:48:44
---
```

添加 type: "categories"到内容中，添加后是这样的：

```
---
title: categories
date: 2019-01-10 14:48:44
type: "categories"
---
```

后面你就可以给你的文章添加分类了

```
---
title: xxx
categories: 生活随笔
tags:
- web
- Vue
---
```

添加 tags 也是一样的哦 (⊙o⊙)

### Hexo 部署 github page

#### 关联 github page

在根目录下的 `_config.yml`

```
deploy:
  type:git
  repo:https://github.com/redye/redye.github.io.git
  branch:master
```

#### 在 hexo 根目录下

```
git clone https://github.com/redye/redye.github.io.git .deploy/redye.github.io
```

#### 部署脚本

```
commitInfo='update'
branch='master'

while getopts "m:b:" arg #选项后面的冒号表示该选项需要参数
do
	case $arg in
		m)
			commitInfo=${OPTARG}
			echo "commit info ${commitInfo}"
			;;
		b)
			branch=${OPTARG}
			;;
		?)
			echo 'NOT KNOW'
			;;
	esac
done

hexo clean
hexo generate
cp -R public/* .deploy/redye.github.io
cd .deploy/redye.github.io
git add .
git commit -m ${commitInfo}
git push origin ${branch}
```

### Hexo 常用命令

```
hexo clean # 清除静态文件和缓存

hexo generate || hexo g  # 打包静态文件

hexo server || hexo s # 启动服务

hexo deploy || hexo d # 部署服务到站点

```

### 安装 Next 主题

```bash
hexo clean
git clone https://github.com/iissnan/hexo-theme-next themes/next
```

启用主题，修改根目录下的 _config.yml 文件

```
theme: next
```

### hexo 主题配置

配置文件位于 themes/next 下的 _config.yml 文件

可以配置 menu、scheme 等

愉快的开始折腾吧 ✧(≖ ◡ ≖✿)

### 链接

[Hexo 中文网站](https://hexo.io/zh-cn/index.html)

[hexo-theme-next](https://github.com/iissnan/hexo-theme-next)

[Hexo + Github Pages搭建个人独立博客](https://linghucong.js.org/2016/04/15/2016-04-15-hexo-github-pages-blog/)