---
title: Mac 上 GoLand 破解与许可证验证
date: 2026-09-30
categories: Go入门
tags: [GoLand, Go, Mac]
---

GoLand 是 JetBrains 出品的 Go 语言 IDE，功能强大但需要付费订阅。本文记录在 Mac 上通过 jetbra 破解 GoLand 的完整流程，以及破解后遇到 `We could not validate your license` 弹窗的解决办法。

<!-- more -->

### GoLand 安装

从 JetBrains 官网下载 GoLand 安装包：

> https://www.jetbrains.com.cn/go/

如需指定版本，可在此页面找到历史版本：

> https://www.jetbrains.com.cn/go/download/other.html

Mac 下载 `.dmg` 文件，双击打开后将 GoLand 拖入 Applications 即可完成安装。

### 使用 jetbra 破解 GoLand

#### 1. 下载 jetbra

jetbra 是 JetBrains 全家桶的通用破解工具，支持 IDEA、PyCharm、GoLand、CLion 等。

激活码获取网站：

> https://3.jetbra.in/

在该网站页面找到 GoLand 对应的激活码，鼠标悬浮后复制备用。

jetbra 工具包下载方式（任选其一）：

- 从激活码网站页面提供的链接直接下载
- 百度网盘：`https://pan.baidu.com/s/1J5Ou8VWmq6Kk-wEl-6kq2Q?pwd=zrvb`

下载后解压，得到一个文件夹，**后续不要移动或删除这个文件夹**。

#### 2. 执行脚本

解压后的目录结构中，进入 `scripts` 文件夹：

```
jetbra/
├── scripts/
│   ├── uninstall.sh
│   └── install.sh
└── ...
```

打开终端，进入 `scripts` 目录，依次执行：

```bash
# 第一步：卸载（如果之前破解过其他 JetBrains 产品，必须先卸载再重新安装）
bash uninstall.sh

# 等待约 30 秒，弹出 "Done" 提示

# 第二步：安装
bash install.sh

# 等待约 1 分钟，弹出 "Done" 提示
```

> **注意**：如果电脑上已有其他破解过的 JetBrains 产品（如 PyCharm、IDEA），必须先执行 `uninstall`，再执行 `install`，否则可能冲突。

#### 3. 激活 GoLand

1. 打开 GoLand，在激活界面选择 **Activation Code**
2. 粘贴从 jetbra 网站复制的 GoLand 激活码
3. 点击 **Activate**，显示激活成功即可

如果之前已经打开过 GoLand（非首次启动），可以从菜单 `Help | Register` 进入许可证管理界面，切换到 Activation Code 输入激活码。

### `We could not validate your license` 解决方法

破解后如果反复弹窗提示 `We could not validate your license XXXX`，问题通常出在 **地区设置** 上。

#### 原因分析

GoLand 的许可证验证请求会根据用户选择的地区，发往不同的验证服务器。如果地区设置为 **中国大陆**，验证请求会发往大陆地区的专用地址，而 jetbra 工具只会拦截和处理普通地区的验证请求，导致大陆地区的请求验证失败。

#### 解决方法

**方法一：修改地区为"不指定"（推荐）**

1. 打开 GoLand，进入 `Help | Register`
2. 在许可证管理界面找到 **Region / 地区** 选项
3. 将地区从"中国大陆"改为 **"No region / 不指定"**（列表最下方的选项）
4. 重启 GoLand，弹窗消失

**方法二：设置 HTTP 代理**

如果方法一不够或不方便直接修改地区，可以通过设置代理绕过大陆地区验证：

1. 打开 `Settings | Appearance & Behavior | System Settings | HTTP Proxy`
2. 选择 **Manual proxy configuration**
3. 填写：
   - Host name: `localhost`
   - Port: `80`
4. 在 **No proxy for** 中填入：`*.github.com,plugins.jetbrains.com`
5. 保存后重启 GoLand

> **注意**：设置代理后插件市场可能无法正常访问。解决办法：先用代理解决弹窗问题，确认不再弹窗后，将地区改为"不指定"，然后删除代理设置，插件市场即可恢复正常。

### 常见问题汇总

| 问题 | 原因 | 解决方法 |
|------|------|----------|
| 激活码粘贴后提示无效 | jetbra 未正确安装 | 重新执行 `uninstall.sh` → `install.sh` |
| 反复弹窗 `We could not validate your license` | 地区设置为中国大陆 | 改为"不指定"，或设置代理 |
| 设置代理后插件市场打不开 | 代理拦截了插件站点请求 | 删除代理设置，改为"不指定"地区 |
| 多个 JetBrains 产品共存时激活失败 | 之前破解的残留冲突 | 先 `uninstall` 清除旧破解，再 `install` 重新安装 |
| install.sh 执行后长时间无反应 | 正常现象 | 等待约 1 分钟，直到弹出 "Done" |

### 参考

[Go安装和配置+Vscode、GoLand安装激活+Go环境变量避坑的超详细教程](https://blog.csdn.net/weixin_51360020/article/details/145511537)

[运行自己的第一个Go程序](https://blog.csdn.net/weixin_45683778/article/details/144907111)

[JetBrains 开发工具弹窗 We could not validate your license](https://blog.csdn.net/TianKongShuLovey/article/details/142794281)
