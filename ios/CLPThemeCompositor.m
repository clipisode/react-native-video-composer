#import "CLPThemeCompositor.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>

// We know we're working with kCVPixelFormatType_32BGRA
const size_t COLOR_COMPONENT_COUNT = 4;

@implementation CLPThemeCompositor
{
  CGAffineTransform coordinateTransform;
}

@synthesize theme;
@synthesize logo;

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
  CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)@"Open Sans", 44.0);
  CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 0.0, NULL);
  CGColorRef foregroundColor = [UIColor whiteColor].CGColor;

//  CGFloat leading = 25.0;
  CTTextAlignment alignment = kCTTextAlignmentCenter; // just for test purposes
  const CTParagraphStyleSetting styleSettings[] = {
//      {kCTParagraphStyleSpecifierLineSpacingAdjustment, sizeof(CGFloat), &leading},
      {kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &alignment}
  };
//  CFStringRef settingKeys[] = { kCTParagraphStyleSpecifierAlignment };
//  CFTypeRef settingValues[] = { kCTTextAlignmentCenter };
//  CFDictionaryRef settings = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&settingKeys, (const void**)&settingValues, sizeof(settingKeys) / sizeof(settingKeys[0]), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  
  CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(styleSettings, 1);
  
  CFRelease(descriptor);

  CFStringRef keys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName, kCTParagraphStyleAttributeName };
  CFTypeRef values[] = { font, foregroundColor, paragraphStyle };

  CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys, (const void**)&values, sizeof(keys) / sizeof(keys[0]), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

  CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, string, attributes);
  
  CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString(attrString);
  
  CGMutablePathRef framePath = CGPathCreateMutable();
  CGRect frameRect= CGRectApplyAffineTransform(CGRectMake(20, 1280 - 210, 720 - 20, 1280 - 20), coordinateTransform);
  CGPathAddRect(framePath, NULL, frameRect);
  
  CFRange currentRange = CFRangeMake(0, 0);
  
  CTFrameRef frame = CTFramesetterCreateFrame(frameSetter, currentRange, framePath, NULL);
  
  CTFrameDraw(frame, context);
  
  CGColorRelease(foregroundColor);
  CGPathRelease(framePath);
  CFRelease(frame);
  CFRelease(string);
  CFRelease(frameSetter);
}

- (void)drawLogo:(CGContextRef)context {
  if (self.logo == NULL) {
    NSLog(@"logo property is NULL");
    return;
  }
  
  CGSize size = CGSizeMake(80.0, 80.0);
  CGFloat padding = 30.0;
  
  CGRect rect = CGRectApplyAffineTransform(CGRectMake(720.0 - size.width - padding, padding, size.width, size.height), coordinateTransform);
  
  CGContextDrawImage(context, rect, self.logo.CGImage);
}

- (void)drawGradient:(CGContextRef)context {
  CGGradientRef myGradient;
  CGColorSpaceRef myColorspace;

  size_t num_locations = 3;

  UIColor *baseColor = [UIColor colorWithRed:52.0/255.0 green:152.0/255.0 blue:219.0/255.0 alpha:1];
  
  CGColorRef colorOne = [baseColor colorWithAlphaComponent:0.0].CGColor;
  CGColorRef colorTwo = [baseColor colorWithAlphaComponent:0.8].CGColor;
  CGColorRef colorThree = [baseColor colorWithAlphaComponent:1.0].CGColor;
  
  const CGFloat *scc = CGColorGetComponents(colorOne);
  const CGFloat *mcc = CGColorGetComponents(colorTwo);
  const CGFloat *ecc = CGColorGetComponents(colorThree);

  CGFloat locations[3] = { 0.0, 0.45, 1.0 };
  
  CGFloat components[COLOR_COMPONENT_COUNT * 3] = { scc[0], scc[1], scc[2], scc[3],
                                                    mcc[0], mcc[1], mcc[2], mcc[3],
                                                    ecc[0], ecc[1], ecc[2], ecc[3] };
  
  CGFloat height = 210.0;

  myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
  myGradient = CGGradientCreateWithColorComponents(myColorspace, components, locations, num_locations);
  
  CGPoint myStartPoint = CGPointApplyAffineTransform(CGPointMake(0, 1280.0 - height), coordinateTransform);
  CGPoint myEndPoint = CGPointApplyAffineTransform(CGPointMake(0, 1280.0), coordinateTransform);
  
  CGContextSaveGState(context);
  CGContextClipToRect(context, CGRectApplyAffineTransform(CGRectMake(0, 1280.0 - height, 720, 1280), coordinateTransform));
  CGContextDrawLinearGradient(context, myGradient, myStartPoint, myEndPoint, 0);
  CGContextRestoreGState(context);
  
  CGGradientRelease(myGradient);
  CGColorSpaceRelease(myColorspace);
  myGradient = NULL;
  myColorspace = NULL;
  colorOne = NULL;
  colorTwo = NULL;
  colorThree = NULL;
}

// start AVVideoCompositing protocol

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
  CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
  
  CVPixelBufferLockBaseAddress(destination, 0);
  
  CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(destination), CVPixelBufferGetHeight(destination));
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  
  void * destinationBaseAddress = CVPixelBufferGetBaseAddress(destination);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(destination);
  CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst;
  
  CGContextRef context = CGBitmapContextCreate(destinationBaseAddress, destinationSize.width, destinationSize.height, 8, bytesPerRow, colorSpace, bitmapInfo);
  CGContextSetAllowsAntialiasing(context, YES);
  
  UIGraphicsPushContext(context);
  
  CMPersistentTrackID lastSourceTrackId = [request.sourceTrackIDs lastObject].intValue;
  CVPixelBufferRef sourceFrame = [request sourceFrameByTrackID:lastSourceTrackId];
  CVPixelBufferLockBaseAddress(sourceFrame, kCVPixelBufferLock_ReadOnly);
  CIImage *sourceFrameImage = [CIImage imageWithCVPixelBuffer:sourceFrame];

  AVMutableVideoCompositionInstruction *mainInstruction = (AVMutableVideoCompositionInstruction *)request.videoCompositionInstruction;
  for (AVMutableVideoCompositionLayerInstruction* li in mainInstruction.layerInstructions) {
    if (li.trackID == lastSourceTrackId) {
      CGAffineTransform startTransform;

      [li getTransformRampForTime:request.compositionTime startTransform:&startTransform endTransform:NULL timeRange:NULL];

      if (!CGAffineTransformIsIdentity(startTransform)) {
        sourceFrameImage = [sourceFrameImage imageByApplyingTransform:CGAffineTransformConcat(startTransform, coordinateTransform)];
      }
    }
  }
  
  CIContext *cicontext = [CIContext contextWithCGContext:context options:NULL];

  // draw underlying frame
  CGImageRef sourceFrameCGImage = [cicontext createCGImage:sourceFrameImage fromRect:sourceFrameImage.extent];

  CGContextDrawImage(context, sourceFrameImage.extent, sourceFrameCGImage);

  [self drawGradient:context];
  [self drawLogo:context];
  
  
  CGImageRelease(sourceFrameCGImage);
  CVPixelBufferUnlockBaseAddress(sourceFrame, kCVPixelBufferLock_ReadOnly);
  
  UIGraphicsPopContext();
  CGContextRelease(context);
  
  CVPixelBufferUnlockBaseAddress(destination, 0);
  
  [request finishWithComposedVideoFrame:destination];
  CGColorSpaceRelease(colorSpace);
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
