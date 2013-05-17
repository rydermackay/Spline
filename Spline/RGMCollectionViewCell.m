//
//  RGMCollectionViewCell.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-13.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMCollectionViewCell.h"

@interface RGMCollectionViewCell ()
@property (nonatomic, weak) IBOutlet UIImageView *imageView;
@end

@implementation RGMCollectionViewCell

- (UIImage *)image
{
    return self.imageView.image;
}

- (void)setImage:(UIImage *)image
{
    self.imageView.image = image;
}

@end
