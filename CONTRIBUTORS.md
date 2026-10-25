# 贡献者与开源致谢

## 项目维护

- [Aaron-CNSD](https://github.com/Aaron-CNSD)：项目所有者、功能与产品方向。
- 实现过程中使用 OpenAI Codex 辅助编程与验证；Codex 为工具，不作为独立的人类贡献者。
- 实际 Git 提交贡献记录以 [GitHub Contributors](https://github.com/Aaron-CNSD/GCL/graphs/contributors) 为准，不添加虚构贡献者。

## 第三方组件与数据源

- [burningtnt / Terracotta](https://github.com/burningtnt/Terracotta)：独立房间联机组件，未经修改，通过本机 HTTP API 集成；AGPL-3.0-or-later 及其集成例外。许可和 README 见 docs/third-party。
- [xfl03 / MCCustomSkinLoader](https://github.com/xfl03/MCCustomSkinLoader)：按需从官方 Modrinth 项目下载的本地皮肤模组，GPL-3.0；保留该模组自身署名。
- [FabricMC](https://fabricmc.net/)、[QuiltMC](https://quiltmc.org/)、[MinecraftForge](https://minecraftforge.net/)、[NeoForged](https://neoforged.net/)：各自的官方加载器元数据和安装器；不冒称为 GCL 自研。
- [Eclipse Adoptium](https://adoptium.net/)：按需下载的 Temurin 运行时；保留下载包中的许可。
- Mojang / Microsoft：游戏元数据与资源源站；Modrinth：公开资源元数据与下载源。

GCL 不打包游戏文件或上述加载器 / 皮肤 / 联机运行时，实际使用时从相应官方源下载。
