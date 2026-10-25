import SwiftUI
import CryptoKit

actor RoomEngine {
    let engine:Engine
    let installCheck:URL
    var process:Process?
    var base:URL?
    init(root:URL?=nil,installCheck:URL=URL(fileURLWithPath:"/Applications/terracotta.app")){engine=root.map{Engine(root:$0)} ?? Engine();self.installCheck=installCheck}
    #if arch(arm64)
    static let architecture="arm64"
    static let checksum="13de7f9ce8733971b23493fabbe7e16d480f1e0d16a6265b4861f5a01bbecb60"
    #else
    static let architecture="x86_64"
    static let checksum="16306157d89423ce79fa901cdb75a6386ec1a9b1bd43a5d47c2c47cf01a16b86"
    #endif
    static let version="0.4.2"
    func prepare() async throws -> URL {
        let folder=try await engine.folder("multiplayer/Terracotta-\(Self.version)-\(Self.architecture)")
        let stem="terracotta-\(Self.version)-macos-\(Self.architecture)"
        let archive=folder.appendingPathComponent("official.tar.gz")
        var data=try? Data(contentsOf:archive)
        if data==nil || SHA256.hash(data:data!).map({String(format:"%02x",$0)}).joined() != Self.checksum {
            data=try await engine.fetch("https://github.com/burningtnt/Terracotta/releases/download/v\(Self.version)/\(stem)-pkg.tar.gz")
            guard SHA256.hash(data:data!).map({String(format:"%02x",$0)}).joined()==Self.checksum else{throw LaunchError(message:"陶瓦官方组件校验失败")}
            try data!.write(to:archive,options:.atomic)
        }
        // Always extract again from the verified vendor archive, not an unverified cached executable.
        try await engine.run("/usr/bin/tar",["-xzf",archive.path,"-C",folder.path])
        let binary=folder.appendingPathComponent(stem)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:binary.path)
        guard FileManager.default.fileExists(atPath:folder.appendingPathComponent(stem+".pkg").path) else{throw LaunchError(message:"陶瓦组件不完整")}
        return folder.appendingPathComponent(stem+".pkg")
    }
    func connect() async throws {
        guard FileManager.default.fileExists(atPath:installCheck.path) else{throw LaunchError(message:"请先点击“安装系统组件”，在系统安装器中完成授权；再启动陶瓦")}
        if base != nil {return}
        let pkg=try await prepare(),binary=pkg.deletingPathExtension()
        let info=pkg.deletingLastPathComponent().appendingPathComponent("session-\(UUID().uuidString).json")
        defer{try? FileManager.default.removeItem(at:info)}
        let log=try await engine.folder("logs").appendingPathComponent("terracotta.log")
        FileManager.default.createFile(atPath:log.path,contents:Data())
        let handle=try FileHandle(forWritingTo:log)
        let p=Process();p.executableURL=binary;p.arguments=["--hmcl",info.path];p.standardOutput=handle;p.standardError=handle
        p.terminationHandler={_ in try? handle.close()}
        try p.run();process=p
        for _ in 0..<80 {
            try Task.checkCancellation()
            if let data=try? Data(contentsOf:info),let obj=try? JSONSerialization.jsonObject(with:data) as? [String:Any],let port=obj["port"] as? Int,(1...65535).contains(port) {
                try attach(port:port)
                let meta=try await request("/meta")
                guard (meta["version"] as? String)?.contains(Self.version)==true else{base=nil;throw LaunchError(message:"已有陶瓦版本不兼容，请退出旧版后重试")}
                return
            }
            try await Task.sleep(nanoseconds:100_000_000)
        }
        throw LaunchError(message:"陶瓦启动超时，请查看 terracotta.log；检查系统组件和本地网络权限")
    }
    func attach(port:Int) throws {guard (1...65535).contains(port) else{throw LaunchError(message:"本地陶瓦端口无效")};base=URL(string:"http://127.0.0.1:\(port)")}
    func request(_ path:String,parameters:[URLQueryItem]=[]) async throws -> [String:Any] {
        guard let base=base else{throw LaunchError(message:"请先启动陶瓦组件")}
        var url=URLComponents(url:base,resolvingAgainstBaseURL:false)!;url.path=path;url.queryItems=parameters.isEmpty ? nil:parameters
        var req=URLRequest(url:url.url!);req.timeoutInterval=8
        let (data,response)=try await URLSession.shared.data(for:req)
        guard let http=response as? HTTPURLResponse,(200...299).contains(http.statusCode) else{throw LaunchError(message:"陶瓦拒绝操作：请检查房间码或先离开当前房间")}
        if data.isEmpty{return [:]}
        return (try? JSONSerialization.jsonObject(with:data) as? [String:Any]) ?? [:]
    }
    func state() async throws -> [String:Any] {try await request("/state")}
    func create(player:String) async throws {
        let current=try await state();guard current["state"] as? String=="waiting" else{throw LaunchError(message:"请先离开当前房间再创建")}
        _=try await request("/state/scanning",parameters:[URLQueryItem(name:"player",value:player)])
    }
    func join(code:String,player:String) async throws {
        let text=code.trimmingCharacters(in:.whitespacesAndNewlines)
        guard text.count>=10,text.count<=100,text.hasPrefix("U/") else{throw LaunchError(message:"请输入完整陶瓦房间码，通常以 U/ 开头")}
        let current=try await state();guard current["state"] as? String=="waiting" else{throw LaunchError(message:"请先离开当前房间再加入")}
        _=try await request("/state/guesting",parameters:[URLQueryItem(name:"room",value:text),URLQueryItem(name:"player",value:player)])
    }
    func leave() async throws{_=try await request("/state/ide")}
}

