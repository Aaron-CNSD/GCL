import Foundation

struct LaunchSettings:Codable,Equatable {
    var memoryMB:Int=4096
    var width:Int=1280
    var height:Int=720
    func validated() throws -> Self {
        guard (1024...32768).contains(memoryMB),(640...7680).contains(width),(360...4320).contains(height) else{throw LaunchError(message:"内存或窗口尺寸超出范围")};return self
    }
}
struct LocalMod:Identifiable {let name:String;let size:Int64;let enabled:Bool;var id:String{name}}
struct SavedServer:Codable,Identifiable {var id=UUID().uuidString;var name:String;var address:String}
extension Engine {
    func idleForChange() throws {if let process=running,process.isRunning{throw LaunchError(message:"请先停止游戏或当前操作")}}
    func settingsURL(version:String,packID:String?) throws -> URL {
        let key:String
        if let id=packID{guard UUID(uuidString:id) != nil else{throw LaunchError(message:"无效配置")};key=id}
        else{guard VersionSupport.isSupported(version) else{throw LaunchError(message:"无效游戏版本")};key="vanilla-"+version}
        return try folder("settings").appendingPathComponent(key+".json")
    }
    func settings(version:String,packID:String?) throws -> LaunchSettings {
        let file=try settingsURL(version:version,packID:packID)
        guard FileManager.default.fileExists(atPath:file.path) else{return LaunchSettings()}
        return try JSONDecoder().decode(LaunchSettings.self,from:Data(contentsOf:file)).validated()
    }
    func saveSettings(_ value:LaunchSettings,version:String,packID:String?) throws {
        _=try value.validated();let url=try settingsURL(version:version,packID:packID);try JSONEncoder().encode(value).write(to:url,options:.atomic)
    }
    func createVanilla(name:String,version:String) throws -> String {
        try idleForChange();let title=name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !title.isEmpty,title.count<=64,VersionSupport.isSupported(version) else{throw LaunchError(message:"请输入有效名称与游戏版本")}
        let id=UUID().uuidString,record:[String:Any]=["id":id,"name":title,"minecraft":version,"loaderProfile":[:]]
        try JSONSerialization.data(withJSONObject:record).write(to:folder("packs").appendingPathComponent(id+".json"),options:.atomic)
        _=try gameFolder(version:version,packID:id);return id
    }
    func renameProfile(id:String,name:String) throws {
        try idleForChange();guard UUID(uuidString:id) != nil else{throw LaunchError(message:"无效配置")}
        let title=name.trimmingCharacters(in:.whitespacesAndNewlines);guard !title.isEmpty,title.count<=64 else{throw LaunchError(message:"名称需要 1–64 个字符")}
        let file=try folder("packs").appendingPathComponent(id+".json")
        guard var record=try JSONSerialization.jsonObject(with:Data(contentsOf:file)) as? [String:Any] else{throw LaunchError(message:"配置文件损坏")}
        record["name"]=title;try JSONSerialization.data(withJSONObject:record).write(to:file,options:.atomic)
    }
    func localMods(version:String,packID:String?) throws -> [LocalMod] {
        let dir=try gameFolder(version:version,packID:packID).appendingPathComponent("mods")
        guard FileManager.default.fileExists(atPath:dir.path) else{return []}
        return try FileManager.default.contentsOfDirectory(at:dir,includingPropertiesForKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey]).compactMap{url in
            let props=try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
            guard props.isRegularFile==true,props.isSymbolicLink != true,url.lastPathComponent.hasSuffix(".jar") || url.lastPathComponent.hasSuffix(".jar.disabled") else{return nil}
            return LocalMod(name:url.lastPathComponent,size:Int64(props.fileSize ?? 0),enabled:url.pathExtension=="jar")
        }.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
    func setMod(name:String,enabled:Bool,version:String,packID:String?) throws {
        try idleForChange();guard name==URL(fileURLWithPath:name).lastPathComponent,!name.contains("\\"),name.hasSuffix(".jar") || name.hasSuffix(".jar.disabled") else{throw LaunchError(message:"无效模组文件名")}
        let dir=try gameFolder(version:version,packID:packID).appendingPathComponent("mods"),source=dir.appendingPathComponent(name)
        let props=try source.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey]);guard props.isRegularFile==true,props.isSymbolicLink != true else{throw LaunchError(message:"不能修改此文件")}
        let targetName=enabled ? (name.hasSuffix(".disabled") ? String(name.dropLast(9)):name):(name.hasSuffix(".disabled") ? name:name+".disabled")
        if targetName==name{return}
        let target=dir.appendingPathComponent(targetName)
        guard !FileManager.default.fileExists(atPath:target.path) else{throw LaunchError(message:"同名模组已存在，请先检查文件夹")}
        try FileManager.default.moveItem(at:source,to:target)
    }
    func savedServers() throws -> [SavedServer] {
        let file=try folder("preferences").appendingPathComponent("servers.json")
        guard FileManager.default.fileExists(atPath:file.path) else{return []}
        return try JSONDecoder().decode([SavedServer].self,from:Data(contentsOf:file))
    }
    func saveServer(name:String,address:String) throws {
        let value=address.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !value.isEmpty else{throw LaunchError(message:"服务器地址不能为空")}
        _=try multiplayerArguments(version:"1.21.1",address:value)
        let title=name.trimmingCharacters(in:.whitespacesAndNewlines);guard title.count<=64 else{throw LaunchError(message:"收藏名称过长")}
        var list=try savedServers()
        if let i=list.firstIndex(where:{$0.address.caseInsensitiveCompare(value) == .orderedSame}){list[i].name=title.isEmpty ? value:title}
        else{list.append(SavedServer(name:title.isEmpty ? value:title,address:value))}
        try JSONEncoder().encode(list).write(to:folder("preferences").appendingPathComponent("servers.json"),options:.atomic)
    }
    func logTail() throws -> String {
        let file=try folder("logs").appendingPathComponent("latest.log")
        guard FileManager.default.fileExists(atPath:file.path) else{return "暂无游戏日志。首次启动后可在这里查看。"}
        let handle=try FileHandle(forReadingFrom:file);defer{try? handle.close()}
        let size=try handle.seekToEnd();try handle.seek(toOffset:size>65536 ? size-65536:0)
        return String(decoding:try handle.readToEnd() ?? Data(),as:UTF8.self)
    }
    func diagnostics(version:String,packID:String?) throws -> String {
        let mods=try localMods(version:version,packID:packID),settings=try self.settings(version:version,packID:packID),log=try logTail()
        let javaDir=root.appendingPathComponent("java")
        let runtimes=(try? FileManager.default.contentsOfDirectory(atPath:javaDir.path)) ?? []
        var result="GCL 0.3.0\n系统：\(ProcessInfo.processInfo.operatingSystemVersionString)\n游戏：\(version)\n配置：\(packID ?? "默认原版")\n内存：\(settings.memoryMB) MB\n窗口：\(settings.width) × \(settings.height)\n已准备 Java：\(runtimes.joined(separator:", "))\n模组：\(mods.filter{$0.enabled}.count) 启用 / \(mods.count) 总计\n"
        if log.contains("Realms") && (log.contains("authentication") || log.contains("SignedJWT")){result+="\n检测到 Realms 登录失败：本地账号不支持 Realms；这条消息本身不证明单机或离线服务器启动失败。\n"}
        if log.contains("UnsatisfiedLinkError"){result+="\n检测到本地库加载失败，请核对游戏版本与 Mac CPU 架构。\n"}
        return result
    }
    func managedTool(_ tool:String,_ arguments:[String]) async throws {
        let p=Process();p.executableURL=URL(fileURLWithPath:tool);p.arguments=arguments;p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice
        running=p;defer{running=nil};let result=try await execute(p);try Task.checkCancellation();guard result==0 else{throw LaunchError(message:"备份工具未完成操作")}
    }
    func backup(version:String,packID:String?,destination:URL) async throws {
        try idleForChange();guard destination.pathExtension.lowercased()=="zip",!FileManager.default.fileExists(atPath:destination.path) else{throw LaunchError(message:"请选择一个尚不存在的 ZIP 文件名，避免覆盖旧备份")}
        let stage=try folder("staging/backup-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:stage)}
        let container=stage.appendingPathComponent("GCL-backup");try FileManager.default.createDirectory(at:container,withIntermediateDirectories:true)
        let game=try gameFolder(version:version,packID:packID)
        try await managedTool("/usr/bin/ditto",[game.path,container.appendingPathComponent("game").path])
        let manifest:[String:Any]=["format":"gcl-backup-v1","minecraft":version,"profile":packID ?? "vanilla","created":ISO8601DateFormatter().string(from:Date())]
        try JSONSerialization.data(withJSONObject:manifest,options:.prettyPrinted).write(to:container.appendingPathComponent("backup.json"))
        try JSONEncoder().encode(settings(version:version,packID:packID)).write(to:container.appendingPathComponent("settings.json"))
        if let id=packID{try FileManager.default.copyItem(at:root.appendingPathComponent("packs/\(id).json"),to:container.appendingPathComponent("profile.json"))}
        let zip=stage.appendingPathComponent("export.zip");try await managedTool("/usr/bin/ditto",["-c","-k","--keepParent",container.path,zip.path])
        try FileManager.default.moveItem(at:zip,to:destination)
    }
}
