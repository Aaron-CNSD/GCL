import SwiftUI
import UniformTypeIdentifiers

@MainActor final class Model:ObservableObject {
    @Published var versions=["1.21.1","1.20.1"]
    @Published var selected="1.21.1"
    @Published var name=UserDefaults.standard.string(forKey:"player") ?? "Player"
    @Published var server=UserDefaults.standard.string(forKey:"server") ?? ""
    @Published var memory=4096.0
    @Published var status="准备就绪 · 选择配置开始探索"
    @Published var busy=false
    @Published var packs=[[String:String]]()
    @Published var packID=""
    @Published var loaderKind="原版"
    @Published var loaderBuild=""
    @Published var loaderBuilds=[String]()
    @Published var loadingLoaders=false
    @Published var page="开始游戏"
    @Published var contentSection="资源下载"
    @Published var showVersionChooser=false
    @Published var showInstanceChooser=false
    @Published var query=""
    @Published var resourceType="mod"
    @Published var hits=[ResourceHit]()
    @Published var searchBusy=false
    @Published var resource:ResourceHit?
    @Published var resourceVersions=[ResourceVersion]()
    @Published var resourceVersionID=""
    @Published var skinPreview:NSImage?
    @Published var windowWidth=1280
    @Published var windowHeight=720
    @Published var appearance=UserDefaults.standard.string(forKey:"appearance") ?? "system"
    @Published var newProfileName="新的游戏配置"
    @Published var renameText=""
    @Published var mods=[LocalMod]()
    @Published var modQuery=""
    @Published var savedServers=[SavedServer]()
    @Published var serverName=""
    @Published var diagnosticText="点击刷新诊断，查看当前配置与常见错误。"
    @Published var gameLog="暂无日志"
    @Published var activities=[ActivityItem]()
    var didSetInitialWindowSize=false
    var settingsRequest=0,modRequest=0
    @Published var backdropPath=UserDefaults.standard.string(forKey:"backdropPath") ?? ""
    let engine:Engine
    let demoMode=Bundle.main.object(forInfoDictionaryKey:"GCLDemoMode") as? Bool == true
    init(){
        if demoMode {
            engine=Engine(root:FileManager.default.temporaryDirectory.appendingPathComponent("gcl-v02-preview-"+UUID().uuidString))
            name="Player";server="";appearance="light";selected="1.21.1";versions=["1.21.1","1.20.1","1.19.4"];status="准备就绪"
        } else {engine=Engine()}
    }
    func chooseBackdrop(){
        let panel=NSOpenPanel();panel.title="选择启动器背景";panel.message="支持 PNG、JPEG、MP4、MOV；选择后自动保存。";panel.allowsMultipleSelection=false;panel.canChooseDirectories=false;panel.allowedContentTypes=[.png,.jpeg,.mpeg4Movie,.quickTimeMovie]
        guard panel.runModal() == .OK,let source=panel.url else{return}
        do {
            let size=try source.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size>0,size<=512*1024*1024 else{throw LaunchError(message:"请选择小于 512 MB 的图片或视频")}
            if ["png","jpg","jpeg"].contains(source.pathExtension.lowercased()),NSImage(contentsOf:source)==nil{throw LaunchError(message:"无法读取这张图片")}
            let directory=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("GCL/Backgrounds")
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
            let destination=directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(source.pathExtension)
            try FileManager.default.copyItem(at:source,to:destination)
            backdropPath=destination.path;UserDefaults.standard.set(backdropPath,forKey:"backdropPath")
        }catch{status="背景导入失败：\(error.localizedDescription)"}
    }
    func resetBackdrop(){backdropPath="";UserDefaults.standard.removeObject(forKey:"backdropPath")}

