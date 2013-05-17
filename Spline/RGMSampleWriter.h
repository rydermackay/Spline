//
//  RGMSampleWriter.h
//  Spline
//
//  Created by Ryder Mackay on 2013-05-11.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RGMSampleWriter : NSObject

- (id)initWithURL:(NSURL *)URL;
@property (nonatomic, readonly) NSURL *URL;

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer mediaType:(NSString *)mediaType;
- (void)finish:(void (^)())completion;

@end
