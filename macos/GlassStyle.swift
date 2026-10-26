import SwiftUI

// Apple platforms use system-provided materials and controls, without simulated rims or gradients.
struct GCLIcon:View {
    let symbol:String
    var size:CGFloat=28
    var color:Color = .accentColor
    var body:some View{Image(systemName:symbol).font(.system(size:size*0.62,weight:.regular)).symbolRenderingMode(.hierarchical).foregroundStyle(color).frame(width:size,height:size).accessibilityHidden(true)}
}
struct GameTile:View {
    var size:CGFloat=50
    var body:some View{Image(nsImage:NSApplication.shared.applicationIconImage).resizable().interpolation(.high).frame(width:size,height:size).accessibilityLabel("GCL 游戏图标")}
}
struct AppleButtons:ViewModifier {
    @ViewBuilder func body(content:Content)->some View{if #available(macOS 26.0,*){content.buttonStyle(.glass)}else{content.buttonStyle(.bordered)}}
}
struct ApplePrimaryButton:ViewModifier {
    @ViewBuilder func body(content:Content)->some View{if #available(macOS 26.0,*){content.buttonStyle(.glassProminent)}else{content.buttonStyle(.borderedProminent)}}
}
