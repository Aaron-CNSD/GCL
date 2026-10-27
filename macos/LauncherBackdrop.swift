import SwiftUI
import AVFoundation

struct LauncherBackdrop:View {
    let path:String
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body:some View {
        GeometryReader{geometry in
            ZStack {
                Color(nsColor:.windowBackgroundColor)
                if !path.isEmpty,FileManager.default.fileExists(atPath:path) {
                    if ["mp4","mov","m4v"].contains(URL(fileURLWithPath:path).pathExtension.lowercased()) {
                        LocalBackdropVideo(url:URL(fileURLWithPath:path),paused:phase != .active || reducedMotion)
                    }else if let image=NSImage(contentsOfFile:path) {
                        Image(nsImage:image).resizable().scaledToFill().frame(width:geometry.size.width,height:geometry.size.height)
                    }
                }
            }.frame(width:geometry.size.width,height:geometry.size.height).clipped()
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
private struct LocalBackdropVideo:NSViewRepresentable {
    let url:URL
    let paused:Bool
    final class PlayerView:NSView {
        let videoLayer=AVPlayerLayer()
        var queue:AVQueuePlayer?
        var looper:AVPlayerLooper?
        var source:URL?
        override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.addSublayer(videoLayer);videoLayer.videoGravity = .resizeAspectFill}
        required init?(coder:NSCoder){fatalError("init(coder:) is unavailable")}
        override func layout(){super.layout();videoLayer.frame=bounds}
        func load(_ url:URL){guard source != url else{return};queue?.pause();looper?.disableLooping();source=url;let player=AVQueuePlayer();player.isMuted=true;looper=AVPlayerLooper(player:player,templateItem:AVPlayerItem(url:url));queue=player;videoLayer.player=player}
    }
    func makeNSView(context:Context)->PlayerView{PlayerView(frame:.zero)}
    func updateNSView(_ view:PlayerView,context:Context){view.load(url);if paused{view.queue?.pause()}else{view.queue?.play()}}
    static func dismantleNSView(_ view:PlayerView,coordinator:()){view.queue?.pause();view.looper?.disableLooping();view.videoLayer.player=nil}
}
