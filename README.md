# Selkies Cloud Desktop

**Ubuntu 26.04 LTS + XFCE lite 桌面 + Microsoft Edge + Z.ai ZCode CLI 的 Selkies WebRTC 云桌面**

[![build-image](https://github.com/cshdotcom/selkies-cloud-desktop/actions/workflows/docker-build.yml/badge.svg)](https://github.com/cshdotcom/selkies-cloud-desktop/actions/workflows/docker-build.yml)
[![GHCR image](https://img.shields.io/badge/ghcr.io-cshdotcom%2Fselkies--cloud--desktop-blue)](https://github.com/cshdotcom/selkies-cloud-desktop/pkgs/container/selkies-cloud-desktop)
[![release](https://img.shields.io/github/v/release/cshdotcom/selkies-cloud-desktop?display_name=tag)](https://github.com/cshdotcom/selkies-cloud-desktop/releases/latest)

产品形态参考 [linuxserver/webtop](https://github.com/linuxserver/docker-webtop)（容器化浏览器云桌面），
流式层采用 [Selkies v2](https://github.com/selkies-project/selkies)（WebSockets / WebRTC，MPL-2.0）官方
base 容器 `ghcr.io/selkies-project/selkies/base:2.2.1-ubuntu26.04` 构建：

- **多人同时控制**：所有人连同一桌面，各自键鼠可**同时**操作、互见对方光标（multi-peer，输入权限由服务端强制执行）
- **HTTP + HTTPS 双端口**：`8080`（HTTP）与 `8443`（HTTPS，未配置证书时自动生成自签证书）同时监听
- **zcode 网页端独立端口**：`8081`——应用端（云桌面里的 TUI）与网页端同时运行；
  nginx 认证网关双重防护：**浏览器弹窗输入用户名+密码**（BasicAuth，默认与桌面同一套密码）
  + 内层随机 Bearer token（自动注入，用户无感知）
- **自定义用户名/密码登录**：三个网页入口（8080/8443/8081）均需密码登录；另支持**只读观看密码**（给只需要"看"的同事）
- **完整权限开放**：Web 面板命令通道开启、桌面账户带 sudo（fakeroot）、全员完整控制权
- **数据完整持久化**：家目录（常规目录）、Edge 配置/缓存（软件目录）、`~/.zcode`（zcode 专属目录）独立成卷；
  **会话内装的软件包也持久化**（pkg-persist 自动快照 + 容器重建后开机自动重装）
- **中文输入开箱即用**：fcitx5 + 拼音（`Ctrl+Space` 切换）+ Noto CJK 字体 + zh_CN.UTF-8 locale + LibreOffice 中文界面
- **2G 内存可运行**：XFCE 关合成器 + 初始 30fps + 软编 x264（`mem_limit: 2g` 模板已内置）
- **浏览器只要 Edge**：镜像内唯一浏览器为 Microsoft Edge（官方 apt 仓库，已设为系统默认）
- **zcode 最新版**：Z.ai 官方仓库 [zai-org/ZCode](https://github.com/zai-org/ZCode)（Apache-2.0）的
  CLI 提取分发 `@ljwei-stak/zcode-cli`（TUI / `--web` / Agent 三合一，无 Electron）
- **必要软件工具全家桶**：办公（LibreOffice 文字/表格/演示）、开发（git/tmux/vim/Node24/Python+pip）、
  媒体（mpv）、归档（file-roller/7zip）、系统工具（htop/jq/wget/rsync/ssh 客户端）等
- **GitHub Actions 编译镜像**：推送即构建，打 `v*` 标签自动发 Release

> 镜像架构：`linux/amd64`（Microsoft Edge 与 zcode Linux CLI 均仅提供 x86_64）。

---

## 目录

1. [快速开始](#快速开始)
2. [端口说明](#端口说明)
3. [登录与多人协作](#登录与多人协作)
4. [环境变量](#环境变量)
5. [数据持久化（含软件包持久化）](#数据持久化)
6. [中文输入与中文界面](#中文输入与中文界面)
7. [zcode（Z.ai 编码 CLI）使用指南](#zcodezai-编码-cli使用指南)
8. [2G 内存部署建议](#2g-内存部署建议)
9. [常用应用清单](#常用应用清单)
10. [多实例部署（每人独立桌面）](#多实例部署每人独立桌面)
11. [GitHub Actions 构建与发行](#github-actions-构建与发行)
12. [架构说明](#架构说明)
13. [故障排查](#故障排查)
14. [致谢与许可](#致谢与许可)

---

## 快速开始

### 方式一：docker run（一条命令）

```bash
docker run -d --name selkies-cloud-desktop \
  --shm-size=512m --memory=2g \
  -p 8080:8080 -p 8443:8443 -p 8081:8081 -p 3478:3478/tcp -p 3478:3478/udp \
  -e SELKIES_BASIC_AUTH_USER=admin \
  -e SELKIES_BASIC_AUTH_PASSWORD=你的密码 \
  -v selkies-home:/home/ubuntu \
  -v selkies-edge-config:/home/ubuntu/.config/microsoft-edge \
  -v selkies-edge-cache:/home/ubuntu/.cache/microsoft-edge \
  -v selkies-zcode:/home/ubuntu/.zcode \
  ghcr.io/cshdotcom/selkies-cloud-desktop:latest
```

浏览器打开：

| 地址 | 说明 |
| --- | --- |
| `http://<主机>:8080` | 云桌面 HTTP 入口（弹窗输入用户名+密码） |
| `https://<主机>:8443` | 云桌面 HTTPS 入口（自签证书，首次访问在浏览器接受即可） |
| `http://<主机>:8081` | **ZCode 网页端**（默认同一套用户名+密码登录） |

浏览器弹出登录框 → 输入自定义的**用户名 + 密码** → 进入 XFCE 云桌面；
`8081` 登录后直接进入 ZCode 的网页版编码界面（与云桌面里的 zcode 共用登录态与工作区）。

> 剪贴板、麦克风、摄像头功能在浏览器侧需要安全上下文（HTTPS 或 `localhost`）；
> 想用这些能力请走 `https://<主机>:8443`。

### 方式二：docker compose（推荐，含完整持久化与 2G 资源约束）

```bash
git clone https://github.com/cshdotcom/selkies-cloud-desktop.git
cd selkies-cloud-desktop
cp .env.example .env        # 编辑 .env，设置 SELKIES_BASIC_AUTH_PASSWORD（必填）
docker compose up -d
```

### 方式三：本地构建

```bash
git clone https://github.com/cshdotcom/selkies-cloud-desktop.git
cd selkies-cloud-desktop
docker compose up -d --build
```

---

## 端口说明

| 端口 | 协议 | 用途 |
| --- | --- | --- |
| `8080` | HTTP | 云桌面 Web 入口（登录 + WebSockets/WebRTC 流） |
| `8443` | HTTPS | 云桌面 Web 入口（自签证书；配置真实证书见环境变量表） |
| `8081` | HTTP | **ZCode 网页端**：nginx 认证网关（BasicAuth 登录 → 代理到仅监听本机的 zcode Web 服务） |
| `3478` | TCP+UDP | 内置 coTURN（WebRTC 跨 NAT 中继；同机房/局域网/端口直通场景可不开） |

- 双端口由 `SELKIES_PORT=8080` + `SELKIES_HTTPS_PORT=8443` 实现，同一服务进程同时监听；
- WebSockets 传输（默认）只需 8080/8443 任一可达；WebRTC 传输（Web 面板可切换，双模默认开启）
  在严格 NAT 下依赖 3478 中继或 `--network host`；
- `8081` 网关安全模型见 [zcode 网页端](#zcode-网页端8081独立密码登录) 一节。

---

## 登录与多人协作

### 自定义用户名 / 密码

Web 登录使用 HTTP BasicAuth，**用户名与密码均通过环境变量自定义**，浏览器弹出输入框：

```bash
-e SELKIES_BASIC_AUTH_USER=admin \
-e SELKIES_BASIC_AUTH_PASSWORD=你的密码
```

- 桌面账户（容器内 `ubuntu` 用户）的密码独立配置：`-e PASSWD=另一个密码`（sudo 提权时使用）。
- 容器启动时若检测到密码仍是出厂占位值（`mypasswd`），会在日志里明确告警。

### 多人同时控制（共享同控）

Selkies 的多连接模型：**任何人用同一地址再开一个标签页/浏览器/设备登录，都会作为"并列控制器"
加入同一桌面——所有人同时看到同一个画面、同时拥有完整的键鼠控制权**（输入在服务端汇聚执行，
彼此的光标位置互相可见）。

- 你自己：`https://主机:8443`
- 同事 A（另一个浏览器/另一台电脑）：同样地址 + 同样的用户名密码 → 立即加入共同控制
- 会话分辨率默认跟随**最新连接**的浏览器窗口自适应（`SELKIES_ENABLE_RESIZE=true`）

### 只读观看 / 分级权限（可选）

| 链接/密码 | 权限 |
| --- | --- |
| 同一地址 + 登录密码 | 完整控制（默认） |
| 同一地址 + **观看密码** `SELKIES_BASIC_AUTH_VIEWONLY_PASSWORD` | 只能看，不能操作 |
| `https://主机:8443/#shared` | 只读观看链接（无需另建账号） |
| `https://主机:8443/#player2` ~ `#player4` | 观看 + 对应手柄槽位操作（云游戏场景） |

> 输入权限在**服务端**强制执行，改前端无法越权。

---

## 环境变量

常用变量（完整清单见 [Selkies Settings Reference](https://docs.selkies.io/settings)）：

### 登录与账户

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SELKIES_ENABLE_BASIC_AUTH` | `true` | 启用 BasicAuth 登录 |
| `SELKIES_BASIC_AUTH_USER` | `admin`（compose） | Web 登录**用户名**（可自定义） |
| `SELKIES_BASIC_AUTH_PASSWORD` | 必填（compose） | Web 登录**密码**（可自定义） |
| `SELKIES_BASIC_AUTH_VIEWONLY_PASSWORD` | 空 | 只读观看密码（不设则全员完整控制） |
| `ZCODE_WEB_USER` | 复用 `SELKIES_BASIC_AUTH_USER` | zcode 网页端（8081）登录用户名 |
| `ZCODE_WEB_PASSWORD` | 复用 `SELKIES_BASIC_AUTH_PASSWORD` | zcode 网页端（8081）登录密码；两者均未设时 8081 拒绝放行 |
| `ZCODE_WEB_PORT` | `8081` | zcode 网页端网关监听端口 |
| `ZCODE_WEB_TOKEN` | 每次启动随机 | zcode 内层 token（固定指定可自义；默认随机更安全） |
| `ZCODE_WEB_WORKSPACE` | `~/workspace` | zcode 网页端默认工作区（在家目录持久化卷内） |
| `PASSWD` | `mypasswd` | 容器内桌面账户密码（sudo 用） |

### 网络 / 端口 / 证书

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SELKIES_PORT` | `8080` | HTTP 监听端口 |
| `SELKIES_HTTPS_PORT` | `8443`（本镜像默认） | HTTPS 监听端口（与 HTTP 同时开放） |
| `SELKIES_ENABLE_HTTPS` | `false` | 是否把主端口也切为 HTTPS |
| `SELKIES_HTTPS_CERT` / `SELKIES_HTTPS_KEY` | 自签 | 挂载真实证书：`-v ./cert.pem:/certs/fullchain.pem -e SELKIES_HTTPS_CERT=/certs/fullchain.pem ...` |
| `SELKIES_MODE` | `websockets` | 传输模式：`websockets` / `webrtc` |
| `SELKIES_ENABLE_DUAL_MODE` | `true` | 双模开关（Web 面板里可切换传输） |
| `SELKIES_TURN_HOST` 等 | 自动 | 外部 TURN 配置；不配置时自动启用内置 coTURN（3478） |

### 画质与资源（2G 优化默认值）

| 变量 | 默认 | 说明 |
| --- | --- | --- |
| `SELKIES_FRAMERATE` | `30,8-60` | 初始 30fps，允许 8-60（Web 面板可调） |
| `SELKIES_VIDEO_BITRATE` | `6000,1000-16000`（compose） | 初始 6Mbps，允许 1-16Mbps |
| `SELKIES_ENCODER` | `h264enc` | 软编 x264；有 GPU 时自动用 NVENC/VA-API |
| `DISPLAY_SIZEW` / `DISPLAY_SIZEH` | `1600`/`900`（compose） | 初始分辨率，连入后随浏览器自适应 |
| `SELKIES_AUDIO_ENABLED` | `true` | 音频（PipeWire → Opus） |
| `SELKIES_ENABLE_CLIPBOARD` | `true` | 双向剪贴板（文本 + 图片） |

---

## 数据持久化

四个独立卷（compose 已配好，`docker run` 见快速开始）：

| 卷 | 容器路径 | 保存内容 |
| --- | --- | --- |
| `home` | `/home/ubuntu` | **常规目录**：桌面/文档/下载/图片/音乐/视频 + 各应用 dotfiles + `~/persist`（软件包清单） |
| `edge-config` | `/home/ubuntu/.config/microsoft-edge` | **Edge 软件目录**：书签、密码、扩展、登录态、设置 |
| `edge-cache` | `/home/ubuntu/.cache/microsoft-edge` | **Edge 缓存**（体积大、可丢弃，单独成卷便于只读/清理） |
| `zcode-data` | `/home/ubuntu/.zcode` | **zcode 专属目录**：`/login` 认证态、会话、插件与模型配置 |

行为细节：

- **首次开机**自动铺 `/etc/skel` 模板（XFCE 关合成器等 2G 优化配置），之后所有改动随卷持久化；
- 容器销毁重建（`docker compose down && up -d`）后，桌面、Edge 登录态、zcode 认证全部原样恢复；
- 使用 **bind mount** 时请确保宿主机目录属主为 `1000:1000`
  （`mkdir -p data/home && sudo chown -R 1000:1000 data`），或交给入口脚本自动修复（内置
  `sudo-root chown` 兜底）；

### 软件包持久化（pkg-persist，自动）

会话内 `sudo apt install ...` 装的软件默认位于容器层：容器**重启**保留；容器**删除重建**后丢失。
本镜像内置 `pkg-persist` 机制补上这一环，实现**数据 + 软件双完整持久化**：

| 动作 | 时机 | 说明 |
| --- | --- | --- |
| 快照 | 每 30 分钟 + 容器停止时 | 用户在基线之上新装的包写入 `~/persist/system-packages.txt`（家目录卷） |
| 恢复 | 容器重建后开机 | 后台 `apt-get install` 清单中的包，日志见 `~/persist/pkg-persist.log` |

常用命令（桌面终端内）：

```bash
pkg-persist list              # 查看已持久化的软件包清单
pkg-persist save              # 立即快照当前新装的包
pkg-persist remove gimp       # 从清单移除某个包（下次重建不再自动装）
```

> 注：恢复需联网且耗时与包数量成正比；重要数据请永远放在家目录卷内（桌面/文档/下载等）。

---

## 中文输入与中文界面

### 输入法（开箱即用）

- 桌面已内置 **fcitx5 + 拼音**（`fcitx5-chinese-addons`）并随会话自启；
- 任意输入框按 **`Ctrl + Space`** 切换中英文；任务栏托盘可见 fcitx5 图标；
- 输入法配置界面：开始菜单搜 "Fcitx 5 Configuration"（`fcitx5-config-qt`），可加双拼/五笔/仓颉等；
- 覆盖范围：GTK（Edge/Thunar/Mousepad/LibreOffice）、Qt（Qt5/Qt6 应用）、XIM（终端等）均有前端模块；
- 字体：Noto Sans CJK / 彩色 Emoji 已内置，中文显示不口口。

### 中文界面（可选）

镜像已生成 `zh_CN.UTF-8` locale 并预装 `language-pack-zh-hans` 与
`libreoffice-l10n-zh-cn`（LibreOffice 中文界面默认即中文）。想整体切成中文界面：

```bash
# 写入 ~/.bashrc 后重启容器（或重新登录会话）
echo 'export LANG=zh_CN.UTF-8' >> ~/.bashrc
echo 'export LANGUAGE=zh_CN:zh' >> ~/.bashrc
```

或只给单个应用切中文：`LANG=zh_CN.UTF-8 libreoffice`。XFCE 面板等自身翻译随
`LANG` 自动切换（上游镜像保留了应用的翻译文件）。

---

## zcode（Z.ai 编码 CLI）使用指南

镜像内安装了 [zai-org/ZCode](https://github.com/zai-org/ZCode)（Z.ai 官方开源，Apache-2.0）的
CLI 发行版：终端 `zcode` 命令 = **TUI 交互 + 本地 Web 界面 + Agent CLI** 三合一（无 Electron，
无需桌面即可运行，node>=24.14.0 已内置）。

### 首次登录

桌面打开终端（或开始菜单里的 **ZCode** 快捷方式）：

```bash
zcode                # 进入 TUI 交互界面
```

TUI 内输入 `/login` → 选择 Z.AI / BigModel 浏览器授权（会自动调起 Edge 完成登录）。
登录态保存在 `~/.zcode`（持久化卷），**重建容器后无需重新登录**。

### 直接用 API Key / GLM Coding Plan 启动（免登录）

在 compose 里取消注释并填入：

```yaml
environment:
  ZCODE_MODEL: "zai/glm-4.6"                      # 格式必须是 provider/model
  ZCODE_BASE_URL: "https://api.z.ai/api/anthropic" # Z.ai Anthropic 兼容端点
  ANTHROPIC_API_KEY: "sk-你的Key"                  # Z.ai / BigModel API Key
```

使用 GLM Coding Plan 订阅时，端点换为 BigModel（智谱开放平台）：

```bash
export ZCODE_BASE_URL="https://open.bigmodel.cn/api/anthropic"
# OpenAI 兼容端点则为：https://open.bigmodel.cn/api/coding/paas/v4
```

> 在 GLM Coding Plan 订阅下使用 ZCode 可享额度折扣活动（以
> [官方文档](https://docs.bigmodel.cn/cn/coding-plan/tool/zcode) 为准）。

### 常用命令

```bash
zcode                       # TUI 交互（云桌面里最常用）
zcode -p "解释这个仓库的结构" --mode plan   # 单次非交互调用
zcode doctor                # 运行环境自检
zcode --version             # 版本
```

### zcode 网页端（8081，独立密码登录）

除了云桌面里的终端 TUI（应用端），镜像同时常驻一个 **ZCode 网页端**（第二个网页入口）：

```text
浏览器 ──① BasicAuth 弹窗输用户名+密码──▶ nginx 认证网关 :8081 ──② 注入随机 Bearer token──▶ zcode --web（仅监听 127.0.0.1:3030）
```

- **打开方式**：`http://<主机>:8081` → 浏览器弹窗输入用户名+密码 → 进入 ZCode 网页版界面；
- **一套密码走天下**：默认复用 `SELKIES_BASIC_AUTH_USER/PASSWORD`；需要单独密码时设
  `ZCODE_WEB_USER` / `ZCODE_WEB_PASSWORD`（改后重启容器生效）；
- **双层认证**：外层 nginx BasicAuth（bcrypt 哈希校验，未登录连静态资源都拿不到）
  + 内层 zcode token（每次容器启动随机生成，网关自动注入，用户无感知）；
- **不设密码不放行**：`ZCODE_WEB_PASSWORD` 与 `SELKIES_BASIC_AUTH_PASSWORD` 均未设时，
  网关直接停靠，8081 拒绝任何流量（zcode 本体仍仅监听本机回环，不存在裸奔入口）；
- **长连接支持**：网关已透传 WebSocket 升级与流式响应（1 小时空闲超时），对话/流式输出正常；
- **与云桌面同源**：两端共用 `~/.zcode` 登录态与 `~/workspace` 工作区（都在持久化卷内），
  桌面里开始的任务在网页端也能接着看；
- 云桌面内部：开始菜单 → **ZCode Web** 快捷方式会自动带本机 token 直接打开（免二次输密码）。

> 安全提示：8081 为 HTTP（与 8080 同级）。如需加密，建议在前面套一层自己的 TLS 反代
> （或用 Cloudflare Tunnel / frp 等带 TLS 的入口）再对外。

### 升级与更换发行渠道

```bash
sudo npm install -g @ljwei-stak/zcode-cli@latest   # 会话内直接升级到最新
```

想换其他发行渠道（例如未来官方发布的 Linux 原生包）时，重新构建镜像并覆盖
`--build-arg ZCODE_NPM_PACKAGE=...` 即可；`ZCODE_NPM_VERSION` 可钉住版本。

> 说明：zai-org/ZCode 官方 Release 目前仅附 macOS/Windows 桌面包；Linux CLI 由社区
> 按官方源码（Apache-2.0）原样提取分发，本镜像默认采用其中维护最活跃的
> `@ljwei-stak/zcode-cli`（版本跟随上游仓库 tag）。

---

## 2G 内存部署建议

镜像默认即为 2G 预算调优：

| 项 | 默认 | 说明 |
| --- | --- | --- |
| `mem_limit` | `2g`（compose） | 容器整机内存上限 |
| `shm_size` | `512m` | Edge 渲染共享内存（另已加 `--disable-dev-shm-usage`） |
| 帧率 | 30fps 初始 | CPU 软编下均衡值；Web 面板随时可调 8-60 |
| 码率 | 6Mbps 初始 | 文字清晰度足够；弱网下调到 2000-3000 |
| XFCE 合成器 | 关闭 | 省 CPU/内存，Xvfb 上无视觉损失 |
| 初始分辨率 | 1600x900 | 连入后随浏览器自适应 |

进一步压内存：`SELKIES_FRAMERATE=20,8-30`、`SELKIES_VIDEO_BITRATE=3000,1000-8000`、
`DISPLAY_SIZEW=1280 DISPLAY_SIZEH=720`；Edge 同时只开必要标签页（约 300MB/标签）。

---

## 常用应用清单

| 类别 | 应用 |
| --- | --- |
| 桌面 | XFCE 4（面板/桌面/设置守护/xfwm4 窗口管理） |
| 浏览器 | **Microsoft Edge**（唯一浏览器，系统默认） |
| AI 编码 | **zcode**（Z.ai GLM Coding Agent：TUI/Web/CLI） |
| 办公 | LibreOffice Writer/Calc/Impress（含中文界面包） |
| 终端 | xfce4-terminal（bash + 补全 + 中文输入法）+ tmux |
| 文件 | Thunar + 归档（file-roller、7zip）、gvfs 网络位置 |
| 文本/查看 | Mousepad、Vim、Nano（文本）、Ristretto（图片）、Papers（PDF） |
| 媒体 | mpv（视频/音频）、PulseAudio 控制（pavucontrol） |
| 系统工具 | 任务管理器、截图（xfce4-screenshooter）、htop、jq、file、less、计算器 |
| 网络 | curl、wget、openssh-client、rsync、ping/ip |
| 输入法 | fcitx5 + 拼音（`Ctrl+Space` 切换）+ 配置工具，Noto CJK 字体 + 彩色 Emoji |
| 开发 | git、Node.js 24、npm、Python 3 + pip、zip/unzip |

> 上面没有的软件（GIMP、Steam、IDE 等）任选一种方式补：
> ① 会话内 `sudo apt install gimp`（pkg-persist 自动把 gimp 记入持久化清单，重建容器后自动重装）；
> ② 要瘦身进镜像就写进 Dockerfile 重建。

---

## 多实例部署（每人独立桌面）

默认是"一个桌面全员同控"。如果某些同事想要**各自独立的桌面**，起多个实例即可
（每个实例 = 独立桌面 + 独立数据卷）：

```yaml
services:
  desk-alice:
    image: ghcr.io/cshdotcom/selkies-cloud-desktop:latest
    mem_limit: 2g
    shm_size: 512m
    ports: [ "8101:8080", "8444:8443", "8181:8081" ]
    environment:
      SELKIES_BASIC_AUTH_USER: alice
      SELKIES_BASIC_AUTH_PASSWORD: "${ALICE_PASSWD}"
    volumes: [ "alice-home:/home/ubuntu", "alice-edge-cfg:/home/ubuntu/.config/microsoft-edge", "alice-edge-cache:/home/ubuntu/.cache/microsoft-edge", "alice-zcode:/home/ubuntu/.zcode" ]

  desk-bob:
    image: ghcr.io/cshdotcom/selkies-cloud-desktop:latest
    mem_limit: 2g
    shm_size: 512m
    ports: [ "8102:8080", "8445:8443", "8182:8081" ]
    environment:
      SELKIES_BASIC_AUTH_USER: bob
      SELKIES_BASIC_AUTH_PASSWORD: "${BOB_PASSWD}"
    volumes: [ "bob-home:/home/ubuntu", "bob-edge-cfg:/home/ubuntu/.config/microsoft-edge", "bob-edge-cache:/home/ubuntu/.cache/microsoft-edge", "bob-zcode:/home/ubuntu/.zcode" ]

volumes: { alice-home: {}, alice-edge-cfg: {}, alice-edge-cache: {}, alice-zcode: {}, bob-home: {}, bob-edge-cfg: {}, bob-edge-cache: {}, bob-zcode: {} }
```

每个实例内同样支持多人同控（例如 Alice 和她的两个协作者共控 Alice 的桌面）。

---

## GitHub Actions 构建与发行

`.github/workflows/docker-build.yml`：

| 触发 | 行为 |
| --- | --- |
| push 到 `main` | lint → 构建镜像 → 推送 `ghcr.io/cshdotcom/selkies-cloud-desktop:latest`（+ `sha-xxxxxxx`） |
| push `v*` 标签 | 同上构建推送 `v1.0.0` / `1.0` 版本 tag → **自动创建 GitHub Release**（含变更说明） |
| Pull Request | lint → 仅构建不推送（保证 PR 不破坏镜像） |
| 手动 workflow_dispatch | 同 main |

- 使用仓库内置 `GITHUB_TOKEN` 推 GHCR，**无需配置任何额外 secret**；
- BuildKit 缓存（`cache-from/to: type=gha`）加速重复构建；
- lint job 先做 shell/YAML/compose/结构校验，把低级错误挡在构建之前。

本地等价命令：

```bash
docker build -t selkies-cloud-desktop .
docker tag selkies-cloud-desktop ghcr.io/<你>/selkies-cloud-desktop:dev
```

---

## 架构说明

```
┌─────────────────────────────────────────────────────────────────┐
│ ghcr.io/selkies-project/selkies/base:2.2.1-ubuntu26.04（上游）   │
│  · Ubuntu 26.04 LTS · s6 服务监督 · Xvfb(打补丁) · PipeWire 音频 │
│  · Selkies v2 服务器（WebSockets+WebRTC、自签 HTTPS、内置 coTURN）│
├─────────────────────────────────────────────────────────────────┤
│ 本镜像追加层                                                      │
│  · XFCE 完整会话（s6 服务 /etc/service/desktop，等 Xvfb 就绪）   │
│  · xsettingsd 服务停靠（xfce4-settings-daemon 接管 XSETTINGS）   │
│  · Microsoft Edge（apt 官方源 + 启动器加固 + 系统默认浏览器）     │
│  · Node.js 24 + zcode CLI（/opt/zcode，~/.zcode 持久化）         │
│  · zcode --web 本地服务（127.0.0.1:3030 + token）                  │
│  · nginx 认证网关 :8081（BasicAuth → Bearer 注入 → 3030）         │
│  · fcitx5 拼音 + Noto CJK + 常用应用                              │
│  · ENTRYPOINT 包装 desktop-init：首次开机铺模板 / 卷属主修复      │
└─────────────────────────────────────────────────────────────────┘
```

多人同控由 Selkies 服务器原生提供：所有客户端共享同一编码器输出与输入通道，
服务端强制执行输入权限（完整控制 / 只读观看 / 手柄槽位）。

---

## 故障排查

| 症状 | 处理 |
| --- | --- |
| 浏览器打不开 | `docker logs selkies-cloud-desktop`；确认端口映射与 `SELKIES_BASIC_AUTH_PASSWORD` 已设 |
| HTTPS 证书告警 | 自签证书属预期（点"继续访问"）；要正式证书：挂载 `SELKIES_HTTPS_CERT/KEY` 指向你的 pem/key |
| 画面卡顿 | Web 侧栏降低帧率/码率；或 `SELKIES_VIDEO_BITRATE=3000` 重启；跨 NAT 走 WebRTC + 3478 |
| Edge 首次打开慢 | 首次初始化配置文件，之后由持久化卷加速 |
| zcode 提示未登录 | TUI 里 `/login`，或用 `ZCODE_MODEL`/`ZCODE_BASE_URL`/`ANTHROPIC_API_KEY` 环境变量 |
| zcode 网页端 8081 打不开 | `docker logs` 里搜 `zcode-web-gate`：未设密码时网关按设计停靠（设 `ZCODE_WEB_PASSWORD` 或 `SELKIES_BASIC_AUTH_PASSWORD` 后重启）；设了密码仍打不开则看网关日志是否端口冲突 |
| 中文无法输入 | `Ctrl+Space` 切换 fcitx5；托盘无图标时终端跑 `fcitx5 -d &`；确认输入焦点在应用内 |
| 重建容器后软件丢了 | 等 pkg-persist 恢复完成（看 `~/persist/pkg-persist.log`），或手动 `pkg-persist restore` |

---

## 致谢与许可

- [Selkies](https://github.com/selkies-project/selkies)（MPL-2.0）— 本镜像的流式底座，
  由 Google 工程师发起、学术界与 LinuxServer.io 社区维护；
- [linuxserver/docker-webtop](https://github.com/linuxserver/docker-webtop) — 产品形态参考；
- [zai-org/ZCode](https://github.com/zai-org/ZCode)（Apache-2.0）— Z.ai 官方编码 Agent 开源仓库；
  Linux CLI 分发 `@ljwei-stak/zcode-cli` 为其社区提取版；
- Microsoft Edge 按微软 [软件许可条款](https://learn.microsoft.com/microsoft-edge/) 随镜像分发；
- 本仓库自身脚本与配置以 MIT 许可发布（见 [LICENSE](LICENSE)）。

使用即代表你接受各上游组件自身的许可条款。
