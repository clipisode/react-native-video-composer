#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <React/RCTComponent.h>
#import <React/RCTBridgeModule.h>
#import <React/RCTComponent.h>
#import <Photos/Photos.h>
#import "CLPThemeCompositor.h"


@interface CLPVideo : UIView <AVPlayerViewControllerDelegate>

@property (nonatomic, copy) RCTDirectEventBlock onVideoProgress;
@property (nonatomic, copy) RCTDirectEventBlock onVideoLoad;
@property (nonatomic, copy) RCTDirectEventBlock onExportProgress;

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
  CMTime lastEndTime;
  NSMutableArray *_videoTracks;
  AVMutableCompositionTrack *_audioTrack;
  
  id _timeObserver;
  
  BOOL _paused;
  float _rate;
}

static NSString *const statusKeyPath = @"status";

- (instancetype)init
{
  if (self = [super init]) {
    _rate = 1.0;
    _videoTracks = [NSMutableArray array];
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];

  _syncLayer.frame = self.bounds;
  self.layer.anchorPoint = CGPointMake(0.0, 0.0);
  self.layer.transform = CATransform3DConcat(CATransform3DMakeScale(self.bounds.size.width / 720.0, self.bounds.size.height / 1280.0, 1), CATransform3DMakeTranslation(-self.bounds.size.width / 2, -self.bounds.size.height / 2, 0.0));
}

- (void)removeFromSuperview
{
  if (_playerLayer.player != nil) {
    [_playerLayer.player pause];
    _playerLayer.player = nil;
  }
  
  [_playerLayer removeFromSuperlayer];
  [self removePlayerItemObservers];
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

- (CALayer *)createParentLayer:(CALayer *)videoLayer overlay:(CALayer *)overlayLayer
{
  CALayer *parentLayer = [CALayer layer];

  parentLayer.drawsAsynchronously = NO;
  parentLayer.frame = CGRectMake(0.0, 0.0, 720.0, 1280.0);
  // parentLayer.backgroundColor = [[UIColor purpleColor] CGColor];
  
  videoLayer.frame = parentLayer.frame;
  
  [parentLayer addSublayer:videoLayer];
  
  return parentLayer;
}

- (void)addPlayerItemObservers
{
  [_playerItem addObserver:self forKeyPath:statusKeyPath options:0 context:nil];
//  [_playerItem addObserver:self forKeyPath:playbackBufferEmptyKeyPath options:0 context:nil];
//  [_playerItem addObserver:self forKeyPath:playbackLikelyToKeepUpKeyPath options:0 context:nil];
//  [_playerItem addObserver:self forKeyPath:timedMetadata options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removePlayerItemObservers
{
  [_playerItem removeObserver:self forKeyPath:statusKeyPath];
//  [_playerItem removeObserver:self forKeyPath:playbackBufferEmptyKeyPath];
//  [_playerItem removeObserver:self forKeyPath:playbackLikelyToKeepUpKeyPath];
//  [_playerItem removeObserver:self forKeyPath:timedMetadata];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (object != _playerItem) {
    return;
  }
  
  // handle status change
  if ([keyPath isEqualToString:statusKeyPath]) {
    if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
      float duration = CMTimeGetSeconds(_playerItem.asset.duration);
      
      if (isnan(duration)) {
        duration = 0.0;
      }
      
      if (self.onVideoLoad != nil) {
        self.onVideoLoad(@{ @"duration": [NSNumber numberWithFloat:duration] });
      }
    }
  }
}

- (void)setComposition:(NSDictionary *)composition
{
  _composition = composition;
  
  NSLog(@"Composition set... %@", composition);
  
  if (_mixComposition == nil) {
    _mixComposition = [AVMutableComposition composition];
    _playerItem = [AVPlayerItem playerItemWithAsset:_mixComposition];
    
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    
    [self addPlayerItemObservers];
    
    _playerLayer.needsDisplayOnBoundsChange = YES;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    _syncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:_playerItem];
    [self.layer addSublayer:_syncLayer];
    
    [self addPlayerTimeObserver];
    
    CALayer *parentLayer = [self createParentLayer:_playerLayer overlay:[CALayer layer]];
    
    [_syncLayer addSublayer:parentLayer];
  }
  
  [self load];
  
  // TODO : does this help match the export?
  _playerItem.videoComposition = _mainCompositionInst;
  
  if (_playerItem.customVideoCompositor) {
    if ([_playerItem.customVideoCompositor isKindOfClass:[CLPThemeCompositor class]]) {
      CLPThemeCompositor *themeCompositor = (id)_playerItem.customVideoCompositor;
      
      [themeCompositor setIcon:[UIImage imageNamed:@"iconfortheme.png"]];
      [themeCompositor setLogo:[UIImage imageNamed:@"logofortheme.png"]];
      [themeCompositor setArrow:[UIImage imageNamed:@"swipearrow.png"]];
      [themeCompositor setComposition:_composition];
    }
  }
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
    CMTime tolerance = kCMTimeZero; // CMTimeMakeWithSeconds(0.05, timeScale);
    
    if (!_paused) {
      [_player pause];
    }
    
    [_player seekToTime:to toleranceBefore:tolerance toleranceAfter:tolerance completionHandler:^(BOOL finished) {
      if (!self->_paused) {
        [self->_player play];
      }
    }];
  }
}

