//
//  RDUSyncEnginePush.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/19/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncEnginePush.h"


NSString * const kSDSyncEngineInitialCompleteKeyPush = @"SDSyncEngineInitialSyncPushCompleted";
NSString * const kSDSyncEngineSyncStartedNotificationNamePush = @"SDSyncEngineSyncPushStarted";
NSString * const kSDSyncEngineSyncCompletedNotificationNamePush = @"SDSyncEngineSyncPushCompleted";

@interface AWSyncEnginePush (){
    NSArray * _result;
    NSManagedObjectContext *_managedObjectContext;
}
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
    }
    return self;
}

- (void)startSync
{
    if ([self.registeredClassesToSync count]!= 0) {
        if (!self.syncInProgress) {
            [[NSNotificationCenter defaultCenter]
             postNotificationName:kSDSyncEngineSyncStartedNotificationNamePush
             object:nil];
            [self willChangeValueForKey:@"syncPushInProgress"];
            self.syncInProgress = YES;
            [self didChangeValueForKey:@"syncPushInProgress"];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                [self postAndSyncObjects];
            });
        }
    }
}

- (void)executeSyncCompletedOperations {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setInitialSyncCompleted];
        NSError *error = nil;
        [self.coreDataController saveBackgroundContext];
        if (error) {
            NSLog(@"Error saving background context after creating objects on server: %@", error);
        }
        
        [self.coreDataController saveMasterContext];
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSDSyncEngineSyncCompletedNotificationNamePush
         object:nil];
        [self willChangeValueForKey:@"syncPushInProgress"];
        self.syncInProgress = NO;
        [self didChangeValueForKey:@"syncPushInProgress"];
        [self recordLastSyncDate];
    });
}

- (void)recordLastSyncDate
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSDate date] forKey:@"lastSyncPush"];
    [defaults synchronize];
}

- (NSDate*)lastSyncPushDate
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:@"lastSyncPush"];
}

#warning hardcoded return value (leave it - working)
- (BOOL)initialSyncComplete
{
    return NO;
    //return [[[NSUserDefaults standardUserDefaults] valueForKey:kSDSyncEngineInitialCompleteKey] boolValue];
}

- (void)setInitialSyncCompleted
{
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kSDSyncEngineInitialCompleteKeyPush];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)postAndSyncObjects
{
    [self executeConnectionOperationWithRequestType:kPOST completionBlock:^{
        [self executeSyncCompletedOperations];
    }];
    
}

@end
