# syntax=docker/dockerfile:1
# =============================================================================
# Selkies Cloud Desktop — Ubuntu 26.04 LTS + XFCE lite 桌面 + Microsoft Edge
#                                 + Z.ai ZCode CLI
#
# 产品形态参考 linuxserver/webtop（容器化浏览器云桌面），流式层采用 Selkies v2
# （WebSockets / WebRTC，MPL-2.0），构建于官方 base 容器之上：
#     ghcr.io/selkies-project/selkies/base:2.2.1-ubuntu26.04
#
# 特性：
#   - 多人同时控制同一桌面（Selkies multi-peer，全员完整键鼠权限）
#   - HTTP(8080) 与 HTTPS(8443, 自签证书) 双端口同时监听
#   - BasicAuth 自定义用户名/密码登录（另支持只读观看密码）
#   - 数据持久化：家目录 / Edge 配置与缓存 / ZCode 专属目录
#   - 2G 内存可运行（XFCE 无合成器 + 30fps 初始帧率 + 软编 x264）
#   - 浏览器仅 Microsoft Edge（唯一默认浏览器）
#
# 构建（本仓库 GitHub Actions 自动执行）：
#   docker build -t selkies-cloud-desktop .
# 可选构建参数：
#   --build-arg SELKIES_BASE_IMAGE=ghcr.io/selkies-project/selkies/base:2.2.1-ubuntu26.04
#   --build-arg ZCODE_NPM_PACKAGE=@ljwei-stak/zcode-cli
#   --build-arg ZCODE_NPM_VERSION=latest
# =============================================================================

ARG SELKIES_BASE_IMAGE="ghcr.io/selkies-project/selkies/base:2.2.1-ubuntu26.04"

FROM ${SELKIES_BASE_IMAGE}

LABEL org.opencontainers.image.title="selkies-cloud-desktop" \
      org.opencontainers.image.description="Ubuntu 26.04 + XFCE lite desktop + Microsoft Edge + Z.ai ZCode CLI on Selkies v2 WebRTC: multi-user shared control, HTTP+HTTPS, persistence, 2GB-RAM friendly" \
      org.opencontainers.image.source="https://github.com/cshdotcom/selkies-cloud-desktop" \
      org.opencontainers.image.licenses="MPL-2.0"

ARG DEBIAN_FRONTEND="noninteractive"
# zcode：Z.ai 官方仓库 zai-org/ZCode（Apache-2.0）的无 Electron CLI 提取分发
# （TUI + 本地 Web + Agent，node>=24.14.0，运行时数据写入 ~/.zcode）
ARG ZCODE_NPM_PACKAGE="@ljwei-stak/zcode-cli"
ARG ZCODE_NPM_VERSION="latest"

# -----------------------------------------------------------------------------
# 0) 释放 setuid/setgid 登记表（rootless 分层约定，与上游 desktop addon 一致）
# -----------------------------------------------------------------------------
USER 0
SHELL ["/bin/sh", "-c"]
RUN selkies-privileged-files release

USER 1000
SHELL ["/usr/bin/fakeroot", "--", "/bin/sh", "-c"]

