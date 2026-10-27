import SwiftUI

extension LauncherView {
    var downloadCenter:some View {
        VStack(spacing:16) {
            GlassPanel {
                VStack(alignment:.leading,spacing:12) {
                    Text("安装与内容").font(.headline)
                    Text("当前游戏：\(m.selected) · 安装加载器后，可直接搜索匹配的模组。整合包会导入为独立配置。")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("操作",selection:$m.contentSection) {
                        Text("资源下载").tag("资源下载")
                        Text("加载器").tag("加载器")
                        Text("整合包导入").tag("整合包导入")
                    }.pickerStyle(.segmented)
                }
            }
            switch m.contentSection {
            case "加载器":
                configuration
                play
            case "整合包导入":
                GlassPanel {
                    VStack(alignment:.leading,spacing:16) {
                        Label("导入整合包",systemImage:"shippingbox").font(.title3.weight(.semibold))
                        Text("选择 .mrpack 文件，自动下载清单中的游戏与资源，并创建独立游戏配置。")
                        Button("选择 .mrpack 文件…"){m.importModpack()}.buttonStyle(.borderedProminent).disabled(m.busy)
                        Button("在线寻找整合包"){m.resourceType="modpack";m.contentSection="资源下载"}.buttonStyle(.borderless)
                        Text("目前支持 Modrinth .mrpack；CurseForge ZIP 暂不支持。导入后可在首页选择该配置。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            default: resources
            }
        }
    }
}
