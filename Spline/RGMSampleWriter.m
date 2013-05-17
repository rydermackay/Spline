//
//  RGMSampleWriter.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-11.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMSampleWriter.h"

@interface RGMSampleWriter ()
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@end

@implementation RGMSampleWriter {
    dispatch_queue_t _movieWritingQueue;
}

- (id)initWithURL:(NSURL *)URL
{
    NSParameterAssert(URL);
    if (self = [super init]) {
        _URL = URL;
    }
    
    return self;
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType
{
    NSParameterAssert(sampleBuffer);
    
    if (_movieWritingQueue == NULL) {
        _movieWritingQueue = dispatch_queue_create("com.rydermackay.movieWritingQueue", DISPATCH_QUEUE_SERIAL);
    }
    
    CFRetain(sampleBuffer);
    dispatch_async(_movieWritingQueue, ^{
        
        NSError *error;
        
        if (!self.assetWriter) {
            self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.URL fileType:AVFileTypeMPEG4 error:&error];
            if (!self.assetWriter) {
                NSLog(@"error creating asset writer: %@", error);
            }
        }
        
        if (!self.audioInput && mediaType == AVMediaTypeAudio) {
            NSDictionary *outputSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC)};
            self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                 outputSettings:outputSettings
                                                               sourceFormatHint:CMSampleBufferGetFormatDescription(sampleBuffer)];
            self.audioInput.expectsMediaDataInRealTime = YES;
            if ([self.assetWriter canApplyOutputSettings:outputSettings forMediaType:AVMediaTypeAudio]) {
                if ([self.assetWriter canAddInput:self.audioInput]) {
                    [self.assetWriter addInput:self.audioInput];
                } else {
                    NSLog(@"couldn't add audio input");
                }
            } else {
                NSLog(@"couldn't apply audio settings");
            }
        }
        
        if (!self.videoInput && mediaType == AVMediaTypeVideo) {
            NSDictionary *outputSettings = @{AVVideoCodecKey : AVVideoCodecH264};
            if ([self.assetWriter canApplyOutputSettings:outputSettings forMediaType:AVMediaTypeVideo]) {
                self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                     outputSettings:outputSettings
                                                                   sourceFormatHint:CMSampleBufferGetFormatDescription(sampleBuffer)];
                self.videoInput.expectsMediaDataInRealTime = YES;
                if ([self.assetWriter canAddInput:self.videoInput]) {
                    [self.assetWriter addInput:self.videoInput];
                } else {
                    NSLog(@"couldn't add video input");
                }
            } else {
                NSLog(@"couldn't apply video settings");
            }
        }
        
        if (self.assetWriter.status != AVAssetWriterStatusWriting) {
            
            if (!(self.videoInput && self.audioInput)) {
                return;
            }
            
            if ([mediaType isEqualToString:AVMediaTypeAudio]) {
                return;
            }
            
            if ([self.assetWriter startWriting]) {
                [self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
            } else {
                NSLog(@"error starting writing: %@", self.assetWriter.error);
            }
        }
        
        if ([mediaType isEqualToString:AVMediaTypeAudio]) {
            if (self.audioInput.isReadyForMoreMediaData) {
                if (![self.audioInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"error appending sample buffer: %@", self.assetWriter.error);
                }
            }
        } else if ([mediaType isEqualToString:AVMediaTypeVideo]) {
            if (self.videoInput.isReadyForMoreMediaData) {
                if (![self.videoInput appendSampleBuffer:sampleBuffer]) {
                    NSLog(@"error appending sample buffer: %@", self.assetWriter.error);
                }
            }
        }
        CFRelease(sampleBuffer);
    });
}

- (void)finish:(void (^)())completion
{
    dispatch_async(_movieWritingQueue, ^{
        [self.assetWriter finishWritingWithCompletionHandler:^{
            if (self.assetWriter.status == AVAssetWriterStatusFailed) {
                NSLog(@"error finishing: %@", self.assetWriter.error);
            }
            dispatch_async(dispatch_get_main_queue(), completion);
        }];
    });
}

@end