    var job:Task<Void,Never>?,searchID=0,loaderRequest=0
    var currentPack:String? {packID.isEmpty ? nil:packID}
    func progress(_ text:String){status=text;if activities.last?.text != text{activities.append(ActivityItem(text:text));if activities.count>60{activities.removeFirst(activities.count-60)}}}
    func perform(_ action:@escaping () async throws -> Void){guard !busy else{return};busy=true;job=Task{do{try await action()}catch is CancellationError{status="已取消，可重新尝试"}catch{status=error.localizedDescription};busy=false;job=nil}}
    func cancel(){job?.cancel();Task{await engine.stop()}}
    func refresh(){Task{packs=(try? await engine.packList()) ?? [];do{let list=try await engine.versions();versions=list;if !list.contains(selected){selected=list.first ?? "1.21.1"}}catch{status="版本列表加载失败，可重试：\(error.localizedDescription)"}}}
    func reloadPacks(_ id:String?) async throws{packs=try await engine.packList();if let id=id{packID=id;selected=packs.first(where:{$0["id"]==id})?["minecraft"] ?? selected}}
    func start(join:Bool=false){let game=selected,player=name,pack=currentPack,ram=Int(memory),address=join ? server:nil,width=windowWidth,height=windowHeight;UserDefaults.standard.set(player,forKey:"player");if join{UserDefaults.standard.set(server,forKey:"server")};perform{try await self.engine.saveSettings(LaunchSettings(memoryMB:ram,width:width,height:height),version:game,packID:pack);try await self.engine.launch(version:game,name:player,memory:ram,packID:pack,server:address,windowWidth:width,windowHeight:height){text in Task{@MainActor in self.progress(text)}}}}
    func loadVersions(){loaderRequest+=1;let request=loaderRequest,game=selected,kind=loaderKind;loadingLoaders=true;loaderBuilds=[];loaderBuild="";Task{do{let list=try await engine.loaderVersions(game:game,kind:kind);guard request==loaderRequest else{return};loaderBuilds=list;loaderBuild=list.first ?? "";if kind != "原版" && list.isEmpty{status="此游戏版本没有对应的 \(kind) 版本"}}catch{if request==loaderRequest{status=error.localizedDescription}};if request==loaderRequest{loadingLoaders=false}}}
    func installLoader(){let game=selected,kind=loaderKind,build=loaderBuild;guard !build.isEmpty else{return};perform{let id=try await self.engine.createLoader(game:game,kind:kind,build:build){text in Task{@MainActor in self.progress(text)}};try await self.reloadPacks(id);self.status="加载器已安装，可以启动或下载模组"}}
    func importModpack(){let panel=NSOpenPanel();panel.allowedContentTypes=[UTType(filenameExtension:"mrpack") ?? .archive];guard panel.runModal() == .OK,let url=panel.url else{return};perform{let id=try await self.engine.importPack(url){text in Task{@MainActor in self.progress(text)}};try await self.reloadPacks(id)}}
    func importFile(shader:Bool){let panel=NSOpenPanel();panel.allowsMultipleSelection=true;panel.allowedContentTypes=[UTType(filenameExtension:shader ? "zip":"jar") ?? .archive];guard panel.runModal() == .OK else{return};let files=panel.urls,game=selected,pack=currentPack;perform{let folder=try await self.engine.gameFolder(version:game,packID:pack).appendingPathComponent(shader ? "shaderpacks":"mods");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);for file in files{let dest=folder.appendingPathComponent(file.lastPathComponent);guard !FileManager.default.fileExists(atPath:dest.path) else{throw LaunchError(message:"已存在同名文件：\(file.lastPathComponent)")};try FileManager.default.copyItem(at:file,to:dest)};self.status="文件已导入，需安装匹配的加载器 / 光影支持模组"}}
    func openFolder(logs:Bool=false){Task{let folder=logs ? try? await engine.folder("logs"):try? await engine.gameFolder(version:selected,packID:currentPack);if let folder=folder{NSWorkspace.shared.open(folder)}}}
    func resetResources(){searchID+=1;hits=[];resource=nil;resourceVersions=[];resourceVersionID="";searchBusy=false}
    func search(){searchID+=1;let request=searchID,game=selected,type=resourceType,term=query;searchBusy=true;resource=nil;resourceVersions=[];Task{do{let list=try await engine.searchResources(query:term,type:type,game:game);if request==searchID{hits=list;status=list.isEmpty ? "没有匹配资源，请修改关键词或游戏版本":"找到 \(list.count) 项资源，点击选择版本"}}catch{if request==searchID{status=error.localizedDescription}};if request==searchID{searchBusy=false}}}
    func select(_ hit:ResourceHit){resource=hit;resourceVersions=[];resourceVersionID="";let game=selected,pack=currentPack;Task{do{let loader=hit.project_type=="mod" ? try await engine.activeLoader(pack):"";let list=try await engine.resourceVersions(project:hit.id,game:game,loader:loader);guard resource?.id==hit.id else{return};resourceVersions=list;resourceVersionID=list.first?.id ?? "";if list.isEmpty{status="此版本与加载器没有匹配的下载"}}catch{status=error.localizedDescription}}}
    func downloadResource(){guard let hit=resource,let version=resourceVersions.first(where:{$0.id==resourceVersionID}) else{return};let game=selected,pack=currentPack;perform{let id=try await self.engine.installResource(version,type:hit.project_type,game:game,pack:pack){text in Task{@MainActor in self.progress(text)}};if id != nil{try await self.reloadPacks(id)}}}
    func chooseSkin(){let panel=NSOpenPanel();panel.allowedContentTypes=[.png];guard panel.runModal() == .OK,let url=panel.url else{return};let player=name,game=selected,pack=currentPack;perform{let id=try await self.engine.installSkin(url,username:player,game:game,pack:pack){text in Task{@MainActor in self.progress(text)}};self.skinPreview=NSImage(contentsOf:url);try await self.reloadPacks(id)}}
}

