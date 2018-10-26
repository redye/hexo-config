## Hexo 站点及主题配置

使用 Hexo + Github Page 的方式搭建个人网站，真的是相当友好，赞~

主题采用当下比较流行的 NexT

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

### 链接

[Hexo 中文网站](https://hexo.io/zh-cn/index.html)

[hexo-theme-next](https://github.com/iissnan/hexo-theme-next)