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
  
}

static CGAffineTransform coordinateTransform;

@synthesize theme;
@synthesize logo;
@synthesize textLogo;
@synthesize composition;

+ (void)initialize {
  coordinateTransform = CGAffineTransformScale(CGAffineTransformTranslate(CGAffineTransformIdentity, 0, 1280.0), 1, -1);
}

- (nullable SEL)selectorForElementType:(NSString *)elementType {
  if ([elementType isEqualToString:@"rect"]) {
    return @selector(draw_rect:props:);
  } else if ([elementType isEqualToString:@"text"]) {
    return @selector(draw_text:props:);
  } else if ([elementType isEqualToString:@"image"]) {
    return @selector(draw_image:props:);
  } else if ([elementType isEqualToString:@"gradient"]) {
    return @selector(draw_gradient:props:);
  }
  
  return NULL;
}

- (void)draw_rect:(CGContextRef)context props:(NSDictionary *)props {
  NSString *color = (NSString *)props[@"color"];
  NSNumber *alpha = (NSNumber *)props[@"alpha"];
  CGRect rect = [CLPThemeCompositor rectFromProps:props withModifier:NULL];
  
  if (alpha == NULL) alpha = @1.0;
  
  UIBezierPath *rectBezierPath = [UIBezierPath bezierPathWithRect:rect];
  UIColor *fillColor = [CLPThemeCompositor getUIColorObjectFromHexString:color alpha:alpha];
  
  [fillColor setFill];
  
  [rectBezierPath fill];
}

- (void)draw_text:(CGContextRef)context props:(NSDictionary *)props {
  NSString *value = (NSString *)props[@"value"];
  NSNumber *alpha = (NSNumber *)props[@"alpha"];
  NSString *fontName = (NSString *)props[@"fontName"];
  NSNumber *fontSize = (NSNumber *)props[@"fontSize"];
  NSString *color = (NSString *)props[@"color"];
  NSString *textAlign = (NSString *)props[@"textAlign"];
  
  // Apply default values
  if (alpha == NULL) alpha = @1.0;
  if (fontName == NULL) fontName = @"Open Sans";
  if (fontSize == NULL) fontSize = @44.0;
  if (color == NULL) color = @"#FFFFFF";
  if (textAlign == NULL) textAlign = @"left";
  
  // TODO: Can we check the validity of fontName?
  
  CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)fontName, fontSize.floatValue);
  CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 0.0, NULL);
  CGColorRef foregroundColor = [CLPThemeCompositor getUIColorObjectFromHexString:color alpha:alpha].CGColor;

  CTTextAlignment alignment = kCTTextAlignmentLeft;
  
  if ([textAlign isEqualToString:@"center"]) alignment = kCTTextAlignmentCenter;
  else if ([textAlign isEqualToString:@"right"]) alignment = kCTTextAlignmentRight;
  else if ([textAlign isEqualToString:@"justified"]) alignment = kCTTextAlignmentJustified;
  else if ([textAlign isEqualToString:@"natural"]) alignment = kCTTextAlignmentNatural;
  
  const CTParagraphStyleSetting styleSettings[] = {
    {kCTParagraphStyleSpecifierAlignment, sizeof(CTTextAlignment), &alignment}
  };
  
  CTParagraphStyleRef paragraphStyle = CTParagraphStyleCreate(styleSettings, 1);
  
  CFRelease(descriptor);

  CFStringRef keys[] = { kCTFontAttributeName, kCTForegroundColorAttributeName, kCTParagraphStyleAttributeName };
  CFTypeRef values[] = { font, foregroundColor, paragraphStyle };

  CFDictionaryRef attributes = CFDictionaryCreate(kCFAllocatorDefault, (const void**)&keys, (const void**)&values, sizeof(keys) / sizeof(keys[0]), &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

  CFAttributedStringRef attrString = CFAttributedStringCreate(kCFAllocatorDefault, (CFStringRef)value, attributes);
  
  CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString(attrString);
  
  CGMutablePathRef framePath = CGPathCreateMutable();
  CGRect frameRect = [CLPThemeCompositor rectFromProps:props withModifier:NULL];
  CGPathAddRect(framePath, NULL, frameRect);
  
  CFRange currentRange = CFRangeMake(0, 0);
  
  CTFrameRef frame = CTFramesetterCreateFrame(frameSetter, currentRange, framePath, NULL);
  
  CTFrameDraw(frame, context);
  
  CGColorRelease(foregroundColor);
  CGPathRelease(framePath);
  CFRelease(frame);
  CFRelease(frameSetter);
}

- (void)draw_image:(CGContextRef)context props:(NSDictionary *)props {
  NSNumber *alpha = (NSNumber *)props[@"alpha"];
  NSString *imageKey = (NSString *)props[@"imageKey"];
  CGRect rect = [CLPThemeCompositor rectFromProps:props withModifier:NULL];
  
  // Apply default values
  if (alpha == NULL) alpha = @1.0;
  
  UIImage *image = NULL;
  
  if ([imageKey isEqualToString:@"logo"]) image = self.logo;
  if ([imageKey isEqualToString:@"textlogo"]) image = self.textLogo;
  
  // TODO: 👆 'logo' and 'textlogo' are provided by the app bundle.
  // This is where we'll add support for other images provided by
  // the theme and downloaded by the application at runtime.
  
  if (image == NULL) {
    NSLog(@"Image not found for key: '%@'", imageKey);
  } else {
    CGContextSaveGState(context);
    CGContextSetAlpha(context, alpha.floatValue);
    CGContextDrawImage(context, rect, image.CGImage);
    CGContextRestoreGState(context);
  }
}

