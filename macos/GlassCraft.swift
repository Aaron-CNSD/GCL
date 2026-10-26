import SwiftUI
import CryptoKit
import UniformTypeIdentifiers
import ImageIO

struct LaunchError: LocalizedError { var message: String; var errorDescription: String? { message } }
actor Engine {
    let root: URL
    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GlassCraft")) { self.root = root }
    var running: Process?
    let session: URLSession = {let config=URLSessionConfiguration.default;config.timeoutIntervalForRequest=45;config.timeoutIntervalForResource=240;return URLSession(configuration:config)}()
    func stop() {if let p=running,p.isRunning{p.terminate()}}
    func execute(_ process:Process) async throws -> Int32 {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler={p in continuation.resume(returning:p.terminationStatus)}
            do{try process.run()}catch{process.terminationHandler=nil;continuation.resume(throwing:error)}
        }
    }
    func folder(_ name: String) throws -> URL { let p=root.appendingPathComponent(name); try FileManager.default.createDirectory(at:p,withIntermediateDirectories:true); return p }
    func fetch(_ url: String) async throws -> Data {
        guard let u=URL(string:url),u.scheme == "https" else { throw LaunchError(message:"无效下载地址") }
        var req=URLRequest(url:u); req.timeoutInterval=90; req.setValue("GCL/0.3 (Aaron-CNSD/GCL)",forHTTPHeaderField:"User-Agent")
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do {
                let (data,res)=try await session.data(for:req)
                guard let r=res as? HTTPURLResponse else{throw LaunchError(message:"下载无响应")}
                if r.statusCode==429 || r.statusCode>=500 {throw URLError(.badServerResponse)}
                guard (200...299).contains(r.statusCode) else{throw LaunchError(message:"下载失败（HTTP \(r.statusCode)）：\(u.host ?? "")")};return data
            }catch let error as LaunchError{throw error}
            catch{if Task.isCancelled{throw CancellationError()};if attempt==2{throw error};try await Task.sleep(nanoseconds:UInt64(attempt+1)*1_000_000_000)}
        }
        throw LaunchError(message:"下载失败")
    }
    func object(_ url: String) async throws -> [String:Any] { try JSONSerialization.jsonObject(with:await fetch(url)) as? [String:Any] ?? [:] }
    func digest(_ d:Data)->String { Insecure.SHA1.hash(data:d).map{String(format:"%02x",$0)}.joined() }
    func download(_ item:[String:Any],to path:URL) async throws {
        let expected=item["sha1"] as? String
        if let old=try? Data(contentsOf:path) {if let sha=expected {if digest(old)==sha{return}} else if !old.isEmpty{return}}
        guard let u=item["url"] as? String else {throw LaunchError(message:"缺少下载地址")}
        let data=try await fetch(u)
        if let sha=expected,digest(data) != sha {throw LaunchError(message:"下载校验失败，请重试")}
        try FileManager.default.createDirectory(at:path.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:path,options:.atomic)
    }
    func run(_ tool:String,_ args:[String]) throws {
        let p=Process();p.executableURL=URL(fileURLWithPath:tool);p.arguments=args
        p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice;try p.run();p.waitUntilExit()
        if p.terminationStatus != 0 {throw LaunchError(message:"工具执行失败：\(tool)")}
    }
    func java(_ major:Int,forceIntel:Bool=false) async throws -> URL {
        #if arch(arm64)
        let useIntel=forceIntel || major<=8
        #else
        let useIntel=false
        #endif
        let base=try folder("java/\(major)"+(useIntel ? "-x64":""))
        func findJava()->URL? {
            let list=FileManager.default.enumerator(at:base,includingPropertiesForKeys:nil)
            while let p=list?.nextObject() as? URL {if p.path.hasSuffix("/Contents/Home/bin/java"),FileManager.default.isExecutableFile(atPath:p.path){return p}}
            return nil
        }
        if let j=findJava(){return j}
        #if arch(arm64)
        let arch=useIntel ? "x64":"aarch64"
        #else
        let arch="x64"
        #endif
        let json=try await fetch("https://api.adoptium.net/v3/assets/latest/\(major)/hotspot?architecture=\(arch)&image_type=jre&os=mac&vendor=eclipse")
        guard let entries=try JSONSerialization.jsonObject(with:json) as? [[String:Any]],let binary=entries.first?["binary"] as? [String:Any],let package=binary["package"] as? [String:Any],let link=package["link"] as? String, let sha=package["checksum"] as? String else {throw LaunchError(message:"未找到适配此 Mac 的 Java \(major)")}
        let data=try await fetch(link)
        guard SHA256.hash(data:data).map({String(format:"%02x",$0)}).joined()==sha else {throw LaunchError(message:"Java 校验失败")}
        let archive=base.appendingPathComponent("runtime.tar.gz");try data.write(to:archive)
        try run("/usr/bin/tar",["-xzf",archive.path,"-C",base.path]);try? FileManager.default.removeItem(at:archive)
        guard let j=findJava() else {throw LaunchError(message:"Java 解压失败")};return j
    }
    func allowed(_ item:[String:Any])->Bool {
        guard let rules=item["rules"] as? [[String:Any]] else{return true}
        var result=false
        for rule in rules {
            if rule["features"] != nil {continue}
            if let os=rule["os"] as? [String:String] {
                if let name=os["name"],name != "osx" {continue}
                if let pattern=os["version"],ProcessInfo.processInfo.operatingSystemVersionString.range(of:pattern,options:.regularExpression)==nil {continue}
                if let arch=os["arch"] {
                    #if arch(arm64)
                    if arch != "aarch64" && arch != "arm64" {continue}
                    #else
                    if arch != "x86_64" && arch != "x64" {continue}
                    #endif
                }
            }
            result=rule["action"] as? String == "allow"
        }
        return result
    }
    func versions() async throws -> [String] {
        let manifest=try await object("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
        return (manifest["versions"] as? [[String:Any]] ?? []).compactMap { v in
            guard v["type"] as? String == "release", let id=v["id"] as? String else{return nil}
            return VersionSupport.isSupported(id) ? id:nil
        }
    }
    func loaderVersions(game:String,kind:String) async throws -> [String] {
        if kind=="原版" {return []}
        if kind=="Fabric" || kind=="Quilt" {
            let base=kind=="Fabric" ? "https://meta.fabricmc.net/v2":"https://meta.quiltmc.org/v3"
            let data=try await fetch("\(base)/versions/loader/\(game)")
            let rows=try JSONSerialization.jsonObject(with:data) as? [[String:Any]] ?? []
            return rows.compactMap{($0["loader"] as? [String:Any])?["version"] as? String}
        }
        if kind=="Forge" {
            let data=try await fetch("https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml")
            let xml=String(decoding:data,as:UTF8.self)
            let regex=try NSRegularExpression(pattern:"<version>([^<]+)</version>")
            return regex.matches(in:xml,range:NSRange(xml.startIndex...,in:xml)).compactMap{match in
                guard let range=Range(match.range(at:1),in:xml) else{return nil};let version=String(xml[range]);return version.hasPrefix(game+"-") ? version:nil
            }.sorted{$0.compare($1,options:.numeric) == .orderedDescending}
        }
        guard kind=="NeoForge" else{throw LaunchError(message:"不支持的加载器")}
        let parts=game.split(separator:".").compactMap{Int($0)}
        guard parts.count>=2,parts[0]==1,parts[1]>=20,game != "1.20.1" else{return []}
        let prefix="\(parts[1]).\(parts.count>2 ? parts[2]:0)."
        let meta=try await object("https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge")
        return (meta["versions"] as? [String] ?? []).filter{$0.hasPrefix(prefix)}.sorted{$0.compare($1,options:.numeric) == .orderedDescending}
    }
    func loaderProfile(game:String,kind:String,build:String,progress:@escaping @Sendable(String)->Void) async throws -> [String:Any] {
        guard VersionSupport.isSupported(game),build.range(of:"^[A-Za-z0-9._+-]+$",options:.regularExpression) != nil else{throw LaunchError(message:"无效加载器版本")}
        if kind=="Fabric" || kind=="Quilt" {
            let base=kind=="Fabric" ? "https://meta.fabricmc.net/v2":"https://meta.quiltmc.org/v3"
            let profile=try await object("\(base)/versions/loader/\(game)/\(build)/profile/json")
            guard profile["mainClass"] is String,profile["libraries"] is [[String:Any]] else{throw LaunchError(message:"加载器配置无效")};return profile
        }
        guard kind=="Forge" || kind=="NeoForge" else{throw LaunchError(message:"不支持的加载器")}
        progress("准备 \(kind) 官方安装器…")
        let manifest=try await object("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
        guard let entry=(manifest["versions"] as? [[String:Any]])?.first(where:{$0["id"] as? String==game}),let url=entry["url"] as? String else{throw LaunchError(message:"没有对应的游戏版本")}
        let metaData=try await fetch(url)
        let meta=try JSONSerialization.jsonObject(with:metaData) as! [String:Any]
        let versionDir=try folder("versions/\(game)");try metaData.write(to:versionDir.appendingPathComponent("\(game).json"),options:.atomic)
        guard let client=(meta["downloads"] as? [String:Any])?["client"] as? [String:Any] else{throw LaunchError(message:"缺少游戏文件")}
        try await download(client,to:versionDir.appendingPathComponent("\(game).jar"))
        let launcher=root.appendingPathComponent("launcher_profiles.json")
        if !FileManager.default.fileExists(atPath:launcher.path){try Data("{\"profiles\":{}}".utf8).write(to:launcher)}
        let major=(meta["javaVersion"] as? [String:Any])?["majorVersion"] as? Int ?? 17
        let runtime=try await java(major)
        let coordinate=kind=="Forge" ? "net/minecraftforge/forge/\(build)/forge-\(build)-installer.jar":"net/neoforged/neoforge/\(build)/neoforge-\(build)-installer.jar"
        let origin=kind=="Forge" ? "https://maven.minecraftforge.net/":"https://maven.neoforged.net/releases/"
        let installerURL=origin+coordinate
        let sha=String(decoding:try await fetch(installerURL+".sha1"),as:UTF8.self).trimmingCharacters(in:.whitespacesAndNewlines)
        guard sha.count==40 else{throw LaunchError(message:"安装器校验信息无效")}
        let installer=try folder("installers").appendingPathComponent("\(kind)-\(build).jar")
        try await download(["url":installerURL,"sha1":sha],to:installer)
        progress("运行 \(kind) 安装器，首次安装可能需要几分钟…")
        let log=try folder("logs").appendingPathComponent("installer-\(kind).log");FileManager.default.createFile(atPath:log.path,contents:Data())
        let handle=try FileHandle(forWritingTo:log);defer{try? handle.close()}
        let task=Process();task.executableURL=runtime;task.currentDirectoryURL=root;task.arguments=["-Djava.awt.headless=true","-jar",installer.path,"--installClient",root.path];task.standardOutput=handle;task.standardError=handle
        running=task;defer{running=nil};let code=try await execute(task)
        try Task.checkCancellation()
        guard code==0 else{throw LaunchError(message:"\(kind) 安装失败，详见 \(log.path)")}
        let key=kind=="Forge" ? "\(game)-forge-\(build.replacingOccurrences(of:game+"-",with:""))":"neoforge-\(build)"
        let generated=root.appendingPathComponent("versions/\(key)/\(key).json")
        guard let result=try JSONSerialization.jsonObject(with:Data(contentsOf:generated)) as? [String:Any],result["mainClass"] is String else{throw LaunchError(message:"未找到安装器生成的启动配置")}
        return result
    }
    func createLoader(game:String,kind:String,build:String,progress:@escaping @Sendable(String)->Void) async throws -> String {
        let profile=try await loaderProfile(game:game,kind:kind,build:build,progress:progress)
        let id=UUID().uuidString
        let record:[String:Any]=["id":id,"name":"\(kind) \(build) · \(game)","minecraft":game,"loaderProfile":profile]
        let dest=try folder("packs").appendingPathComponent("\(id).json")
        try JSONSerialization.data(withJSONObject:record).write(to:dest,options:.atomic)
        _=try gameFolder(version:game,packID:id);return id
    }
    func safePath(_ path:String) throws -> String {
        let parts=path.split(separator:"/",omittingEmptySubsequences:false)
        guard !path.isEmpty,!path.hasPrefix("/"),!path.contains("\\"),!path.contains(":"),!path.contains("\0"),!parts.contains(".."),!parts.contains(".") else {throw LaunchError(message:"整合包包含不安全路径")}
        return path
    }
    func capture(_ args:[String]) throws -> String {
        let p=Process(),pipe=Pipe();p.executableURL=URL(fileURLWithPath:"/usr/bin/zipinfo");p.arguments=args;p.standardOutput=pipe;p.standardError=FileHandle.nullDevice
        try p.run();let data=pipe.fileHandleForReading.readDataToEndOfFile();p.waitUntilExit()
        guard p.terminationStatus==0,let result=String(data:data,encoding:.utf8) else{throw LaunchError(message:"无法读取整合包 ZIP")};return result
    }
    func packList() throws -> [[String:String]] {
        let dir=try folder("packs")
        return try FileManager.default.contentsOfDirectory(at:dir,includingPropertiesForKeys:nil).filter{$0.pathExtension=="json"}.compactMap{url in
            guard let data=try? Data(contentsOf:url),let obj=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let id=obj["id"] as? String,let name=obj["name"] as? String,let mc=obj["minecraft"] as? String else{return nil}
            return ["id":id,"name":name,"minecraft":mc]
        }.sorted{($0["name"] ?? "")<($1["name"] ?? "")}
    }
    func gameFolder(version:String,packID:String?) throws -> URL {
        if let id=packID {guard UUID(uuidString:id) != nil else{throw LaunchError(message:"无效整合包配置")};return try folder("instances/packs/\(id)")}
        return try folder("instances/\(version)")
    }
    func importPack(_ archive:URL,progress:@escaping @Sendable(String)->Void) async throws -> String {
        let fm=FileManager.default
        guard archive.pathExtension.lowercased()=="mrpack",(try archive.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0)<536870912 else{throw LaunchError(message:"请选择小于 512 MB 的 .mrpack 文件；不支持 CurseForge ZIP")}
        progress("检查整合包…")
        let listing=try capture(["-1",archive.path]).split(separator:"\n").map(String.init)
        guard listing.count<30000,Set(listing).count==listing.count else{throw LaunchError(message:"整合包条目过多或重复")}
        for name in listing {_ = try safePath(name)}
        let details=try capture(["-l",archive.path]);var total:Int64=0
        for line in details.split(separator:"\n") {
            if line.hasPrefix("l"){throw LaunchError(message:"整合包不允许符号链接")}
            if line.hasPrefix("-") || line.hasPrefix("d") {let fields=line.split(whereSeparator:{$0==" " || $0=="\t"});if fields.count>3,let size=Int64(fields[3]){total += size}}
        }
        guard total<2147483648 else{throw LaunchError(message:"整合包解压大小超过 2 GB")}
        let id=UUID().uuidString,stage=try folder("staging/\(id)"),game=stage.appendingPathComponent("game")
        defer{try? fm.removeItem(at:stage)}
        let unpack=stage.appendingPathComponent("archive");try fm.createDirectory(at:unpack,withIntermediateDirectories:true)
        try run("/usr/bin/ditto",["-xk",archive.path,unpack.path])
        let indexData=try Data(contentsOf:unpack.appendingPathComponent("modrinth.index.json"))
        guard let index=try JSONSerialization.jsonObject(with:indexData) as? [String:Any],index["formatVersion"] as? Int==1,index["game"] as? String=="minecraft",let deps=index["dependencies"] as? [String:String],let mc=deps["minecraft"],let files=index["files"] as? [[String:Any]] else{throw LaunchError(message:"不支持的 mrpack 清单")}
        guard VersionSupport.isSupported(mc) else{throw LaunchError(message:"目前整合包仅支持 1.7+ 与 26.x 正式版")}
        guard Set(deps.keys).isSubset(of:["minecraft","fabric-loader","quilt-loader","forge","neoforge"]),deps.keys.filter({$0 != "minecraft"}).count<=1 else{throw LaunchError(message:"不支持此整合包加载器组合")}
        var profile:[String:Any]=[:]
        for (key,kind) in [("fabric-loader","Fabric"),("quilt-loader","Quilt"),("forge","Forge"),("neoforge","NeoForge")] {
            if let build=deps[key] {
                let resolved=kind=="Forge" && !build.hasPrefix(mc+"-") ? mc+"-"+build:build
                profile=try await loaderProfile(game:mc,kind:kind,build:resolved,progress:progress)
            }
        }
        try fm.createDirectory(at:game,withIntermediateDirectories:true)
        guard files.count<30000 else{throw LaunchError(message:"整合包文件过多")}
        var seen=Set<String>()
        for (i,file) in files.enumerated() {
            let client=(file["env"] as? [String:String])?["client"] ?? "required"
            if client=="unsupported" || client=="optional" {continue}
            guard client=="required",let path=file["path"] as? String,let hashes=file["hashes"] as? [String:String],let urls=file["downloads"] as? [String],!urls.isEmpty else{throw LaunchError(message:"资源条目无效")}
            _=try safePath(path);guard seen.insert(path).inserted else{throw LaunchError(message:"资源路径重复")}
            progress("下载整合包文件 \(i+1)/\(files.count)…")
            var verified:Data?
            for link in urls {
                guard let u=URL(string:link),u.scheme=="https",let host=u.host,["cdn.modrinth.com","github.com","raw.githubusercontent.com","gitlab.com"].contains(host) else{continue}
                do{let data=try await fetch(link)
                    if let size=file["fileSize"] as? Int,data.count != size {continue}
                    if let sha=hashes["sha512"],SHA512.hash(data:data).map({String(format:"%02x",$0)}).joined()==sha {verified=data;break}
                    if hashes["sha512"]==nil,let sha=hashes["sha1"],digest(data)==sha {verified=data;break}
                }catch{continue}
            }
            guard let data=verified else{throw LaunchError(message:"下载或校验失败：\(path)")}
            let dest=game.appendingPathComponent(path);try fm.createDirectory(at:dest.deletingLastPathComponent(),withIntermediateDirectories:true);try data.write(to:dest,options:.atomic)
        }
        for folder in ["overrides","client-overrides"] {
            let source=unpack.appendingPathComponent(folder)
            if let items=fm.enumerator(at:source,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey]) {
                while let item=items.nextObject() as? URL {
                    let values=try item.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey]);guard values.isSymbolicLink != true else{throw LaunchError(message:"不允许符号链接")}
                    let rel=String(item.path.dropFirst(source.path.count+1));_=try safePath(rel);let dest=game.appendingPathComponent(rel)
                    if values.isDirectory==true {try fm.createDirectory(at:dest,withIntermediateDirectories:true)}
                    else{try fm.createDirectory(at:dest.deletingLastPathComponent(),withIntermediateDirectories:true);if fm.fileExists(atPath:dest.path){try fm.removeItem(at:dest)};try fm.copyItem(at:item,to:dest)}
                }
            }
        }
        let final=try gameFolder(version:mc,packID:id);try fm.removeItem(at:final);try fm.moveItem(at:game,to:final)
        do {let record:[String:Any]=["id":id,"name":index["name"] as? String ?? archive.deletingPathExtension().lastPathComponent,"minecraft":mc,"loaderProfile":profile]
            let dest=try folder("packs").appendingPathComponent("\(id).json");try JSONSerialization.data(withJSONObject:record).write(to:dest,options:.atomic)
        }catch{try? fm.removeItem(at:final);throw error}
        progress("整合包已导入。可选客户端模组默认跳过。请选择整合包后启动。")
        return id
    }
    func launch(version:String,name:String,memory:Int,packID:String?=nil,server:String?=nil,windowWidth:Int=1280,windowHeight:Int=720,progress:@escaping @Sendable (String)->Void) async throws {
        if let p=running,p.isRunning {throw LaunchError(message:"游戏已在运行，请先关闭游戏")}
        guard name.range(of:"^[A-Za-z0-9_]{3,16}$",options:.regularExpression) != nil else {throw LaunchError(message:"用户名须为 3–16 位英文字母、数字或下划线")}
        _=try LaunchSettings(memoryMB:memory,width:windowWidth,height:windowHeight).validated()
        let joinArguments=try multiplayerArguments(version:version,address:server)
        progress("读取版本资料…")
        let manifest=try await object("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
        guard let entry=(manifest["versions"] as? [[String:Any]])?.first(where:{$0["id"] as? String==version}),let url=entry["url"] as? String else{throw LaunchError(message:"未找到游戏版本")}
        var meta=try await object(url)
        if let id=packID {
            guard UUID(uuidString:id) != nil else{throw LaunchError(message:"无效整合包配置")}
            let data=try Data(contentsOf:root.appendingPathComponent("packs/\(id).json"))
            guard let record=try JSONSerialization.jsonObject(with:data) as? [String:Any],record["minecraft"] as? String==version else{throw LaunchError(message:"整合包游戏版本不匹配")}
            let profile=record["loaderProfile"] as? [String:Any] ?? [:]
            if let main=profile["mainClass"] as? String {meta["mainClass"]=main}
            let libs=(profile["libraries"] as? [[String:Any]] ?? [])+(meta["libraries"] as? [[String:Any]] ?? [])
            var names=Set<String>();meta["libraries"]=libs.filter {names.insert($0["name"] as? String ?? UUID().uuidString).inserted}
            var args=meta["arguments"] as? [String:Any] ?? [:]
            for key in ["jvm","game"] {args[key]=(args[key] as? [Any] ?? [])+((profile["arguments"] as? [String:Any])?[key] as? [Any] ?? [])}
            meta["arguments"]=args
        }
        let major=(meta["javaVersion"] as? [String:Any])?["majorVersion"] as? Int ?? VersionSupport.fallbackJava(version)
        progress("准备 Java \(major)，首次下载需要时间…")
        let parts=version.split(separator:".").compactMap{Int($0)}
        let needsIntel=parts.count>1 && parts[0]==1 && parts[1]<19
        if needsIntel{progress("旧版游戏使用 x64 Java；Apple Silicon 需要已安装 Rosetta 2") }
        let runtime=try await java(major,forceIntel:needsIntel)
        let libs=try folder("libraries"),assets=try folder("assets"),game=try gameFolder(version:version,packID:packID),natives=try folder("natives/\(version)")

        guard let client=(meta["downloads"] as? [String:Any])?["client"] as? [String:Any] else {throw LaunchError(message:"缺少游戏文件")}
        let jar=try folder("versions/\(version)").appendingPathComponent("\(version).jar")
        progress("下载并校验游戏文件…");try await download(client,to:jar)
        var classpath=[String]()
        let libraries=meta["libraries"] as? [[String:Any]] ?? []
        for (i,lib) in libraries.enumerated() where allowed(lib) {
            progress("准备依赖 \(i+1)/\(libraries.count)…")
            var downloads=lib["downloads"] as? [String:Any]
            if downloads==nil,let name=lib["name"] as? String {
                let c=name.split(separator:":").map(String.init)
                guard c.count==3 else{throw LaunchError(message:"不支持的加载器依赖")}
                let path=c[0].replacingOccurrences(of:".",with:"/")+"/"+c[1]+"/"+c[2]+"/"+c[1]+"-"+c[2]+".jar"
                let base=lib["url"] as? String ?? "https://libraries.minecraft.net/"
                downloads=["artifact":["path":path,"url":base+(base.hasSuffix("/") ? "":"/")+path]]
            }
            if let downloads=downloads {
                if let a=downloads["artifact"] as? [String:Any],let path=a["path"] as? String {
                    let dest=libs.appendingPathComponent(path);try await download(a,to:dest);classpath.append(dest.path)
                }
                if let classifiers=downloads["classifiers"] as? [String:Any],let native=(lib["natives"] as? [String:String])?["osx"],let a=classifiers[native.replacingOccurrences(of:"${arch}",with:"64")] as? [String:Any],let path=a["path"] as? String {
                    let dest=libs.appendingPathComponent(path);try await download(a,to:dest);try run("/usr/bin/ditto",["-xk",dest.path,natives.path])
                }
            }
        }
        guard let index=meta["assetIndex"] as? [String:Any],let indexID=index["id"] as? String else{throw LaunchError(message:"缺少资源索引")}
        let indexFile=assets.appendingPathComponent("indexes/\(indexID).json");try await download(index,to:indexFile)
        let indexJSON=try JSONSerialization.jsonObject(with:Data(contentsOf:indexFile)) as? [String:Any]
        let objects=indexJSON?["objects"] as? [String:[String:Any]] ?? [:]
        try await withThrowingTaskGroup(of:Void.self) { group in
            var count=0
            for item in objects.values {
                guard let hash=item["hash"] as? String,hash.count==40 else{continue}
                let key="\(hash.prefix(2))/\(hash)"
                group.addTask {try await self.download(["url":"https://resources.download.minecraft.net/\(key)","sha1":hash],to:assets.appendingPathComponent("objects/\(key)"))}
                count += 1
                if count>=12 {try await group.next()}
                if count%25==0 {progress("准备音效与资源 \(count)/\(objects.count)…")}
            }
            try await group.waitForAll()
        }
        if indexJSON?["virtual"] as? Bool==true || indexJSON?["map_to_resources"] as? Bool==true {
            let base=indexJSON?["map_to_resources"] as? Bool==true ? game.appendingPathComponent("resources"):assets.appendingPathComponent("virtual/\(indexID)")
            for (path,item) in objects {let valid=try safePath(path);guard let hash=item["hash"] as? String else{continue};let source=assets.appendingPathComponent("objects/\(hash.prefix(2))/\(hash)"),target=base.appendingPathComponent(valid);try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true);if !FileManager.default.fileExists(atPath:target.path){try FileManager.default.copyItem(at:source,to:target)}}
        }
        let uuid=VersionSupport.offlineID(name)
        let vars=["auth_player_name":name,"version_name":version,"game_directory":game.path,"assets_root":assets.path,"assets_index_name":indexID,"auth_uuid":uuid,"auth_access_token":"0","user_type":"legacy","version_type":"release","natives_directory":natives.path,"launcher_name":"GCL","launcher_version":"0.3","classpath":(classpath+[jar.path]).joined(separator:":"),"library_directory":libs.path,"classpath_separator":":","clientid":"","auth_xuid":"","user_properties":"{}","game_assets":assets.appendingPathComponent("virtual/\(indexID)").path]
        func expand(_ s:String)->String {var t=s;for (k,v) in vars {t=t.replacingOccurrences(of:"${\(k)}",with:v)};return t}
        func arguments(_ name:String)->[String] {
            if name=="game",let legacy=meta["minecraftArguments"] as? String {return VersionSupport.legacyArguments(legacy).map(expand)}
            if name=="jvm",(meta["arguments"] as? [String:Any])?["jvm"]==nil{return ["-Djava.library.path=\(natives.path)","-cp",vars["classpath"]!]}
            let list=(meta["arguments"] as? [String:Any])?[name] as? [Any] ?? []
            return list.flatMap{item->[String] in
                if let s=item as? String{return [expand(s)]}
                guard let rule=item as? [String:Any],allowed(rule) else{return []}
                if let s=rule["value"] as? String{return [expand(s)]}
                return (rule["value"] as? [String] ?? []).map(expand)
            }
        }
        guard let main=meta["mainClass"] as? String else{throw LaunchError(message:"缺少启动入口")}
        let logs=try folder("logs").appendingPathComponent("latest.log");FileManager.default.createFile(atPath:logs.path,contents:Data())
        let handle=try FileHandle(forWritingTo:logs)
        let p=Process();p.executableURL=runtime;p.currentDirectoryURL=game;p.arguments=["-Xmx\(memory)M"]+arguments("jvm")+[main]+arguments("game")+["--width",String(windowWidth),"--height",String(windowHeight)]+joinArguments;p.standardOutput=handle;p.standardError=handle
        running=p;defer{running=nil;try? handle.close()};progress("正在启动游戏，日志：\(logs.path)")
        let code=try await execute(p);try Task.checkCancellation()
        if code != 0 {throw LaunchError(message:"游戏退出（\(p.terminationStatus)），请查看 logs/latest.log。旧版本的原生依赖可能不支持此 Mac 架构。")}
        progress("游戏已退出")
    }
}
