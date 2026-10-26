# GCL — GlassCraft Launcher

你的世界，由你定义。独立的 Minecraft Java Edition 启动器项目，提供 Mac 原生版、Windows/Linux 桌面版和 iOS 侧载开发包，由 Aaron-CNSD 维护。

[下载 Release](https://github.com/Aaron-CNSD/GCL/releases) · [贡献者与致谢](CONTRIBUTORS.md) · [使用说明](docs/MACOS.md)

## 下载格式

详见 [平台、安装和验证范围](docs/PLATFORMS.md)。

| 平台 | 文件 | 打开方式 |
| --- | --- | --- |
| macOS 13+，ARM / Intel | DMG、ZIP、macOS.jar | 原生应用；Mac JAR 是该应用入口 |
| Windows x64 | windows-x64.zip | 解压运行 Start-GCL.cmd，内置启动器 Java |
| Linux x64 桌面 | linux-x64.tar.gz | 解压运行 ./start-gcl.sh，内置启动器 Java |
| Windows / Linux / Mac（桌面 Java 实现） | Desktop.jar | Java 17+；功能范围不同于 Mac 原生版 |
| iOS / iPadOS 14+ | iOS.ipa | 重新签名侧载，需设备支持 JIT；未真机验证 |

macOS 26+ 和 iOS 26+ 使用系统原生 Liquid Glass；旧系统使用系统材质回退。Windows / Linux 不调用 Apple 的 Liquid Glass API。包内许可证与源码署名保留。游戏完整进入世界仍待验证。

当前开发版本：**v0.3.0**。Apple 原生 Liquid Glass 分栏、工具栏与按钮，新增 Windows / Linux 自带 Java 便携包和 iOS 侧载 IPA；桌面正式版列表扩展至 1.7+ 与 26.x。

[保持用户免费的收入方案](docs/MONETIZATION.md)

## Mac 原生版功能

- 游戏版本、Java 与加载器管理；原版 / Forge / NeoForge / Fabric / Quilt。
- 软件内搜索下载模组、整合包和光影，导入 `.mrpack`。
- 本地 PNG 皮肤，通过按需下载 CustomSkinLoader 实现。
- 陶瓦房间式联机：系统授权安装组件后，创建房间、分享房间码、加入朋友。
- macOS 26+ 系统液态玻璃，旧系统半透明材质。

## 验证范围

开发预览，不保证任意版本可玩。既有版本已测试编译、下载接口、资源 / 皮肤配置、整合包导入和模拟房间 API；**完整进入世界、游戏内皮肤和真实跨网联机尚未验证**，Forge / NeoForge 完整安装亦未验证。CurseForge ZIP 暂不支持。iOS IPA 已构建，仍需重新签名及符合设备条件的 JIT，尚未完成真机游戏测试。

由 GlassCraft 的 macOS 分支整理而来，沿用 `~/Library/Application Support/GlassCraft` 数据目录，避免升级丢失原有配置。iOS 通过固定版本子模块接入 Amethyst 原生引擎，GCL 首页与构建覆盖文件位于 ios/；保留 GPL 和全部第三方致谢。非 Mojang / Microsoft 官方产品。

## 构建

`bash scripts/package.sh /绝对路径/输出目录`。需要 macOS、Xcode 命令行工具和 JDK 17+（Mac JAR 使用 Java 8 目标字节码，Desktop JAR 使用 Java 17）。构建器输出 ZIP、DMG、JAR 与 SHA256SUMS。许可 GPL-3.0，第三方组件遵循其各自许可。

独立项目首个开发版本为 **v0.1.0**。应用与 DMG 现使用 GCL 像素草地方块图标；JAR 文件在 Finder 中通常显示 Java 图标，运行后打开的 GCL.app 使用应用图标。

官网介绍页：https://aarongame.com/ 。单文件 HTML 源码位于 `website/index.html`，包含样式、交互式功能示意、下载入口和开发预览说明。