struct GlassPanel<Content:View>:View {
    let content:Content
    init(@ViewBuilder content:()->Content){self.content=content()}
    var body:some View {content.padding(20).frame(maxWidth:.infinity,alignment:.leading).modifier(LauncherGlassSurface()).padding(2)}
}
struct LauncherView:View {
    @ObservedObject var m:Model
    @StateObject var updater=LauncherUpdate()
    @StateObject var lan=LANModel()
    @Namespace var navigationSelection
    @AppStorage("clearGlass") var clearGlass=false
    @AppStorage("backdropOpacity") var backdropOpacity=1.0
    @AppStorage("backdropBlur") var backdropBlur=0.0
    @AppStorage("backdropFit") var backdropFit="fill"
    @AppStorage("animateBuiltInBackground") var animateBuiltInBackground=true
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let pages=[("开始游戏","play.fill"),("版本管理","square.stack.3d.up"),("模组管理","puzzlepiece.extension"),("资源下载","square.and.arrow.down"),("一键联机","network"),("我的皮肤","tshirt"),("任务与日志","waveform.path.ecg"),("启动设置","slider.horizontal.3"),("关于 GCL","info.circle")]
    var configuration:some View{GlassPanel{VStack(alignment:.leading,spacing:14){HStack{Text("游戏配置").font(.headline);Spacer();Button("打开目录"){m.openFolder()}}
        HStack{TextField("本地用户名",text:$m.name).textFieldStyle(.roundedBorder).frame(width:155);Picker("Minecraft",selection:$m.selected){ForEach(m.versions,id:\.self){Text($0)}}.disabled(!m.packID.isEmpty)}
        Picker("启动配置",selection:$m.packID){Text("新建 / 原版").tag("");ForEach(m.packs,id:\.self){pack in Text(pack["name"] ?? "整合包").tag(pack["id"] ?? "")}}.onChange(of:m.packID){id in m.resetResources();m.loadPreferences();m.refreshMods();if let pack=m.packs.first(where:{$0["id"]==id}){m.selected=pack["minecraft"] ?? m.selected}}
    }.disabled(m.busy)}}
    var play:some View{GlassPanel{VStack(alignment:.leading,spacing:20){Label("安装游戏与加载器",systemImage:"square.and.arrow.down").font(.title3.weight(.semibold))
        HStack{Picker("加载器",selection:$m.loaderKind){ForEach(["原版","Forge","NeoForge","Fabric","Quilt"],id:\.self){Text($0)}}.onChange(of:m.loaderKind){_ in m.loadVersions()};Picker(m.loadingLoaders ? "读取中":"版本",selection:$m.loaderBuild){Text("请选择").tag("");ForEach(m.loaderBuilds,id:\.self){Text($0)}};Button("安装"){m.installLoader()}.disabled(m.loaderBuild.isEmpty || m.loadingLoaders)}.disabled(m.busy || !m.packID.isEmpty)
        HStack{Text("内存 \(Int(m.memory)) MB").monospacedDigit();Slider(value:$m.memory,in:2048...m.maxMemoryMB,step:1024)}.disabled(m.busy)
        HStack{Button("导入 .mrpack"){m.importModpack()};Button("导入模组"){m.importFile(shader:false)};Button("导入光影"){m.importFile(shader:true)}}.disabled(m.busy)
        Text("游戏、Java 与资源均在软件内下载。支持 1.7+ 与 26.x 正式版；旧版本兼容性仍待验证。CurseForge ZIP 尚未支持，Forge / NeoForge 仍有未验证的兼容情况。").font(.caption).foregroundStyle(.secondary)
    }}}
    var resources:some View{GlassPanel{VStack(alignment:.leading,spacing:14){HStack{Picker("类型",selection:$m.resourceType){Text("模组").tag("mod");Text("整合包").tag("modpack");Text("光影").tag("shader")}.frame(width:190);TextField("搜索资源，例如 Sodium",text:$m.query).textFieldStyle(.roundedBorder).onSubmit{m.search()};Button(m.searchBusy ? "搜索中":"搜索"){m.search()}.disabled(m.searchBusy || m.busy)}
        Text("来源 Modrinth · 按当前 Minecraft 版本筛选，模组版本进一步匹配当前加载器。").font(.caption).foregroundStyle(.secondary)
        if let hit=m.resource{Divider();Text(hit.title).font(.headline);Picker("下载版本",selection:$m.resourceVersionID){Text("请选择").tag("");ForEach(m.resourceVersions){Text($0.name).tag($0.id)}};Button(hit.project_type=="modpack" ? "下载并导入整合包":"下载到当前配置"){m.downloadResource()}.buttonStyle(.borderedProminent).disabled(m.busy || m.resourceVersionID.isEmpty)}
        ForEach(m.hits){hit in Button{m.select(hit)}label:{VStack(alignment:.leading,spacing:4){Text(hit.title).font(.headline);Text(hit.description).font(.caption).lineLimit(2).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).padding(12).background(m.resource?.id==hit.id ? Color.blue.opacity(0.15):Color.primary.opacity(0.03),in:RoundedRectangle(cornerRadius:12))}.buttonStyle(.plain)}
        Text("普通模组的额外依赖需另行安装；光影需要兼容的渲染模组。点击下载不会打开外部浏览器。").font(.caption).foregroundStyle(.secondary)
    }}}
    var multiplayer:some View{VStack(spacing:16){LANPanel(username:m.name,version:m.selected,room:lan){address in m.server=address;m.start(join:true)};serverFavorites;directMultiplayer}}
    var directMultiplayer:some View{GlassPanel{VStack(alignment:.leading,spacing:18){Label("高级：服务器地址直连",systemImage:"person.2.fill").font(.title2.bold());TextField("服务器地址，例如 192.168.1.8:25565",text:$m.server).textFieldStyle(.roundedBorder);Button{m.start(join:true)}label:{Label("启动并加入服务器",systemImage:"network").padding(8)}.buttonStyle(.borderedProminent).disabled(m.busy || m.server.trimmingCharacters(in:.whitespaces).isEmpty)
        Text("使用本地用户名加入允许离线账号的服务器。局域网游戏：让房主在游戏内开放局域网，再填写房主 IP 和显示的端口。双方须匹配游戏、加载器与模组。").font(.callout)
        Text("此功能不创建服务器、不提供公网穿透；要求 Microsoft 验证的服务器仍无法加入。").font(.caption).foregroundStyle(.secondary)
    }}}
    var about:some View{GlassPanel{VStack(alignment:.leading,spacing:16){Text("GCL · GlassCraft Launcher").font(.title2.bold());Text("项目维护：Aaron-CNSD"); updatePanel;Text("使用 Codex 辅助实现与验证；不添加虚构的人类贡献者。").foregroundStyle(.secondary);Text("开源致谢").font(.headline);Text("CustomSkinLoader / xfl03：本地皮肤模组\nFabricMC · QuiltMC · MinecraftForge · NeoForged\nEclipse Adoptium · Modrinth · Mojang / Microsoft");Text("GPL-3.0 · 第三方遵循各自许可。非 Mojang / Microsoft 官方产品。").font(.caption);Link("项目与贡献记录",destination:URL(string:"https://github.com/Aaron-CNSD/GCL")!);Text("0.3.0 开发预览 · macOS 13+ · JAR 仅作为 Mac 原生应用入口，不代表支持 Windows / Linux。").font(.caption).foregroundStyle(.secondary)}}}
    var skin:some View{GlassPanel{VStack(alignment:.leading,spacing:18){Label("皮肤设置",systemImage:"tshirt").font(.title2.bold());HStack(spacing:20){if let image=m.skinPreview{Image(nsImage:image).interpolation(.none).resizable().scaledToFit().frame(width:100,height:100).background(.quaternary,in:RoundedRectangle(cornerRadius:12))}else{Image(systemName:"tshirt").font(.system(size:65)).foregroundStyle(.secondary)};VStack(alignment:.leading,spacing:8){Text("本地 PNG 皮肤").font(.headline);Text("64×64 或 64×32 · 小于 2 MB").foregroundStyle(.secondary);Button("选择并一键应用"){m.chooseSkin()}.buttonStyle(.borderedProminent).disabled(m.busy)}}
        Text("自动下载兼容的 CustomSkinLoader。原版配置会自动创建 Fabric 配置；已有加载器则沿用当前配置。重启游戏后生效，皮肤图片保存在本机。").font(.callout)
        Text("本地皮肤不会同步给所有玩家；其他客户端需配置相同皮肤或皮肤服务才能看到。修改用户名后请重新应用。").font(.caption).foregroundStyle(.secondary)
    }}}
}

#if !GLASSCRAFT_TESTS
@main struct GCLApp:App{@StateObject var model=Model();var body:some Scene{WindowGroup{LauncherView(m:model)}.windowStyle(.titleBar).defaultSize(width:760,height:480).windowResizability(.contentMinSize)}}

#endif
