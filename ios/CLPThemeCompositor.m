#import "CLPThemeCompositor.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>

@implementation CLPThemeCompositor
{
  CALayer *_layer;
}

- (instancetype)init {
    return self;
}

- (void)setCALayer:(CALayer *)layer {
  _layer = layer;
}

- (void)processPixelBuffer: (CVImageBufferRef)pixelBuffer {
    int BYTES_PER_PIXEL = 4;

    size_t bufferWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t bufferHeight = CVPixelBufferGetHeight(pixelBuffer);
    unsigned char *pixels = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    for (int i = 0; i < (bufferWidth * bufferHeight); i++) {
        // Calculate the combined grayscale weight of the RGB channels
      
        int weight = (pixels[0] * 0.11) + (pixels[1] * 0.59) + (pixels[2] * 0.3);

        // Apply the grayscale weight to each of the colorchannels
        pixels[0] = weight; // Blue
        pixels[1] = weight; // Green
        pixels[2] = weight; // Red
        pixels += BYTES_PER_PIXEL;
    }
}

- (void)writeToBuffer:(UIImage *)image buffer:(CVPixelBufferRef)destination {
  CVPixelBufferLockBaseAddress(destination, 0);
  
  void *pixelData = CVPixelBufferGetBaseAddress(destination);
  
  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
  
  CGContextRef context = CGBitmapContextCreateWithData(pixelData, image.size.width, image.size.height, 8, CVPixelBufferGetBytesPerRow(destination), rgbColorSpace, kCGImageAlphaNoneSkipFirst, NULL, NULL);
  
  CGContextTranslateCTM(context, 0, image.size.height);
  CGContextScaleCTM(context, 1, -1);
  
  UIGraphicsPushContext(context);
  
  [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
  
  UIGraphicsPopContext();
  
  CVPixelBufferUnlockBaseAddress(destination, 0);
}

- (void)drawSquare:(CGContextRef)context square:(CGRect)path {
  UIBezierPath *squarePath = [UIBezierPath bezierPathWithRect:path];
  
  
  [[UIColor blueColor] setFill];
  
//  CGContextSetFillColor(context, CGColorGetComponents([UIColor blueColor].CGColor));
  
  //CGContextDrawPath(context, CGPathDrawingMode);
  [squarePath fill];
}

// start AVVideoCompositing protocol

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
  CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
  
  CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(destination), CVPixelBufferGetHeight(destination));
  
  UIGraphicsBeginImageContextWithOptions(destinationSize, TRUE, request.renderContext.renderScale);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  // ------------------
  
  CGGradientRef myGradient;
  CGColorSpaceRef myColorspace;

  size_t num_locations = 2;

  CGFloat locations[2] = { 0.0, CMTimeGetSeconds(request.compositionTime) / 10.0 };
  CGFloat components[8] = { 0.894, 0.894, 0.894, 1.0,
                            0.694, 0.694, 0.694, 1.0};

  myColorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
  myGradient = CGGradientCreateWithColorComponents(myColorspace, components, locations, num_locations);
  
  CGPoint myStartPoint, myEndPoint;

  myStartPoint.x = 0.0;
  myStartPoint.y = 0.0;

  myEndPoint.x = destinationSize.width;
  myEndPoint.y = destinationSize.height;
  
  CGContextDrawLinearGradient(context, myGradient, myStartPoint, myEndPoint, 0);
  
  [self drawSquare:context square:CGRectMake(10.0, 10.0, 500.0, 500.0)];
  [self drawSquare:context square:CGRectMake(520.0, 10.0, 500.0, 500.0)];
  
  UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
  
  UIGraphicsEndImageContext();
  
  [self writeToBuffer:img buffer:destination];
//  [img draw]
//  [CIImage imageWithCGImage:<#(nonnull CGImageRef)#>]
  
  CGGradientRelease(myGradient);
  CGColorSpaceRelease(myColorspace);
