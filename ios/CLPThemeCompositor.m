#import "CLPThemeCompositor.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>

@implementation CLPThemeCompositor
{
  CGAffineTransform coordinateTransform;
}

@synthesize theme;

- (instancetype)init {
  if (self = [super init]) {
    coordinateTransform = CGAffineTransformScale(CGAffineTransformTranslate(CGAffineTransformIdentity, 0, 1280.0), 1, -1);
  }
  
  return self;
}

- (void)writeToBuffer:(UIImage *)image buffer:(CVPixelBufferRef)destination {
  CVPixelBufferLockBaseAddress(destination, 0);
  
  void *pixelData = CVPixelBufferGetBaseAddress(destination);
  
  CGImageRef cgimg = image.CGImage;
  CGColorSpaceRef rgbColorSpace = CGImageGetColorSpace(cgimg);
  CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(cgimg);
  
  CGContextRef context = CGBitmapContextCreateWithData(pixelData, image.size.width, image.size.height, 8, CVPixelBufferGetBytesPerRow(destination), rgbColorSpace, alphaInfo, NULL, NULL);
  
  UIGraphicsPushContext(context);
  
  [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
  
  UIGraphicsPopContext();
  
  CVPixelBufferUnlockBaseAddress(destination, 0);
}

- (void)drawSquare:(CGContextRef)context square:(CGRect)path {
  UIBezierPath *squarePath = [UIBezierPath bezierPathWithRect:CGRectApplyAffineTransform(path, coordinateTransform)];
  
  [[UIColor blueColor] setFill];
  
  [squarePath fill];
}

- (void)drawMultilineText:(CGContextRef)context text:(CFStringRef)string {
  CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)@"Arial", 120.0);
  CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 0.0, NULL);
  
  CFRelease(descriptor);

  CFStringRef keys[] = { kCTFontAttributeName };
  CFTypeRef values[] = { font };

  CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys, (const void**)&values, sizeof(keys) / sizeof(keys[0]), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

  CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attributes);
  
  CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString(attrString);
  
  CGMutablePathRef framePath = CGPathCreateMutable();
  CGRect frameRect= CGRectApplyAffineTransform(CGRectMake(10, 10, 500, 500), coordinateTransform);
  CGPathAddRect(framePath, NULL, frameRect);
  
  CFRange currentRange = CFRangeMake(0, 0);
  
  CTFrameRef frame = CTFramesetterCreateFrame(frameSetter, currentRange, framePath, NULL);
  
  CTFrameDraw(frame, context);
  
  CGPathRelease(framePath);
  CFRelease(frame);
  CFRelease(string);
  CFRelease(frameSetter);
}

- (void)drawImage:(CGContextRef)context {
  UIImage *img = [UIImage imageNamed:@"AppIcon"];
  
  CGRect rect = CGRectApplyAffineTransform(CGRectMake(25, 25, 225, 225), coordinateTransform);
  
  CGContextDrawImage(context, rect, img.CGImage);
}

- (void)drawGradient:(CGContextRef)context {
  CGGradientRef myGradient;
  CGColorSpaceRef myColorspace;

  size_t num_locations = 2;

  const CGFloat *scc = CGColorGetComponents([UIColor colorWithRed:5 green:5 blue:5 alpha:0].CGColor);
  const CGFloat *ecc = CGColorGetComponents([UIColor greenColor].CGColor);
  
  CGFloat locations[2] = { 0.0, 1.0 };
  CGFloat components[8] = { scc[2], scc[0], scc[1], scc[3],
                            ecc[2], ecc[0], ecc[1], ecc[3] };

  myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  myGradient = CGGradientCreateWithColorComponents(myColorspace, components, locations, num_locations);
  
  CGPoint myStartPoint = CGPointMake(0, 600);
  CGPoint myEndPoint = CGPointMake(0, 720);
  
  CGContextSaveGState(context);
  CGContextClipToRect(context, CGRectApplyAffineTransform(CGRectMake(0, 600, 720, 1280), coordinateTransform));
  CGContextDrawLinearGradient(context, myGradient, myStartPoint, myEndPoint, 0);
  CGContextRestoreGState(context);
  
  CGGradientRelease(myGradient);
  CGColorSpaceRelease(myColorspace);
  myGradient = NULL;
  myColorspace = NULL;
}

// start AVVideoCompositing protocol

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
  CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
  CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(destination), CVPixelBufferGetHeight(destination));
  
  CVPixelBufferLockBaseAddress(destination, 0);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  UIGraphicsBeginImageContextWithOptions(destinationSize, YES, request.renderContext.renderScale);
  
  CGContextRef context = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), destinationSize.width, destinationSize.height, 8, CVPixelBufferGetBytesPerRow(destination), colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
  UIGraphicsPushContext(context);
  CGContextSetAllowsAntialiasing(context, YES);
  
  CVPixelBufferRef sourceFrame = [request sourceFrameByTrackID:[request.sourceTrackIDs lastObject].intValue];
  CVPixelBufferLockBaseAddress(sourceFrame, kCVPixelBufferLock_ReadOnly);
  CIImage *sourceFrameImage = [CIImage imageWithCVPixelBuffer:sourceFrame];
  
  CIContext *cicontext = [CIContext context];
  
  CGImageRef sourceFrameCGImage = [cicontext createCGImage:sourceFrameImage fromRect:sourceFrameImage.extent];
  CGContextDrawImage(context, sourceFrameImage.extent, sourceFrameCGImage);

  [self drawGradient:context];
  [self drawSquare:context square:CGRectMake(10.0, 10.0, CMTimeGetSeconds(request.compositionTime) * 100.0, 500.0)];
  [self drawSquare:context square:CGRectMake(520.0, 10.0, 500.0, 500.0)];
  [self drawImage:context];
  [self drawMultilineText:context text:(CFStringRef)@"This is a longer line of text that should wrap."];
  
  UIGraphicsPopContext();
  
  CVPixelBufferUnlockBaseAddress(sourceFrame, kCVPixelBufferLock_ReadOnly);
  CVPixelBufferUnlockBaseAddress(destination, 0);
  
  CGContextRelease(context);
  CGImageRelease(sourceFrameCGImage);
  CGColorSpaceRelease(colorSpace);
  
  [request finishWithComposedVideoFrame:destination];

  CVBufferRelease(destination);
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
  NSLog(@"RENDER CONTEXT CHANGED");
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (NSDictionary *)sourcePixelBufferAttributes {
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (void)cancelAllPendingVideoCompositionRequests {
  NSLog(@"CANCELLING ALL!");
}

// end AVVideoCompositing protocol

@end
