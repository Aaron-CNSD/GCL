import Foundation
@main struct PackTest {
static func main() async throws {
let root=URL(fileURLWithPath:"/private/tmp/glasscraft-pack-test-"+UUID().uuidString)
let e=Engine(root:root)
let source=URL(fileURLWithPath:"/private/tmp/glasscraft-pack-fixtures")
for file in ["traversal.mrpack","symlink.mrpack","forge.mrpack","hash-fail.mrpack"] {
 var failed=false
 do{_ = try await e.importPack(source.appendingPathComponent(file)){_ in }}catch{failed=true;print("Rejected",file,error.localizedDescription)}
 precondition(failed)
 let packs=try await e.packList();precondition(packs.isEmpty)
}
let id=try await e.importPack(source.appendingPathComponent("good.mrpack")){print($0)}
let packs=try await e.packList();precondition(packs.count==1 && packs[0]["id"]==id)
let game=try await e.gameFolder(version:"1.21.1",packID:id)
let config=try String(contentsOf:game.appendingPathComponent("config/check.txt"),encoding:.utf8);precondition(config=="client")
precondition(FileManager.default.fileExists(atPath:game.appendingPathComponent("mods/fabric-api.jar").path))
precondition(!FileManager.default.fileExists(atPath:game.appendingPathComponent("mods/optional.jar").path))
let record=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("packs/\(id).json"))) as! [String:Any]
let profile=record["loaderProfile"] as! [String:Any];precondition((profile["mainClass"] as? String)?.contains("fabricmc")==true)
for lib in profile["libraries"] as! [[String:Any]] {
 let c=(lib["name"] as! String).split(separator:":").map(String.init)
 let path=c[0].replacingOccurrences(of:".",with:"/")+"/"+c[1]+"/"+c[2]+"/"+c[1]+"-"+c[2]+".jar"
 let base=lib["url"] as? String ?? "https://libraries.minecraft.net/"
 let data=try await e.fetch(base+(base.hasSuffix("/") ? "":"/")+path);precondition(data.starts(with:[0x50,0x4b]))
}
print("PASS: real mod + loader libraries, SHA verification, profile persistence, isolated instance, override priority, optional skip, rejection and rollback")
try FileManager.default.removeItem(at:root)
}}
