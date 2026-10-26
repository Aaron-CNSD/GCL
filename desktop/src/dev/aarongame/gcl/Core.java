package dev.aarongame.gcl;

import com.google.gson.*;
import java.io.*;
import java.net.*;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.*;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Consumer;
import java.util.regex.Pattern;
import java.util.zip.*;

public final class Core {
    public static final String VERSION="0.3.0";
    public record Platform(String os,String arch) {
        public static Platform detect(){return of(System.getProperty("os.name"),System.getProperty("os.arch"));}
        public static Platform of(String os,String arch){String o=os.toLowerCase(Locale.ROOT);return new Platform(o.contains("win")?"windows":o.contains("mac")?"osx":"linux",Set.of("aarch64","arm64").contains(arch)?"aarch64":"x64");}
        public String javaOS(){return os.equals("osx")?"mac":os;}
        public String separator(){return os.equals("windows")?";":":";}
    }
    public record Instance(String id,String name,String game,String loader,String build) {public String toString(){return name+" · "+game+" · "+loader;}}
    public final Path root;
    public final Platform platform;
    private final HttpClient http=HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NORMAL).connectTimeout(Duration.ofSeconds(30)).build();
    public volatile Process process;
    public Core(Path root,Platform platform)throws IOException{this.root=root.toAbsolutePath().normalize();this.platform=platform;Files.createDirectories(root);}
    public static Path defaultRoot(){String app=System.getenv("APPDATA"),xdg=System.getenv("XDG_DATA_HOME"),home=System.getProperty("user.home");return switch(Platform.detect().os){case "windows"->Path.of(app==null?home:app,"GCL");case "osx"->Path.of(home,"Library","Application Support","GCL-Desktop");default->Path.of(xdg==null?home+"/.local/share":xdg,"gcl");};}
    public static JsonObject obj(JsonElement e){return e!=null&&e.isJsonObject()?e.getAsJsonObject():new JsonObject();}
    public static JsonArray arr(JsonObject o,String key){return o.has(key)&&o.get(key).isJsonArray()?o.getAsJsonArray(key):new JsonArray();}
    public static String str(JsonObject o,String key,String fallback){return o.has(key)&&!o.get(key).isJsonNull()?o.get(key).getAsString():fallback;}
    public static int number(JsonObject o,String key,int fallback){return o.has(key)?o.get(key).getAsInt():fallback;}
    public static void check()throws InterruptedException{if(Thread.currentThread().isInterrupted())throw new InterruptedException("已取消");}
    public static Path safe(Path base,String name)throws IOException{
        if(name.isBlank()||name.contains("\\")||name.contains(":")||name.startsWith("/")||name.indexOf(0)>=0||Arrays.asList(name.split("/",-1)).contains(".."))throw new IOException("不安全的文件路径");
        Path normalizedBase=base.toAbsolutePath().normalize(),target=normalizedBase.resolve(name).normalize();
        if(!target.startsWith(normalizedBase)||target.equals(normalizedBase))throw new IOException("文件路径越界");
        for(Path p=target;p!=null&&p.startsWith(normalizedBase);p=p.getParent())if(Files.isSymbolicLink(p))throw new IOException("不允许通过符号链接写入");
        return target;
    }
    public JsonElement json(String url)throws Exception{return JsonParser.parseString(new String(bytes(url),StandardCharsets.UTF_8));}
    public byte[] bytes(String url)throws Exception{check();URI uri=URI.create(url);if(!"https".equals(uri.getScheme()))throw new IOException("只允许 HTTPS 下载");var request=HttpRequest.newBuilder(uri).timeout(Duration.ofMinutes(4)).header("User-Agent","GCL/"+VERSION+" (Aaron-CNSD/GCL)").build();var response=http.send(request,HttpResponse.BodyHandlers.ofByteArray());if(response.statusCode()/100!=2)throw new IOException("HTTP "+response.statusCode()+" · "+uri.getHost());return response.body();}
    public static String hash(byte[] bytes,String algorithm)throws Exception{return HexFormat.of().formatHex(MessageDigest.getInstance(algorithm).digest(bytes));}
    public void download(String url,Path dest,String digest,String algorithm)throws Exception{
        check();if(Files.isRegularFile(dest)&&digest!=null&&hash(Files.readAllBytes(dest),algorithm).equalsIgnoreCase(digest))return;
        if(digest==null&&Files.isRegularFile(dest)&&Files.size(dest)>0)return;
        byte[] data=bytes(url);if(digest!=null&&!hash(data,algorithm).equalsIgnoreCase(digest))throw new IOException("文件校验失败："+dest.getFileName());
        Files.createDirectories(dest.getParent());Path temp=dest.resolveSibling(dest.getFileName()+"."+UUID.randomUUID()+".part");
        try{Files.write(temp,data);Files.move(temp,dest,StandardCopyOption.REPLACE_EXISTING);}finally{Files.deleteIfExists(temp);}
    }
    private void artifact(JsonObject a,Path target)throws Exception{download(str(a,"url",""),target,str(a,"sha1",null),"SHA-1");}
    public List<String> versions()throws Exception{List<String> result=new ArrayList<>();for(JsonElement e:arr(obj(json("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")),"versions")){JsonObject v=obj(e);String id=str(v,"id","");if(str(v,"type","").equals("release")&&supported(id))result.add(id);}return result;}
    public JsonObject metadata(String version)throws Exception{
        validateVersion(version);Path dest=root.resolve("versions/"+version+"/"+version+".json");
        if(Files.exists(dest))return obj(JsonParser.parseString(Files.readString(dest)));
        for(JsonElement e:arr(obj(json("https://piston-meta.mojang.com/mc/game/version_manifest_v2.json")),"versions")){JsonObject v=obj(e);if(version.equals(str(v,"id",""))){artifact(v,dest);return obj(JsonParser.parseString(Files.readString(dest)));}}
        throw new IOException("找不到 Minecraft 版本");
    }
    public static boolean supported(String v){if(!v.matches("[0-9]+\\.[0-9]+(\\.[0-9]+)?"))return false;String[] parts=v.split("\\.");int first=Integer.parseInt(parts[0]),minor=Integer.parseInt(parts[1]);return first==1&&minor>=7||first>=26;}
    public static void validateVersion(String v)throws IOException{if(!supported(v))throw new IOException("不支持此版本编号");}
    public List<Instance> instances()throws IOException{Path dir=root.resolve("profiles");Files.createDirectories(dir);List<Instance> result=new ArrayList<>();try(var stream=Files.list(dir)){for(Path p:stream.filter(p->p.toString().endsWith(".json")).toList()){JsonObject j=obj(JsonParser.parseString(Files.readString(p)));String id=str(j,"id","");UUID.fromString(id);result.add(new Instance(id,str(j,"name","未命名"),str(j,"game",""),str(j,"loader","原版"),str(j,"build","")));}}return result;}
    public Instance create(String name,String game,String loader,String build)throws Exception{validateVersion(game);if(name.isBlank()||name.length()>64)throw new IOException("配置名需要 1–64 个字符");if(!Set.of("原版","Fabric","Quilt").contains(loader))throw new IOException("桌面版当前支持原版、Fabric、Quilt");if(!loader.equals("原版")&&!build.matches("[A-Za-z0-9._+\\-]+"))throw new IOException("请选择加载器版本");Instance i=new Instance(UUID.randomUUID().toString(),name,game,loader,build);JsonObject j=new JsonObject();j.addProperty("id",i.id);j.addProperty("name",i.name);j.addProperty("game",i.game);j.addProperty("loader",i.loader);j.addProperty("build",i.build);saveJSON(root.resolve("profiles/"+i.id+".json"),j);Files.createDirectories(gameDir(i));return i;}
    public Path gameDir(Instance i){UUID.fromString(i.id);return root.resolve("instances/"+i.id);}
    public static void saveJSON(Path path,JsonElement data)throws IOException{Files.createDirectories(path.getParent());Path temp=Files.createTempFile(path.getParent(),"gcl-",".tmp");try{Files.writeString(temp,new GsonBuilder().setPrettyPrinting().create().toJson(data));Files.move(temp,path,StandardCopyOption.REPLACE_EXISTING);}finally{Files.deleteIfExists(temp);}}
    public List<String> loaders(String game,String kind)throws Exception{if(kind.equals("原版"))return List.of();List<String> result=new ArrayList<>();String host=kind.equals("Fabric")?"https://meta.fabricmc.net/v2":"https://meta.quiltmc.org/v3";for(JsonElement e:json(host+"/versions/loader/"+game).getAsJsonArray())result.add(str(obj(obj(e).get("loader")),"version",""));return result;}
    public boolean allowed(JsonObject item){return allowed(item,platform,System.getProperty("os.version"));}
    public static boolean allowed(JsonObject item,Platform platform,String osVersion){if(!item.has("rules"))return true;boolean result=false;for(JsonElement e:arr(item,"rules")){JsonObject rule=obj(e);if(rule.has("features")){boolean matches=true;for(var f:obj(rule.get("features")).entrySet())if(f.getValue().getAsBoolean())matches=false;if(!matches)continue;}
        JsonObject os=obj(rule.get("os"));if(os.has("name")&&!str(os,"name","").equals(platform.os))continue;
        if(os.has("version")&&!Pattern.compile(str(os,"version","")).matcher(osVersion).find())continue;
        if(os.has("arch")){String a=str(os,"arch","");boolean arm=platform.arch.equals("aarch64");if(!(arm?Set.of("aarch64","arm64"):Set.of("x86_64","amd64","x64")).contains(a))continue;}
        result=str(rule,"action","").equals("allow");}return result;}
    public static List<String> arguments(JsonArray list,Map<String,String> vars,Platform platform,String osVersion)throws IOException{List<String> result=new ArrayList<>();for(JsonElement item:list){if(item.isJsonPrimitive())result.add(expand(item.getAsString(),vars));else{JsonObject o=obj(item);if(!allowed(o,platform,osVersion))continue;JsonElement value=o.get("value");if(value.isJsonArray())for(JsonElement v:value.getAsJsonArray())result.add(expand(v.getAsString(),vars));else result.add(expand(value.getAsString(),vars));}}return result;}
    public static String expand(String text,Map<String,String> vars)throws IOException{String value=text;for(var entry:vars.entrySet())value=value.replace("${"+entry.getKey()+"}",entry.getValue());if(value.contains("${"))throw new IOException("不支持的启动参数："+value);return value;}
    public Path java(int major,Consumer<String> log)throws Exception{
        Path base=root.resolve("java/"+major);Files.createDirectories(base);Path found=findJava(base);if(found!=null)return found;
        log.accept("准备 Java "+major+" · "+platform.javaOS()+" / "+platform.arch);
        JsonObject binary=obj(obj(json("https://api.adoptium.net/v3/assets/latest/"+major+"/hotspot?architecture="+platform.arch+"&image_type=jre&os="+platform.javaOS()+"&vendor=eclipse").getAsJsonArray().get(0)).get("binary"));JsonObject pkg=obj(binary.get("package"));boolean zip=platform.os.equals("windows");Path archive=base.resolve(zip?"runtime.zip":"runtime.tar.gz");download(str(pkg,"link",""),archive,str(pkg,"checksum",""),"SHA-256");
        if(zip)extract(archive,base,1024L*1024*1024);else{Process p=new ProcessBuilder("tar","-xzf",archive.toString(),"-C",base.toString()).redirectErrorStream(true).redirectOutput(root.resolve("runtime-extract.log").toFile()).start();process=p;try{if(p.waitFor()!=0)throw new IOException("Java 解压失败");}finally{process=null;}}Files.deleteIfExists(archive);found=findJava(base);if(found==null)throw new IOException("Java 安装不完整");return found;
    }
    private Path findJava(Path base)throws IOException{try(var walk=Files.walk(base,8)){return walk.filter(p->p.getFileName().toString().equals(platform.os.equals("windows")?"java.exe":"java")&&p.getParent().getFileName().toString().equals("bin")&&Files.isRegularFile(p)).findFirst().orElse(null);}}
    public static void extract(Path zip,Path dest,long maximum)throws Exception{Files.createDirectories(dest);long count=0;int files=0;Set<String> seen=new HashSet<>();try(ZipInputStream in=new ZipInputStream(Files.newInputStream(zip))){for(ZipEntry entry;(entry=in.getNextEntry())!=null;){check();if(++files>30000||!seen.add(entry.getName()))throw new IOException("ZIP 条目重复或过多");Path target=safe(dest,entry.getName());if(entry.isDirectory()){Files.createDirectories(target);continue;}Files.createDirectories(target.getParent());try(OutputStream out=Files.newOutputStream(target,StandardOpenOption.CREATE_NEW)){byte[] buffer=new byte[65536];int n;while((n=in.read(buffer))!=-1){count+=n;if(count>maximum)throw new IOException("ZIP 解压大小超限");out.write(buffer,0,n);}}}}}
    public static String offlineUUID(String name){return UUID.nameUUIDFromBytes(("OfflinePlayer:"+name).getBytes(StandardCharsets.UTF_8)).toString().replace("-","");}
    public void stop(){Process p=process;if(p!=null)p.destroy();}
    public void launch(Instance instance,String username,int memory,int width,int height,Consumer<String> log)throws Exception{
        if(!username.matches("[A-Za-z0-9_]{1,16}"))throw new IOException("本地用户名需为 1–16 个英文字母、数字或下划线");if(memory<1024||memory>32768||width<640||width>7680||height<360||height>4320)throw new IOException("内存或窗口尺寸不合法");
        JsonObject meta=metadata(instance.game).deepCopy();
        if(!instance.loader.equals("原版")){String host=instance.loader.equals("Fabric")?"https://meta.fabricmc.net/v2":"https://meta.quiltmc.org/v3";JsonObject profile=obj(json(host+"/versions/loader/"+instance.game+"/"+instance.build+"/profile/json"));meta.add("mainClass",profile.get("mainClass"));JsonArray all=new JsonArray();all.addAll(arr(profile,"libraries"));all.addAll(arr(meta,"libraries"));meta.add("libraries",all);JsonObject args=obj(meta.get("arguments"));for(String key:List.of("game","jvm")){JsonArray a=arr(args,key);a.addAll(arr(obj(profile.get("arguments")),key));args.add(key,a);}meta.add("arguments",args);}
        int major=number(obj(meta.get("javaVersion")),"majorVersion",!instance.game.startsWith("1.")?25:Integer.parseInt(instance.game.split("\\.")[1])<17?8:17);Path runtime=java(major,log),game=gameDir(instance),libs=root.resolve("libraries"),assets=root.resolve("assets"),natives=game.resolve("natives");Files.createDirectories(natives);
        Path client=root.resolve("versions/"+instance.game+"/"+instance.game+".jar");log.accept("下载并校验游戏文件");artifact(obj(obj(meta.get("downloads")).get("client")),client);
        List<String> cp=new ArrayList<>();Set<String> coordinates=new HashSet<>();int index=0;
        for(JsonElement e:arr(meta,"libraries")){check();JsonObject lib=obj(e);if(!allowed(lib))continue;String name=str(lib,"name","");String[] parts=name.split(":");String identity=parts.length>=2?parts[0]+":"+parts[1]+(parts.length>3?":"+parts[3]:""):name;if(!coordinates.add(identity))continue;log.accept("准备依赖 "+(++index));JsonObject downloads=obj(lib.get("downloads")),a=obj(downloads.get("artifact"));if(a.size()==0){if(parts.length<3||parts.length>4)throw new IOException("不支持的依赖坐标");String path=parts[0].replace('.','/')+"/"+parts[1]+"/"+parts[2]+"/"+parts[1]+"-"+parts[2]+(parts.length==4?"-"+parts[3]:"")+".jar";a.addProperty("path",path);String base=str(lib,"url","https://libraries.minecraft.net/");a.addProperty("url",base+(base.endsWith("/")?"":"/")+path);}Path dest=safe(libs,str(a,"path",""));artifact(a,dest);cp.add(dest.toString());
            String classifier=str(obj(lib.get("natives")),platform.os,null);if(classifier!=null){JsonObject nativeFile=obj(obj(downloads.get("classifiers")).get(classifier.replace("${arch}","64")));if(nativeFile.size()>0){Path nativeJar=safe(libs,str(nativeFile,"path",""));artifact(nativeFile,nativeJar);extractNatives(nativeJar,natives);}}
        }
        JsonObject assetIndex=obj(meta.get("assetIndex"));String assetID=str(assetIndex,"id","");Path indexFile=safe(assets,"indexes/"+assetID+".json");artifact(assetIndex,indexFile);JsonObject objects=obj(obj(JsonParser.parseString(Files.readString(indexFile))).get("objects"));log.accept("下载音效与资源 · "+objects.size()+" 项");
        JsonObject assetMeta=obj(JsonParser.parseString(Files.readString(indexFile)));
        ExecutorService pool=Executors.newFixedThreadPool(8);List<Future<?>> jobs=new ArrayList<>();try{for(var item:objects.entrySet()){String hash=str(obj(item.getValue()),"hash","");if(!hash.matches("[a-f0-9]{40}"))throw new IOException("资源校验值非法");String path=hash.substring(0,2)+"/"+hash;jobs.add(pool.submit(()->{try{download("https://resources.download.minecraft.net/"+path,assets.resolve("objects/"+path),hash,"SHA-1");}catch(Exception ex){throw new CompletionException(ex);}}));}for(Future<?> job:jobs){check();job.get();}}finally{pool.shutdownNow();}
        if(assetMeta.has("virtual")&&assetMeta.get("virtual").getAsBoolean()||assetMeta.has("map_to_resources")&&assetMeta.get("map_to_resources").getAsBoolean()){boolean mapped=assetMeta.has("map_to_resources")&&assetMeta.get("map_to_resources").getAsBoolean();Path targetBase=mapped?game.resolve("resources"):assets.resolve("virtual/"+assetID);for(var entry:objects.entrySet()){String h=str(obj(entry.getValue()),"hash","");Path target=safe(targetBase,entry.getKey());Files.createDirectories(target.getParent());Files.copy(assets.resolve("objects/"+h.substring(0,2)+"/"+h),target,StandardCopyOption.REPLACE_EXISTING);}}
        cp.add(client.toString());Map<String,String> vars=new HashMap<>();vars.put("auth_player_name",username);vars.put("version_name",instance.game);vars.put("game_directory",game.toString());vars.put("assets_root",assets.toString());vars.put("assets_index_name",assetID);vars.put("auth_uuid",offlineUUID(username));vars.put("auth_access_token","0");vars.put("user_type","legacy");vars.put("version_type","release");vars.put("natives_directory",natives.toString());vars.put("launcher_name","GCL");vars.put("launcher_version",VERSION);vars.put("classpath",String.join(platform.separator(),cp));vars.put("classpath_separator",platform.separator());vars.put("library_directory",libs.toString());vars.put("clientid","");vars.put("auth_xuid","");vars.put("user_properties","{}");vars.put("game_assets",assets.resolve("virtual/"+assetID).toString());
        List<String> command=new ArrayList<>();command.add(runtime.toString());command.add("-Xmx"+memory+"M");if(platform.os.equals("osx"))command.add("-XstartOnFirstThread");JsonObject arguments=obj(meta.get("arguments"));if(!arguments.has("jvm"))command.addAll(List.of("-Djava.library.path="+natives,"-cp",vars.get("classpath")));else command.addAll(arguments(arr(arguments,"jvm"),vars,platform,System.getProperty("os.version")));command.add(str(meta,"mainClass","net.minecraft.client.main.Main"));if(meta.has("minecraftArguments"))command.addAll(legacyArguments(str(meta,"minecraftArguments",""),vars));else command.addAll(arguments(arr(arguments,"game"),vars,platform,System.getProperty("os.version")));command.addAll(List.of("--width",""+width,"--height",""+height));
        Files.createDirectories(root.resolve("logs"));log.accept("正在启动游戏；日志位于 logs/latest.log");Process p=new ProcessBuilder(command).directory(game.toFile()).redirectErrorStream(true).redirectOutput(root.resolve("logs/latest.log").toFile()).start();process=p;try{int exit=p.waitFor();if(exit!=0)throw new IOException("游戏退出（"+exit+"），请检查日志");}finally{if(p.isAlive())p.destroy();process=null;}log.accept("游戏已退出");
    }
    public static List<String> legacyArguments(String text,Map<String,String> vars)throws IOException{List<String> result=new ArrayList<>();java.util.regex.Matcher matcher=Pattern.compile("\"([^\"]*)\"|([^\\s]+)").matcher(text);while(matcher.find())result.add(expand(matcher.group(1)!=null?matcher.group(1):matcher.group(2),vars));return result;}
    private static void extractNatives(Path jar,Path dir)throws Exception{try(ZipInputStream in=new ZipInputStream(Files.newInputStream(jar))){for(ZipEntry e;(e=in.getNextEntry())!=null;){if(e.isDirectory()||e.getName().startsWith("META-INF/"))continue;Path p=safe(dir,e.getName());Files.createDirectories(p.getParent());Files.copy(in,p,StandardCopyOption.REPLACE_EXISTING);}}}
    public List<Path> mods(Instance i)throws IOException{Path dir=gameDir(i).resolve("mods");Files.createDirectories(dir);try(var list=Files.list(dir)){return list.filter(p->Files.isRegularFile(p,LinkOption.NOFOLLOW_LINKS)&&(p.toString().endsWith(".jar")||p.toString().endsWith(".jar.disabled"))).sorted().toList();}}
    public void toggle(Instance i,Path mod)throws IOException{Path source=safe(gameDir(i).resolve("mods"),mod.getFileName().toString());if(!Files.isRegularFile(source,LinkOption.NOFOLLOW_LINKS))throw new IOException("模组文件无效");String s=source.getFileName().toString();if(!(s.endsWith(".jar")||s.endsWith(".jar.disabled")))throw new IOException("不支持此模组文件");Path target=source.resolveSibling(s.endsWith(".disabled")?s.substring(0,s.length()-9):s+".disabled");Files.move(source,target);}
    public String logTail()throws IOException{Path file=root.resolve("logs/latest.log");if(!Files.exists(file))return "暂无游戏日志";try(var in=new RandomAccessFile(file.toFile(),"r")){in.seek(Math.max(0,in.length()-65536));byte[] data=new byte[(int)Math.min(in.length(),65536)];in.readFully(data);return new String(data,StandardCharsets.UTF_8);}}
    public JsonArray search(String query,String type,String game)throws Exception{String facets="[[\"project_type:"+type+"\"],[\"versions:"+game+"\"]]";return arr(obj(json("https://api.modrinth.com/v2/search?limit=20&query="+URLEncoder.encode(query,StandardCharsets.UTF_8)+"&facets="+URLEncoder.encode(facets,StandardCharsets.UTF_8))),"hits");}
    public void installMod(JsonObject hit,Instance i,Consumer<String> log)throws Exception{if(i.loader.equals("原版"))throw new IOException("请先选择 Fabric 或 Quilt 配置");String url="https://api.modrinth.com/v2/project/"+str(hit,"project_id","")+"/version?game_versions="+URLEncoder.encode("[\""+i.game+"\"]",StandardCharsets.UTF_8)+"&loaders="+URLEncoder.encode("[\""+i.loader.toLowerCase(Locale.ROOT)+"\"]",StandardCharsets.UTF_8);JsonArray versions=json(url).getAsJsonArray();if(versions.isEmpty())throw new IOException("没有兼容的模组版本");JsonArray files=arr(obj(versions.get(0)),"files");JsonObject file=obj(files.get(0));for(JsonElement e:files)if(obj(e).has("primary")&&obj(e).get("primary").getAsBoolean())file=obj(e);String filename=str(file,"filename","");if(!filename.endsWith(".jar"))throw new IOException("模组文件格式无效");log.accept("下载模组 "+filename);download(str(file,"url",""),safe(gameDir(i).resolve("mods"),filename),str(obj(file.get("hashes")),"sha512",""),"SHA-512");log.accept("模组已安装；额外依赖请另行安装");}
}
