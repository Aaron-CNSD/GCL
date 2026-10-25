import Foundation
@main struct LoaderTest {static func main() async throws {
let e=Engine(root:URL(fileURLWithPath:"/private/tmp/glasscraft-loader-tests"))
for kind in ["Forge","NeoForge","Fabric","Quilt"] {
 let game=kind=="Forge" ? "1.20.1":"1.21.1"
 let list=try await e.loaderVersions(game:game,kind:kind);precondition(!list.isEmpty);print(kind,game,list.prefix(2))
}
let unsupported=try await e.loaderVersions(game:"1.20.1",kind:"NeoForge");precondition(unsupported.isEmpty)
let kind=CommandLine.arguments.count>1 ? CommandLine.arguments[1]:"Fabric"
let game=kind=="Forge" ? "1.20.1":"1.21.1"
let build=try await e.loaderVersions(game:game,kind:kind).first!
let profile=try await e.loaderProfile(game:game,kind:kind,build:build){print($0)}
precondition(profile["mainClass"] is String);precondition(!(profile["libraries"] as! [Any]).isEmpty)
print("PASS",kind,profile["id"] ?? "",profile["mainClass"] ?? "")
}}
