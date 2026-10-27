import SwiftUI
import UniformTypeIdentifiers

struct ActivityItem:Identifiable {let id=UUID();let time=Date();let text:String}
@MainActor extension Model {
    var maxMemoryMB:Double {Double(min(16384,max(2048,Int(ProcessInfo.processInfo.physicalMemory/1048576)*3/4)))}
    func loadWorkspace(){Task{do{savedServers=try await engine.savedServers()}catch{status=error.localizedDescription}};loadPreferences();refreshMods()}
    func loadPreferences(){settingsRequest+=1;let request=settingsRequest,game=selected,pack=currentPack;Task{do{let value=try await engine.settings(version:game,packID:pack);guard request==settingsRequest else{return};memory=min(Double(value.memoryMB),maxMemoryMB);windowWidth=value.width;windowHeight=value.height;renameText=packs.first(where:{$0["id"]==packID})?["name"] ?? ""}catch{status="启动设置读取失败，可在设置中重新保存：\(error.localizedDescription)"}}}
    func savePreferences(){let value=LaunchSettings(memoryMB:Int(memory),width:windowWidth,height:windowHeight),game=selected,pack=currentPack;perform{try await self.engine.saveSettings(value,version:game,packID:pack);self.progress("当前配置启动设置已保存")}}
    func createProfile(){let title=newProfileName,game=selected;perform{let id=try await self.engine.createVanilla(name:title,version:game);try await self.reloadPacks(id);self.loadPreferences();self.progress("已创建独立原版配置，首次启动时下载游戏文件")}}
    func renameProfile(){guard let id=currentPack else{return};let title=renameText;perform{try await self.engine.renameProfile(id:id,name:title);self.packs=try await self.engine.packList();self.progress("配置已重命名")}}
    func selectProfile(_ pack:[String:String]){packID=pack["id"] ?? "";selected=pack["minecraft"] ?? selected;loadPreferences();refreshMods();page="开始游戏"}
    func refreshMods(){modRequest+=1;let request=modRequest,game=selected,pack=currentPack;Task{do{let list=try await engine.localMods(version:game,packID:pack);if request==modRequest{mods=list}}catch{if request==modRequest{status=error.localizedDescription}}}}
    func toggleMod(_ mod:LocalMod){let game=selected,pack=currentPack;perform{try await self.engine.setMod(name:mod.name,enabled:!mod.enabled,version:game,packID:pack);self.mods=try await self.engine.localMods(version:game,packID:pack);self.progress("模组状态已更新，下次启动生效")}}
    func favoriteServer(){let name=serverName,address=server;perform{try await self.engine.saveServer(name:name,address:address);self.savedServers=try await self.engine.savedServers();self.progress("服务器已收藏，仅保存在本机")}}
    func refreshDiagnostics(){let game=selected,pack=currentPack;Task{do{diagnosticText=try await engine.diagnostics(version:game,packID:pack);gameLog=try await engine.logTail()}catch{diagnosticText=error.localizedDescription}}}
    func watchLog() async {while !Task.isCancelled && page=="任务与日志"{do{gameLog=try await engine.logTail();try await Task.sleep(nanoseconds:1_000_000_000)}catch{break}}}
    func copyDiagnostic(){NSPasteboard.general.clearContents();NSPasteboard.general.setString(diagnosticText,forType:.string);progress("诊断摘要已复制，未包含完整日志")}
    func exportLog(){let panel=NSSavePanel();panel.nameFieldStringValue="GCL-game.log";guard panel.runModal() == .OK,let url=panel.url else{return};let text=gameLog;perform{try Data(text.utf8).write(to:url,options:.atomic);self.progress("日志已导出到所选文件")}}
    func backupProfile(){let panel=NSSavePanel();panel.allowedContentTypes=[.zip];panel.nameFieldStringValue="GCL-\(selected)-\(Int(Date().timeIntervalSince1970)).zip";guard panel.runModal() == .OK,let url=panel.url else{return};let game=selected,pack=currentPack;perform{self.progress("正在导出当前配置和游戏目录，可取消…");try await self.engine.backup(version:game,packID:pack,destination:url);self.progress("备份完成。此为 GCL 文件备份，非 mrpack 整合包")}}
}

