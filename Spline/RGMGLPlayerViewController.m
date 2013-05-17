//
//  RGMGLPlayerViewController.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-14.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMGLPlayerViewController.h"
#import <GLKit/GLKit.h>
#import <OpenGLES/EAGL.h>
#import <CoreImage/CoreImage.h>

@interface RGMGLPlayerViewController () <AVPlayerItemOutputPullDelegate, GLKViewDelegate>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic, strong) EAGLContext *eaglContext;
@property (nonatomic, strong) IBOutlet GLKView *glkView;
@property (nonatomic, strong) IBOutlet UISlider *slider;
@end

@implementation RGMGLPlayerViewController {
    CVPixelBufferRef _pixelBuffer;
    CVOpenGLESTextureCacheRef _textureCache;
    CVOpenGLESTextureRef _texture;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    self.glkView.context = self.eaglContext;
    self.glkView.enableSetNeedsDisplay = NO;
    self.glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
    self.glkView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    self.glkView.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
    self.glkView.delegate = self;
    self.context = [CIContext contextWithEAGLContext:self.eaglContext options:@{kCIContextWorkingColorSpace: [NSNull null]}];
    
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 100, 44)];
    self.slider.minimumValue = 0;
    self.slider.maximumValue = 1;
    self.navigationItem.titleView = self.slider;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupPlaybackWithAsset:self.asset];
        });
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.displayLink invalidate];
    self.displayLink = nil;
    self.player.rate = 0;
    self.player = nil;
}

- (void)setupPlaybackWithAsset:(AVAsset *)asset
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    NSDictionary *options = @{ (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                               (__bridge NSString *)kCVPixelBufferOpenGLESCompatibilityKey : @YES };
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:options];
    self.videoOutput.suppressesPlayerRendering = YES;
    [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:1];
    [self.videoOutput setDelegate:self queue:dispatch_get_main_queue()];
    [item addOutput:self.videoOutput];
    
    self.player = [AVPlayer playerWithPlayerItem:item];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [self.player play];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkFired:)];
    self.displayLink.paused = YES;
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)displayLinkFired:(CADisplayLink *)sender
{
    NSTimeInterval nextDisplayTime = sender.timestamp + sender.duration;
    CMTime itemTime = [self.videoOutput itemTimeForHostTime:nextDisplayTime];
    
    if ([self.videoOutput hasNewPixelBufferForItemTime:itemTime]) {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:itemTime itemTimeForDisplay:nil];
        [self.glkView display];
    } else {
        [self.videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:1];
        self.displayLink.paused = YES;
    }
}

#pragma mark - GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // TODO: make me fast
    
    if (_textureCache == NULL) {
        CVOpenGLESTextureCacheCreate(NULL,
                                     NULL,
                                     self.eaglContext,
                                     NULL,
                                     &_textureCache);
    } else {
        CVOpenGLESTextureCacheFlush(_textureCache, 0);
    }
    
    if (_texture) {
        CFRelease(_texture);
        _texture = NULL;
    }
    
    size_t width = CVPixelBufferGetWidth(_pixelBuffer);
    size_t height = CVPixelBufferGetHeight(_pixelBuffer);
    
    CVReturn result = CVOpenGLESTextureCacheCreateTextureFromImage(NULL,
                                                                   _textureCache,
                                                                   _pixelBuffer,
                                                                   NULL,
                                                                   GL_TEXTURE_2D,
                                                                   GL_RGBA,
                                                                   width,
                                                                   height,
                                                                   GL_BGRA,
                                                                   GL_UNSIGNED_BYTE,
                                                                   0,
                                                                   &_texture);
    if (result != kCVReturnSuccess) {
        NSLog(@"error creating texture: %i", result);
    }
    
    glBindTexture(CVOpenGLESTextureGetTarget(_texture), CVOpenGLESTextureGetName(_texture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    // new and fast!!
    CIImage *image = [CIImage imageWithTexture:CVOpenGLESTextureGetName(_texture)
                                          size:CGSizeMake(width, height)
                                       flipped:YES
                                    colorSpace:NULL];
    // old and slow
    // CIImage *image = [CIImage imageWithCVPixelBuffer:_pixelBuffer options:nil];
    
    static CIFilter *filter;
    if (!filter) {
        filter = [CIFilter filterWithName:@"CIColorMonochrome"];
        [filter setDefaults];
        [filter setValue:[CIColor colorWithRed:0 green:1 blue:0] forKey:@"inputColor"];
    }
    
    [filter setValue:image forKey:kCIInputImageKey];
    [filter setValue:@(self.slider.value) forKey:@"inputIntensity"];
    
    CIImage *outputImage = filter.outputImage;
    
    CGRect drawableRect = CGRectMake(0, 0, view.drawableWidth, view.drawableHeight);
    CGRect aspectRect = AVMakeRectWithAspectRatioInsideRect(image.extent.size, drawableRect);
    [self.context drawImage:outputImage inRect:aspectRect fromRect:image.extent];
}

#pragma mark - Notifications

- (void)itemDidPlayToEnd:(NSNotification *)note
{
    [[note object] seekToTime:kCMTimeZero];
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    self.displayLink.paused = NO;
}

- (void)outputSequenceWasFlushed:(AVPlayerItemOutput *)output
{
    // discard queued samples
}

@end
