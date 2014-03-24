//
//  RDUSyncEnginePush.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/19/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncEnginePush.h"

NSString * const kSDSyncEngineSyncStartedNotificationNamePush = @"SDSyncEngineSyncPushStarted";
NSString * const kSDSyncEngineSyncCompletedNotificationNamePush = @"SDSyncEngineSyncPushCompleted";

@interface AWSyncEnginePush (){
    NSArray * _result;
    NSManagedObjectContext *_managedObjectContext;
}
@end

@implementation AWSyncEnginePush

+ (AWSyncEnginePush*)sharedEngine
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[AWSyncEnginePush alloc]init];
    });
    return sharedInstance;
//    SHARED_INSTANCE_USING_BLOCK(^{return [[AWSyncEnginePush alloc]init];})
}

- (id)init
{
    if (self = [super init]) {
        _syncInProgress = NO;
        self.requestMethod = kPOST;
        _syncInProgressProperty = @"syncPushInProgress";
    }
    return self;
}

- (void)startSync
{
    [self checkBaseURL];
    NSError *error = nil;
    if ([self initalizeSyncError:&error]) {
        [self setSyncInProgress];
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSDSyncEngineSyncStartedNotificationNamePush
         object:nil];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self postAndSyncObjects];
        });
    } else {
        NSLog(@"Error initializing sync push: %@",error);
    }
}

- (void)executeSyncCompletedOperations {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self saveContexts];
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSDSyncEngineSyncCompletedNotificationNamePush
         object:nil];
        [self resetSyncInProgress];
        [self setLastSyncDateForKey:@"lastSyncedPush"];
    });
}

- (NSDate*)lastSyncedDate
{
    return [self lastSyncPushDateForKey:@"lastSyncedPush"];
}

- (void)postAndSyncObjects
{
    [self executeConnectionOperationWithCompletionBlock:^{
        [self executeSyncCompletedOperations];
    }];
    
}

@end
