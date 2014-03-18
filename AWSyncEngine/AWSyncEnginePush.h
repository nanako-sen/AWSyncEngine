//
//  RDUSyncEnginePush.h
//  RDULoyalty
//
//  Created by Anna Walser on 10/19/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncEngineBase.h"

@interface AWSyncEnginePush : AWSyncEngineBase

@property (atomic, readonly) BOOL syncInProgress;
+ (AWSyncEnginePush*)sharedEngine;
- (void)startSync;
- (NSDate*)lastSyncPushDate;


@end
