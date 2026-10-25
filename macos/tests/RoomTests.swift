import Foundation
@main struct RoomTests {
 @MainActor static func main() async throws {
    let root=URL(fileURLWithPath:"/private/tmp/glasscraft-room-tests-"+UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:root)}
    let room=RoomEngine(root:root,installCheck:root.appendingPathComponent("uninstalled.app"))
    let folder=root.appendingPathComponent("multiplayer/Terracotta-0.4.2-"+RoomEngine.architecture)
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    try FileManager.default.copyItem(at:URL(fileURLWithPath:ProcessInfo.processInfo.environment["GCL_TERRACOTTA_ARCHIVE"] ?? "/private/tmp/terracotta-macos-arm64.tar.gz"),to:folder.appendingPathComponent("official.tar.gz"))
    let pkg=try await room.prepare();precondition(FileManager.default.fileExists(atPath:pkg.path));precondition(FileManager.default.isExecutableFile(atPath:pkg.deletingPathExtension().path))
    var denied=false;do{try await room.connect()}catch{denied=true};precondition(denied)
    let port=Int(CommandLine.arguments[1])!;try await room.attach(port:port)
    let meta=try await room.request("/meta");precondition(meta["version"] as? String=="v0.4.2")
    try await room.create(player:"Test Player");try await room.join(code:"U/TEST-TEST-TEST-TEST",player:"Guest");try await room.leave()
    let model=RoomModel();model.apply(["state":"host-ok","room":"U/TEST-TEST-TEST-TEST","profiles":[["name":"Host"]]])
    precondition(model.invitation=="U/TEST-TEST-TEST-TEST" && model.members==["Host"])
    model.apply(["state":"guest-ok","url":"127.0.0.1:25566"]);precondition(model.address=="127.0.0.1:25566")
    model.apply(["state":"waiting"]);precondition(model.address.isEmpty && model.invitation.isEmpty)
    print("PASS: official archive SHA-256, extraction, installer prerequisite, loopback API, room actions, encoding and UI state transitions")
 }
}