# -----------------------------------------------------------------------------
# 1) XFCE lite 桌面 + 常用应用 + 中文输入法（fcitx5 拼音）+ CJK 字体补强
#    包名与上游 2.2.1 desktop addon 在 ubuntu26.04 上验证过的集合保持一致；
#    所有包名已对照 archive.ubuntu.com resolute/resolute-updates 索引预检
# -----------------------------------------------------------------------------
RUN set -eu; \
    apt-get clean; apt-get update; \
    apt-get install --no-install-recommends -y \
        xfce4 \
        xfce4-terminal \
        thunar \
        thunar-archive-plugin \
        mousepad \
        ristretto \
        xfce4-taskmanager \
        xfce4-screenshooter \
        dbus-x11 \
        pavucontrol \
        pulseaudio-utils \
        file-roller \
        7zip \
        mpv \
        papers \
        gnome-calculator \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress \
        libreoffice-l10n-zh-cn \
        bash-completion \
        openssh-client \
        rsync \
        tree \
        htop \
        psmisc \
        iproute2 \
        iputils-ping \
        curl \
        wget \
        gnupg \
        nano \
        vim \
        vim-tiny \
        tmux \
        jq \
        zip \
        unzip \
        file \
        less \
        locales \
        python3-pip \
        adwaita-icon-theme \
        fonts-noto-cjk \
        fonts-noto-color-emoji \
        gsettings-desktop-schemas \
        libglib2.0-bin \
        gtk-update-icon-cache \
        gvfs \
        gvfs-daemons \
        fcitx5 \
        fcitx5-chinese-addons \
        fcitx5-config-qt \
        fcitx5-frontend-gtk2 \
        fcitx5-frontend-gtk3 \
        fcitx5-frontend-gtk4 \
        fcitx5-frontend-qt5 \
        fcitx5-frontend-qt6 \
        language-pack-zh-hans \
        ; \
    # 生成 zh_CN.UTF-8 locale（应用中文界面 + 输入法所需）\
    locale-gen zh_CN.UTF-8; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# 2) Microsoft Edge（本镜像唯一浏览器）
#    - 官方 apt 仓库（packages.microsoft.com/repos/edge）
#    - 启动器按上游同款方案加固：容器默认 seccomp 下自动回退 --no-sandbox，
#      并附带 --password-store=basic（无 keyring 守护进程）与 --disable-dev-shm-usage
#    - 注册为系统默认浏览器（x-www-browser 备选项 + XDG mimeapps 默认）
# -----------------------------------------------------------------------------
RUN set -eu; \
    mkdir -pm755 /etc/apt/keyrings /etc/apt/sources.list.d; \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft-edge.gpg; \
    echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft-edge.gpg] https://packages.microsoft.com/repos/edge stable main' > /etc/apt/sources.list.d/microsoft-edge.list; \
    apt-get clean; apt-get update; \
    apt-get install --no-install-recommends -y microsoft-edge-stable; \
    EDGE_WRAPPER=/opt/microsoft/msedge/microsoft-edge; \
    if [ -f "${EDGE_WRAPPER}" ] && [ -f /opt/microsoft/msedge/msedge ]; then \
        if grep -q '^exec -a "$0" "$HERE/msedge" "$@"$' "${EDGE_WRAPPER}"; then \
            sed -i 's#^exec -a "$0" "$HERE/msedge" "$@"$#exec -a "$0" "$HERE/msedge" $(unshare --user --map-root-user --pid --net --fork true 2>/dev/null || echo --no-sandbox) --password-store=basic --disable-dev-shm-usage "$@"#' "${EDGE_WRAPPER}"; \
            grep -q -- '--password-store=basic --disable-dev-shm-usage' "${EDGE_WRAPPER}" || { \
                printf '%s\n' '#!/bin/sh' 'exec /opt/microsoft/msedge/msedge $(unshare --user --map-root-user --pid --net --fork true 2>/dev/null || echo --no-sandbox) --password-store=basic --disable-dev-shm-usage "$@"' > "${EDGE_WRAPPER}"; \
            }; \
        else \
            printf '%s\n' '#!/bin/sh' 'exec /opt/microsoft/msedge/msedge $(unshare --user --map-root-user --pid --net --fork true 2>/dev/null || echo --no-sandbox) --password-store=basic --disable-dev-shm-usage "$@"' > "${EDGE_WRAPPER}"; \
        fi; \
        chmod -f 755 "${EDGE_WRAPPER}"; \
    else \
        echo 'WARN: unexpected Microsoft Edge install layout; launcher left unpatched'; \
    fi; \
    if [ -e /usr/bin/microsoft-edge ]; then \
        update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/microsoft-edge 200; \
        update-alternatives --install /usr/bin/www-browser www-browser /usr/bin/microsoft-edge 200; \
    fi; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# 3) Node.js 24（NodeSource）+ zcode CLI（Z.ai 官方仓库社区提取分发）
