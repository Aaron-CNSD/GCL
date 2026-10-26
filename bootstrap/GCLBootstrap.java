import java.io.*;
import java.nio.file.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.zip.*;
import javax.swing.JOptionPane;

/** macOS entry point for the bundled native GCL application. Not a cross-platform game engine. */
public final class GCLBootstrap {
    static final String VERSION="0.3.0";
    static String hex(byte[] data){StringBuilder b=new StringBuilder();for(byte x:data)b.append(String.format("%02x",x&255));return b.toString();}
    static InputStream resource(String name) throws IOException {
        InputStream in=GCLBootstrap.class.getResourceAsStream(name);
        if(in==null)throw new IOException("Missing package resource: "+name);return in;
    }
    static Path verifiedPayload(Path folder) throws Exception {
        Path zip=folder.resolve("GCL-native.zip");
        MessageDigest hash=MessageDigest.getInstance("SHA-256");
        try(InputStream in=resource("/GCL-native.zip");OutputStream out=Files.newOutputStream(zip)){
            byte[] block=new byte[65536];int n;while((n=in.read(block))!=-1){hash.update(block,0,n);out.write(block,0,n);}
        }
        String expected;
        try(InputStream in=resource("/GCL-native.sha256")){ByteArrayOutputStream bytes=new ByteArrayOutputStream();byte[] b=new byte[512];int n;while((n=in.read(b))!=-1)bytes.write(b,0,n);expected=new String(bytes.toByteArray(),"UTF-8").trim();}
        if(!hex(hash.digest()).equals(expected))throw new IOException("Native package checksum mismatch");
        try(ZipFile archive=new ZipFile(zip.toFile())){
            if(archive.getEntry("GCL.app/Contents/MacOS/GCL")==null || archive.getEntry("GCL.app/Contents/Info.plist")==null)throw new IOException("Native application is incomplete");
        }
        return zip;
    }
    static void run(String...command) throws Exception {
        Process p=new ProcessBuilder(command).inheritIO().start();
        if(p.waitFor()!=0)throw new IOException("Command failed: "+command[0]);
    }
    public static void main(String[] args) {
        try {
            boolean verify=Arrays.asList(args).contains("--verify");
            if(!verify && !System.getProperty("os.name","").toLowerCase(Locale.ROOT).contains("mac"))throw new IOException("GCL 0.2 的 JAR 是 macOS 原生应用入口，需要 macOS 13+；目前不支持 Windows 或 Linux。");
            Path parent=verify ? Paths.get(System.getProperty("java.io.tmpdir")):Paths.get(System.getProperty("user.home"),"Library","Application Support","GCL","jar-launches");
            Files.createDirectories(parent);
            Path folder=Files.createTempDirectory(parent,"gcl-"+VERSION+"-");
            try {
                Path zip=verifiedPayload(folder);
                if(verify){System.out.println("PASS: GCL "+VERSION+" JAR payload, SHA-256 and native application entries; macOS-only launcher");Files.delete(zip);Files.delete(folder);return;}
                run("/usr/bin/ditto","-xk",zip.toString(),folder.toString());
                Path app=folder.resolve("GCL.app");
                run("/usr/bin/codesign","--verify","--deep","--strict",app.toString());
                run("/usr/bin/open","-n",app.toString());
                Files.delete(zip);
                System.out.println("GCL opened: "+app+"\nNative application retained here for this run. Java is only the entry point.");
            } catch(Exception e){try{Files.deleteIfExists(folder.resolve("GCL-native.zip"));}catch(Exception ignored){}throw e;}
        }catch(Exception e){System.err.println(e.getMessage());if(!java.awt.GraphicsEnvironment.isHeadless())JOptionPane.showMessageDialog(null,e.getMessage(),"GCL",JOptionPane.ERROR_MESSAGE);System.exit(1);}
    }
}
