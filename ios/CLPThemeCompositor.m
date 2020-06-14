#import "CLPThemeCompositor.h"
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>
#import "CLPThemePainter.h"

@implementation CLPThemeCompositor
{
  CLPThemePainter *_painter;
}

@synthesize theme;
@synthesize icon;
@synthesize logo;
@synthesize arrow;
@synthesize composition;

- (id)init
{
    self = [super init];
    if (self) {
      _painter = [[CLPThemePainter alloc] initWithHeight:@1280.0];
    }

    return self;
}

- (void)setIcon:(UIImage *)icon {
  [_painter setIcon:icon];
}

- (void)setLogo:(UIImage *)logo {
  [_painter setLogo:logo];
}

- (void)setArrow:(UIImage *)arrow {
  [_painter setArrow:arrow];
}

- (BOOL)isTimeInRange:(CMTime)time from:(CMTime)from to:(CMTime)to {
  return CMTimeCompare(time, from) >= 0 && CMTimeCompare(time, to) <= 0;
}

- (NSNumber *)tween:(CMTime)time fromValue:(NSNumber *)fromValue toValue:(NSNumber *)toValue startTime:(NSNumber *)startTime endTime:(NSNumber *)endTime {

  CMTime animFromTime = CMTimeMake(startTime.floatValue * 1000, 1000);
  CMTime animToTime = CMTimeMake(endTime.floatValue * 1000, 1000);

  CMTime animDuration = CMTimeSubtract(animToTime, animFromTime);
  CMTime animProgress = CMTimeSubtract(time, animFromTime);
  float progress =  CMTimeGetSeconds(animProgress) / CMTimeGetSeconds(animDuration);
    
  float newValue = fromValue.floatValue + ((toValue.floatValue - fromValue.floatValue) * progress);
    
  return [NSNumber numberWithFloat:newValue];
}

- (NSDictionary *)tweenAll:(NSDictionary *)props with:(nullable NSArray *)animations at:(CMTime)time {
  if (animations == NULL) return props;
  
  NSMutableDictionary *finalProps = [NSMutableDictionary dictionaryWithDictionary:props];
  
  for (NSDictionary *animation in animations) {
    NSString *field = (NSString *)animation[@"field"];
    NSNumber *startAt = (NSNumber *)animation[@"startAt"];
    NSNumber *endAt = (NSNumber *)animation[@"endAt"];
    NSNumber *fromValue = (NSNumber *)animation[@"from"];
    NSNumber *toValue = (NSNumber *)animation[@"to"];

    CMTime animFromTime = CMTimeMake(startAt.floatValue * 1000, 1000);
    CMTime animToTime = CMTimeMake(endAt.floatValue * 1000, 1000);

    if ([self isTimeInRange:time from:animFromTime to:animToTime]) {
      finalProps[field] = [self tween:time fromValue:fromValue toValue:toValue startTime:startAt endTime:endAt];
    }
  }
  
  return finalProps;
}

// start AVVideoCompositing protocol

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request {
  // this is the point in the teaser where the video will freeze
  NSNumber *teaserVideoDurationConfig = self.composition[@"teaserVideoDuration"];
  
  CMTime teaserVideoDuration = CMTimeMake([teaserVideoDurationConfig intValue], 1000);
  
//  NSLog(@"***** STARTED COMP *****");
  CVPixelBufferRef destination = [request.renderContext newPixelBuffer];
// // empty render test lines
//   [request finishWithComposedVideoFrame:destination];
//   CVBufferRelease(destination);
//   NSLog(@"***** ENDED COMP *****");
//   return;
  
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
        CGAffineTransform rotatedTransform = CGAffineTransformTranslate(CGAffineTransformRotate(startTransform, 3.141593), -1280.0, -720.0);

        sourceFrameImage = [sourceFrameImage imageByApplyingTransform:rotatedTransform];
      }
    }
  }
  
  CIContext *cicontext = [CIContext contextWithCGContext:context options:NULL];

  // This will draw a solid color over the current buffer to prevent old image data from showing
  // through on frames where we don't draw over every pixel. This is necessary because of optimizations
  // in AVFoundation that cause pixel buffers to be reused for multiple compositor rendering requests.
  [_painter drawBackground:context];
  
  // draw underlying frame
  CGImageRef sourceFrameCGImage = [cicontext createCGImage:sourceFrameImage fromRect:sourceFrameImage.extent];
  CGContextDrawImage(context, sourceFrameImage.extent, sourceFrameCGImage);

  if (self.composition != NULL) {
    NSArray *elements = self.composition[@"elements"];
    NSArray *teaserElements = self.composition[@"teaserElements"];

    if (elements != nil) {
      if (teaserVideoDurationConfig != nil && CMTimeCompare(request.compositionTime, teaserVideoDuration) == 1) {
        [self drawAll:elements atTime:teaserVideoDuration inContext:context];
      } else {
        [self drawAll:elements atTime:request.compositionTime inContext:context];
      }
    }
    
    if (teaserElements != nil) {
      [self drawAll:teaserElements atTime:request.compositionTime inContext:context];
    }
  }
  
  CGImageRelease(sourceFrameCGImage);
  CVPixelBufferUnlockBaseAddress(sourceFrame, kCVPixelBufferLock_ReadOnly);
  
  UIGraphicsPopContext();
  CGContextRelease(context);
  
  CVPixelBufferUnlockBaseAddress(destination, 0);
  
  [request finishWithComposedVideoFrame:destination];
  CGColorSpaceRelease(colorSpace);
  CVBufferRelease(destination);
//  NSLog(@"***** ENDED COMP *****");
}

- (void)drawAll:(NSArray *)elements atTime:(CMTime)compositionTime inContext:(CGContextRef)context {
  for (NSDictionary* element in elements) {
    NSNumber *startAt = (NSNumber *)element[@"startAt"];
    NSNumber *endAt = (NSNumber *)element[@"endAt"];
    NSString *type = (NSString *)element[@"type"];
    NSDictionary *props = (NSDictionary *)element[@"props"];

    CMTime fromTime = CMTimeMakeWithSeconds(startAt.floatValue, 1000);
    CMTime toTime = CMTimeMakeWithSeconds(endAt.floatValue, 1000);

    if ([self isTimeInRange:compositionTime from:fromTime to:toTime]) {
      NSArray *animations = (NSArray *)[element valueForKey:@"animations"];
      NSDictionary *animatedProps = [self tweenAll:props with:animations at:compositionTime];
        
      // NSLog(@"START type '%@' **********", type);
      [_painter draw:type context:context props:animatedProps];
      // NSLog(@"  END type '%@' **********", type);
    }
  }
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