- (void)setRate:(float)rate
{
  _rate = rate;

  [_player setRate:rate];
}

- (void)save:(NSString *)outPath resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  [_player pause];

  CALayer *videoLayer = [CALayer layer];
  CALayer *overlayLayer = [CALayer layer];
  
  CALayer *parentLayer = [self createParentLayer:videoLayer overlay:overlayLayer];
  parentLayer.geometryFlipped = YES;

  _mainCompositionInst.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
  
  AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:_mixComposition presetName:AVAssetExportPreset1280x720];

  exporter.outputURL = [NSURL URLWithString:outPath];
  exporter.outputFileType = AVFileTypeMPEG4;
  // exporter.outputFileType = AVFileTypeQuickTimeMovie;
//  exporter.audioMix.
//  exporter.shouldOptimizeForNetworkUse = YES;
  
  exporter.videoComposition = _mainCompositionInst;
  
  if (exporter.customVideoCompositor) {
    if ([exporter.customVideoCompositor isKindOfClass:[CLPThemeCompositor class]]) {
      CLPThemeCompositor *themeCompositor = (id)exporter.customVideoCompositor;
      
      [themeCompositor setIcon:[UIImage imageNamed:@"iconfortheme.png"]];
      [themeCompositor setLogo:[UIImage imageNamed:@"logofortheme.png"]];
      [themeCompositor setArrow:[UIImage imageNamed:@"swipearrow.png"]];
      [themeCompositor setComposition:_composition];
    }
  }
  
  if (_mixComposition.isExportable) {
    if (self.onExportProgress) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer * _Nonnull timer) {
          if (exporter.status == AVAssetExportSessionStatusExporting) {
            self.onExportProgress(@{@"progress": [NSNumber numberWithFloat:exporter.progress]});
          } else if (exporter.status == AVAssetExportSessionStatusCompleted) {
            [timer invalidate];
          }
        }];
      });
    }
    
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
      if (exporter.status == AVAssetExportSessionStatusCompleted) {
        dispatch_async(dispatch_get_main_queue(), ^{
          resolve(NULL);
        });
//        dispatch_async(dispatch_get_main_queue(), ^{
//          [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
//            [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:exporter.outputURL];
//          } completionHandler:^(BOOL success, NSError * _Nullable error) {
//            if (error != nil) {
//              reject(@"ExportError", error.localizedDescription, error);
//            } else {
//              resolve(nil);
//            }
//          }];
//        });
      } else if (exporter.status == AVAssetExportSessionStatusFailed) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (exporter.error) {
            reject(@"ExportError", exporter.error.localizedDescription, exporter.error);
          } else {
            reject(@"ExportError", @"Unknown", exporter.error);
          }
        });
      }
    }];
  } else {
    reject(@"ExportError", @"Not exportable", nil);
  }
}

- (void)addFirstFrame:(AVAssetTrack *)videoTrack forDuration:(CMTime)duration videolayerInstructions:(NSMutableArray *)videolayerInstructions {
  AVMutableCompositionTrack *_startTrack = [_mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  
  CMTimeRange frameOneTimeRange = CMTimeRangeMake(kCMTimeZero, CMTimeMake(1, 30));
  
  [_startTrack insertTimeRange:frameOneTimeRange ofTrack:videoTrack atTime:lastEndTime error:NULL];
  [_startTrack scaleTimeRange:_startTrack.timeRange toDuration:duration];
  [_videoTracks addObject:_startTrack];
  
  AVMutableVideoCompositionLayerInstruction *vli = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:_startTrack];
  
  [vli setOpacity:0.0 atTime:duration];

  [vli setTransform:videoTrack.preferredTransform atTime:kCMTimeZero];
  [videolayerInstructions addObject:vli];

  lastEndTime = CMTimeAdd(lastEndTime, duration);
}

