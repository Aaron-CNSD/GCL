import SwiftUI

struct LauncherMark:View {
    var size:CGFloat=32
    private static let mark:NSImage = Bundle.main.url(forResource:"GCLIcon",withExtension:"png").flatMap{NSImage(contentsOf:$0)} ?? NSApplication.shared.applicationIconImage ?? NSImage(size:NSSize(width:64,height:64))
    var body:some View {Image(nsImage:Self.mark).resizable().interpolation(.high).scaledToFit().frame(width:size,height:size).accessibilityLabel("GCL 工作台图标")}
}

struct SidebarMaterial:ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduced
    @ViewBuilder func body(content:Content)->some View {
        if reduced {content.background(Color(nsColor:.controlBackgroundColor))}
        else if #available(macOS 26.0,*) {content.glassEffect(.regular,in:Rectangle())}
        else {content.background(.ultraThinMaterial)}
    }
}

extension LauncherView {
    private var pageTransition:AnyTransition {reduceMotion ? .identity:.opacity.combined(with:.offset(y:5))}
    private var selectedTitle:String {m.packs.first(where:{$0["id"]==m.packID})?["name"] ?? "Minecraft \(m.selected)"}
    var body:some View {
        HStack(spacing:0) {
            navigation.frame(width:224).modifier(SidebarMaterial())
            VStack(alignment:.leading,spacing:0) {
                HStack(alignment:.center) {
                    VStack(alignment:.leading,spacing:4) {
                        Text(m.page).font(.system(size:22,weight:.semibold))
                        Text(m.page == "开始游戏" ? "Minecraft: Java Edition":"当前配置 · \(selectedTitle)").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("选择背景图片或视频…"){m.chooseBackdrop()}
                        if !m.backdropPath.isEmpty {Button("恢复默认背景"){m.resetBackdrop()}}
                    } label:{Image(systemName:"photo").frame(width:22,height:22)}.menuStyle(.borderlessButton).fixedSize().help("更换背景")
                }.padding(.horizontal,28).padding(.top,24).padding(.bottom,20)
                ZStack(alignment:.topLeading) {
                if m.page == "开始游戏" {
                    home.frame(maxWidth:.infinity,maxHeight:.infinity).transition(pageTransition)
                } else {
                    ScrollView {
                        VStack(spacing:16) {
                            switch m.page {
                            case "版本管理":configuration;instances;play
                            case "模组管理":modManager
                            case "资源下载":resources
                            case "一键联机":multiplayer
                            case "我的皮肤":skin
                            case "任务与日志":diagnostics
                            case "启动设置":launchSettings
                            case "关于 GCL":about
                            default:EmptyView()
                            }
                        }.frame(maxWidth:900).frame(maxWidth:.infinity).padding(.horizontal,24).padding(.bottom,16)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity).id(m.page).transition(pageTransition)
                }
                }.animation(reduceMotion ? nil:.easeInOut(duration:0.22),value:m.page)
                statusLine
            }
        }
        .frame(minWidth:980,minHeight:680)
        .background{LauncherBackdrop(path:m.backdropPath)}
        .tint(Color(red:0.35,green:0.40,blue:0.70))
        .accentColor(Color(red:0.35,green:0.40,blue:0.70))
        .onAppear{if !m.demoMode {m.refresh()};m.loadWorkspace();if m.demoMode{DispatchQueue.main.asyncAfter(deadline:.now()+0.3){NSApp.activate(ignoringOtherApps:true);NSApp.windows.first?.makeKeyAndOrderFront(nil)}}}
        .onChange(of:m.selected){_ in m.resetResources();m.loadVersions();m.loadPreferences();m.refreshMods()}
        .onChange(of:m.packID){id in m.resetResources();m.loadPreferences();m.refreshMods();if let pack=m.packs.first(where:{$0["id"]==id}){m.selected=pack["minecraft"] ?? m.selected}}
        .onChange(of:m.appearance){UserDefaults.standard.set($0,forKey:"appearance")}
        .onChange(of:m.page){if $0 == "模组管理"{m.refreshMods()}}
        .preferredColorScheme(m.appearance == "dark" ? .dark:m.appearance == "light" ? .light:nil)
    }

