import AppKit
import CryptoKit

/// Reads only Mojang panorama assets already cached by a launcher on this Mac.
/// Game textures are neither copied into the project nor redistributed in the app.
enum CachedMinecraftPanorama {
    static func image()->NSImage? {
        let support=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        let roots=[support.appendingPathComponent("minecraft/assets"),support.appendingPathComponent("GlassCraft/assets")]
        // Prefer the daylight mangrove panorama, then the cherry-grove sunset.
        let preferred=["e956e0986b597ec1b7d1db720dc8aec3a0642630","f228a4964175f885b334033c5e5cf12bf62421d0"]
        for hash in preferred {for root in roots {if let image=read(hash:hash,root:root){return image}}}
        for root in roots {
            let directory=root.appendingPathComponent("indexes")
            let indexes=(try? FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? []
            for index in indexes.filter({$0.pathExtension == "json"}).prefix(12) {
                guard let size=try? index.resourceValues(forKeys:[.fileSizeKey]).fileSize,size<8*1024*1024,
                      let data=try? Data(contentsOf:index),let object=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
                      let objects=object["objects"] as? [String:[String:Any]],
                      let hash=objects["minecraft/textures/gui/title/background/panorama_0.png"]?["hash"] as? String else{continue}
                if let image=read(hash:hash,root:root){return image}
            }
        }
        return nil
    }
    private static func read(hash:String,root:URL)->NSImage? {
        guard hash.count==40,hash.allSatisfy({$0.isHexDigit}) else{return nil}
        let file=root.appendingPathComponent("objects/\(hash.prefix(2))/\(hash)")
        guard let size=try? file.resourceValues(forKeys:[.fileSizeKey]).fileSize,size>1024,size<8*1024*1024,
              let data=try? Data(contentsOf:file),Insecure.SHA1.hash(data:data).map({String(format:"%02x",$0)}).joined()==hash,
              let image=NSImage(data:data),image.size.width>=512,image.size.height>=512 else{return nil}
        return image
    }
}
