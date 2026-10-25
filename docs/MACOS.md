# GlassCraft macOS 0.2 开发预览

这是本项目新增的 SwiftUI 原生 Mac 应用，不是 Amethyst IPA 的改名包。源码位于 macos/，沿用本仓库 GPL-3.0 许可。

## 安装

下载 GlassCraft-macOS-universal.zip，解压后将 GlassCraft.app 放入应用程序。支持 macOS 13+，含 Apple Silicon 与 Intel 二进制。应用为临时签名，未经过 Apple 公证；系统可能阻止打开，可在系统设置「隐私与安全性」中按系统提示处理。无需关闭 Gatekeeper。

## 使用

1. 输入 3–16 位本地用户名，选择游戏版本与内存。
2. 点击「下载并启动游戏」：自动准备 Temurin Java、游戏文件、依赖库和音效资源；校验 SHA-256 / SHA-1。首次下载较大，请保持联网。
3. 游戏输出在 ~/Library/Application Support/GlassCraft/logs/latest.log；各版本有独立 instances 目录。
4. 「资源中心」打开网页检索；导入模组 / 光影只是复制文件。**自动安装 Forge/Fabric、整合包和启用光影尚未实现，当前自动启动仅支持原版 1.19+**。

本地账号不登录 Microsoft，不能进入要求正版验证的服务器。旧游戏版本的原生依赖未必兼容 Apple Silicon。没有物理 Intel Mac 或完整游戏进入世界的验证结果，不保证所有列出的版本能运行。未打包 Microsoft 游戏文件或 Java 二进制，首次启动从官方源获取。

## 开发

运行 `bash macos/build.sh`。下载接口为 Mojang manifest/resources 与 Adoptium v3；开源运行时的许可由其下载包保留。此版本未实现下载取消、Microsoft 登录或自动更新。

## 0.3：导入整合包

点击「导入整合包 .mrpack」，选择从 Modrinth 导出的文件，等待下载校验完成；在「启动配置」中选择该包，点击「下载并启动游戏」。导入后会自动选中整合包和对应游戏版本。可在运行游戏前更改用户名与内存；若用户名被禁用，先切回原版修改再选回整合包。

支持 Minecraft 1.19+ 的原版、Fabric、Quilt `.mrpack`，自动获取对应加载器配置和依赖。包内 overrides 与 client-overrides 按顺序覆盖，客户端标记为 optional / unsupported 的文件默认跳过。失败导入不会登记启动配置；每次导入创建新实例，不覆盖旧存档。

不支持 Forge、NeoForge、CurseForge ZIP。下载地址限 Modrinth / GitHub / GitLab 官方格式允许的主机；使用其他源的包会报告失败。导入与加载器依赖下载经过自动化测试，尚未完成游戏进入世界的真机验证。

## 0.4：选择加载器

在「启动配置」选择「新建 / 原版」，选择 Minecraft 版本，再在「加载器」中选择原版、Forge、NeoForge、Fabric 或 Quilt。选择对应的加载器版本后点击「安装加载器」。完成后会创建并自动选中独立配置，再点击「下载并启动游戏」。原版无需安装加载器。

Forge / NeoForge 从官方 Maven 下载并校验官方安装器，运行客户端安装流程以生成补丁与启动配置。Fabric / Quilt 使用官方 metadata 服务。Minecraft 版本范围仍为 1.19+；没有对应发行版时会提示。NeoForge 1.20.1 暂不提供，1.20.2+ 按对应版本筛选。

`.mrpack` 的 Forge / NeoForge 依赖现在也会调用相同安装流程。CurseForge ZIP 仍未适配。所有加载器安装均可能因上游网络或不兼容的处理器失败，错误信息会指向 logs/installer-Forge.log 或 installer-NeoForge.log。完整游戏进入世界仍未验证，不保证任意整合包都可运行。

## 0.5：液态玻璃、内置资源、本地皮肤与联机

