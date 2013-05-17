//
//  RGMScrubberControl.h
//  Spline
//
//  Created by Ryder Mackay on 2013-05-12.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RGMScrubberControl;

@protocol RGMScrubberControlDataSource <NSObject>

- (CMTime)scrubberDuration:(RGMScrubberControl *)scrubber;
- (CGSize)scrubberAspect:(RGMScrubberControl *)scrubber;

- (void)scrubber:(RGMScrubberControl *)scrubber imagesForTimes:(NSArray *)times;

@end



@interface RGMScrubberControl : UIControl

@property (nonatomic, assign) CMTime currentTime;

- (void)reloadData;
- (void)setImage:(UIImage *)image atTime:(CMTime)time;
@property (nonatomic, weak) id <RGMScrubberControlDataSource> datasource;

@end
