//
//  RGMTableViewController.m
//  Spline
//
//  Created by Ryder Mackay on 2013-05-11.
//  Copyright (c) 2013 Ryder Mackay. All rights reserved.
//

#import "RGMTableViewController.h"
#import "RGMPlayerViewController.h"

@interface RGMTableViewController ()
@property (nonatomic, strong) NSMutableArray *URLs;
@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, strong) NSMutableDictionary *thumbnails;
@end

@implementation RGMTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.thumbnails = [NSMutableDictionary new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    
    [self refreshData];
}

- (void)refreshData
{
    NSString *docsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSError *error;
    self.URLs = [[[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:docsPath isDirectory:YES]
                                               includingPropertiesForKeys:@[NSFileCreationDate]
                                                                  options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                    error:&error] mutableCopy];

    self.assets = [NSMutableArray new];
    
    for (NSURL *URL in self.URLs) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:URL options:nil];
        [self.assets addObject:asset];
        
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        generator.maximumSize = CGSizeMake(100, 100);
        generator.appliesPreferredTrackTransform = YES;
        [generator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:kCMTimeZero]]
                                        completionHandler:^(CMTime requestedTime, CGImageRef cgimage, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
                                            if (result == AVAssetImageGeneratorSucceeded) {
                                                UIImage *image = [UIImage imageWithCGImage:cgimage];
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [self.thumbnails setObject:image forKey:URL];
                                                    [self.tableView reloadData];
                                                });
                                            }
                                        }];
    }
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.URLs.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    NSURL *URL = [self.URLs objectAtIndex:indexPath.row];
    cell.textLabel.text = URL.lastPathComponent;
    cell.imageView.image = [self.thumbnails objectForKey:URL];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[NSFileManager defaultManager] removeItemAtURL:[self URLForIndexPath:indexPath] error:nil];
        [self.URLs removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
}

- (NSURL *)URLForIndexPath:(NSIndexPath *)indexPath
{
    return self.URLs[indexPath.row];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    [self playMovieWithURL:[self URLForIndexPath:indexPath]];
}

- (void)playMovieWithURL:(NSURL *)URL
{
    MPMoviePlayerViewController *controller = [[MPMoviePlayerViewController alloc] initWithContentURL:URL];
    [self presentMoviePlayerViewControllerAnimated:controller];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
        AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[self URLForIndexPath:indexPath] options:@{AVURLAssetPreferPreciseDurationAndTimingKey: @YES}];
        [segue.destinationViewController setAsset:asset];
    }
}

@end
