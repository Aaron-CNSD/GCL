import SwiftUI
import AVFoundation

struct LauncherBackdrop:View,Equatable {
    let path:String
    var playing=true
    static func ==(lhs:Self,rhs:Self)->Bool {lhs.path==rhs.path && lhs.playing==rhs.playing}
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.accessibilityReduceTransparency) private var reducedTransparency
    @AppStorage("backdropOpacity") private var opacity=1.0
    @AppStorage("backdropBlur") private var blur=0.0
    @AppStorage("backdropFit") private var fit="fill"
    @AppStorage("animateBuiltInBackground") private var animateBuiltIn=true
    private static let bundledVideo=Bundle.main.url(forResource:"DefaultBackground",withExtension:"mp4")
    private static let bundled=Bundle.main.url(forResource:"DefaultBackground",withExtension:"jpg").flatMap{NSImage(contentsOf:$0)}
    var body:some View {
        GeometryReader{geometry in
            ZStack {
                if reducedTransparency {Color(nsColor:.windowBackgroundColor)}else{WindowVibrancy()}
                if !path.isEmpty,FileManager.default.fileExists(atPath:path) {
                    Group {
                    if ["mp4","mov","m4v"].contains(URL(fileURLWithPath:path).pathExtension.lowercased()) {
                        LocalBackdropVideo(url:URL(fileURLWithPath:path),paused:!playing || phase != .active || reducedMotion,fill:fit=="fill")
                    }else if let image=BackdropImageCache.image(path) {
                        Image(nsImage:image).resizable().aspectRatio(contentMode:fit=="fit" ? .fit:.fill).frame(width:geometry.size.width,height:geometry.size.height)
                    }
                    }.blur(radius:blur).opacity(reducedTransparency ? 1:opacity)
                }else if animateBuiltIn,!reducedMotion,let video=Self.bundledVideo {
                    LocalBackdropVideo(url:video,paused:!playing || phase != .active,fill:fit=="fill").blur(radius:blur).opacity(reducedTransparency ? 1:opacity)
                }else if let image=Self.bundled {
                    Image(nsImage:image).resizable().aspectRatio(contentMode:fit=="fit" ? .fit:.fill).frame(width:geometry.size.width,height:geometry.size.height).blur(radius:blur).opacity(reducedTransparency ? 1:opacity)
                }
            }.frame(width:geometry.size.width,height:geometry.size.height).clipped()
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
private struct LocalBackdropVideo:NSViewRepresentable {
    let url:URL
    let paused:Bool
    let fill:Bool
    final class PlayerView:NSView {
        let videoLayer=AVPlayerLayer()
        var queue:AVQueuePlayer?
        var looper:AVPlayerLooper?
        var source:URL?
        var wasPaused:Bool?
        override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.addSublayer(videoLayer);videoLayer.videoGravity = .resizeAspectFill}
        required init?(coder:NSCoder){fatalError("init(coder:) is unavailable")}
        override func layout(){super.layout();CATransaction.begin();CATransaction.setDisableActions(true);videoLayer.frame=bounds;CATransaction.commit()}
        func load(_ url:URL){guard source != url else{return};wasPaused=nil;queue?.pause();looper?.disableLooping();source=url;let player=AVQueuePlayer();player.isMuted=true;looper=AVPlayerLooper(player:player,templateItem:AVPlayerItem(url:url));queue=player;videoLayer.player=player}
    }
    func makeNSView(context:Context)->PlayerView{PlayerView(frame:.zero)}
    func updateNSView(_ view:PlayerView,context:Context){view.load(url);view.videoLayer.videoGravity = fill ? .resizeAspectFill:.resizeAspect;if view.wasPaused != paused {view.wasPaused=paused;if paused{view.queue?.pause()}else{view.queue?.play()}}}
    static func dismantleNSView(_ view:PlayerView,coordinator:()){view.queue?.pause();view.looper?.disableLooping();view.videoLayer.player=nil}
}

private enum BackdropImageCache {
    private static let cache=NSCache<NSString,NSImage>()
    static func image(_ path:String)->NSImage? {
        if let image=cache.object(forKey:path as NSString){return image}
        guard let image=NSImage(contentsOfFile:path) else{return nil}
        cache.countLimit=3;cache.setObject(image,forKey:path as NSString);return image
    }
}
