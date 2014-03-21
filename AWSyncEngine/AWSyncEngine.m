//
//  RDUSyncEngine.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/2/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncEngine.h"

NSString * const kSDSyncEngineInitialCompleteKey = @"SDSyncEngineInitialSyncCompleted";
NSString * const kSDSyncEngineSyncCompletedNotificationName = @"SDSyncEngineSyncCompleted";
NSString * const kSyncInProgressProperty = @"syncInProgress";

#define kSyncInterval 3600*24*1

@interface AWSyncEngine (){
    NSArray * _result;
}

@property (atomic, assign) BOOL syncInProgress;
@property (nonatomic, strong) NSString *syncInProgressProperty;

@end


@implementation AWSyncEngine

@synthesize  syncInterval = _syncInterval;

+ (AWSyncEngine*)sharedEngine
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[AWSyncEngine alloc]init];
    });
    return sharedInstance;
}

- (id)init
{
    if (self = [super init]) {
        self.syncInProgress = NO;
        self.syncInterval = kSyncInterval;
        self.coreDataController = [AWCoreDataController new];
        self.requestMethod = kGET;
        self.syncInProgressProperty = kSyncInProgressProperty;
    }
    return self;
}

- (void)startSync
{
    /* reachability check doesn't work like expected, it gets handled in app delegate */
    NSError *error = nil;
    if ([self initalizeSyncError:&error]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self syncObjects];
        });
    } else {
        NSLog(@"Error initializing sync: %@",error);
    }
}


- (void)executeSyncCompletedOperations {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setInitialSyncCompleted];
        [self saveContexts];
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSDSyncEngineSyncCompletedNotificationName
         object:nil];
        [self resetSyncInProgress];
        [self setLastSyncDateForKey:@"lastSynced"];
    });
}




- (BOOL)needsSyncing
{
#warning hardcoded return value - CHANGE!!
    return true;
    //    NSDate *lastSync = [self lastSynced];
    //    if (lastSync != nil) {
    //
    //        NSDate *newDate = [lastSync dateByAddingTimeInterval:self.syncInterval];
    //        NSDate *today = [NSDate date];
    //
    //        if ([newDate compare:today] == NSOrderedAscending)
    //            return true;
    //        else
    //            return false;
    //    }
    return true;
}


- (NSDate*)lastSyncedDate
{
    return [self lastSyncPushDateForKey:@"lastSynced"];
}

#warning hardcoded return value (leave it till if find out if needed - its working like it is)

- (void)syncObjects
{
    [self executeConnectionOperationWithCompletionBlock:^{
        [self executeSyncCompletedOperations];
    }];
}


@end