#    安装到 /opt/zcode（全局 bin 由最后一层真实 root 软链到 /usr/local/bin）
# -----------------------------------------------------------------------------
RUN set -eu; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    echo 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main' > /etc/apt/sources.list.d/nodesource.list; \
    apt-get clean; apt-get update; \
    apt-get install --no-install-recommends -y nodejs; \
    mkdir -pm755 /opt/zcode; \
    HOME=/tmp npm_config_cache=/tmp/npm-cache npm install --global --prefix /opt/zcode "${ZCODE_NPM_PACKAGE}@${ZCODE_NPM_VERSION}"; \
    HOME=/tmp /opt/zcode/bin/zcode --version || echo 'WARN: zcode --version smoke test failed (non-fatal)'; \
    rm -rf /tmp/npm-cache /tmp/*; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /var/cache/debconf/* /var/log/* /tmp/* /var/tmp/*

# -----------------------------------------------------------------------------
# 3b) 软件包持久化基线：记录镜像构建完成时的 apt 手动安装包集合。
#     pkg-persist（rootfs 内）用它计算“用户在会话内新装的包”，快照到
#     ~/persist/system-packages.txt（家目录持久化卷），容器重建后开机自动重装。
# -----------------------------------------------------------------------------
RUN set -eu; \
    apt-mark showmanual | LC_ALL=C sort -u > /opt/pkg-baseline.txt; \
    [ -s /opt/pkg-baseline.txt ]; \
    printf '# selkies-cloud-desktop package baseline (build time)\n' >> /opt/pkg-baseline.txt; \
    wc -l /opt/pkg-baseline.txt

# -----------------------------------------------------------------------------
# 4) 本仓库的 rootfs 配置层：
#    - /etc/service/desktop/        新增 s6 服务：Xvfb 就绪后启动完整 XFCE 会话
#    - /etc/service/xsettingsd/run  改为停靠（XFCE 自带 xfce4-settings-daemon
#                                   提供 XSETTINGS，避免双管理器争抢 selection）
#    - /etc/service/pkg-persist/    软件包持久化：定时快照 + 重建后自动恢复
#    - /etc/xdg/autostart/fcitx5    输入法自启（中文输入，Ctrl+Space 切换）
#    - /usr/local/bin/pkg-persist   软件包持久化工具
#    - /etc/xdg/mimeapps.list       默认浏览器 = Microsoft Edge
#    - /etc/skel/...                首次开机家目录模板（关合成器等 2G 优化）
#    - zcode 桌面快捷方式（TUI / 本地 Web 两种入口）
#    - scripts/desktop-init         ENTRYPOINT 包装：首次开机初始化 + 卷属主修复
# -----------------------------------------------------------------------------
COPY --chown=1000:1000 rootfs/ /
COPY --chown=1000:1000 scripts/desktop-init /usr/local/bin/desktop-init

