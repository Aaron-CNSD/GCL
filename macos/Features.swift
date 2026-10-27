import SwiftUI
import CryptoKit
import ImageIO
struct ResourceHit:Decodable,Identifiable {let project_id:String;let title:String;let description:String;let project_type:String;var id:String{project_id}}
struct SearchResponse:Decodable {let hits:[ResourceHit]}
struct ResourceFile:Decodable {let url:String;let filename:String;let hashes:[String:String];let primary:Bool?}
struct ResourceVersion:Decodable,Identifiable {let id:String;let name:String;let files:[ResourceFile];let loaders:[String];let game_versions:[String]}
extension Engine {
    func multiplayerArguments(version:String,address:String?) throws -> [String] {
        guard let input=address?.trimmingCharacters(in:.whitespacesAndNewlines),!input.isEmpty else{return []}
        guard !input.contains(where:{$0.isWhitespace || "/?#@\\".contains($0)}),let url=URLComponents(string:"minecraft://"+input),let host=url.host,!host.isEmpty,(url.port ?? 25565)>0,(url.port ?? 25565)<65536 else{throw LaunchError(message:"服务器地址无效，请填写 host:port 或 [IPv6]:port")}
        let minor=Int(version.split(separator:".").dropFirst().first ?? "0") ?? 0
        if minor>=20 || (Int(version.split(separator:".").first ?? "0") ?? 0)>=26 {return ["--quickPlayMultiplayer",input]}
        return ["--server",host,"--port",String(url.port ?? 25565)]
    }
    func activeLoader(_ id:String?) throws -> String {
        guard let id=id,!id.isEmpty else{return ""}
        guard UUID(uuidString:id) != nil else{throw LaunchError(message:"无效配置")}
        let obj=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("packs/\(id).json"))) as? [String:Any]
        let profile=obj?["loaderProfile"] as? [String:Any] ?? [:]
        let libraries=(profile["libraries"] as? [[String:Any]] ?? []).compactMap{$0["name"] as? String}.joined(separator:" ")
        if libraries.contains("org.quiltmc"){return "quilt"}
        if libraries.contains("net.neoforged"){return "neoforge"}
        if libraries.contains("net.minecraftforge"){return "forge"}
        if libraries.contains("net.fabricmc"){return "fabric"}
        return ""
    }
    func searchResources(query:String,type:String,game:String) async throws -> [ResourceHit] {
        guard ["mod","modpack","shader"].contains(type) else{throw LaunchError(message:"资源类型无效")}
        let facets=try JSONSerialization.data(withJSONObject:[["project_type:\(type)"],["versions:\(game)"]])
        var u=URLComponents(string:"https://api.modrinth.com/v2/search")!
        u.queryItems=[URLQueryItem(name:"query",value:query),URLQueryItem(name:"facets",value:String(decoding:facets,as:UTF8.self)),URLQueryItem(name:"limit",value:"20")]
        return try JSONDecoder().decode(SearchResponse.self,from:await fetch(u.url!.absoluteString)).hits
    }
    func resourceVersions(project:String,game:String,loader:String="") async throws -> [ResourceVersion] {
        guard project.range(of:"^[A-Za-z0-9_-]+$",options:.regularExpression) != nil else{throw LaunchError(message:"资源 ID 无效")}
        var u=URLComponents(string:"https://api.modrinth.com/v2/project/\(project)/version")!
        u.queryItems=[URLQueryItem(name:"game_versions",value:String(decoding:try JSONEncoder().encode([game]),as:UTF8.self))]
        if !loader.isEmpty{u.queryItems!.append(URLQueryItem(name:"loaders",value:String(decoding:try JSONEncoder().encode([loader]),as:UTF8.self)))}
        return try JSONDecoder().decode([ResourceVersion].self,from:await fetch(u.url!.absoluteString))
    }
    func installResource(_ version:ResourceVersion,type:String,game:String,pack:String?,progress:@escaping @Sendable(String)->Void) async throws -> String? {
        guard version.game_versions.contains(game) else{throw LaunchError(message:"资源版本已过期，请按当前 Minecraft 版本重新搜索")}
        if type=="mod"{let loader=try activeLoader(pack);if !loader.isEmpty && !version.loaders.contains(loader){throw LaunchError(message:"资源与当前加载器不匹配，请重新选择版本")}}
        guard let file=version.files.first(where:{$0.primary==true}) ?? version.files.first,file.filename==URL(fileURLWithPath:file.filename).lastPathComponent,!file.filename.contains("\\") else{throw LaunchError(message:"资源文件无效")}
        let ext=URL(fileURLWithPath:file.filename).pathExtension.lowercased()
        guard (type=="mod" && ext=="jar") || (type=="shader" && ext=="zip") || (type=="modpack" && ext=="mrpack") else{throw LaunchError(message:"资源格式不支持")}
        if type=="modpack" {
            let target=try folder("downloads").appendingPathComponent(UUID().uuidString+".mrpack")
            defer{try? FileManager.default.removeItem(at:target)}
            progress("下载整合包…");try await download(["url":file.url,"sha1":file.hashes["sha1"] ?? ""],to:target)
            return try await importPack(target,progress:progress)
        }
        let base=try gameFolder(version:game,packID:pack)
        let target=base.appendingPathComponent(type=="mod" ? "mods":"shaderpacks").appendingPathComponent(file.filename)
        progress("下载并校验 \(file.filename)…")
        try await download(["url":file.url,"sha1":file.hashes["sha1"] ?? ""],to:target)
        progress("下载完成：\(file.filename)。模组的其他依赖请在资源中心一并安装；光影需要兼容的 Iris / OptiFine。")
        return nil
    }
    func installSkin(_ url:URL,username:String,game:String,pack:String?,progress:@escaping @Sendable(String)->Void) async throws -> String? {
        guard username.range(of:"^[A-Za-z0-9_]{3,16}$",options:.regularExpression) != nil else{throw LaunchError(message:"用户名格式无效")}
        let data=try Data(contentsOf:url)
        guard data.count<2_097_152,data.starts(with:[137,80,78,71,13,10,26,10]),let source=CGImageSourceCreateWithData(data as CFData,nil),let info=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let width=info[kCGImagePropertyPixelWidth] as? Int,let height=info[kCGImagePropertyPixelHeight] as? Int,width==64,[32,64].contains(height) else{throw LaunchError(message:"请选择 64×64 或 64×32 的 PNG 皮肤（小于 2 MB）")}
        var id=pack;var loader=try activeLoader(pack)
        if loader.isEmpty {
            progress("为本地皮肤创建 Fabric 配置…")
            guard let build=try await loaderVersions(game:game,kind:"Fabric").first else{throw LaunchError(message:"此版本没有可用 Fabric")}
            id=try await createLoader(game:game,kind:"Fabric",build:build,progress:progress);loader="fabric"
        }
        guard let version=try await resourceVersions(project:"customskinloader",game:game,loader:loader).first else{throw LaunchError(message:"当前版本 / 加载器没有兼容的 CustomSkinLoader，请选择其他版本")}
        _=try await installResource(version,type:"mod",game:game,pack:id,progress:progress)
        let base=try gameFolder(version:game,packID:id),folder=base.appendingPathComponent("CustomSkinLoader/LocalSkin/skins")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try data.write(to:folder.appendingPathComponent(username+".png"),options:.atomic)
        let configURL=base.appendingPathComponent("CustomSkinLoader/CustomSkinLoader.json")
        var config:[String:Any]=["version":"15.1","buildNumber":0]
        if let old=try? Data(contentsOf:configURL),let value=try? JSONSerialization.jsonObject(with:old) as? [String:Any] {
            config=value
            let backup=configURL.appendingPathExtension("glasscraft-backup")
            if !FileManager.default.fileExists(atPath:backup.path){try old.write(to:backup,options:.atomic)}
        }
        let local:[String:Any]=["name":"GCL Local","type":"Legacy","skin":"LocalSkin/skins/{USERNAME}.png"]
        var list=config["loadlist"] as? [[String:Any]] ?? []
        list.removeAll{($0["skin"] as? String)=="LocalSkin/skins/{USERNAME}.png"}
        list.insert(local,at:0);config["loadlist"]=list
        try JSONSerialization.data(withJSONObject:config,options:.prettyPrinted).write(to:configURL,options:.atomic)
        progress("本地皮肤已设置，重启游戏生效。其他玩家需使用相同皮肤配置才能看到；不会上传皮肤图片。")
        return id
    }
}
