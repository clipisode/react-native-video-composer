#import "CLPThemeOverlayLayer.h"

@implementation CLPThemeOverlayLayer

@dynamic progress;
//@synthesize fillColor, strokeColor, strokeWidth;
//
//...

- (id)init {
    self = [super init];
  
    if (self) {
      self.progress = 0;
    
      [self setNeedsDisplay];
    }
  
    return self;
}


//- (void)layoutSublayers {
//  [super layoutSublayers];
//
//      NSLog(@"layer beginTime = %f", self.beginTime);
//}

- (instancetype)initWithLayer:(id)layer
{
  if (self = [super initWithLayer:layer]) {
    if ([layer isKindOfClass:[CLPThemeOverlayLayer class]]) {
      CLPThemeOverlayLayer *other = (CLPThemeOverlayLayer *)layer;
      self.progress = other.progress;
    }
  }
  
  return self;
}

- (void)renderInContext:(CGContextRef)ctx
{
  NSLog(@"layer PROGRESS is now = %f", self.progress);
  
  [super renderInContext:ctx];
}

+ (BOOL)needsDisplayForKey:(NSString *)key {
  if ([key isEqualToString:@"progress"]) {
    return YES;
  }

  return [super needsDisplayForKey:key];
}

- (void)setProgress:(CGFloat)progress {
  NSLog(@"layer setProgress is now = %f", progress);
}

- (void)drawInContext:(CGContextRef)ctx {
  
  NSLog(@"layer progress is now = %f", self.progress);
//
//  NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:@"firstsecondthird"];
//  [str addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0,5)];
//  [str addAttribute:NSForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(5,6)];
//  [str addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(11,5)];
//
//  return str;
//
  
  
  
  
  
  // Create the path
  CGPoint center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
  CGFloat radius = MIN(center.x, center.y);

  CGContextBeginPath(ctx);
  CGContextMoveToPoint(ctx, center.x, center.y);

  CGPoint p1 = CGPointMake(center.x + radius * cosf(5.2), center.y + radius * sinf(5.2));
  CGContextAddLineToPoint(ctx, p1.x, p1.y);

  int clockwise = YES;
  CGContextAddArc(ctx, center.x, center.y, radius, 5.2, 90.2 - (15*self.progress), clockwise);

  CGContextClosePath(ctx);

  
  // Color it
  CGContextSetFillColorWithColor(ctx, [[UIColor blueColor] CGColor]);
  CGContextSetStrokeColorWithColor(ctx, [[UIColor redColor] CGColor]);
  CGContextSetLineWidth(ctx, 2.0);

  CGContextDrawPath(ctx, kCGPathFillStroke);
}

@end
