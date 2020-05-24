#import <AVKit/AVKit.h>

@interface CLPThemePainter: NSObject

@property (nonatomic, retain) UIImage *icon;
@property (nonatomic, retain) UIImage *logo;
@property (nonatomic, retain) UIImage *arrow;

- (id)initWithHeight:(NSNumber *)height;
- (void)drawBackground:(CGContextRef)context;
- (void)draw:(NSString *)type context:(CGContextRef)context props:(NSDictionary *)props;

@end