    private var navigation:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:10) {
                LauncherMark(size:34)
                VStack(alignment:.leading,spacing:2){Text("GCL").font(.system(size:19,weight:.semibold));Text("GlassCraft Launcher").font(.system(size:10)).foregroundStyle(.secondary)}
            }.padding(.horizontal,18).padding(.top,22).padding(.bottom,20)
            VStack(alignment:.leading,spacing:8) {
                Text("本地玩家").font(.caption).foregroundStyle(.secondary)
                HStack(spacing:9){Image(systemName:"keyboard").foregroundStyle(.secondary);TextField("玩家名称",text:$m.name).textFieldStyle(.plain).font(.system(size:14,weight:.medium))}.padding(.vertical,4)
            }.padding(.horizontal,22).padding(.bottom,18)
            Divider().padding(.horizontal,18)
            sectionTitle("游戏")
            ForEach(Array(pages.prefix(4)),id:\.0){item in navigationRow(item)}
            sectionTitle("一起游玩")
            ForEach(Array(pages[4...5]),id:\.0){item in navigationRow(item)}
            Spacer(minLength:16)
            Divider().padding(.horizontal,18).padding(.bottom,8)
            ForEach(Array(pages.suffix(3)),id:\.0){item in navigationRow(item)}
            Text("v0.2.0").font(.system(size:10,design:.monospaced)).foregroundStyle(.tertiary).padding(.leading,24).padding(.top,12).padding(.bottom,14)
        }
    }
    private func sectionTitle(_ title:String)->some View {Text(title).font(.system(size:10,weight:.medium)).foregroundStyle(.secondary).padding(.horizontal,24).padding(.top,16).padding(.bottom,7)}
    private func navigationRow(_ item:(String,String))->some View {
        Button{withAnimation(reduceMotion ? nil:.spring(response:0.32,dampingFraction:0.88)){m.page=item.0}}label:{
            HStack(spacing:12){Image(systemName:item.1).font(.system(size:15,weight:.regular)).frame(width:20);Text(item.0).font(.system(size:13,weight:m.page==item.0 ? .semibold:.regular));Spacer()}
                .padding(.horizontal,12).frame(height:36)
                .background{if m.page==item.0{NavigationGlassSelection().matchedGeometryEffect(id:"navigation-selection",in:navigationSelection)}}
                .contentShape(Rectangle())
        }.buttonStyle(NavigationPressStyle()).padding(.horizontal,10).accessibilityAddTraits(m.page==item.0 ? .isSelected:[])
    }
    private var home:some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:12) {
                Image(systemName:"square.stack.3d.up").font(.system(size:23,weight:.light)).foregroundStyle(.secondary)
                VStack(alignment:.leading,spacing:3){Text(selectedTitle).font(.system(size:15,weight:.medium)).lineLimit(1);Text(m.packID.isEmpty ? "原版 · 独立游戏目录":"独立配置 · 模组与设置隔离").font(.caption).foregroundStyle(.secondary)}
                Spacer()
                Button("管理版本"){m.page="版本管理"}.buttonStyle(.borderless).font(.caption)
            }.padding(16).modifier(LauncherGlassSurface()).frame(maxWidth:410)
            Spacer(minLength:100)
            HStack(alignment:.bottom,spacing:20) {
                VStack(alignment:.leading,spacing:12) {
                    Button{m.importModpack()}label:{Label("导入整合包",systemImage:"shippingbox")}
                    Button{m.openFolder()}label:{Label("打开游戏目录",systemImage:"folder")}
                }.font(.caption).modifier(LauncherGlassButton()).disabled(m.busy)
                Spacer(minLength:0)
                launchControl
            }
        }.padding(.horizontal,28).padding(.top,4).padding(.bottom,28)
    }
    private var launchControl:some View {
        LauncherGlassGroup {HStack(spacing:8) {
            Button{m.start()}label:{
                HStack(spacing:14){Image(systemName:m.busy ? "hourglass":"play.fill").font(.system(size:19));VStack(alignment:.leading,spacing:5){Text(m.busy ? "正在运行":"启动游戏").font(.system(size:20,weight:.medium));Text(selectedTitle).font(.system(size:11)).lineLimit(1)}}
                    .frame(width:180,height:58).contentShape(Rectangle())
            }.modifier(LauncherGlassButton(prominent:true)).disabled(m.busy)
            Button{m.showVersionChooser.toggle()}label:{Image(systemName:"chevron.up").font(.system(size:12,weight:.semibold)).frame(width:26,height:58).contentShape(Rectangle())}
                .modifier(LauncherGlassButton()).disabled(m.busy).help("选择版本与配置")
                .popover(isPresented:$m.showVersionChooser,arrowEdge:.bottom){
                    VStack(alignment:.leading,spacing:16){
                        Text("选择游戏").font(.headline)
                        Picker("配置",selection:$m.packID){Text("原版").tag("");ForEach(m.packs,id:\.self){pack in Text(pack["name"] ?? "游戏配置").tag(pack["id"] ?? "")}}
                        Picker("Minecraft",selection:$m.selected){ForEach(m.versions,id:\.self){Text($0)}}.disabled(!m.packID.isEmpty)
                        Divider()
                        Button("管理版本与加载器…"){m.showVersionChooser=false;m.page="版本管理"}.buttonStyle(.borderless)
                        HStack{Spacer();Button("完成"){m.showVersionChooser=false}.keyboardShortcut(.defaultAction)}
                    }.padding(20).frame(width:280)
                }
        }}.accessibilityElement(children:.contain)
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