- (void)addLastFrame:(AVAssetTrack *)videoTrack forDuration:(CMTime)duration videolayerInstructions:(NSMutableArray *)videolayerInstructions {
  AVMutableCompositionTrack *_startTrack = [_mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
  
    CMTimeRange lastFrame = CMTimeRangeMake(
                                            CMTimeSubtract(videoTrack.timeRange.duration, CMTimeMake(1, 30)),
                                            CMTimeMake(1, 30)
                                            );
  
    [_startTrack insertTimeRange:lastFrame ofTrack:videoTrack atTime:lastEndTime error:NULL];
    [_startTrack scaleTimeRange:CMTimeRangeMake(lastEndTime, CMTimeMake(1, 30)) toDuration:duration];
    [_videoTracks addObject:_startTrack];
    
    AVMutableVideoCompositionLayerInstruction *vli = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:_startTrack];
    
//    [vli setOpacity:0.0 atTime:duration];
  
    [vli setTransform:videoTrack.preferredTransform atTime:kCMTimeZero];
    [videolayerInstructions addObject:vli];
    
    lastEndTime = CMTimeAdd(lastEndTime, duration);
}

- (void)load
{
  NSDictionary *composition = _composition;
  // BEGIN COMPOSITION SETUP
  
  _audioTrack = [_mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
  
  lastEndTime = kCMTimeZero;
  
  NSArray *videos = composition[@"videos"];
  
  NSMutableArray *videolayerInstructions = [NSMutableArray array];
  
  BOOL first = YES;
  
  for (NSDictionary* video in videos) {
    NSString *path = video[@"path"];
    
    NSURL *url = [NSURL URLWithString:path];
    AVAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@YES}];
    
    // Add video
    NSArray* asset_videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack* first_videoTrack = asset_videoTracks[0];
    
    if (first) {
      [self addFirstFrame:first_videoTrack forDuration:CMTimeMake(2, 1) videolayerInstructions:videolayerInstructions];
    }
    
    AVMutableCompositionTrack *_videoTrack = [_mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    
    [_videoTrack insertTimeRange:first_videoTrack.timeRange ofTrack:first_videoTrack atTime:lastEndTime error:NULL];

    // Add audio
    NSArray* asset_audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    AVAssetTrack* first_audioTrack = asset_audioTracks[0];
//    [_audioTrack insertTimeRange:first_videoTrack.timeRange ofTrack:first_audioTrack atTime:lastEndTime error:nil];
    if (first) {
      [_audioTrack insertTimeRange:first_videoTrack.timeRange ofTrack:first_audioTrack atTime:kCMTimeZero error:nil];
      [_audioTrack insertEmptyTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(60, 30))  ];
    } else {
      [_audioTrack insertTimeRange:first_videoTrack.timeRange ofTrack:first_audioTrack atTime:lastEndTime error:nil];
    }
    
    CMTime nextLastEndTime = CMTimeAdd(lastEndTime, first_videoTrack.timeRange.duration);
    
    [_videoTracks addObject:_videoTrack];
    
    AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:_videoTrack];
    
    if ([videos lastObject] != video) {
      [videolayerInstruction setOpacity:0.0 atTime:nextLastEndTime];
    }

    [videolayerInstruction setTransform:first_videoTrack.preferredTransform atTime:lastEndTime];
    [videolayerInstructions addObject:videolayerInstruction];
    
    lastEndTime = nextLastEndTime;
    
    if (!first) {
      [self addLastFrame:first_videoTrack forDuration:CMTimeMake(3, 1) videolayerInstructions:videolayerInstructions];
    }
    
    first = NO;
  }
  
//  AVMutableCompositionTrack *vt = [_videoTracks lastObject];
//  CMTime lastFrameDuration = CMTimeMake(301, 30);
//  CMTimeRange lastFrameRange = CMTimeRangeMake(CMTimeSubtract(vt.timeRange.duration, CMTimeMake(1, 30)), CMTimeMake(1, 30));
//  [vt scaleTimeRange:lastFrameRange toDuration:lastFrameDuration];
//  [vt insertEmptyTimeRange:CMTimeRangeMake(lastEndTime, CMTimeMakeWithSeconds(2, 1))];
  
  AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];

  mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, lastEndTime);
  mainInstruction.layerInstructions = videolayerInstructions;
  
  _mainCompositionInst = [AVMutableVideoComposition videoComposition];
  _mainCompositionInst.customVideoCompositorClass = [CLPThemeCompositor class];
  
  _mainCompositionInst.renderSize = CGSizeMake(720.0, 1280.0);
  
  _mainCompositionInst.instructions = @[mainInstruction];
  _mainCompositionInst.frameDuration = CMTimeMake(1, 30);
}

@end
