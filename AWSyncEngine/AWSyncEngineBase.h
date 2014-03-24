//
//  CCCSyncEngineBase.h
//  CCCKerbside
//
//  Created by Anna Walser on 1/21/14.
//  Copyright (c) 2014 Anna Walser. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "AWCoreDataController.h"
#import "AWAFParseAPIClient.h"
#import <AFNetworking/AFHTTPRequestOperation.h>
#import <AFNetworking/AFURLConnectionOperation.h>
#import "objc/runtime.h"
#import "AWSyncEngineFileManager.h"
#import "AWSyncMappingObject.h"

@class AWSyncMappingObject;

typedef enum {
    kGET,
    kPOST
} AWRequestMethod;

@interface AWSyncEngineBase : NSObject
{
    @protected
    BOOL _syncInProgress;
    NSString *_syncInProgressProperty;
}

@property (nonatomic, readonly) NSMutableArray *registeredClassesToSync;
@property (nonatomic, strong) AWSyncEngineFileManager *syncFileManager;
@property (nonatomic, strong) NSURL *baseUrl;
@property (nonatomic, assign) AWRequestMethod requestMethod;
@property (nonatomic, strong) AWCoreDataController *coreDataController;
@property (atomic, readonly) BOOL syncInProgress;
@property (nonatomic, readonly) NSString *syncInProgressProperty;

- (BOOL)initalizeSyncError:(NSError * __autoreleasing *)error;
- (void)checkBaseURL;
- (void)setSyncInProgress;

- (void)resetSyncInProgress;
- (void)setLastSyncDateForKey:(NSString*)key;
- (NSDate*)lastSyncPushDateForKey:(NSString*)key;
- (void)saveContexts;



- (void)registerNSManagedObjectToSync:(AWSyncMappingObject*)mObject;
- (NSString *)dateStringForAPIUsingDate:(NSDate *)date;
- (void)clearRegister;

- (void)setInitialSyncCompleted;

- (void)executeConnectionOperationWithCompletionBlock:(void(^)(void))completionBlock;
//- (void)newManagedObjectForObject:(AWSyncMappingObject *)mObject forRecord:(NSDictionary *)record;
//- (void)updateObject:(AWSyncMappingObject*)mObject forRecord:(NSDictionary*)record;
- (void)updateOrInsertObject:(AWSyncMappingObject *)mObject forRecordsInArray:(NSArray*)records;

- (NSDate*)parseDate:(NSString*)value;

- (void)setAttributes:(NSDictionary*)attributes  fromRecords:(NSDictionary*)record forObject:(NSManagedObject*)object;
- (void)setAttributes:(NSDictionary*)attributes forObject:(NSManagedObject*)object;


- (void)saveManagedObjectContext:(NSManagedObjectContext*)context;



//- (void)deleteAllRecordsForEnity:(NSString*)entity;
- (void)setDeleteFlagForClass:(Class)mClass inContext:(NSManagedObjectContext*)context;
- (void)deleteFlagedRecordsForClass:(Class)mClass inContext:(NSManagedObjectContext*)context;
@end

@interface AWErrorHandling : NSObject

typedef enum {
    AWErrorMissingBaseUrl = 60,
    AWErrorNoRegisteredClasses = 61,
    AWErrorSyncInProgress = 62
} AWErrorCodes;

+ (NSError*)errorWithCode:(AWErrorCodes)code;
@end
