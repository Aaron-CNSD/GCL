import SwiftUI
import Darwin

struct LANOptions {
    var version:String
    var owner:String
    var admins:String
    var port=25565
    var players=8
    var mode="survival"
    var difficulty="normal"
    var online=true
    var pvp=true
    var seed=""
    var eula=false
    func validated() throws -> LANOptions {
        guard eula else {throw LaunchError(message:"请先阅读并同意 Minecraft EULA")}
        guard version.range(of:"^[A-Za-z0-9._-]+$",options:.regularExpression) != nil,!version.contains(".."),version.count<50 else{throw LaunchError(message:"游戏版本无效")}
        guard (1024...65535).contains(port),(1...64).contains(players),["survival","creative","adventure","spectator"].contains(mode),["peaceful","easy","normal","hard"].contains(difficulty) else{throw LaunchError(message:"房间设置无效")}
        for name in operators {guard name.range(of:"^[A-Za-z0-9_]{3,16}$",options:.regularExpression) != nil else{throw LaunchError(message:"房主和管理员须为 3–16 位英文、数字或下划线")}}
        guard !seed.contains(where:{$0.isNewline}),seed.count<100 else{throw LaunchError(message:"种子格式无效")}
        return self
    }
    var operators:[String] {Array(Set(([owner]+admins.split(whereSeparator:{$0=="," || $0.isWhitespace}).map(String.init)).filter{!$0.isEmpty})).sorted()}
    func properties(address:String)->String {
        "server-ip=\(address)\nserver-port=\(port)\nmax-players=\(players)\ngamemode=\(mode)\ndifficulty=\(difficulty)\nonline-mode=\(online)\nenforce-secure-profile=\(online)\npvp=\(pvp)\nlevel-seed=\(seed)\nmotd=GCL LAN\nview-distance=8\nsimulation-distance=6\nenable-rcon=false\nenable-query=false\nop-permission-level=4\n"
    }
    static func localAddress()->String? {
        var addresses:UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses)==0 else{return nil};defer{freeifaddrs(addresses)}
        var cursor=addresses
        while let item=cursor {
            defer{cursor=item.pointee.ifa_next}
            guard let address=item.pointee.ifa_addr,address.pointee.sa_family==UInt8(AF_INET) else{continue}
            var host=[CChar](repeating:0,count:Int(NI_MAXHOST))
            guard getnameinfo(address,socklen_t(address.pointee.sa_len),&host,socklen_t(host.count),nil,0,NI_NUMERICHOST)==0 else{continue}
            let ip=String(cString:host),parts=ip.split(separator:".").compactMap{Int($0)}
            if parts.count==4 && (parts[0]==10 || (parts[0]==192 && parts[1]==168) || (parts[0]==172 && (16...31).contains(parts[1]))) {return ip}
        }
        return nil
    }
}

actor LANServer {
    let engine:Engine
    var process:Process?
    var input:Pipe?
    var output:Pipe?
    var log=""
    var status="未创建房间"
    var address=""
    var operators=[String]()
    var ready=false
    var stopping=false
    init(root:URL?=nil){engine=root.map{Engine(root:$0)} ?? Engine()}
    func start(_ raw:LANOptions) async throws {
        guard process?.isRunning != true else{throw LaunchError(message:"房间已运行，请先关闭")}
        let options=try raw.validated()
        guard let ip=LANOptions.localAddress() else{throw LaunchError(message:"未检测到局域网 IPv4，请连接同一 Wi-Fi 或有线网络")}
        status="下载官方服务器与 Java…";log="";ready=false;stopping=false
        let manifest=try await engine.object("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")
        guard let entry=(manifest["versions"] as? [[String:Any]])?.first(where:{$0["id"] as? String==options.version}),let url=entry["url"] as? String else{throw LaunchError(message:"找不到此服务器版本")}
        let meta=try await engine.object(url)
        guard let server=(meta["downloads"] as? [String:Any])?["server"] as? [String:Any] else{throw LaunchError(message:"此版本没有官方服务器下载")}
        let major=(meta["javaVersion"] as? [String:Any])?["majorVersion"] as? Int ?? VersionSupport.fallbackJava(options.version)
        let java=try await engine.java(major)
        let folder=try await engine.folder("servers/local-\(options.version)")
        try await engine.download(server,to:folder.appendingPathComponent("server.jar"))
        try Data(options.properties(address:ip).utf8).write(to:folder.appendingPathComponent("server.properties"),options:.atomic)
        try Data("eula=true\n".utf8).write(to:folder.appendingPathComponent("eula.txt"),options:.atomic)
        // Clear previous operator grants: the user selects the operator list for this launch.
        try Data("[]".utf8).write(to:folder.appendingPathComponent("ops.json"),options:.atomic)
        let stdin=Pipe(),stdout=Pipe(),p=Process();p.executableURL=java;p.currentDirectoryURL=folder
        p.arguments=["-Xms512M","-Xmx2048M","-jar","server.jar","nogui"]
        p.standardInput=stdin;p.standardOutput=stdout;p.standardError=stdout
        stdout.fileHandleForReading.readabilityHandler={ [weak self] handle in
            let data=handle.availableData;guard !data.isEmpty else{handle.readabilityHandler=nil;return}
            Task{await self?.receive(data)}
        }
        input=stdin;output=stdout;operators=options.operators;address="\(ip):\(options.port)";process=p
        p.terminationHandler={ [weak self] child in Task{await self?.exited(child.terminationStatus)} }
        NotificationCenter.default.addObserver(forName:NSApplication.willTerminateNotification,object:nil,queue:nil){[weak p] _ in if p?.isRunning == true {try? stdin.fileHandleForWriting.write(contentsOf:Data("stop\n".utf8))}}
        do{try p.run();status="服务器启动中，等待世界载入…"}catch{stdout.fileHandleForReading.readabilityHandler=nil;process=nil;throw error}
    }
    func receive(_ data:Data) {
        log += String(decoding:data,as:UTF8.self);if log.count>65536{log=String(log.suffix(65536))}
        if !ready,log.contains("Done (") {
            ready=true;status="房间已开启 · \(address)"
            for name in operators {try? input?.fileHandleForWriting.write(contentsOf:Data("op \(name)\n".utf8))}
        }
    }
    func exited(_ code:Int32){status=stopping ? "房间已关闭":"服务器已退出（\(code)），请查看下方日志";ready=false;process=nil;input=nil;output?.fileHandleForReading.readabilityHandler=nil;output=nil}
    func stop() throws {guard process?.isRunning==true else{return};stopping=true;status="正在保存世界并关闭…";try input?.fileHandleForWriting.write(contentsOf:Data("stop\n".utf8))}
    func snapshot()->(String,String,String,Bool,Bool){(status,address,log,process?.isRunning==true,ready)}
}

