import SwiftUI

struct LauncherMark:View {
    var size:CGFloat=32
    private static let mark:NSImage = Bundle.main.url(forResource:"GCLIcon",withExtension:"png").flatMap{NSImage(contentsOf:$0)} ?? NSApplication.shared.applicationIconImage ?? NSImage(size:NSSize(width:64,height:64))
    var body:some View {Image(nsImage:Self.mark).resizable().interpolation(.high).scaledToFit().frame(width:size,height:size).accessibilityLabel("GCL 村庄房屋图标")}
}

struct SidebarMaterial:ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduced
    @AppStorage("clearGlass") private var clear=false
    @ViewBuilder func body(content:Content)->some View {
        if reduced {content.background(Color(nsColor:.controlBackgroundColor))}
        else {content.modifier(LauncherChrome(radius:10))}
    }
}

extension LauncherView {
    private var pageTransition:AnyTransition {.identity}
    private var selectedTitle:String {m.packs.first(where:{$0["id"]==m.packID})?["name"] ?? "Minecraft \(m.selected)"}
    var body:some View {
        VStack(spacing:0) {
            HStack(spacing:9) {
                LauncherMark(size:18)
                Text("GlassCraft").font(.system(size:12,weight:.semibold))
                Text("GCL").font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)
                Spacer()
                if updater.release != nil {Button("发现更新"){m.page="关于 GCL"}.buttonStyle(.plain)}
                Button {m.chooseBackdrop()} label:{Image(systemName:"photo")}.buttonStyle(.plain).help("更换背景")
                Button {m.page="关于 GCL"} label:{Image(systemName:"questionmark.circle")}.buttonStyle(.plain).help("关于与更新")
            }.padding(.horizontal,14).frame(height:32).modifier(LauncherChrome(radius:0))
        HStack(spacing:0) {
            navigation.frame(width:150).modifier(SidebarMaterial()).padding(8)
            VStack(alignment:.leading,spacing:0) {
                HStack(alignment:.center) {
                    if m.page != "开始游戏" {
                        VStack(alignment:.leading,spacing:4) {
                            Text(pageLabel(m.page)).font(.system(size:22,weight:.semibold))
                            Text("当前配置 · \(selectedTitle)").font(.caption).foregroundStyle(.secondary)
                        }.padding(.horizontal,14).padding(.vertical,10).modifier(LauncherGlassSurface(radius:6))
                    }
                    Spacer()
                }.padding(.horizontal,12).padding(.top,m.page == "开始游戏" ? 0:14).padding(.bottom,m.page == "开始游戏" ? 0:12)
                ZStack(alignment:.topLeading) {
                if m.page == "开始游戏" {
                    home.frame(maxWidth:.infinity,maxHeight:.infinity).transition(pageTransition)
                } else {
                    ScrollView {
                        VStack(spacing:16) {
                            switch m.page {
                            case "版本管理":configuration;instances
                            case "模组管理":modManager
                            case "资源下载":downloadCenter
                            case "一键联机":multiplayer
                            case "我的皮肤":skin
                            case "任务与日志":diagnostics
                            case "启动设置":launchSettings
                            case "关于 GCL":about
                            default:EmptyView()
                            }
                        }.frame(maxWidth:900).frame(maxWidth:.infinity).padding(.horizontal,14).padding(.bottom,12)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity).id(m.page).transition(pageTransition)
                }
                }.animation(nil,value:m.page)
                if m.page != "开始游戏" {statusLine}
            }
        }
        }
        .frame(minWidth:720,minHeight:450)
        .background{LauncherBackdrop(path:m.backdropPath,playing:m.page == "开始游戏").equatable()}
        .tint(Color(red:0.18,green:0.38,blue:0.43))
        .accentColor(Color(red:0.18,green:0.38,blue:0.43))
        .onAppear{if !m.demoMode {m.refresh();updater.check()};m.loadWorkspace();if m.demoMode{DispatchQueue.main.asyncAfter(deadline:.now()+0.3){NSApp.activate(ignoringOtherApps:true);NSApp.windows.first?.makeKeyAndOrderFront(nil)}}}
        .onChange(of:m.selected){_ in m.resetResources();m.loadVersions();m.loadPreferences();m.refreshMods()}
        .onChange(of:m.packID){id in m.resetResources();m.loadPreferences();m.refreshMods();if let pack=m.packs.first(where:{$0["id"]==id}){m.selected=pack["minecraft"] ?? m.selected}}
        .onChange(of:m.appearance){UserDefaults.standard.set($0,forKey:"appearance")}
        .onChange(of:m.page){if $0 == "模组管理"{m.refreshMods()}}
        .preferredColorScheme(m.appearance == "dark" ? .dark:m.appearance == "light" ? .light:nil)
    }

    private var navigation:some View {
        VStack(alignment:.leading,spacing:0) {
            sectionTitle("账户")
            HStack(spacing:10) {
                Image(systemName:"keyboard").font(.system(size:20)).foregroundStyle(.secondary)
                VStack(alignment:.leading,spacing:3) {
                    HStack(spacing:4){TextField("玩家名称",text:$m.name).textFieldStyle(.plain).font(.system(size:14,weight:.medium));Button{m.showInstanceChooser.toggle()}label:{Image(systemName:"chevron.down").font(.system(size:10))}.buttonStyle(.plain).help("选择自己的实例")
                    .popover(isPresented:$m.showInstanceChooser,arrowEdge:.trailing){configuration.frame(width:340).padding(12)}}
                    Text("离线模式").font(.system(size:11)).foregroundStyle(.secondary)
                }
            }.padding(.horizontal,12).padding(.top,4).padding(.bottom,8)
            sectionTitle("游戏")
            ForEach(pages.filter{["开始游戏","版本管理","资源下载","模组管理"].contains($0.0)},id:\.0){navigationRow($0)}
            sectionTitle("通用")
            ForEach(pages.filter{["一键联机","我的皮肤","任务与日志","启动设置","关于 GCL"].contains($0.0)},id:\.0){navigationRow($0)}
            Spacer(minLength:6)
            Text("v"+(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.3.0")).font(.system(size:9,design:.monospaced)).foregroundStyle(.tertiary).padding(.leading,18).padding(.bottom,10)
        }
    }
    private func sectionTitle(_ title:String)->some View {
        VStack(alignment:.leading,spacing:4){Text(title).font(.system(size:10)).foregroundStyle(.secondary);Divider()}
            .padding(.horizontal,12).padding(.top,5).padding(.bottom,3)
    }
    private func navigationRow(_ item:(String,String))->some View {
        Button{m.page=item.0}label:{
            HStack(spacing:7){Image(systemName:item.1).font(.system(size:12,weight:.regular)).frame(width:16);VStack(alignment:.leading,spacing:3){Text(pageLabel(item.0)).font(.system(size:11,weight:m.page==item.0 ? .semibold:.regular));if item.0=="版本管理"{Text(selectedTitle).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)}};Spacer()}
                .padding(.horizontal,8).frame(height:item.0=="版本管理" ? 34:25)
                .background{if m.page==item.0{NavigationGlassSelection()}}
                .contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.horizontal,6).accessibilityAddTraits(m.page==item.0 ? .isSelected:[])
    }
    private func pageLabel(_ page:String)->String {
        switch page {case "一键联机":return "联机";case "版本管理":return "游戏配置";case "资源下载":return "下载与整合包";case "启动设置":return "设置";case "关于 GCL":return "关于与更新";default:return page}
    }
    private var home:some View {
        VStack {
            Spacer(minLength:40)
            HStack(alignment:.bottom) {
                if m.busy {
                    HStack(spacing:8){ProgressView().controlSize(.mini);Text(m.status).font(.caption);Button("停止"){m.cancel()}}
                        .padding(10).modifier(LauncherGlassSurface(radius:4)).frame(maxWidth:280)
                }
                Spacer(minLength:12)
                launchControl
            }
        }.padding(.horizontal,14).padding(.bottom,14)
    }
    private var launchControl:some View {
        HStack(spacing:0) {
            Button{m.start()}label:{
                HStack(spacing:10){Image(systemName:m.busy ? "hourglass":"play.fill").font(.system(size:17));VStack(alignment:.leading,spacing:5){Text(m.busy ? "正在运行":"启动游戏").font(.system(size:15,weight:.semibold));Text(selectedTitle).font(.system(size:11)).lineLimit(1)}}
                    .frame(width:150,height:50).contentShape(Rectangle())
            }.buttonStyle(NavigationPressStyle()).disabled(m.busy)
            Divider().frame(height:40)
            Button{m.showVersionChooser.toggle()}label:{Image(systemName:"chevron.up").font(.system(size:15,weight:.semibold)).frame(width:30,height:50).contentShape(Rectangle())}
                .buttonStyle(NavigationPressStyle()).disabled(m.busy).help("选择版本与配置")
                .popover(isPresented:$m.showVersionChooser,arrowEdge:.bottom){
                    VStack(alignment:.leading,spacing:16){
                        Text("选择游戏").font(.headline)
                        Picker("配置",selection:$m.packID){Text("原版").tag("");ForEach(m.packs,id:\.self){pack in Text(pack["name"] ?? "游戏配置").tag(pack["id"] ?? "")}}
                        Picker("Minecraft",selection:$m.selected){ForEach(m.versions,id:\.self){Text($0)}}.disabled(!m.packID.isEmpty)
                        Divider()
                        Button("管理游戏配置…"){m.showVersionChooser=false;m.page="版本管理"}.buttonStyle(.borderless)
                        HStack{Spacer();Button("完成"){m.showVersionChooser=false}.keyboardShortcut(.defaultAction)}
                    }.padding(20).frame(width:280)
                }
        }.modifier(LauncherSplitGlass()).accessibilityElement(children:.contain)
    }
    private var statusLine:some View {
        HStack(spacing:8) {
            if m.busy {ProgressView().controlSize(.mini)}
            Text(m.status).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
            Spacer(minLength:8)
            if m.busy {Button("停止"){m.cancel()}.font(.caption)}
            else if m.page != "开始游戏" {Button("返回启动"){m.page="开始游戏"}.font(.caption)}
        }.padding(.horizontal,28).padding(.vertical,12).frame(minHeight:40)
    }
}