- macOS 26+ 使用系统 Liquid Glass；macOS 13–15 使用半透明材质，保留兼容。
- 资源下载页内搜索 Modrinth 模组、整合包、光影，选择版本后直接下载到当前配置。整合包下载后自动进入导入流程。额外模组依赖仍需另行安装，不支持 CurseForge ZIP。
- 一键联机：填写允许离线账号的服务器地址，例如 `192.168.1.8:25565`，点击启动并加入。1.20+ 使用 Quick Play，1.19 使用旧版服务器参数。双方游戏、加载器和模组必须匹配；不提供服务器托管或公网穿透，不绕过微软服务器验证。
- 我的皮肤：选择 64×64 / 64×32 PNG，小于 2 MB。自动下载当前版本兼容的 CustomSkinLoader；原版会创建 Fabric 配置。图片保存在当前实例 `CustomSkinLoader/LocalSkin/skins/<用户名>.png`，配置本地皮肤优先，已有配置首次修改前保存 `.glasscraft-backup`。无需上传皮肤。其他玩家需同样的皮肤配置才能看到，修改用户名后重新应用，重启游戏生效。
- 修正整合包选中时无法修改用户名、加载器版本列表异步请求覆盖、资源与当前版本不匹配的问题。新增限时重试、取消下载 / 安装 / 游戏进程，进程等待改为异步，避免阻塞取消。

验证：Apple Silicon / Intel 通用编译与签名；原生窗口和内置搜索；真实皮肤模组下载、校验、本地 PNG 与优先配置；联机地址 / 参数；异步进程结束与取消测试。尚未验证游戏内皮肤显示、两台机器实际联机、完整进入世界，Forge / NeoForge 安装的既有限制仍适用。

开源皮肤组件：https://github.com/xfl03/MCCustomSkinLoader （GPL-3.0，按需从官方 Modrinth 项目下载，不打包冒充自研组件）。

## 0.6：陶瓦式房间码联机

现已接入 Terracotta 0.4.2 官方独立组件，通过仅监听 127.0.0.1 的 HTTP API 控制，不修改或链接其二进制，联机界面显著保留原作者与许可信息。支持 Apple Silicon / Intel，按当前架构下载并固定 SHA-256 校验官方包。许可及上游 README 位于 docs/third-party/。

1. 打开「一键联机」→「安装系统组件」。下载在软件内完成，随后由 macOS 系统安装器提示你完成安装授权。不会自动输入密码或代你授权。首次使用还需按系统提示允许陶瓦访问本地网络。
2. 点击「启动陶瓦」。系统组件 `/Applications/terracotta.app` 缺失时会阻止启动，避免出现能开界面却无法发现房间的问题。
3. 房主先启动游戏、进入存档并「对局域网开放」，再点击「创建房间」。核心扫描后生成陶瓦房间码；点击复制，自己发给朋友。
4. 朋友输入完整 `U/…` 房间码，点击「加入房间」。状态到「已加入」后可以启动并进入房间，也可在游戏多人列表中选择陶瓦广播的局域网入口。
5. 结束时点击「离开 / 重置」。组件独立运行，关闭启动器不强制终止可能被其他启动器共享的陶瓦服务。

不要求在 GlassCraft 登录 Microsoft，但双方游戏、加载器和模组必须匹配。不是永久公网服务器；P2P 穿透依赖公共节点和 NAT 条件，不保证任何网络都可连接。应用保留高级地址直连功能。

验证：通用编译、签名、官方档案校验和解包、安装前置检查、本机模拟 HTTP API 的创建 / 加入 / 重置参数，以及邀请码 / 成员 / 连接地址状态转换。**没有完成系统级组件安装或真实双机跨网测试**；模拟 API 测试不代表 P2P 已验证。新版原生界面检查工具超时，未完成该页面的交互检查。

上游：https://github.com/burningtnt/Terracotta
官方集成文档：https://burningtnt.github.io/Terracotta/http-api/
