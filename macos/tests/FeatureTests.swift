import Foundation
@main struct FeatureTests {
static func main() async throws {
 let root=URL(fileURLWithPath:"/private/tmp/glasscraft05-tests-"+UUID().uuidString),engine=Engine(root:root)
 defer{try? FileManager.default.removeItem(at:root)}
 let modern=try await engine.multiplayerArguments(version:"1.21.1",address:"localhost:25565");precondition(modern==["--quickPlayMultiplayer","localhost:25565"])
 let old=try await engine.multiplayerArguments(version:"1.19.4",address:"192.168.1.2:12345");precondition(old==["--server","192.168.1.2","--port","12345"])
 for input in ["host:99999","https://host","user@host","host/path","a b"] {var rejected=false;do{_=try await engine.multiplayerArguments(version:"1.21.1",address:input)}catch{rejected=true};precondition(rejected)}
 print("PASS: multiplayer addresses and launch arguments")
 let hits=try await engine.searchResources(query:"Sodium",type:"mod",game:"1.21.1");precondition(!hits.isEmpty)
 let versions=try await engine.resourceVersions(project:"customskinloader",game:"1.21.1",loader:"fabric");precondition(!versions.isEmpty)
 let png=URL(fileURLWithPath:"/private/tmp/glasscraft05-skin.png")
 let id=try await engine.installSkin(png,username:"GlassTest",game:"1.21.1",pack:nil){print($0)}
 let folder=try await engine.gameFolder(version:"1.21.1",packID:id)
 let copied=try Data(contentsOf:folder.appendingPathComponent("CustomSkinLoader/LocalSkin/skins/GlassTest.png"));let original=try Data(contentsOf:png);precondition(copied==original)
 let config=try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("CustomSkinLoader/CustomSkinLoader.json"))) as! [String:Any]
 precondition(((config["loadlist"] as! [[String:Any]]).first?["name"] as? String)=="GCL Local")
 print("PASS: live in-app search, Fabric profile, verified skin mod download, PNG copy and local priority config")
 let process=Process();process.executableURL=URL(fileURLWithPath:"/bin/sleep");process.arguments=["1"]
 let code=try await engine.execute(process);precondition(code==0)
 print("PASS: asynchronous process completion")
 let task=Task{try await engine.cancellationProbe()}
 try await Task.sleep(nanoseconds:150_000_000);await engine.stop()
 let cancelled=try await task.value;precondition(cancelled != 0)
 print("PASS: cancel terminates running process without blocking actor")
}}

extension Engine{func cancellationProbe() async throws -> Int32{let p=Process();p.executableURL=URL(fileURLWithPath:"/bin/sleep");p.arguments=["20"];running=p;defer{running=nil};return try await execute(p)}}
