//
//  RGMRecordingViewController.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-11.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMRecordingViewController.h"
#import "RGMSampleWriter.h"

@interface RGMRecordingViewController () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) RGMSampleWriter *sampleWriter;
@property (atomic, assign, getter = isRecording) BOOL recording;
@property (atomic, assign, getter = isReady) BOOL ready;
@property (nonatomic, strong) NSMutableArray *URLs;
@property (nonatomic, strong) AVAssetExportSession *exportSession;
@property (nonatomic, strong) UIProgressView *progressView;
- (IBAction)stop:(id)sender;
@end



@implementation RGMRecordingViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.URLs = [NSMutableArray new];
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.hidden = YES;
    [self.view addSubview:self.progressView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    
    [self.session beginConfiguration];
    
    // audio
    NSError *error;
    AVCaptureDevice *audioDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio][0];
    AVCaptureDeviceInput *audioIn = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (!audioIn) {
        NSLog(@"error creating audio input: %@", error);
    }
    if ([self.session canAddInput:audioIn]) {
        [self.session addInput:audioIn];
    }
    
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioOutput setSampleBufferDelegate:self queue:dispatch_queue_create("com.rydermackay.audioQueue", DISPATCH_QUEUE_SERIAL)];
    
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    
    
    
    // video
    AVCaptureDevice *videoDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][0];
    AVCaptureDeviceInput *videoIn = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&error];
    if (!videoIn) {
        NSLog(@"error creating video input: %@", error);
    }
    if ([self.session canAddInput:videoIn]) {
        [self.session addInput:videoIn];
    }
    
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoOutput setSampleBufferDelegate:self queue:dispatch_queue_create("com.rydermackay.videoQueue", DISPATCH_QUEUE_SERIAL)];
    
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
    }
    
    AVCaptureConnection *connection = self.videoOutput.connections[0];
    switch (self.interfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIInterfaceOrientationPortrait:
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            break;
    }
    
    [self.session commitConfiguration];
    
    [self.session startRunning];
    
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    layer.frame = self.view.layer.bounds;
    layer.orientation = connection.videoOrientation;
    [self.view.layer insertSublayer:layer atIndex:0];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.session stopRunning];
    self.session = nil;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.progressView.bounds = CGRectMake(0, 0, 300, 0);
    [self.progressView sizeToFit];
    self.progressView.center = CGPointMake(self.view.center.x, self.view.center.y + 100);
}

#pragma mark - AVCaptureAudio/VideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.isRecording) {
        return;
    }
    
    if (!self.sampleWriter) {
        NSString *filename = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"];
        NSURL *URL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), filename]];
        self.sampleWriter = [[RGMSampleWriter alloc] initWithURL:URL];
    }
    
    if (captureOutput == self.audioOutput) {
        [self.sampleWriter appendSampleBuffer:sampleBuffer mediaType:AVMediaTypeAudio];
    } else if (captureOutput == self.videoOutput) {
        [self.sampleWriter appendSampleBuffer:sampleBuffer mediaType:AVMediaTypeVideo];
    }
}

#pragma mark - IBActions

- (IBAction)stop:(id)sender
{
    if (!self.isReady) {
        return;
    }
    
    [self.session stopRunning];
    [self composeAssetsFromURLs:self.URLs];
}

- (void)composeAssetsFromURLs:(NSArray *)URLs;
{
    AVMutableComposition *composition = [AVMutableComposition composition];
    CMTime insertPoint = kCMTimeZero;
    
    for (NSURL *URL in URLs) {
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:URL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
        NSError *error;
        if (![composition insertTimeRange:CMTimeRangeMake(kCMTimeZero, asset.duration) ofAsset:asset atTime:insertPoint error:&error]) {
            NSLog(@"error inserting track: %@", error);
        } else {
            insertPoint = CMTimeAdd(insertPoint, asset.duration);
        }
    }
    
    NSString *filename = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"mp4"];
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSURL *URL = [NSURL fileURLWithPath:[docs stringByAppendingPathComponent:filename]];
    
    self.exportSession = [AVAssetExportSession exportSessionWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    self.exportSession.outputFileType = AVFileTypeMPEG4;
    self.exportSession.outputURL = URL;
    [self.exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:nil];
        });
    }];
    
    [self showProgressWithSession:self.exportSession];
}

- (void)showProgressWithSession:(AVAssetExportSession *)exportSession
{
    switch (exportSession.status) {
        case AVAssetExportSessionStatusWaiting:
        case AVAssetExportSessionStatusExporting:
            self.progressView.hidden = NO;
            [self.progressView setProgress:exportSession.progress animated:YES];
            [self performSelector:@selector(showProgressWithSession:) withObject:exportSession afterDelay:0.1 inModes:@[NSRunLoopCommonModes]];
            break;
        default:
            self.progressView.hidden = YES;
            break;
    }
}

#pragma mark - UIResponder

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.recording = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self stopRecording];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self stopRecording];
}

- (void)stopRecording
{
    self.recording = NO;
    self.ready = NO;
    [self.sampleWriter finish:^{
        [self.URLs addObject:self.sampleWriter.URL];
        self.ready = YES;
        self.sampleWriter = nil;
    }];
}

@end
