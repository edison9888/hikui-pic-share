//
//  TimelineViewController.m
//  PicShareClient_iOS
//
//  Created by 缪和光 on 12-3-28.
//  Copyright (c) 2012年 Shanghai University. All rights reserved.
//

#import "TimelineViewController.h"
#import "PicShareEngine.h"
#import "TimelineCell.h"
#import "ASIDownloadCache.h"
#import "UIImageView+Resize.h"

@interface TimelineViewController ()

- (void)loadData;
- (void)loadDataDidFinish:(NSArray *)resultArray;
- (void)pageData;
- (void)pageDataDidFinish:(NSArray *)resultArray;
- (void)loadImage:(NSURL *)imageUrl WithProgressDelegate:(UIProgressView *)progressView atIndexPath:(NSIndexPath *)path;
- (void)loadImageDidFinish:(ASIHTTPRequest *)request;
- (void)loadImageDidFailed:(ASIHTTPRequest *)request;

@end

@implementation TimelineViewController
@synthesize timeline,hasnext,currentPage,pictures,progressViews,aliveRequest;

- (void)dealloc
{
    [timeline release];
    [pictures release];
    [progressViews release];
    for (ASIHTTPRequest *aRequest in aliveRequest) {
        [aRequest clearDelegatesAndCancel];
    }
    [aliveRequest release];
    [super dealloc];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    aliveRequest = [[NSMutableArray alloc]init];
    [self startLoading];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (timeline == nil) {
        return 0;
    }
    return self.timeline.count+1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    if (indexPath.row == self.timeline.count) {
        //more button
        UITableViewCell *cell =[tableView dequeueReusableCellWithIdentifier:@"moreButton"];
        if (cell==nil) {
            cell = [[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"moreButton"]autorelease];
        }
        if (hasnext) {
            cell.textLabel.text = @"更多...";
        }
        else {
            cell.textLabel.text=@"";
        }
        
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        cell.textLabel.font = [UIFont systemFontOfSize:13];
        return cell;
        
    }
    
    TimelineCell *cell = (TimelineCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell==nil) {
        cell = [[[TimelineCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier]autorelease];
    }
    [cell clearImage];
    PictureStatus *ps = [timeline objectAtIndex:indexPath.row];
    [cell setPictureStatus:ps];
    [cell layout];
    if ([self.pictures objectAtIndex:indexPath.row]==[NSNull null]){
        if ([self.progressViews objectAtIndex:indexPath.row]!=[NSNull null]) { // is already start loading
            [cell.mainImageView addSubview:[self.progressViews objectAtIndex:indexPath.row]];
        }else if(self.tableView.dragging == NO && self.tableView.decelerating == NO){
            UIProgressView *progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleBar];
            CGSize mainImageViewSize = cell.mainImageView.frame.size;
            progressView.frame = CGRectMake((mainImageViewSize.width-100)/2, mainImageViewSize.height/2, 100, 20);
            [cell.mainImageView addSubview:progressView];
            [self.progressViews replaceObjectAtIndex:indexPath.row withObject:progressView];
            NSURL *url = [NSURL URLWithString:ps.pictureUrl];
            [self loadImage:url WithProgressDelegate:progressView atIndexPath:indexPath];
            [progressView release];

        }
    }
    else {
        cell.mainImageView.image = [self.pictures objectAtIndex:indexPath.row];
        NSLog(@"aaaaa");
    }
        
    return cell;
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == self.timeline.count) {
        return 40;
    }
    PictureStatus *ps = [self.timeline objectAtIndex:indexPath.row];
    return [TimelineCell calculateCellHeightWithPictureStatus:ps];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

-(void)refresh
{
    [self performSelectorInBackground:@selector(loadData) withObject:nil];
}


