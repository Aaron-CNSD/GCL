package dev.aarongame.gcl;
import com.google.gson.*;
import java.nio.file.*;
import java.util.*;
import java.util.zip.*;
public class CoreTests {
 interface Throwing {void run()throws Exception;}
 static void rejects(Throwing test)throws Exception{try{test.run();}catch(Exception expected){return;}throw new AssertionError("Expected rejection");}
 static void verify(boolean value){if(!value)throw new AssertionError();}
 public static void main(String[] args)throws Exception{
  verify(Core.supported("26.3")&&Core.supported("26.1.2")&&!Core.supported("26.4-snapshot-5"));
  var win=Core.Platform.of("Windows 11","amd64");var linux=Core.Platform.of("Linux","amd64");var arm=Core.Platform.of("Mac OS X","aarch64");verify(win.os().equals("windows")&&win.separator().equals(";"));verify(linux.separator().equals(":"));verify(arm.javaOS().equals("mac")&&arm.arch().equals("aarch64"));
  JsonObject rule=JsonParser.parseString("{\"rules\":[{\"action\":\"allow\"},{\"action\":\"disallow\",\"os\":{\"name\":\"windows\"}}]}").getAsJsonObject();verify(!Core.allowed(rule,win,"11")&&Core.allowed(rule,linux,"6.8"));
  JsonObject features=JsonParser.parseString("{\"rules\":[{\"action\":\"allow\",\"features\":{\"has_custom_resolution\":true}}]}").getAsJsonObject();verify(!Core.allowed(features,win,"11"));
  Map<String,String> vars=Map.of("classpath","C:\\Game Files\\libs;a.jar","auth_player_name","Test");List<String> argv=Core.arguments(JsonParser.parseString("[\"-cp\",\"${classpath}\"]").getAsJsonArray(),vars,win,"11");verify(argv.size()==2&&argv.get(1).equals(vars.get("classpath")));verify(Core.legacyArguments("--username ${auth_player_name} --name \"One World\"",vars).equals(List.of("--username","Test","--name","One World")));rejects(()->Core.expand("${missing}",vars));verify(Core.offlineUUID("Notch").equals("b50ad385829d3141a2167e7d7539ba7f"));
  Path temp=Files.createTempDirectory("gcl-desktop-test");Core core=new Core(temp,win);Core.Instance first=core.create("A","1.7.10","原版",""),second=core.create("B","1.12.2","原版","");verify(!core.gameDir(first).equals(core.gameDir(second))&&core.instances().size()==2);rejects(()->core.create("bad","../../x","原版",""));rejects(()->Core.safe(temp,"../escape"));rejects(()->Core.safe(temp,"C:/x"));rejects(()->Core.safe(temp,"nested\\x"));
  Path mod=core.gameDir(first).resolve("mods/test.jar");Files.createDirectories(mod.getParent());Files.writeString(mod,"mod bytes");core.toggle(first,mod);Path disabled=mod.resolveSibling("test.jar.disabled");verify(Files.readString(disabled).equals("mod bytes"));core.toggle(first,disabled);verify(Files.exists(mod));
  Path zip=temp.resolve("evil.zip");try(var z=new ZipOutputStream(Files.newOutputStream(zip))){z.putNextEntry(new ZipEntry("../escape.txt"));z.write("bad".getBytes());z.closeEntry();}rejects(()->Core.extract(zip,temp.resolve("unpack"),1024));verify(!Files.exists(temp.resolve("escape.txt")));
  Path logs=temp.resolve("logs/latest.log");Files.createDirectories(logs.getParent());Files.writeString(logs,"a".repeat(80000));verify(core.logTail().length()==65536);
  if(args.length>0&&args[0].equals("--network")){List<String> versions=core.versions();verify(versions.contains("1.7.10")&&versions.contains("1.12.2")&&versions.contains("1.20.1"));for(String v:List.of("1.7.10","1.12.2","1.20.1","26.3")){JsonObject meta=core.metadata(v);verify(meta.has("downloads")&&meta.has("mainClass"));System.out.println("Metadata verified: "+v);}verify(!core.loaders("1.20.1","Fabric").isEmpty());}
  try(var walk=Files.walk(temp)){for(Path p:walk.sorted(Comparator.reverseOrder()).toList())Files.delete(p);}System.out.println("PASS: platform rules, Windows argv paths, legacy quotes, offline UUID, isolated instances, mod preservation, ZIP traversal and log cap");
 }
}
