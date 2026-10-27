import Foundation
@main struct LANOptionsTests {
 static func main() throws {
    var options=LANOptions(version:"1.21.1",owner:"Owner",admins:"Alice, Bob")
    do {_=try options.validated();fatalError("EULA must require explicit consent")}catch{}
    options.eula=true;_=try options.validated()
    precondition(options.operators == ["Alice","Bob","Owner"])
    precondition(options.properties(address:"192.168.1.2").contains("online-mode=true\n"))
    options.online=false
    precondition(options.properties(address:"192.168.1.2").contains("enforce-secure-profile=false\n"))
    options.admins="Alice\nstop"
    // Newlines are separators, but every token must still be a valid player name.
    options.admins="Alice;op"
    do {_=try options.validated();fatalError("Command injection accepted")}catch{}
    options.admins="";options.port=65536
    do {_=try options.validated();fatalError("Invalid port accepted")}catch{}
    precondition(VersionSupport.isSupported("1.7.10") && VersionSupport.isSupported("26.3"))
    precondition(!VersionSupport.isSupported("../../bad"))
    precondition(VersionSupport.offlineID("Notch")=="b50ad385829d3141a2167e7d7539ba7f")
    print("PASS: room consent, operators, online/offline properties, injection/port validation, old/new version support")
 }
}