RUN set -eu; \
    chmod -f 755 /usr/local/bin/desktop-init /usr/local/bin/pkg-persist \
        /etc/service/desktop/run /etc/service/desktop/finish \
        /etc/service/pkg-persist/run /etc/service/pkg-persist/finish \
        /etc/service/xsettingsd/run; \
    install -d -m755 /home/ubuntu/Desktop /home/ubuntu/Documents /home/ubuntu/Downloads \
        /home/ubuntu/Pictures /home/ubuntu/Music /home/ubuntu/Videos \
        /home/ubuntu/.config/microsoft-edge /home/ubuntu/.cache/microsoft-edge \
        /home/ubuntu/.zcode; \
    EDGE_DESKTOP="$(basename "$(ls /usr/share/applications/microsoft-edge*.desktop 2>/dev/null | head -n 1)" 2>/dev/null || true)"; \
    if [ -n "${EDGE_DESKTOP}" ] && [ "${EDGE_DESKTOP}" != "microsoft-edge.desktop" ]; then \
        sed -i "s#microsoft-edge\.desktop#${EDGE_DESKTOP}#g" /etc/xdg/mimeapps.list; \
    fi; \
    printf "[org.gnome.desktop.wm.preferences]\nbutton-layout=':minimize,maximize,close'\n" \
        > /usr/share/glib-2.0/schemas/selkies-decoration.gschema.override; \
    glib-compile-schemas /usr/share/glib-2.0/schemas/ || true; \
    if [ -f /etc/gtk-3.0/settings.ini ] && grep -q '^\[Settings\]' /etc/gtk-3.0/settings.ini; then \
        sed -i '/^\[Settings\]/a gtk-decoration-layout=:minimize,maximize,close' /etc/gtk-3.0/settings.ini; \
    else \
        mkdir -pm755 /etc/gtk-3.0; \
        printf '[Settings]\ngtk-decoration-layout=:minimize,maximize,close\n' > /etc/gtk-3.0/settings.ini; \
    fi; \
    printf '%s\n' '' \
        '# selkies-cloud-desktop: user-local bin on PATH' \
        'case ":${PATH}:" in *":${HOME}/.local/bin:"*) ;; *) PATH="${HOME}/.local/bin:${PATH}" ;; esac' \
        "alias ll='ls -alF'" \
        >> /etc/bash.bashrc

# -----------------------------------------------------------------------------
# 5) 收尾（真实 root 层）：恢复 setuid/setgid、软链 zcode、xfce4-terminal 的
#    utempter setgid（与上游 desktop addon 相同的恢复流程）
# -----------------------------------------------------------------------------
USER 0
SHELL ["/bin/sh", "-c"]
RUN set -eu; \
    ln -sfn /opt/zcode/bin/zcode /usr/local/bin/zcode; \
    [ -e /opt/zcode/bin/zcode ]; \
    selkies-privileged-files restore; \
    for helper in /usr/lib/*/utempter/utempter /usr/libexec/utempter/utempter; do \
        if [ -e "${helper}" ]; then \
            chown -f root:utmp "${helper}" && chmod -f 2755 "${helper}" || \
                echo "WARN: could not restore setgid on ${helper}"; \
        fi; \
    done

USER 1000
SHELL ["/bin/sh", "-c"]

# -----------------------------------------------------------------------------
# 6) 默认运行时配置
# -----------------------------------------------------------------------------
# SELKIES_DESKTOP=false : 不启动 Selkies 自带的极简 WM/shell，完整 XFCE 会话由
#                          /etc/service/desktop 提供（多人同控 = 所有连接者共享该会话）
# SELKIES_HTTPS_PORT    : 与 HTTP(SELKIES_PORT, 8080) 同时监听的 HTTPS 端口，
#                          未配置证书时自动生成自签证书
# SELKIES_FRAMERATE     : 初始 30fps（区间 8-60），2G 内存/小核 CPU 的均衡默认值
# SELKIES_COMMAND_ENABLED: 允许 Web 面板向会话内执行命令（完整权限开放）
# *_IM_MODULE / XMODIFIERS: fcitx5 中文输入
ENV SELKIES_DESKTOP="false" \
    SELKIES_COMMAND_ENABLED="true" \
    SELKIES_HTTPS_PORT="8443" \
    SELKIES_FRAMERATE="30,8-60" \
    BROWSER="/usr/bin/microsoft-edge" \
    GTK_IM_MODULE="fcitx" \
    QT_IM_MODULE="fcitx" \
    XMODIFIERS="@im=fcitx"

# HTTP / HTTPS / 内置 coTURN（WebRTC 中继，tcp+udp）
EXPOSE 8080 8443 3478/tcp 3478/udp

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD timeout 3 bash -c "</dev/tcp/127.0.0.1/${SELKIES_PORT:-8080}" || exit 1

# 先做首次开机初始化（家目录模板 / 持久化目录 / 卷属主修复），再交接给
# 上游 base 的 /etc/container-entrypoint.sh（s6 服务监督）
ENTRYPOINT ["/usr/local/bin/desktop-init"]
