import Foundation
@main struct VersionTests {
 static func main(){
  for version in ["1.7.10","1.8.9","1.12.2","1.16.5","1.20.1","1.21.11","26.3","26.1.2"]{precondition(VersionSupport.isSupported(version))}
  for version in ["1.6.4","../../bad","1.20-pre1"]{precondition(!VersionSupport.isSupported(version))}
  precondition(VersionSupport.fallbackJava("26.3")==25)
  precondition(VersionSupport.fallbackJava("1.7.10")==8 && VersionSupport.fallbackJava("1.12.2")==8 && VersionSupport.fallbackJava("1.18.2")==17)
  precondition(VersionSupport.legacyArguments("--name \"One World\" --user ${auth_player_name}")==["--name","One World","--user","${auth_player_name}"])
  precondition(VersionSupport.offlineID("Notch")=="b50ad385829d3141a2167e7d7539ba7f")
  print("PASS: legacy version range, Java fallback, quoted arguments and offline UUID compatibility")
 }
}
