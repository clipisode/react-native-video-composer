#import "CLPThemeCompositor.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>

@implementation CLPThemeCompositor

- (instancetype)init {
    return self;
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
  
  [squarePath fill];
}

// start AVVideoCompositing protocol

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
  CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
  
  CGSize destinationSize = CGSizeMake(CVPixelBufferGetWidth(destination), CVPixelBufferGetHeight(destination));
  
  UIGraphicsBeginImageContextWithOptions(destinationSize, TRUE, request.renderContext.renderScale);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
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
  
  CGGradientRelease(myGradient);
  CGColorSpaceRelease(myColorspace);
  myGradient = NULL;
  myColorspace = NULL;
  context = NULL;
  img = NULL;

  [request finishWithComposedVideoFrame:destination];
  CVBufferRelease(destination);
  destination = NULL;
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

@end
