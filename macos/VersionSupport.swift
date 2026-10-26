import Foundation
import CryptoKit

enum VersionSupport {
    static func isSupported(_ id:String)->Bool{guard id.range(of:#"^[0-9]+\.[0-9]+(\.[0-9]+)?$"#,options:.regularExpression) != nil else{return false};let parts=id.split(separator:".").compactMap{Int($0)};return parts.count>=2 && ((parts[0]==1 && parts[1]>=7) || parts[0]>=26)}
    static func fallbackJava(_ version:String)->Int{let parts=version.split(separator:".").compactMap{Int($0)};if let first=parts.first,first>=26{return 25};return parts.count>1 && parts[1]<17 ? 8:17}
    static func legacyArguments(_ text:String)->[String]{guard let pattern=try? NSRegularExpression(pattern:#""([^"]*)"|(\S+)"#) else{return []};return pattern.matches(in:text,range:NSRange(text.startIndex...,in:text)).compactMap{match in for index in [1,2]{if let range=Range(match.range(at:index),in:text){return String(text[range])}};return nil}}
    static func offlineID(_ username:String)->String{var bytes=Array(Insecure.MD5.hash(data:Data("OfflinePlayer:\(username)".utf8)));bytes[6]=(bytes[6]&0x0f)|0x30;bytes[8]=(bytes[8]&0x3f)|0x80;return bytes.map{String(format:"%02x",$0)}.joined()}
}
