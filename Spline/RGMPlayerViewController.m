//
//  RGMPlayerViewController.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-12.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMPlayerViewController.h"
#import "RGMScrubberControl.h"

@interface RGMPlayerViewController () <RGMScrubberControlDataSource>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) RGMScrubberControl *scrubber;
@property (nonatomic, strong) AVSynchronizedLayer *synchronizedLayer;
- (IBAction)addMagic:(id)sender;
@end

@implementation RGMPlayerViewController {
    id _periodicObserver;
    BOOL _recordingPan;
    NSMutableArray *_info;
    NSDate *_startDate;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.scrubber = [[RGMScrubberControl alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.navigationController.navigationBar.frame) * 0.5f, 30)];
    self.navigationItem.titleView = self.scrubber;
    self.scrubber.datasource = self;
    [self.scrubber addTarget:self action:@selector(scrubbingBegan:) forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubbed:) forControlEvents:UIControlEventValueChanged];
    [self.scrubber addTarget:self action:@selector(scrubbingEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [self.scrubber reloadData];
}

- (IBAction)scrubbingBegan:(RGMScrubberControl *)sender
{
    [self.player pause];
}

- (IBAction)scrubbed:(RGMScrubberControl *)sender
{
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem seekToTime:sender.currentTime];
}

- (IBAction)scrubbingEnded:(RGMScrubberControl *)sender
{
    [self.player play];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    __weak typeof(self) weakSelf = self;
    NSArray *keys = @[@"tracks", @"playable"];
    [self.asset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf loadedAsset:self.asset keys:keys];
        });
    }];
}

- (void)loadedAsset:(AVAsset *)asset keys:(NSArray *)keys
{
    for (NSString *key in keys) {
        NSError *error;
        AVKeyValueStatus status = [asset statusOfValueForKey:key error:&error];
        if (status != AVKeyValueStatusLoaded) {
            NSLog(@"key not loaded: %@", key);
            return;
        }
    }
    
    if (!asset.isPlayable) {
        NSLog(@"asset not playable");
        return;
    }
    
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:item];
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [self.player play];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    [self.playerLayer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew context:&_playerLayer];
    
    __weak typeof(self)weakSelf = self;
    _periodicObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.15, 600) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        if (weakSelf.player.rate != 0) {
            weakSelf.scrubber.currentTime = time;
        }
    }];
}

- (void)itemDidPlayToEnd:(NSNotification *)note
{
    [note.object seekToTime:kCMTimeZero];
    [self addCircle];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.player removeTimeObserver:_periodicObserver];
    [self.player pause];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [self.asset cancelLoading];
    [self.playerLayer removeObserver:self forKeyPath:@"readyForDisplay"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == &_playerLayer) {
        if (self.playerLayer.isReadyForDisplay) {
            self.playerLayer.frame = self.view.layer.bounds;
            [self.view.layer insertSublayer:self.playerLayer atIndex:0];
        } else {
            [self.playerLayer removeFromSuperlayer];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Notifications

#pragma mark - RGMScrubberControlDataSource

- (CMTime)scrubberDuration:(RGMScrubberControl *)scrubber
{
    return self.asset.duration;
}

- (CGSize)scrubberAspect:(RGMScrubberControl *)scrubber
{
    AVAssetTrack *videoTrack = [self.asset tracksWithMediaType:AVMediaTypeVideo][0];
    return videoTrack.naturalSize;
}

- (void)scrubber:(RGMScrubberControl *)scrubber imagesForTimes:(NSArray *)times
{
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(100, 100);
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    [generator generateCGImagesAsynchronouslyForTimes:times
                                    completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
                                        if (result == AVAssetImageGeneratorSucceeded) {
                                            UIImage *uiimage = [UIImage imageWithCGImage:image];
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                [scrubber setImage:uiimage atTime:requestedTime];
                                            });
                                        } else {
                                            NSLog(@"error generating image: %@", error);
                                        }
                                    }];
}

- (IBAction)addMagic:(id)sender
{
    if (_recordingPan) {
        return;
    }
    
    [self.player seekToTime:kCMTimeZero
          completionHandler:^(BOOL finished) {
              if (finished) {
                  [self.player play];
                  [self recordPan];
              }
          }];
}

- (void)recordPan
{
    _recordingPan = YES;
    
    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    [self.view addGestureRecognizer:recognizer];
    _info = [NSMutableArray new];
    _startDate = [NSDate date];
    [self.synchronizedLayer removeFromSuperlayer];
    self.synchronizedLayer = nil;
}

- (IBAction)didPan:(UIPanGestureRecognizer *)sender
{
    NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:_startDate];
    NSDictionary *info = @{@"time": @(interval / duration), @"point": [NSValue valueWithCGPoint:[sender locationInView:self.view]]};
    [_info addObject:info];
}

- (void)addCircle
{
    if (!_recordingPan) {
        return;
    }
    
    CAShapeLayer *shape = [CAShapeLayer layer];
    shape.bounds = CGRectMake(0, 0, 100, 100);
    shape.path = [UIBezierPath bezierPathWithOvalInRect:shape.bounds].CGPath;
    shape.fillColor = [UIColor redColor].CGColor;
    
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    animation.beginTime = AVCoreAnimationBeginTimeAtZero;
    animation.duration = CMTimeGetSeconds(self.player.currentItem.duration);
    animation.removedOnCompletion = NO;
    animation.keyTimes = [_info valueForKey:@"time"];
    animation.values = [_info valueForKey:@"point"];
    
    [shape addAnimation:animation forKey:@"position"];
    
    self.synchronizedLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:self.player.currentItem];
    self.synchronizedLayer.frame = self.view.layer.bounds;
    [self.synchronizedLayer addSublayer:shape];
    [self.view.layer addSublayer:self.synchronizedLayer];
    
    _info = nil;
    _startDate = nil;
    self.view.gestureRecognizers = nil;
    _recordingPan = NO;
}

@end
