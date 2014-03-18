//
//  RDUSyncEngine.h
//  RDULoyalty
//
//  Created by Anna Walser on 10/2/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncEngineBase.h"

@class AWSyncMappingObject;

typedef enum {
    RDUObjectSynced = 0
} RDUObjectSyncStatus;

@interface AWSyncEngine : AWSyncEngineBase

@property (atomic, readonly) BOOL syncInProgress;
@property (nonatomic,readonly) NSDate* lastSynced;
@property (nonatomic, assign) CGFloat syncInterval;

+ (AWSyncEngine*)sharedEngine;
- (void)startSync;
- (BOOL)needsSyncing;


@end
