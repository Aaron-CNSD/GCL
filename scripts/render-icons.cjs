const fs=require('fs'),path=require('path'),sharp=require('sharp'),{execFileSync}=require('child_process');
(async()=>{
 const base=path.resolve(__dirname,'..'),asset=path.join(base,'macos/Assets');
 const source=fs.readFileSync(path.join(asset,fs.existsSync(path.join(asset,'GCL-source.png'))?'GCL-source.png':'GCL.svg'));
 const iconset=path.join(asset,'GCL.iconset');fs.mkdirSync(iconset,{recursive:true});
 for(const size of [16,32,128,256,512])for(const factor of [1,2])await sharp(source).resize(size*factor,size*factor).png().toFile(path.join(iconset,`icon_${size}x${size}${factor===2?'@2x':''}.png`));
 await sharp(source).resize(1024).png().toFile(path.join(asset,'GCL-preview.png'));
 await sharp(source).resize(256).png().toFile(path.join(base,'website/icon.png'));
 execFileSync('/usr/bin/iconutil',['-c','icns',iconset,'-o',path.join(asset,'GCL.icns')]);
 console.log('Rendered GCL village house icon');
})().catch(error=>{console.error(error);process.exitCode=1;});
