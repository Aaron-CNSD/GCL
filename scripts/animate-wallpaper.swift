import AppKit
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// Render a seamless eight-second wallpaper with local water/foliage motion.
let args=CommandLine.arguments
let input=URL(fileURLWithPath:args[1]), output=URL(fileURLWithPath:args[2])
let width=1280,height=720,fps=30,seconds=8
let source=CIImage(contentsOf:input)!
let image=source.transformed(by:CGAffineTransform(scaleX:Double(width)/source.extent.width,y:Double(height)/source.extent.height))
let context=CIContext(options:[.cacheIntermediates:false])
let kernel=CIWarpKernel(source:"""
kernel vec2 landscape(float phase, float w, float h) {
    vec2 p=destCoord();
    float water=1.0-smoothstep(h*0.30,h*0.52,p.y);
    float shore=smoothstep(w*0.65,w*0.95,p.x);
    float sway=sin(phase)*sin(p.y/h*3.14159);
    p.x+=water*sin(p.y*0.105+phase*2.0)*1.1;
    p.y+=water*sin(p.x*0.025+phase)*0.45;
    p.x+=shore*sway*1.2;
    return p;
}
""")!
try? FileManager.default.removeItem(at:output)
let writer=try AVAssetWriter(outputURL:output,fileType:.mp4)
let track=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:2_500_000,AVVideoMaxKeyFrameIntervalKey:fps*seconds]])
let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:track,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferIOSurfacePropertiesKey as String:[:]])
writer.add(track);guard writer.startWriting() else { fatalError("Cannot start writer: \(String(describing:writer.error))") };writer.startSession(atSourceTime:.zero)
let gifURL=output.deletingPathExtension().appendingPathExtension("gif")
let gif=CGImageDestinationCreateWithURL(gifURL as CFURL,UTType.gif.identifier as CFString,80,nil)!
CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
for frame in 0..<(fps*seconds) {
    autoreleasepool {
        while !track.isReadyForMoreMediaData { Thread.sleep(forTimeInterval:0.002) }
        var pixel:CVPixelBuffer?;CVPixelBufferCreate(nil,width,height,kCVPixelFormatType_32BGRA,[kCVPixelBufferIOSurfacePropertiesKey as String:[:]] as CFDictionary,&pixel)
        let phase=Double(frame)/Double(fps*seconds)*Double.pi*2
        let animated=kernel.apply(extent:CGRect(x:0,y:0,width:width,height:height),roiCallback:{_,rect in rect.insetBy(dx:-8,dy:-8)},image:image,arguments:[phase,Double(width),Double(height)])!
        context.render(animated,to:pixel!)
        guard adaptor.append(pixel!,withPresentationTime:CMTime(value:Int64(frame),timescale:Int32(fps))) else { fatalError(writer.error?.localizedDescription ?? "Video writing failed") }
        if frame%3==0 {
            let small=animated.transformed(by:CGAffineTransform(scaleX:0.5,y:0.5))
            let cg=context.createCGImage(small,from:CGRect(x:0,y:0,width:640,height:360))!
            CGImageDestinationAddImage(gif,cg,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
        }
    }
}
track.markAsFinished()
let done=DispatchSemaphore(value:0);writer.finishWriting{done.signal()};done.wait()
guard writer.status == .completed,CGImageDestinationFinalize(gif) else {fatalError(writer.error?.localizedDescription ?? "Animation export failed")}
print("Created 8s seamless 30 fps MP4 and 10 fps GIF")