@MainActor final class LANModel:ObservableObject {
    @Published var admins=""
    @Published var owner=""
    @Published var seed=""
    @Published var status="未创建房间"
    @Published var address=""
    @Published var log=""
    @Published var port=25565
    @Published var players=8
    @Published var mode="survival"
    @Published var difficulty="normal"
    @Published var online=true
    @Published var pvp=true
    @Published var eula=false
    @Published var busy=false
    @Published var running=false
    @Published var ready=false
    let server=LANServer()
    func create(version:String){guard !busy && !running else{return};busy=true;let options=LANOptions(version:version,owner:owner,admins:admins,port:port,players:players,mode:mode,difficulty:difficulty,online:online,pvp:pvp,seed:seed,eula:eula);Task{do{try await server.start(options)}catch{status=error.localizedDescription};busy=false}}
    func stop(){Task{do{try await server.stop()}catch{status=error.localizedDescription}}}
    func poll() async {while !Task.isCancelled{let s=await server.snapshot();if running || busy || s.3 {status=s.0};address=s.1;log=s.2;running=s.3;ready=s.4;try? await Task.sleep(nanoseconds:500_000_000)}}
}

struct LANPanel:View {
    let username:String
    let version:String
    @ObservedObject var room:LANModel
    let join:(String)->Void
    var body:some View {
        GlassPanel {VStack(alignment:.leading,spacing:14){
            Label("联机",systemImage:"network").font(.title2.bold())
            Text("本机启动独立原版服务器，同一 Wi-Fi / 有线局域网的朋友通过地址加入。服务器世界独立于单人存档；模组服暂不支持。").font(.caption).foregroundStyle(.secondary)
            Text("Minecraft \(version)").font(.headline)
            VStack(alignment:.leading,spacing:12){
                HStack{TextField("房主用户名",text:$room.owner);TextField("管理员（逗号分隔）",text:$room.admins)}
                HStack{Stepper("人数 \(room.players)",value:$room.players,in:1...64);TextField("端口",value:$room.port,formatter:NumberFormatter()).frame(width:110)}
                HStack{Picker("模式",selection:$room.mode){Text("生存").tag("survival");Text("创造").tag("creative");Text("冒险").tag("adventure")};Picker("难度",selection:$room.difficulty){Text("和平").tag("peaceful");Text("简单").tag("easy");Text("普通").tag("normal");Text("困难").tag("hard")}}
                TextField("世界种子（仅首次创建世界生效）",text:$room.seed)
                Toggle("正版验证",isOn:$room.online)
                Text("当前启动器使用本地账号；本地账号加入需由房主关闭验证。").font(.caption).foregroundStyle(.secondary)
                Toggle("玩家互相伤害（PVP）",isOn:$room.pvp)
                if !room.online{Text("关闭验证后，局域网内其他人可冒用房主或管理员用户名；请仅在可信网络使用。").font(.caption).foregroundStyle(.orange)}
                HStack{Toggle("我已阅读并同意 Minecraft EULA",isOn:$room.eula);Link("阅读协议",destination:URL(string:"https://www.minecraft.net/eula")!)}
            }.textFieldStyle(.roundedBorder).disabled(room.busy || room.running)
            HStack{Button(room.busy ? "准备中…":"创建房间"){room.create(version:version)}.disabled(room.busy || room.running || !room.eula);Button("关闭房间"){room.stop()}.disabled(!room.running);if room.ready{Button("进入房间"){join(room.address)}}}
            Text(room.status).font(.callout)
            if !room.address.isEmpty{Text(room.address).font(.system(.body,design:.monospaced)).textSelection(.enabled)}
            if !room.log.isEmpty{ScrollView{Text(room.log).font(.system(size:10,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}.frame(height:120)}
        }}.onAppear{if room.owner.isEmpty{room.owner=username}}.task{await room.poll()}
    }
}
