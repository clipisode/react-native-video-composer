#import "CLPThemePainter.h"
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

// We know we're working with kCVPixelFormatType_32BGRA
const size_t COLOR_COMPONENT_COUNT = 4;

@implementation CLPThemePainter
{
  CGAffineTransform _coordinateTransform;
}

@synthesize icon;
@synthesize logo;
@synthesize arrow;

- (id)initWithHeight:(NSNumber *)height
{
    self = [super init];
    if (self) {
      _coordinateTransform = CGAffineTransformScale(CGAffineTransformTranslate(CGAffineTransformIdentity, 0, [height floatValue]), 1, -1);
    }

    return self;
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
  NSNumber *cornerRadius = (NSNumber *)props[@"cornerRadius"];
  NSString *strokeColor = (NSString *)props[@"strokeColor"];
  NSNumber *strokeAlpha = (NSNumber *)props[@"strokeAlpha"];
  NSNumber *strokeWidth = (NSNumber *)props[@"strokeWidth"];
  CGRect rect = [self rectFromProps:props withModifier:NULL];
  
  if (alpha == NULL) alpha = @1.0;
  if (cornerRadius == NULL) cornerRadius = @0.0;

  CGFloat floatRadius = [cornerRadius doubleValue];
  UIBezierPath *rectBezierPath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:floatRadius];
  // UIBezierPath *rectBezierPath = [UIBezierPath bezierPathWithRect:rect];
  UIColor *fillColor = [self getUIColorObjectFromHexString:color alpha:alpha];

  [fillColor setFill];
  
  [rectBezierPath fill];

  if (strokeWidth > 0) {
    CGFloat uiStrokeWidth = [strokeWidth doubleValue];
    CGRect strokeRect = CGRectMake(rect.origin.x - uiStrokeWidth/2, rect.origin.y - uiStrokeWidth/2, rect.size.width + uiStrokeWidth, rect.size.height + uiStrokeWidth);
    UIBezierPath *strokeRectBezierPath = [UIBezierPath bezierPathWithRoundedRect:strokeRect cornerRadius:floatRadius + uiStrokeWidth/2];
    if (strokeAlpha == NULL) strokeAlpha = @1.0;
    if (strokeColor == NULL) strokeColor = @"#000000";
    UIColor *uiStrokeColor = [self getUIColorObjectFromHexString:strokeColor alpha:strokeAlpha];
    [uiStrokeColor setStroke];
    strokeRectBezierPath.lineWidth = uiStrokeWidth;
    [strokeRectBezierPath stroke];
  }
}

- (void)draw_text:(CGContextRef)context props:(NSMutableDictionary *)props {
  NSString *value = (NSString *)props[@"value"];
  NSNumber *alpha = (NSNumber *)props[@"alpha"];
  NSString *fontName = (NSString *)props[@"fontName"];
  NSNumber *fontSize = (NSNumber *)props[@"fontSize"];
  NSString *color = (NSString *)props[@"color"];
  NSString *textAlign = (NSString *)props[@"textAlign"];
  NSString *originY = (NSString *)props[@"originY"];
  NSNumber *width = (NSNumber *)props[@"width"];
  NSNumber *height = (NSNumber *)props[@"height"];
  NSNumber *x = (NSNumber *)props[@"x"];
  NSNumber *y = (NSNumber *)props[@"y"];
  
  // Apply default values
  if (value == NULL) value = @"";
  if (alpha == NULL) alpha = @1.0;
  if (fontName == NULL) fontName = @"Open Sans";
  if (fontSize == NULL) fontSize = @44.0;
  if (color == NULL) color = @"#FFFFFF";
  if (textAlign == NULL) textAlign = @"left";
  if (originY == NULL) originY = @"top";
  
  // TODO: Can we check the validity of fontName?
  
  CTFontDescriptorRef descriptor = CTFontDescriptorCreateWithNameAndSize((CFStringRef)fontName, fontSize.floatValue);
  CTFontRef font = CTFontCreateWithFontDescriptor(descriptor, 0.0, NULL);
  CGColorRef foregroundColor = [self getUIColorObjectFromHexString:color alpha:alpha].CGColor;

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
  
  CFRange currentRange = CFRangeMake(0, 0);

  // vertical align center or bottom?
  CGSize frameConstraints = CGSizeMake([width floatValue], [height floatValue]);
  CGSize frameSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, currentRange, NULL, frameConstraints, NULL);
  if ([originY isEqualToString:@"bottom"]) {
    float newY = [y floatValue] - frameSize.height;
    props[@"y"] = @(newY);
  };
  if ([originY isEqualToString:@"center"]) {
    float newY = [y floatValue] - frameSize.height/2;
    props[@"y"] = @(newY);
  };
  
  CGMutablePathRef framePath = CGPathCreateMutable();
  CGRect frameRect = [self rectFromProps:props withModifier:NULL];
  CGPathAddRect(framePath, NULL, frameRect);
  
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
  CGRect rect = [self rectFromProps:props withModifier:NULL];
  
  // Apply default values
  if (alpha == NULL) alpha = @1.0;
  
  UIImage *image = NULL;
  
  if ([imageKey isEqualToString:@"icon"]) image = self.icon;
  if ([imageKey isEqualToString:@"logo"]) image = self.logo;
  if ([imageKey isEqualToString:@"arrow"]) image = self.arrow;
  
  // TODO: 👆 'icon', 'logo' and 'arrow' are provided by the app bundle.
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
  
  CGPoint myStartPoint = CGPointApplyAffineTransform(CGPointMake(0, 1280.0 - height), _coordinateTransform);
  CGPoint myEndPoint = CGPointApplyAffineTransform(CGPointMake(0, 1280.0), _coordinateTransform);
  
  CGContextSaveGState(context);
  CGContextClipToRect(context, CGRectApplyAffineTransform(CGRectMake(0, 1280.0 - height, 720, 1280), _coordinateTransform));
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

// This functionality adapted from: https://stackoverflow.com/a/20058585
- (void)draw:(NSString *)type context:(CGContextRef)context props:(NSDictionary *)props {
  SEL selector = [self selectorForElementType:type];
  
  if (selector != NULL) {
    IMP imp = [self methodForSelector:selector];
    
    void (*drawElement)(id, SEL, CGContextRef, NSDictionary *) = (void *)imp;
    
    drawElement(self, selector, context, props);
  } else {
    NSLog(@"Selector not found for element type '%@'.", type);
  }
}



- (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(NSNumber *)alpha
{
  // Convert hex string to an integer
  unsigned int hexint = [self intFromHexString:hexStr];

  // Create a color object, specifying alpha as well
  UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexint & 0xFF0000) >> 16))/255
                    green:((CGFloat) ((hexint & 0xFF00) >> 8))/255
                     blue:((CGFloat) (hexint & 0xFF))/255
                    alpha:alpha.floatValue];

  return color;
}

- (unsigned int)intFromHexString:(NSString *)hexStr
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

// This is a standard way to pull x/y/width/height values from props and create a
// CGRect which is commonly used for positioning elements. The modifier parameter
// is there to support having multiple rectangle configs in the case that some draw
// functions need that. This is necessary because the props must be flat key/value
// pairs instead of nested objects to allow for simpler animation (preventing
// base value mutation during animation).
- (CGRect)rectFromProps:(NSDictionary *)props withModifier:(nullable NSString *)modifier {
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
  
  return CGRectApplyAffineTransform(rect, _coordinateTransform);
}

@end
