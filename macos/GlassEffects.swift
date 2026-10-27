import SwiftUI

struct LauncherGlassSurface:ViewModifier {
    var radius:CGFloat=6
    var interactive=false
    @Environment(\.accessibilityReduceTransparency) private var reduced
    @AppStorage("clearGlass") private var clear=false
    @ViewBuilder func body(content:Content)->some View {
        if reduced {content.background(Color(nsColor:.controlBackgroundColor),in:RoundedRectangle(cornerRadius:radius))}
        else if #available(macOS 26.0,*) {
            content.glassEffect(clear ? .clear.interactive(interactive):.regular.interactive(interactive),in:RoundedRectangle(cornerRadius:radius))
        }else {content.background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:radius))}
    }
}

struct LauncherGlassButton:ViewModifier {
    var prominent=false
    var capsule=false
    @ViewBuilder func body(content:Content)->some View {
        if #available(macOS 26.0,*) {
            if prominent {content.buttonStyle(.glassProminent).buttonBorderShape(capsule ? .capsule:.roundedRectangle(radius:6))}
            else {content.buttonStyle(.glass).buttonBorderShape(capsule ? .capsule:.roundedRectangle(radius:6))}
        }else {
            if prominent {content.buttonStyle(.borderedProminent)}
            else {content.buttonStyle(.bordered)}
        }
    }
}

struct LauncherGlassGroup<Content:View>:View {
    let content:Content
    init(@ViewBuilder content:()->Content){self.content=content()}
    @ViewBuilder var body:some View {
        if #available(macOS 26.0,*) {GlassEffectContainer(spacing:10){content}}
        else {content}
    }
}

/// System vibrancy samples the desktop behind this window, without screen capture.
struct WindowVibrancy:NSViewRepresentable {
    final class BackgroundView:NSVisualEffectView {
        override func viewDidMoveToWindow(){super.viewDidMoveToWindow();window?.isOpaque=false;window?.backgroundColor = .clear;window?.titlebarAppearsTransparent=true}
    }
    func makeNSView(context:Context)->BackgroundView {
        let view=BackgroundView();view.material = .underWindowBackground;view.blendingMode = .behindWindow;view.state = .active;return view
    }
    func updateNSView(_ view:BackgroundView,context:Context) {
        view.appearance=NSAppearance(named:context.environment.colorScheme == .dark ? .darkAqua:.aqua)
    }
}

struct NavigationGlassSelection:View {
    @Environment(\.accessibilityReduceTransparency) private var reduced
    var body:some View {
        if reduced {RoundedRectangle(cornerRadius:4).fill(Color.accentColor.opacity(0.18))}
        else if #available(macOS 26.0,*) {RoundedRectangle(cornerRadius:4).fill(Color.accentColor.opacity(0.06)).glassEffect(.regular.tint(Color.accentColor.opacity(0.12)),in:RoundedRectangle(cornerRadius:4))}
        else {RoundedRectangle(cornerRadius:4).fill(.thinMaterial)}
    }
}

struct NavigationPressStyle:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduced
    func makeBody(configuration:Configuration)->some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduced ? 0.985:1)
            .animation(reduced ? nil:.easeOut(duration:0.12),value:configuration.isPressed)
    }
}

/// A restrained, joined launch control matching the reference layout.
struct LauncherSplitGlass:ViewModifier {
    func body(content:Content)->some View {
        content.background(Color(red:0.35,green:0.43,blue:0.77),in:RoundedRectangle(cornerRadius:6)).foregroundStyle(.white)
    }
}