//  CGContextRelease(context);
  myGradient = NULL;
  myColorspace = NULL;
  context = NULL;
  img = NULL;

  [request finishWithComposedVideoFrame:destination];
  CVBufferRelease(destination);
  destination = NULL;
  
  // ------------------
  
  
  
  return;
  
  CMPersistentTrackID lastTrackId = [[[request sourceTrackIDs] lastObject] intValue];
  CVPixelBufferRef bottom = [request sourceFrameByTrackID:lastTrackId];
  
  NSLog(@"sourceTrackIDs=%@", request.sourceTrackIDs);
  
  if (bottom != NULL) {
    CIImage *img = [CIImage imageWithCVPixelBuffer:bottom options:@{}];
    
    
    if (lastTrackId != 77) {
      AVMutableVideoCompositionInstruction *instruction = (id)request.videoCompositionInstruction;
      
      for (AVMutableVideoCompositionLayerInstruction *layerInstruction in instruction.layerInstructions) {
        if (layerInstruction.trackID == lastTrackId) {
          CGAffineTransform transform;
          [layerInstruction getTransformRampForTime:request.compositionTime startTransform:&transform endTransform:NULL timeRange:NULL];
          
          img = [img imageByApplyingTransform:transform];
        }
      }
    
      img = [img imageByApplyingFilter:@"CIAffineClamp"];
      img = [img imageByApplyingFilter:@"CIGaussianBlur"];

      img = [img imageByCroppingToRect:CGRectMake(0, 0, 720, 1280)];
    }
    CIContext *ctx = [CIContext context];
//
//    CGImageRef cgimg = [ctx createCGImage:img fromRect:CGRectMake(0.0, 0.0, request.renderContext.size.width, request.renderContext.size.height)];
//
//
//    CGContextDrawLayerAtPoint(cgimg, CGPointMake(0.0, 0.0), <#CGLayerRef  _Nullable layer#>)
    
//    CGBitmapContextCreate(NULL, 720, 1280, 8, 0, <#CGColorSpaceRef  _Nullable space#>, <#uint32_t bitmapInfo#>)
    

//     * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
    
    
    
//    CGContextRef cgcontext = CGBitmapContextCreate(NULL, 720.0, 1280.0, CGImageGetBitsPerPixel(cgimg), CVPixelBufferGetBytesPerRowOfPlane(bottom, 1), CGImageGetColorSpace(cgimg), kCGBitmapAlphaInfoMask);
    
//    CGContextSetFillColor(cgcontext, [UIColor blueColor].CGColor);
    
//      NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:@"firstsecondthird"];
//      [str addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0,5)];
//      [str addAttribute:NSForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(5,6)];
//      [str addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(11,5)];
//
//    [str draw
    
//    img = [CIImage imageWithCGImage:cgimg];
    
    
    
    
    
    CGRect imgextent = [img extent];
    
    size_t bwidth = CVPixelBufferGetWidth(bottom);
    size_t bheight = CVPixelBufferGetHeight(bottom);
    
    size_t width = CVPixelBufferGetWidth(destination);
    size_t height = CVPixelBufferGetHeight(destination);
    
    [ctx render:img toCVPixelBuffer:destination];
    
    // TRY THIS
  //  get reference to CALayer
  //  CALayer *layer;
  //  layer.name to identify with theme elements
    
    
  //  if (request.sourceTrackIDs.count == 2) {
  //        CVPixelBufferRef front = [request sourceFrameByTrackID:1];
  //        CVPixelBufferRef back = [request sourceFrameByTrackID:2];
  //        CVPixelBufferLockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
  //        CVPixelBufferLockBaseAddress(back, kCVPixelBufferLock_ReadOnly);
  //        CVPixelBufferLockBaseAddress(destination, 0);
  //        [self renderFrontBuffer:front backBuffer:back toBuffer:destination];
  //        CVPixelBufferUnlockBaseAddress(destination, 0);
  //        CVPixelBufferUnlockBaseAddress(back, kCVPixelBufferLock_ReadOnly);
  //        CVPixelBufferUnlockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
  //  }
    
    // my test gray scale code
    
    // The request will only have a single item in sourceTrackIDs when there is only one video track at the current time.
    // When there are overlapping video frames, this will have each of those frame IDs
    
    
    
  //  OSType format = CVPixelBufferGetPixelFormatType(front);
  //  NSLog(@"firstTrackId=%ld", (unsigned long)request.sourceTrackIDs.count);

  //                        CVPixelBufferLockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
//                          CVPixelBufferLockBaseAddress(destination, 0);

  //  [self grayscale:front destination:destination];
  //
  //                          void *ydestPlane = CVPixelBufferGetBaseAddressOfPlane(destination, 0);
  //                          void *ysrcPlane = CVPixelBufferGetBaseAddressOfPlane(front, 0);
  //                          memcpy(ydestPlane, ysrcPlane, CVPixelBufferGetBytesPerRowOfPlane(front, 0) * CVPixelBufferGetHeightOfPlane(front, 0));

  //  void *uvdestPlane = CVPixelBufferGetBaseAddressOfPlane(destination, 1);
  //  void *uvsrcPlane = CVPixelBufferGetBaseAddressOfPlane(front, 1);
  //  memcpy(uvdestPlane, uvsrcPlane, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1))

  //                            [self processPixelBuffer:destination];

//                              CVPixelBufferUnlockBaseAddress(destination, 0);
  //                            CVPixelBufferUnlockBaseAddress(front, kCVPixelBufferLock_ReadOnly);
    
    // end test gray scale my code
    
    
    [request finishWithComposedVideoFrame:destination];
    CVBufferRelease(destination);
  } else {
    [request finishCancelledRequest];
  }
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext {
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext {
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

- (NSDictionary *)sourcePixelBufferAttributes {
    return @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @[ @(kCVPixelFormatType_32BGRA) ] };
}

// end AVVideoCompositing protocol

vImageConverterRef converter;
vImage_Buffer *sourceBuffers;
vImage_Buffer destinationBuffer;
vImage_CGImageFormat cgImageFormat;
vImageCVImageFormatRef cvImageFormat;

- (void)grayscale:(CVPixelBufferRef)pixelBuffer destination:(CVPixelBufferRef)destination
{
  vImage_Error error = kvImageNoError;
  
  // --------------------
  // CREATE CONVERTER
  // --------------------
  
  cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer);;
  if (converter == NULL) {
    vImageCVImageFormat_SetColorSpace(cvImageFormat, CGColorSpaceCreateDeviceRGB());
    vImageCVImageFormat_SetChromaSiting(cvImageFormat, kCVImageBufferChromaLocation_Center);
    
    converter = vImageConverter_CreateForCVToCGImageFormat(cvImageFormat, &cgImageFormat, NULL, kvImageNoFlags, &error);
    
    
    if (error != kvImageNoError) {
      NSLog(@"vImageConverter_CreateForCVToCGImageFormat error: (TODO)");
      return;
    }
  }
  
  // --------------------
  // CREATE SOURCE BUFFERS
  // --------------------
  if (sourceBuffers == NULL) {
    int numberOfSourceBuffers = (int)vImageConverter_GetNumberOfSourceBuffers(converter);
    
    // TODO
//    sourceBuffers = [vImage_Buffer](repeating: vImage_Buffer(),
//    count: numberOfSourceBuffers)
    
    vImage_Buffer sb[numberOfSourceBuffers];
    sourceBuffers = sb;
//    sourceBuffers = *vImage_Buffer[(int)numberOfSourceBuffers];
  }
  
  vImageBuffer_InitForCopyFromCVPixelBuffer(sourceBuffers, converter, pixelBuffer, kvImageNoAllocate);
  
  // --------------------
  // Initialize the Destination Buffer
  // --------------------
  
  if (destinationBuffer.data == NULL) {
//    vImageBuffer_Init(&destinationBuffer, CVPixelBufferGetHeightOfPlane(pixelBuffer, 0));
    vImageBuffer_Init(&destinationBuffer, CVPixelBufferGetHeightOfPlane(pixelBuffer, 0), CVPixelBufferGetWidthOfPlane(pixelBuffer, 0), cgImageFormat.bitsPerPixel, kvImageNoFlags);
  }
  
  // --------------------
  // Convert YpCbCr Planes to RGB
  // --------------------
  
  vImageConvert_AnyToAny(converter, sourceBuffers, &destinationBuffer, NULL, kvImageNoFlags);
  
  // --------------------
  // Apply an Operation to the RGB Image
  // --------------------
  
  vImageEqualization_ARGB8888(&destinationBuffer, &destinationBuffer, kvImageLeaveAlphaUnchanged);
  
  vImageBuffer_CopyToCVPixelBuffer(&destinationBuffer, &cgImageFormat, destination, cvImageFormat, 0, kvImagePrintDiagnosticsToConsole);
  
  free(destinationBuffer.data);
}