- (void)loadImagesForOnscreenRows
{
    NSLog(@"loadImagesForOnscreenRows");
    NSArray *visiblePaths = [self.tableView indexPathsForVisibleRows];
    for (NSIndexPath *indexPath in visiblePaths)
    {
        if (indexPath.row>=self.timeline.count) {
            break;
        }
        if ([self.pictures objectAtIndex:indexPath.row]==[NSNull null]) {
            TimelineCell *cell =(TimelineCell *) [self.tableView cellForRowAtIndexPath:indexPath];
            PictureStatus *ps = [timeline objectAtIndex:indexPath.row];
            UIProgressView *progressView = [[UIProgressView alloc]initWithProgressViewStyle:UIProgressViewStyleBar];
            CGSize mainImageViewSize = cell.mainImageView.frame.size;
            progressView.frame = CGRectMake((mainImageViewSize.width-100)/2, mainImageViewSize.height/2, 100, 20);
            [cell.mainImageView addSubview:progressView];
            [self.progressViews replaceObjectAtIndex:indexPath.row withObject:progressView];
            NSURL *url = [NSURL URLWithString:ps.pictureUrl];
            [self loadImage:url WithProgressDelegate:progressView atIndexPath:indexPath];
            [progressView release];
        }
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
	{
        [self loadImagesForOnscreenRows];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self loadImagesForOnscreenRows];
}

#pragma mark - async methods
- (void)loadData
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
    PicShareEngine *engine = [PicShareEngine sharedEngine];
    NSArray *resultArray = [engine getHomeTimeline];
    //NSLog(@"timeline:%@",resultArray);
    [self performSelectorOnMainThread:@selector(loadDataDidFinish:) withObject:resultArray waitUntilDone:NO];
    [pool release];
}
- (void)loadDataDidFinish:(NSArray *)resultArray
{
    NSMutableArray *mutableResults = [[NSMutableArray alloc]initWithArray:[resultArray subarrayWithRange:NSMakeRange(1, resultArray.count-1)]];
    self.timeline = mutableResults;
    [mutableResults release];
    //NSLog(@"timeline:%@",self.timeline);
    if ([[resultArray objectAtIndex:0]intValue]==1) {
        self.hasnext = YES;
    }
    else {
        self.hasnext = NO;
    }
    self.progressViews = [[[NSMutableArray alloc]init]autorelease];
    self.pictures = [[[NSMutableArray alloc]init]autorelease];
    for (int i = 0; i<self.timeline.count; i++) {
        [progressViews addObject:[NSNull null]];
        [pictures addObject:[NSNull null]];
    }
    currentPage = 1;
    [self stopLoading];
    [self.tableView reloadData];
}
- (void)pageData
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc]init];
    PicShareEngine *engine = [PicShareEngine sharedEngine];
    PictureStatus *theTopOne = [self.timeline objectAtIndex:0];
    NSArray *resultArray = [engine getHomeTimelineOfPage:++currentPage since:-1 max:theTopOne.psId];
    NSLog(@"timeline:%@",resultArray);
    [self performSelectorOnMainThread:@selector(pageDataDidFinish:) withObject:resultArray waitUntilDone:NO];
    [pool release];
}
- (void)pageDataDidFinish:(NSArray *)resultArray
{
    NSArray *psData = [resultArray subarrayWithRange:NSMakeRange(1, resultArray.count-1)];
    int originPSCount = timeline.count;
    for (PictureStatus *aPs in psData) {
        [self.timeline insertObject:aPs atIndex:originPSCount];
        [self.pictures insertObject:[NSNull null] atIndex:originPSCount];
        [self.progressViews insertObject:[NSNull null] atIndex:originPSCount];
        originPSCount++;
    }
    if ([[resultArray objectAtIndex:0] intValue] == 1) {
        self.hasnext = YES;
    }
    else {
        self.hasnext = NO;
    }
    [self.tableView reloadData];
}

- (void)loadImage:(NSURL *)imageUrl WithProgressDelegate:(UIProgressView *)progressView atIndexPath:(NSIndexPath *)path
{
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc]initWithURL:imageUrl];
    [request setDelegate:self];
    [request setTimeOutSeconds:30];
    [request setDownloadProgressDelegate:progressView];
    [request setDownloadCache:[ASIDownloadCache sharedCache]];
    [request setCachePolicy:ASICacheForSessionDurationCacheStoragePolicy];
    [request setNumberOfTimesToRetryOnTimeout:1];
    [request setDidFinishSelector:@selector(loadImageDidFinish:)];
    [request setDidFailSelector:@selector(loadImageDidFailed:)];
    request.userInfo = [[[NSDictionary alloc]initWithObjectsAndKeys:path,@"indexPath", nil]autorelease];
    @synchronized(self.aliveRequest)
    {
        [self.aliveRequest addObject:request];
    }
    [request startAsynchronous];
    
    
}
- (void)loadImageDidFinish:(ASIHTTPRequest *)request
{
    NSLog(@"loadImageDidFinish");
    @synchronized(self.aliveRequest)
    {
         [self.aliveRequest removeObject:request];
    }
    [request.downloadProgressDelegate removeFromSuperview];
    //NSLog(@"path:%@",[request.userInfo objectForKey:@"indexPath"]);
    NSIndexPath *indexPath = [request.userInfo objectForKey:@"indexPath"];
    [self.progressViews replaceObjectAtIndex:indexPath.row withObject:[NSNull null]];
    UIImage *image = [UIImage imageWithData:[request responseData]];
    //裁剪
    UIImage *scaledImage = [UIImageView imageWithImage:image scaledToSizeWithSameAspectRatio:CGSizeMake(MAIN_IMAGE_WIDTH, MAIN_IMAGE_HEIGHT)];
    [self.pictures replaceObjectAtIndex:indexPath.row withObject:scaledImage];
    TimelineCell *cell = (TimelineCell *) [self.tableView cellForRowAtIndexPath:indexPath];
    [cell setPicture:scaledImage WillAnimated:YES];
}

- (void)loadImageDidFailed:(ASIHTTPRequest *)request
{
    NSLog(@"loadImageDidFaild");
    [self.aliveRequest removeObject:request];
    [request.downloadProgressDelegate removeFromSuperview];
    [self.progressViews removeObject:request.downloadProgressDelegate];
}
@end
