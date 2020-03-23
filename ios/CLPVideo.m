#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <React/RCTComponent.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTComponent.h>
#import <Photos/Photos.h>

@interface CLPVideo : UIView <AVPlayerViewControllerDelegate>

@property (nonatomic, copy) RCTDirectEventBlock onVideoProgress;

@end

@implementation CLPVideo
{
  AVMutableComposition *_mixComposition;
  AVPlayerLayer *_playerLayer;
  AVPlayer *_player;
  AVPlayerItem *_playerItem;
  NSDictionary *_composition;
  AVMutableVideoComposition *_mainCompositionInst;
  AVSynchronizedLayer *_syncLayer;
  CALayer *_overlayLayer;
  CMTime lastEndTime;
  AVMutableCompositionTrack *videoTrack;
  
  id _timeObserver;
  
  BOOL _paused;
  float _rate;
}

- (instancetype)init
{
  if (self = [super init]) {
    _rate = 1.0;
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
//  _syncLayer.frame = self.bounds;
  _syncLayer.frame = self.bounds;
  _syncLayer.anchorPoint = CGPointMake(0.0, 0.0);
  _syncLayer.transform = CATransform3DConcat(CATransform3DMakeScale(self.bounds.size.width / 720.0, self.bounds.size.height / 1280.0, 1), CATransform3DMakeTranslation(-self.bounds.size.width / 2, -self.bounds.size.height / 2, 0.0));
}

- (void)removeFromSuperview
{
  if (_playerLayer.player != nil) {
    [_playerLayer.player pause];
    _playerLayer.player = nil;
  }
  
  [_playerLayer removeFromSuperlayer];
  _playerLayer = nil;
  
  [super removeFromSuperview];
}

-(void)addPlayerTimeObserver
{
  const Float64 progressUpdateIntervalMS = 250.0 / 1000;
  // @see endScrubbing in AVPlayerDemoPlaybackViewController.m
  // of https://developer.apple.com/library/ios/samplecode/AVPlayerDemo/Introduction/Intro.html
  __weak CLPVideo *weakSelf = self;
  _timeObserver = [_player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(progressUpdateIntervalMS, NSEC_PER_SEC)
                                                        queue:NULL
                                                   usingBlock:^(CMTime time) { [weakSelf sendProgressUpdate]; }
                   ];
}

/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
  if (_timeObserver)
  {
    [_player removeTimeObserver:_timeObserver];
    _timeObserver = nil;
  }
}

- (void)sendProgressUpdate
{
  AVPlayerItem *video = [_player currentItem];
  
  if (video == nil || video.status != AVPlayerItemStatusReadyToPlay) {
    return;
  }
  
  CMTime playerDuration = video.duration;
  
  CMTime currentTime = _player.currentTime;
//  const Float64 duration = CMTimeGetSeconds(playerDuration);
  const Float64 currentTimeSecs = CMTimeGetSeconds(currentTime);
//
//  [[NSNotificationCenter defaultCenter] postNotificationName:@"RCTVideo_progress" object:nil userInfo:@{@"progress": [NSNumber numberWithDouble: currentTimeSecs / duration]}];
  
  if( currentTimeSecs >= 0 && self.onVideoProgress) {
    self.onVideoProgress(@{
                           @"currentTime": [NSNumber numberWithFloat:CMTimeGetSeconds(currentTime)],
                           @"atValue": [NSNumber numberWithLongLong:currentTime.value],
                           @"atTimescale": [NSNumber numberWithInt:currentTime.timescale],
//                           @"target": self.reactTag,
                           });
  }
}

- (NSAttributedString *)createBasicString:(NSString *)text
{
  NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:@"firstsecondthird"];
  [str addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(0,5)];
  [str addAttribute:NSForegroundColorAttributeName value:[UIColor greenColor] range:NSMakeRange(5,6)];
  [str addAttribute:NSForegroundColorAttributeName value:[UIColor blueColor] range:NSMakeRange(11,5)];
  
  return str;
}

- (CATextLayer *)createTextLayer:(NSAttributedString *)attributedString
{
  CATextLayer *textLayer = [CATextLayer layer];
  
  textLayer.string = attributedString;
  textLayer.shouldRasterize = true;
  
  return textLayer;
}

- (CABasicAnimation *)createPulseAnimation
{
  CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
  
  scaleAnimation.fromValue = [NSNumber numberWithFloat:0.8];
  scaleAnimation.toValue = [NSNumber numberWithFloat:1.2];
  scaleAnimation.duration = 3;
  scaleAnimation.repeatCount = CGFLOAT_MAX;
  scaleAnimation.autoreverses = YES;
  scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
  scaleAnimation.beginTime = AVCoreAnimationBeginTimeAtZero;
  scaleAnimation.removedOnCompletion = NO;
  
  return scaleAnimation;
}

- (CALayer *)createParentLayer:(CALayer *)videoLayer
{
  CALayer *parentLayer = [CALayer layer];
  parentLayer.frame = CGRectMake(0.0, 0.0, 720.0, 1280.0);
  parentLayer.backgroundColor = [[UIColor purpleColor] CGColor];
  
  videoLayer.frame = CGRectMake(20, 20, parentLayer.frame.size.width - 40,  parentLayer.frame.size.height - 40);
  
  [parentLayer addSublayer:videoLayer];
  
  // ADD OVERLAY
  _overlayLayer = [CALayer layer];
  _overlayLayer.frame = CGRectMake(40, 40, 40, 40);
  _overlayLayer.backgroundColor = [[UIColor blueColor] CGColor];
  
  NSAttributedString *str = [self createBasicString:@"firstsecondthird"];
  CATextLayer *textLayer = [self createTextLayer:str];
  
  textLayer.frame = CGRectMake(80, 80, 300, 200);
  
  CABasicAnimation *pulse = [self createPulseAnimation];
  
  [textLayer addAnimation:pulse forKey:@"scale"];
  
  [textLayer displayIfNeeded];
  
  [parentLayer addSublayer:textLayer];
  [parentLayer addSublayer:_overlayLayer];
  
  return parentLayer;
}

