import SwiftUI
import CryptoKit

struct GCLRelease: Decodable {
    struct Asset: Decodable { let name: String; let browser_download_url: URL; let digest: String? }
    let tag_name: String
    let html_url: URL
    let assets: [Asset]
    let prerelease: Bool
    let draft: Bool
    let body: String?
}

@MainActor final class LauncherUpdate: ObservableObject {
    @Published var message = "尚未检查更新"
    @Published var release: GCLRelease?
    @Published var history=[GCLRelease]()
    @Published var checking = false
    @Published var downloading = false
    @Published var downloaded: URL?

    private var current: String { Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.2.0" }
    private func version(_ value: String) -> String { value.trimmingCharacters(in: CharacterSet(charactersIn:"vV")) }
    private func package(_ release: GCLRelease) -> GCLRelease.Asset? {
        release.assets.first { asset in
            let name=asset.name.lowercased()
            return (name.hasSuffix(".zip") || name.hasSuffix(".dmg")) && (name.contains("mac") || name.contains("universal")) && asset.browser_download_url.scheme == "https" && asset.browser_download_url.host == "github.com" && asset.browser_download_url.path.hasPrefix("/Aaron-CNSD/GCL/releases/download/")
        }
    }
    func check() {
        guard !checking && !downloading else { return }
        checking=true;release=nil;downloaded=nil;message="正在检查更新…"
        Task {
            defer { checking=false }
            do {
                var request=URLRequest(url:URL(string:"https://api.github.com/repos/Aaron-CNSD/GCL/releases?per_page=30")!)
                request.setValue("GCL-updater",forHTTPHeaderField:"User-Agent")
                request.timeoutInterval=20
                let (data,response)=try await URLSession.shared.data(for:request)
                guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else { throw LaunchError(message:"无法读取发布信息") }
                let releases=try JSONDecoder().decode([GCLRelease].self,from:data)
                let usable=releases.filter { item in
                    let value=version(item.tag_name)
                    return !item.draft && value.range(of:"^[0-9]+(\\.[0-9]+){1,3}$",options:.regularExpression) != nil && package(item) != nil
                }.sorted { version($0.tag_name).compare(version($1.tag_name),options:.numeric) == .orderedDescending }
                history=usable
                guard let result=usable.first else { message="没有找到可用的 macOS 发布版本";return }
                let latest=version(result.tag_name)
                if latest.compare(version(current),options:.numeric) != .orderedDescending { message="当前已是最新版本（\(current)）";return }
                release=result;message="发现新版本 \(result.tag_name)\(result.prerelease ? "（预发布）":"")，当前版本 \(current)"
            } catch { message="检查更新失败：\(error.localizedDescription)" }
        }
    }
    func download(_ chosen:GCLRelease?=nil) {
        guard let release=chosen ?? release,let asset=package(release),!downloading else{return}
        downloading=true;message="正在下载 \(release.tag_name)…"
        Task {
            defer { downloading=false }
            do {
                var request=URLRequest(url:asset.browser_download_url);request.setValue("GCL-updater",forHTTPHeaderField:"User-Agent")
                let (temporary,response)=try await URLSession.shared.download(for:request)
                guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else { throw LaunchError(message:"更新包下载失败") }
                let directory=FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0].appendingPathComponent("GCL Updates",isDirectory:true)
                try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
                if let expected=asset.digest,expected.hasPrefix("sha256:") {
                    let bytes=try Data(contentsOf:temporary,options:.mappedIfSafe)
                    let actual=SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined()
                    guard actual == String(expected.dropFirst(7)).lowercased() else { throw LaunchError(message:"更新包校验失败") }
                }
                let safeName=URL(fileURLWithPath:asset.name).lastPathComponent
                let destination=directory.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
                try FileManager.default.moveItem(at:temporary,to:destination)
                downloaded=destination;message="下载完成，打开下载文件夹安装更新"
            } catch { message="下载更新失败：\(error.localizedDescription)" }
        }
    }
    func reveal() { if let file=downloaded { NSWorkspace.shared.activateFileViewerSelecting([file]) } }
}

extension LauncherView {
    var updatePanel: some View {
        VStack(alignment:.leading,spacing:8) {
            Label("软件更新",systemImage:"arrow.triangle.2.circlepath").font(.headline)
            Text(updater.message).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button(updater.checking ? "检查中…":"检查更新") { updater.check() }.disabled(updater.checking || updater.downloading)
                if updater.release != nil && updater.downloaded == nil { Button(updater.downloading ? "下载中…":"下载更新") { updater.download() }.disabled(updater.downloading) }
                if updater.downloaded != nil { Button("在访达中显示") { updater.reveal() } }
            }
            ForEach(updater.history,id:\.tag_name) { item in
                DisclosureGroup(item.tag_name+(item.prerelease ? " · 预发布":"")) {
                    VStack(alignment:.leading,spacing:8){
                        Text(item.body ?? "此版本未提供更新说明").font(.caption).textSelection(.enabled)
                        Button("下载此版 / 恢复旧版"){updater.download(item)}.disabled(updater.downloading)
                    }.padding(.vertical,6)
                }
            }
            Text("恢复旧版：下载对应安装包，退出当前应用后替换。游戏数据不自动回退，请先备份存档。").font(.caption).foregroundStyle(.secondary)
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary.opacity(0.5),in:RoundedRectangle(cornerRadius:6))
    }
}
