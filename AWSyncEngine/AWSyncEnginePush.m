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
NSString * const kSyncInProgressProperty = @"syncPushInProgress";

@interface AWSyncEnginePush (){
    NSArray * _result;
    NSManagedObjectContext *_managedObjectContext;
}
@property (nonatomic, strong) NSString *syncInProgressProperty;

@property (atomic, assign) BOOL syncInProgress;
@end

@implementation AWSyncEnginePush

@synthesize syncInProgress = _syncInProgress;


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
        self.syncInProgress = NO;
        self.requestMethod = kPOST;
        self.syncInProgressProperty = kSyncInProgressProperty;
    }
    return self;
}

- (void)startSync
{
    NSError *error = nil;
    if ([self initalizeSyncError:&error]) {
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
