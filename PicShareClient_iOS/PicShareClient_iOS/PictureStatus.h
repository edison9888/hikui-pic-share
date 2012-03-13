//
//  PictureStatus.h
//  PicShareClient_iOS
//
//  Created by 和光 缪 on 12-3-4.
//  Copyright (c) 2012年 Shanghai University. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "User.h"

typedef enum Status_type{
    Original = 1,
    Repin = 2,
    Reported = 3,
    Banned = 4
} Status_type;

@interface PictureStatus : NSObject

@property (readonly) NSInteger psId;
@property (nonatomic,copy) NSString *pictureUrl;
@property (nonatomic,retain) UIImage *picture;
@property (nonatomic,copy) NSString *description;
@property (nonatomic,copy) NSString *location;
@property (readwrite) Status_type statusType;
@property (readwrite) NSInteger boardId;//所属的board
@property (nonatomic,retain) User *owner;
@property (nonatomic,retain) User *via;
@property (nonatomic,retain) NSDate *timestamp;
@property (readwrite) NSInteger commentsCount;

-(id)initWithJSONDict:(NSDictionary *)data;

@end