@MainActor final class RoomModel:ObservableObject {
    @Published var status="先安装系统组件，再启动陶瓦联机"
    @Published var error=""
    @Published var busy=false
    @Published var ready=false
    @Published var code=""
    @Published var invitation=""
    @Published var address=""
    @Published var members=[String]()
    @Published var phase=""
    let engine=RoomEngine()
    var polling:Task<Void,Never>?
    deinit{polling?.cancel()}
    func perform(_ action:@escaping () async throws -> Void){guard !busy else{return};busy=true;error="";Task{do{try await action()}catch{self.error=error.localizedDescription};busy=false}}
    func install(){perform{self.status="下载并校验陶瓦官方组件…";let pkg=try await self.engine.prepare();NSWorkspace.shared.open(pkg);self.status="请在 macOS 系统安装器中完成安装授权，然后点击启动陶瓦；首次使用可能提示本地网络权限"}}
    func start(){perform{try await self.engine.connect();self.ready=true;self.status="陶瓦已连接，可以创建或加入房间";self.polling?.cancel();self.polling=Task{var failures=0;while !Task.isCancelled{do{let obj=try await self.engine.state();self.apply(obj);failures=0}catch{failures+=1;if failures>=5{self.ready=false;self.status="陶瓦连接中断，请重启组件";break}};try? await Task.sleep(nanoseconds:1_000_000_000)}}}}
    func apply(_ obj:[String:Any]) {
        phase=obj["state"] as? String ?? ""
        invitation=obj["room"] as? String ?? ""
        address=obj["url"] as? String ?? ""
        members=(obj["profiles"] as? [[String:Any]] ?? []).compactMap{$0["name"] as? String}
        switch phase {
        case "waiting":status="待机：可以创建或加入房间"
        case "host-scanning":status="等待游戏开放局域网：进入存档 → 对局域网开放"
        case "host-starting":status="正在创建房间…"
        case "host-ok":status="房间已创建，将房间码发给朋友"
        case "guest-connecting","guest-starting":status="正在连接房主，尝试 P2P 穿透…"
        case "guest-ok":status="已加入房间，可以进入游戏"
        case "exception":status="联机异常（\(obj["type"] ?? "未知")），请离开房间后重试"
        default:status="等待陶瓦状态…"
        }
    }
    func create(player:String){perform{try await self.engine.create(player:player)}}
    func join(player:String){let value=code;perform{try await self.engine.join(code:value,player:player)}}
    func leave(){perform{try await self.engine.leave();self.invitation="";self.address="";self.members=[]}}
    func copy(){NSPasteboard.general.clearContents();NSPasteboard.general.setString(invitation,forType:.string)}
}
struct RoomPanel:View {
    let username:String
    let gameRunning:Bool
    let launch:(String?)->Void
    @StateObject private var r=RoomModel()
    var body:some View{GlassPanel{VStack(alignment:.leading,spacing:16){
        Label("房间码联机",systemImage:"person.3.sequence.fill").font(.title2.bold())
        Text("创建房间 → 分享陶瓦码 → 朋友输入后加入。双方需使用相同游戏版本与模组。").foregroundStyle(.secondary)
        HStack{Button("安装系统组件"){r.install()};Button("启动陶瓦"){r.start()}.disabled(r.ready)}.disabled(r.busy)
        Text("首次安装由 macOS 系统安装器完成，需要你授权。陶瓦需要本地网络权限。").font(.caption).foregroundStyle(.secondary)
        Divider()
        HStack{Button("启动游戏"){launch(nil)}.disabled(gameRunning);Button("创建房间"){r.create(player:username)}.buttonStyle(.borderedProminent).disabled(!r.ready || r.busy);Button("离开 / 重置"){r.leave()}.disabled(!r.ready || r.busy)}
        Text("房主先进入存档并“对局域网开放”，陶瓦自动扫描端口。游戏运行时仍可操作房间。").font(.caption).foregroundStyle(.secondary)
        HStack{TextField("粘贴陶瓦房间码 U/…",text:$r.code).textFieldStyle(.roundedBorder);Button("加入房间"){r.join(player:username)}.disabled(!r.ready || r.busy || r.code.isEmpty)}
        if !r.invitation.isEmpty{HStack{Text(r.invitation).font(.headline.monospaced()).textSelection(.enabled);Button("复制房间码"){r.copy()}}}
        if r.phase=="guest-ok"{Button("启动并进入房间"){launch(r.address)}.buttonStyle(.borderedProminent).disabled(gameRunning);Text("备用直连地址：\(r.address)").font(.caption).textSelection(.enabled)}
        if !r.members.isEmpty{Text("房间成员："+r.members.joined(separator:"、")).font(.callout)}
        if !r.error.isEmpty{Text(r.error).foregroundStyle(.red).font(.caption).textSelection(.enabled)}
        HStack{if r.busy{ProgressView().controlSize(.small)};Text(r.status).font(.caption.monospaced()).textSelection(.enabled)}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:12))
        Text("Terracotta 陶瓦联机 — © burningtnt · AGPL-3.0-or-later（未经修改的独立组件，通过本地 HTTP API 集成）").font(.caption2).foregroundStyle(.secondary)
        Text("依赖公共节点和双方网络；不能保证所有 NAT 环境连接成功。无 Microsoft 登录入口，不提供公网长期服务器托管。").font(.caption).foregroundStyle(.secondary)
    }}}
}