- (void)draw_gradient:(CGContextRef)context props:(NSDictionary *)props {
  NSNumber *alpha = (NSNumber *)props[@"alpha"];
  
  // TODO: 👆 alpha is the only supported prop right now to support fading in/out.
  // This needs to be updated to support colors, locations, and path.
  
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
  CGContextSetAlpha(context, alpha.floatValue);
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


// This is a standard way to pull x/y/width/height values from props and create a
// CGRect which is commonly used for positioning elements. The modifier parameter
// is there to support having multiple rectangle configs in the case that some draw
// functions need that. This is necessary because the props must be flat key/value
// pairs instead of nested objects to allow for simpler animation (preventing
// base value mutation during animation).
+ (CGRect)rectFromProps:(NSDictionary *)props withModifier:(nullable NSString *)modifier {
  NSString *xKey = @"x";
  NSString *yKey = @"y";
  NSString *widthKey = @"width";
  NSString *heightKey = @"height";
  
  if (modifier != NULL) {
    xKey = [modifier stringByAppendingString:xKey];
    yKey = [modifier stringByAppendingString:yKey];
    widthKey = [modifier stringByAppendingString:widthKey];
    heightKey = [modifier stringByAppendingString:heightKey];
  }
  
  NSNumber *x = (NSNumber *)props[@"x"];
  NSNumber *y = (NSNumber *)props[@"y"];
  NSNumber *width = (NSNumber *)props[@"width"];
  NSNumber *height = (NSNumber *)props[@"height"];
  
  CGRect rect = CGRectMake(x.floatValue, y.floatValue, width.floatValue, height.floatValue);
  
  return CGRectApplyAffineTransform(rect, coordinateTransform);
}

+ (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(NSNumber *)alpha
{
  // Convert hex string to an integer
  unsigned int hexint = [CLPThemeCompositor intFromHexString:hexStr];

  // Create a color object, specifying alpha as well
  UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexint & 0xFF0000) >> 16))/255
                    green:((CGFloat) ((hexint & 0xFF00) >> 8))/255
                     blue:((CGFloat) (hexint & 0xFF))/255
                    alpha:alpha.floatValue];

  return color;
}

+ (unsigned int)intFromHexString:(NSString *)hexStr
{
  unsigned int hexInt = 0;

  // Create scanner
  NSScanner *scanner = [NSScanner scannerWithString:hexStr];

  // Tell scanner to skip the # character
  [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];

  // Scan hex value
  [scanner scanHexInt:&hexInt];

  return hexInt;
}

- (void) drawBackground:(CGContextRef)context {
  CGRect path = CGRectMake(0.0, 0.0, 720.0, 1280.0);
  UIBezierPath *backgroundPath = [UIBezierPath bezierPathWithRect:path];
  
  [[UIColor blackColor] setFill];
  
  [backgroundPath fill];
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

// This functionality adapted from: https://stackoverflow.com/a/20058585
- (void)draw:(SEL)selector context:(CGContextRef)context props:(NSDictionary *)props {
  IMP imp = [self methodForSelector:selector];
  
  void (*drawElement)(id, SEL, CGContextRef, NSDictionary *) = (void *)imp;
  
  drawElement(self, selector, context, props);
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

  // This will draw a solid color over the current buffer to prevent old image data from showing
  // through on frames where we don't draw over every pixel. This is necessary because of optimizations
  // in AVFoundation that cause pixel buffers to be reused for multiple compositor rendering requests.
  [self drawBackground:context];
  
  // draw underlying frame
  CGImageRef sourceFrameCGImage = [cicontext createCGImage:sourceFrameImage fromRect:sourceFrameImage.extent];
  CGContextDrawImage(context, sourceFrameImage.extent, sourceFrameCGImage);

  if (self.composition != NULL) {
    NSArray *elements = self.composition[@"elements"];

    for (NSDictionary* element in elements) {
      NSNumber *startAt = (NSNumber *)element[@"startAt"];
      NSNumber *endAt = (NSNumber *)element[@"endAt"];
      NSString *type = (NSString *)element[@"type"];
      NSDictionary *props = (NSDictionary *)element[@"props"];

      CMTime fromTime = CMTimeMakeWithSeconds(startAt.floatValue, 1000);
      CMTime toTime = CMTimeMakeWithSeconds(endAt.floatValue, 1000);

      if ([self isTimeInRange:request.compositionTime from:fromTime to:toTime]) {
        SEL selector = [self selectorForElementType:type];
        
        if (selector != NULL) {
          NSArray *animations = (NSArray *)[element valueForKey:@"animations"];
          NSDictionary *animatedProps = [self tweenAll:props with:animations at:request.compositionTime];
          
          [self draw:selector context:context props:animatedProps];
        } else {
          NSLog(@"Selector not found for element type '%@'.", type);
        }
      }
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