- (void)setComposition:(NSDictionary *)composition
{
  _composition = composition;
  
  if (_mixComposition == nil) {
    _mixComposition = [[AVMutableComposition alloc] init];
    _playerItem = [AVPlayerItem playerItemWithAsset:_mixComposition];
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    _player.rate = 1.0;
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.needsDisplayOnBoundsChange = YES;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    _syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:_playerItem];
    [self.layer addSublayer:_syncLayer];
    
    [self addPlayerTimeObserver];
    
    CALayer *parentLayer = [self createParentLayer:_playerLayer];
    
//    _syncLayer.frame = parentLayer.frame;
//    parentLayer.frame = self.bounds;
    [_syncLayer addSublayer:parentLayer];
    
//
//
//    [_syncLayer addSublayer:textLayer];
//    [_syncLayer addSublayer:_overlayLayer];
//    [_playerLayer addSublayer:_syncLayer];
  }
  
  [self load];
}

- (void)setPaused:(BOOL)paused {
  _paused = paused;
  
  if (paused) {
    [_player pause];
  } else {
    [_player play];
  }
}

- (void)setSeek:(NSDictionary *)info
{
  NSNumber *seekTime = info[@"time"];
  
  int timeScale = 1000;
  
  if (_playerItem && _playerItem.status == AVPlayerItemStatusReadyToPlay) {
    CMTime to = CMTimeMakeWithSeconds([seekTime floatValue], timeScale);
    
    [_player seekToTime:to toleranceBefore:CMTimeMakeWithSeconds(0.1, timeScale) toleranceAfter:CMTimeMakeWithSeconds(0.1, timeScale)];
  }
}

- (void)setRate:(float)rate
{
  _rate = rate;
  
  _player.rate = rate;
}

- (UIImage *)imageWithColor:(UIColor *)color rectSize:(CGRect)imageSize {
    CGRect rect = imageSize;
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    [color setFill];
    UIRectFill(rect);   // Fill it with your color
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)save:(NSString *)outPath resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
  mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, lastEndTime);
  
  AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
  [videolayerInstruction setOpacity:0.0 atTime:lastEndTime];
  
  mainInstruction.layerInstructions = [NSArray arrayWithObjects:videolayerInstruction, nil];

  _mainCompositionInst = [AVMutableVideoComposition videoComposition];
  
  _mainCompositionInst.renderSize = CGSizeMake(720.0, 1280.0);
  
  _mainCompositionInst.instructions = [NSArray arrayWithObject:mainInstruction];
  _mainCompositionInst.frameDuration = CMTimeMake(1, 30);
  
  CALayer *videoLayer = [CALayer layer];
  CALayer *parentLayer = [self createParentLayer:videoLayer];
  parentLayer.geometryFlipped = YES;
  
//  CALayer *backgroundLayer = [CALayer layer];
//  UIImage *borderImage = [self imageWithColor:[UIColor blueColor] rectSize:CGRectMake(0, 0, 720, 1280)];
//  [backgroundLayer setContents:(id)[borderImage CGImage]];
//  backgroundLayer.frame = CGRectMake(0, 0, 720, 1280);
//  [backgroundLayer setMasksToBounds:YES];
//  CALayer *videoLayer = [CALayer layer];
//     videoLayer.frame = CGRectMake(20, 20, 680, 1240);
  
//  CALayer *parentLayer = [CALayer layer];
  
//  [parentLayer addSublayer:backgroundLayer];
//  [parentLayer addSublayer:videoLayer];

  
  _mainCompositionInst.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];

  AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:_mixComposition                                                                                           presetName:AVAssetExportPresetHighestQuality];
//  [compositionData setObject:exporter forKey:@"exportSession"];
  
  exporter.outputURL = [NSURL URLWithString:outPath];
  exporter.outputFileType = AVFileTypeMPEG4;
  exporter.shouldOptimizeForNetworkUse = YES;
  exporter.videoComposition = _mainCompositionInst;
  
  [exporter exportAsynchronouslyWithCompletionHandler:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:exporter.outputURL];
      } completionHandler:^(BOOL success, NSError * _Nullable error) {
        resolve(nil);
      }];
    });
  }];
}

- (void)load
{
  NSDictionary *composition = _composition;
  // BEGIN COMPOSITION SETUP
  
  videoTrack = [_mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  
  lastEndTime = kCMTimeZero;
  
  NSArray *videos = composition[@"videos"];
  
  for (NSDictionary* video in videos) {
    NSString *path = video[@"path"];
    // NSNumber* startAt = video[@"startAt"];
    
    NSURL *url = [NSURL URLWithString:path];
    AVAsset *asset = [AVAsset assetWithURL:url];
    
    CMTimeRange range = CMTimeRangeMake(kCMTimeZero, asset.duration);
    NSArray* assetVideoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack* firstVideoTrack = assetVideoTracks[0];
    [videoTrack insertTimeRange:range ofTrack:firstVideoTrack atTime:lastEndTime error:nil];
          
    lastEndTime = CMTimeAdd(lastEndTime, asset.duration);
  }
}

@end
