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

@property (nonatomic, readonly) NSMutableArray *registeredClassesToSync;
@property (nonatomic, strong) AWSyncEngineFileManager *syncFileManager;
@property (nonatomic, strong) NSURL *baseUrl;
@property (nonatomic, strong) AWCoreDataController *coreDataController;


- (void)registerNSManagedObjectToSync:(AWSyncMappingObject*)mObject;
- (NSString *)dateStringForAPIUsingDate:(NSDate *)date;
- (void)clearRegister;

- (void)setInitialSyncCompleted;

- (void)executeConnectionOperationWithRequestType:(AWRequestMethod)type completionBlock:(void(^)(void))completionBlock;
//- (void)newManagedObjectForObject:(AWSyncMappingObject *)mObject forRecord:(NSDictionary *)record;
//- (void)updateObject:(AWSyncMappingObject*)mObject forRecord:(NSDictionary*)record;
- (void)updateOrInsertObject:(AWSyncMappingObject *)mObject forRecordsInArray:(NSArray*)records;

- (NSDate*)parseDate:(NSString*)value;

- (void)setAttributes:(NSDictionary*)attributes  fromRecords:(NSDictionary*)record forObject:(NSManagedObject*)object;
- (void)setAttributes:(NSDictionary*)attributes forObject:(NSManagedObject*)object;


- (void)saveManagedObjectContext:(NSManagedObjectContext*)context;



//- (void)deleteAllRecordsForEnity:(NSString*)entity;
- (void)setDeleteFlagForObject:(AWSyncMappingObject*)object inContext:(NSManagedObjectContext*)context;
- (void)deleteFlagedRecordsForObject:(AWSyncMappingObject*)object inContext:(NSManagedObjectContext*)context;
@end
