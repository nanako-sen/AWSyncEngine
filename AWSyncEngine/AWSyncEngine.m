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

#define kSyncInterval 3600*24*1

@interface AWSyncEngine (){
    NSArray * _result;
    AWCoreDataController *_coreDataController;
}

@property (atomic, assign) BOOL syncInProgress;

@end


@implementation AWSyncEngine

@synthesize syncInProgress = _syncInProgress , syncInterval = _syncInterval;

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
        _coreDataController = [AWCoreDataController new];
    }
    return self;
}

- (void)startSync
{
    /* reachability check doesn't work like expected, it gets handled in app delegate */
    if (self.baseUrl == nil) {
        NSLog(@"baseUrl musn't be nil");
    }
    if (!self.syncInProgress) {
        [self willChangeValueForKey:@"syncInProgress"];
        self.syncInProgress = YES;
        [self didChangeValueForKey:@"syncInProgress"];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            [self syncObjects];
        });
    }

}


- (void)executeSyncCompletedOperations {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setInitialSyncCompleted];
        NSError *error = nil;
        [_coreDataController saveBackgroundContext];
        if (error) {
            NSLog(@"Error saving background context after creating objects on server: %@", error);
        }
        
        [_coreDataController saveMasterContext];
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSDSyncEngineSyncCompletedNotificationName
         object:nil];
        [self changeSyncInProgressValueToNO];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSDate date] forKey:@"lastSynced"];
        [defaults synchronize];
//        [RDUUserDefaults setLastSynced:[NSDate date]];
    });
}

- (void)changeSyncInProgressValueToNO
{
    [self willChangeValueForKey:@"syncInProgress"];
    _syncInProgress = NO;
    [self didChangeValueForKey:@"syncInProgress"];
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


#warning hardcoded return value (leave it till if find out if needed - its working like it is)
- (BOOL)initialSyncComplete
{
    return NO;
    //return [[[NSUserDefaults standardUserDefaults] valueForKey:kSDSyncEngineInitialCompleteKey] boolValue];
}

- (void)setInitialSyncCompleted
{
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kSDSyncEngineInitialCompleteKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)syncObjects
{
    [self executeConnectionOperationWithRequestType:kGET completionBlock:^{
        [self executeSyncCompletedOperations];
    }];
}


@end
