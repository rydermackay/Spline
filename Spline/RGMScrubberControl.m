//
//  RGMScrubberControl.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-12.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMScrubberControl.h"

@interface RGMScrubberControl ()
@property (nonatomic, assign) CMTime duration;
@property (nonatomic, strong) NSMutableDictionary *imageTimeMap;
@property (nonatomic, strong) NSMutableDictionary *viewsTimeMap;
@property (nonatomic, strong) UIImageView *thumb;
@end

@implementation RGMScrubberControl

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        _currentTime = kCMTimeZero;
        _duration = kCMTimeZero;
        self.clipsToBounds = YES;
    }
    
    return self;
}

- (void)reloadData
{
    [self.viewsTimeMap.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.viewsTimeMap = [NSMutableDictionary new];
    self.imageTimeMap = [NSMutableDictionary new];
    
    self.duration = [self.datasource scrubberDuration:self];
    [self.datasource scrubber:self imagesForTimes:[self times]];
    
    self.thumb = [[UIImageView alloc] initWithImage:nil];
    self.thumb.backgroundColor = [UIColor redColor];
    [self addSubview:self.thumb];
}

- (void)setImage:(UIImage *)image atTime:(CMTime)time
{
    UIImageView *imageView = [self imageViewAtTime:[NSValue valueWithCMTime:time]];
    imageView.image = image;
}

- (UIImageView *)imageViewAtTime:(NSValue *)timeValue
{
    UIImageView *view = [self.viewsTimeMap objectForKey:timeValue];
    if (view == nil) {
        view = [[UIImageView alloc] initWithImage:[self.imageTimeMap objectForKey:timeValue]];
        [self insertSubview:view belowSubview:self.thumb];
        [self.viewsTimeMap setObject:view forKey:timeValue];
    }
    
    return view;
}

- (void)setCurrentTime:(CMTime)currentTime
{
    if (CMTIME_COMPARE_INLINE(_currentTime, ==, currentTime)) {
        return;
    }
    
    currentTime = CMTimeClampToRange(currentTime, CMTimeRangeMake(kCMTimeZero, self.duration));
    
    _currentTime = currentTime;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!self.imageTimeMap) {
        [self reloadData];
    }
    
    [[self times] enumerateObjectsUsingBlock:^(NSValue *timeValue, NSUInteger idx, BOOL *stop) {
        UIImageView *view = [self imageViewAtTime:timeValue];
        view.frame = [self frameForIndex:idx];
    }];
    
    self.thumb.frame = [self frameForThumb];
}

- (CGRect)frameForThumb
{
    CGRect bounds = self.bounds;
    Float64 progress = CMTimeGetSeconds(self.currentTime) / CMTimeGetSeconds(self.duration);
    CGPoint midPoint = CGPointMake(progress * CGRectGetWidth(bounds), CGRectGetMidY(bounds));
    CGSize thumbSize = CGSizeMake(20, 44);
    
    return CGRectMake(floorf(midPoint.x - thumbSize.width * 0.5f),
                      floorf(midPoint.y - thumbSize.height * 0.5f),
                      thumbSize.width,
                      thumbSize.height);
}

- (NSArray *)times
{
    CGRect bounds = self.bounds;
    CGSize aspect = [self.datasource scrubberAspect:self];
    CGFloat thumbWidth = floorf(CGRectGetHeight(bounds) / aspect.height * aspect.width);
    
    NSUInteger count = ceilf(CGRectGetWidth(bounds) / thumbWidth);
    
    NSMutableArray *times = [NSMutableArray new];
    
    for (NSUInteger idx = 0; idx < count; idx++) {
        CGRect frame = [self frameForIndex:idx];
        Float64 fraction = MIN((CGRectGetMidX(frame) / CGRectGetWidth(bounds)), 0.999);
        CMTime time = CMTimeMultiplyByFloat64(self.duration, fraction);
        [times addObject:[NSValue valueWithCMTime:time]];
    }
    
    return [times copy];
}

- (CGRect)frameForIndex:(NSUInteger)idx
{
    CGRect bounds = self.bounds;
    CGSize aspect = [self.datasource scrubberAspect:self];
    CGFloat width = CGRectGetHeight(bounds) / aspect.height * aspect.width;
    
    return CGRectMake(idx * width, CGRectGetMinY(bounds), width, CGRectGetHeight(bounds));
}

#pragma mark - UIControl

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGRect frame = CGRectInset([self frameForThumb], (CGRectGetWidth([self frameForThumb]) - 44) * 0.5f, 0);
    return CGRectContainsPoint(frame, [touch locationInView:self]);
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    self.currentTime = CMTimeMultiplyByFloat64(self.duration, [touch locationInView:self].x / CGRectGetWidth(self.bounds));
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    return YES;
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    [super cancelTrackingWithEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [super endTrackingWithTouch:touch withEvent:event];
}

@end