// FIRST ATTEMPT - STOPPED
//- (void)grayscale:(CVPixelBufferRef)source destination:(CVPixelBufferRef)destination
//{
//  OSType format = CVPixelBufferGetPixelFormatType(source);
//
//  // Set the following dict on AVCaptureVideoDataOutput's videoSettings to get YUV output
//  // @{ kCVPixelBufferPixelFormatTypeKey : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange }
//
//  NSAssert(format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, @"Only YUV is supported");
//
//  // The first plane / channel (at index 0) is the grayscale plane
//  // See more infomation about the YUV format
//  // http://en.wikipedia.org/wiki/YUV
//  CVPixelBufferLockBaseAddress(source, 0);
//
//  void *baseaddress = CVPixelBufferGetBaseAddressOfPlane(source, 0);
//
//  CGFloat width = CVPixelBufferGetWidth(source);
//  CGFloat height = CVPixelBufferGetHeight(source);
//
//
//
//  CVPixelBufferUnlockBaseAddress(source, 0);
//}

//- (void)renderFrontBuffer:(CVPixelBufferRef)front backBuffer:(CVPixelBufferRef)back toBuffer:(CVPixelBufferRef)destination {
//    CGImageRef frontImage = [self createSourceImageFromBuffer:front];
//    CGImageRef backImage = [self createSourceImageFromBuffer:back];
//    size_t width = CVPixelBufferGetWidth(destination);
//    size_t height = CVPixelBufferGetHeight(destination);
//    CGRect frame = CGRectMake(0, 0, width, height);
//    CGContextRef gc = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(destination), width, height, 8, CVPixelBufferGetBytesPerRow(destination), CGImageGetColorSpace(backImage), CGImageGetBitmapInfo(backImage));
//    CGContextDrawImage(gc, frame, backImage);
//    CGContextBeginPath(gc);
//    CGContextAddEllipseInRect(gc, CGRectInset(frame, frame.size.width / 10, frame.size.height / 10));
//    CGContextClip(gc);
//    CGContextDrawImage(gc, frame, frontImage);
//    CGContextRelease(gc);
//}
//
//- (CGImageRef)createSourceImageFromBuffer:(CVPixelBufferRef)buffer {
//    size_t width = CVPixelBufferGetWidth(buffer);
//    size_t height = CVPixelBufferGetHeight(buffer);
//    size_t stride = CVPixelBufferGetBytesPerRow(buffer);
//    void *data = CVPixelBufferGetBaseAddress(buffer);
//    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
//    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, height * stride, NULL);
//    CGImageRef image = CGImageCreate(width, height, 8, 32, stride, rgb, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast, provider, NULL, NO, kCGRenderingIntentDefault);
//    CGDataProviderRelease(provider);
//    CGColorSpaceRelease(rgb);
//    return image;
//}

@end