extension LauncherView {
    var instances:some View{GlassPanel{VStack(alignment:.leading,spacing:18){HStack{Label("版本与实例",systemImage:"square.stack.3d.up.fill").font(.title2.bold());Spacer();Button("刷新"){m.refresh()}}
        Text("一个配置对应一个独立游戏目录。当前 Minecraft：\(m.selected)").foregroundStyle(.secondary)
        HStack{TextField("新配置名称",text:$m.newProfileName).textFieldStyle(.roundedBorder);Button("新建原版配置"){m.createProfile()}.disabled(m.newProfileName.trimmingCharacters(in:.whitespaces).isEmpty);Button("导入 .mrpack"){m.importModpack()}}
        if m.packs.isEmpty{Text("还没有独立配置。你可以新建原版，或安装一个加载器。").font(.callout).foregroundStyle(.secondary)}
        ForEach(m.packs,id:\.self){pack in HStack{Image(systemName:"cube.box.fill").font(.title2).foregroundStyle(.green);VStack(alignment:.leading,spacing:5){Text(pack["name"] ?? "未命名配置").font(.headline);Text("Minecraft "+(pack["minecraft"] ?? "未知")).font(.caption).foregroundStyle(.secondary)};Spacer();if pack["id"]==m.packID{Text("当前").font(.caption).foregroundStyle(.green)};Button("使用"){m.selectProfile(pack)}}.padding(14).background(.quaternary,in:RoundedRectangle(cornerRadius:13))}
        if !m.packID.isEmpty{Divider();HStack{TextField("当前配置名称",text:$m.renameText).textFieldStyle(.roundedBorder);Button("重命名"){m.renameProfile()}}}
        HStack{Button("打开当前目录"){m.openFolder()};Button("导出配置备份 ZIP"){m.backupProfile()}}
        Text("备份包含当前配置、设置和游戏目录，可包含存档。当前不提供自动还原；不会把此 ZIP 当作 mrpack 导入。").font(.caption).foregroundStyle(.secondary)
    }.disabled(m.busy)}}
    var modManager:some View{GlassPanel{VStack(alignment:.leading,spacing:16){HStack{Label("本地模组管理",systemImage:"puzzlepiece.extension.fill").font(.title2.bold());Spacer();Button("刷新"){m.refreshMods()}}
        HStack{TextField("搜索模组文件名",text:$m.modQuery).textFieldStyle(.roundedBorder);Button("导入 JAR"){m.importFile(shader:false)};Button("下载更多"){m.page="资源下载"}}
        Text("\(m.mods.filter{$0.enabled}.count) 个启用 · \(m.mods.count) 个文件").font(.caption).foregroundStyle(.secondary)
        if m.mods.isEmpty{Text("此配置还没有模组，请先安装兼容的加载器，再下载或导入。").foregroundStyle(.secondary)}
        ForEach(m.mods.filter{m.modQuery.isEmpty || $0.name.localizedCaseInsensitiveContains(m.modQuery)}){mod in HStack{Image(systemName:mod.enabled ? "puzzlepiece.fill":"puzzlepiece").foregroundStyle(mod.enabled ? .green:.secondary);VStack(alignment:.leading){Text(mod.name).font(.callout).lineLimit(2);Text(ByteCountFormatter.string(fromByteCount:mod.size,countStyle:.file)).font(.caption).foregroundStyle(.secondary)};Spacer();Button(mod.enabled ? "停用":"启用"){m.toggleMod(mod)}}.padding(12).background(.quaternary,in:RoundedRectangle(cornerRadius:12))}
        Text("停用通过追加 .disabled 完成，不删除模组文件。游戏运行时禁止修改，下次启动生效；版本和依赖仍需匹配。").font(.caption).foregroundStyle(.secondary)
    }.disabled(m.busy)}}
    var launchSettings:some View{GlassPanel{VStack(alignment:.leading,spacing:18){Label("启动与外观设置",systemImage:"slider.horizontal.3").font(.title2.bold())
        Text("启动设置按配置独立保存；新建 / 原版模式按游戏版本保存。").foregroundStyle(.secondary)
        HStack{Text("运行内存 \(Int(m.memory)) MB").monospacedDigit();Slider(value:$m.memory,in:2048...m.maxMemoryMB,step:1024)}
        Text("本机总内存 \(ProcessInfo.processInfo.physicalMemory/1073741824) GB，上限随本机内存调整。").font(.caption).foregroundStyle(.secondary)
        Stepper("窗口宽度：\(m.windowWidth)",value:$m.windowWidth,in:640...3840,step:160)
        Stepper("窗口高度：\(m.windowHeight)",value:$m.windowHeight,in:360...2160,step:90)
        Divider()
        HStack{Text("背景");Spacer();Button("选择图片或视频…"){m.chooseBackdrop()};if !m.backdropPath.isEmpty{Button("恢复内置背景"){m.resetBackdrop()}}}
        Text("PNG、JPEG、MP4 或 MOV，仅保存在本机；视频静音循环，窗口不活跃时暂停。默认使用内置壁纸，也可换成自己的背景；重新打开会保留选择。").font(.caption).foregroundStyle(.secondary)
        Group {
            Picker("画面适配",selection:$backdropFit){Text("填满窗口").tag("fill");Text("完整显示").tag("fit")}.pickerStyle(.segmented).frame(maxWidth:300)
            HStack{Text("背景强度");Slider(value:$backdropOpacity,in:0.25...1)}
            HStack{Text("背景虚化");Slider(value:$backdropBlur,in:0...16)}
        }
        if #available(macOS 26.0,*) {Picker("玻璃质感",selection:$clearGlass){Text("磨砂").tag(false);Text("通透").tag(true)}.pickerStyle(.segmented).frame(maxWidth:300)}
        Picker("外观",selection:$m.appearance){Text("跟随系统").tag("system");Text("浅色").tag("light");Text("深色").tag("dark")}
        Button("保存当前配置设置"){m.savePreferences()}.buttonStyle(.borderedProminent)
        Text("macOS 26+ 使用系统液态玻璃；旧系统使用半透明材质。保存后，下次启动会应用窗口尺寸与内存。").font(.caption).foregroundStyle(.secondary)
    }.disabled(m.busy)}}
    var diagnostics:some View{VStack(spacing:16){GlassPanel{VStack(alignment:.leading,spacing:15){HStack{Label("任务与诊断",systemImage:"waveform.path.ecg").font(.title2.bold());Spacer();Button("刷新诊断"){m.refreshDiagnostics()}};Text(m.diagnosticText).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading);Button("复制诊断摘要"){m.copyDiagnostic()};if !m.activities.isEmpty{Divider();ForEach(m.activities.suffix(12).reversed()){event in HStack(alignment:.top){Text(event.time,style:.time).font(.caption2.monospaced()).foregroundStyle(.secondary);Text(event.text).font(.caption).textSelection(.enabled);Spacer()}}}}}
        GlassPanel{VStack(alignment:.leading,spacing:12){HStack{Text("游戏日志 · 最近 64 KB").font(.headline);Spacer();Button("导出日志"){m.exportLog()}.disabled(m.busy);Button("打开日志文件夹"){m.openFolder(logs:true)}};ScrollView([.vertical,.horizontal]){Text(m.gameLog).font(.system(size:11,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(height:240);Text("当前页每秒读取一次日志。分享日志前请自行检查其中的地址、用户名等内容；软件不会自动上传。").font(.caption).foregroundStyle(.secondary)}}
    }.onAppear{m.refreshDiagnostics()}.task{await m.watchLog()}}
    var serverFavorites:some View{GlassPanel{VStack(alignment:.leading,spacing:14){Label("服务器收藏",systemImage:"star.fill").font(.headline);HStack{TextField("收藏名称，可选",text:$m.serverName).textFieldStyle(.roundedBorder);Button("收藏当前地址"){m.favoriteServer()}.disabled(m.server.isEmpty || m.busy)};if m.savedServers.isEmpty{Text("把下方输入的地址保存在本机，方便下次加入。").font(.caption).foregroundStyle(.secondary)};ForEach(m.savedServers){server in HStack{VStack(alignment:.leading){Text(server.name).font(.headline);Text(server.address).font(.caption.monospaced()).foregroundStyle(.secondary)};Spacer();Button("填入地址"){m.server=server.address};Button("加入"){m.server=server.address;m.start(join:true)}.disabled(m.busy)}}}}}
}
