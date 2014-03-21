//
//  CCCSyncEngineBase.m
//  CCCKerbside
//
//  Created by Anna Walser on 1/21/14.
//  Copyright (c) 2014 Anna Walser. All rights reserved.
//

#import "AWSyncEngineBase.h"

NSString * const kSDSyncEngineInitialCompleteKey = @"SDSyncEngineInitialSyncCompleted";
NSString * const kAppDomain = @"private.AWSyncEngine";

@interface AWSyncEngineBase () {
    NSManagedObjectContext *_backgroundManagedObjectContext;
}


@property (nonatomic, strong) NSMutableArray *registeredClassesToSync;

@end

@implementation AWSyncEngineBase

@synthesize registeredClassesToSync = _registeredClassesToSync,
                    syncFileManager = _syncFileManager,
                            baseUrl = _baseUrl,
                 coreDataController = _coreDataController,
                      requestMethod = _requestMethod,
                     syncInProgress = _syncInProgress,
             syncInProgressProperty = _syncInProgressProperty;


- (id)init
{
    if (self = [super init]) {
        self.syncFileManager = [AWSyncEngineFileManager new];
        self.coreDataController = [AWCoreDataController new];
        _backgroundManagedObjectContext = [self.coreDataController backgroundManagedObjectContext];
    }
    return self;
}

- (BOOL)initalizeSyncError:(NSError * __autoreleasing *)error
{
    BOOL success = NO;
    if (self.baseUrl == nil) {
        *error = [AWErrorHandling errorWithCode:AWErrorMissingBaseUrl];
    }
    if ([self.registeredClassesToSync count]!= 0) {
        if (!self.syncInProgress) {
            [self willChangeValueForKey:self.syncInProgressProperty];
            self.syncInProgress = YES;
            [self didChangeValueForKey:self.syncInProgressProperty];
            success = YES;
        } else {
            *error = [AWErrorHandling errorWithCode:AWErrorSyncInProgress];
        }
    } else {
        *error = [AWErrorHandling errorWithCode:AWErrorNoRegisteredClasses];
    }
    return success;
}

- (void)resetSyncInProgress
{
    [self willChangeValueForKey:self.syncInProgressProperty];
    self.syncInProgress = NO;
    [self didChangeValueForKey:self.syncInProgressProperty];
}

- (void)setLastSyncDateForKey:(NSString*)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSDate date] forKey:key];
    [defaults synchronize];
}

- (NSDate*)lastSyncPushDateForKey:(NSString*)key
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:key];
}

- (void)saveContexts
{
//TOdo: error handling
//    NSError *error = nil;
    [self.coreDataController saveBackgroundContext];
    //        if (error) {
    //            NSLog(@"Error saving background context after creating objects on server: %@", error);
    //        }
    
    [self.coreDataController saveMasterContext];
}

#pragma mark - register objects to sync

- (void)registerNSManagedObjectToSync:(AWSyncMappingObject*)mObject
{
    if (!self.registeredClassesToSync) {
        self.registeredClassesToSync = [NSMutableArray array];
    }
    
    if ([mObject.moClass isSubclassOfClass:[NSManagedObject class]]) {
        if (![self.registeredClassesToSync containsObjectWithClass:mObject.moClass]) {
            [self.registeredClassesToSync addObject:mObject];
        } else {
            NSLog(@"Unable to register %@ as it is already registered", [mObject className]);
        }
    } else {
        NSLog(@"Unable to register %@ as it is not a subclass of NSManagedObject", NSStringFromClass(mObject.moClass));
    }
}

- (void)clearRegister
{
    self.registeredClassesToSync = nil;
}



# pragma mark - ManagedObject mapping


- (NSManagedObject*)createManagedObjectForObject:(AWSyncMappingObject *)mObject forRecord:(NSDictionary *)record
{
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[mObject className]
                                                                      inManagedObjectContext:_backgroundManagedObjectContext];
    
    [self setAttributes:mObject.attributesMappingDictionary fromRecords:record forObject:newManagedObject];
    
    [mObject.relatedMappingObjects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        AWSyncMappingObject *mo = (AWSyncMappingObject*)obj;
        if ([record objectForKey:mo.jsonRootAttribute] != nil) {
            if ([[record objectForKey:mo.jsonRootAttribute] isKindOfClass:[NSArray class]]) {
                NSMutableSet *set = [NSMutableSet new];
                for (NSDictionary *subRecord in [record objectForKey:mo.jsonRootAttribute]) {
                    [set addObject:[self createManagedObjectForObject:mo forRecord:subRecord]];
                    [newManagedObject setValue:[set copy] forKey:mo.relationshipNameOnParent];
                }
            }
            else {
                NSManagedObject* managedObject =  [self createManagedObjectForObject:mo forRecord:[record objectForKey:mo.jsonRootAttribute]];
                [newManagedObject setValue:managedObject forKey:mo.relationshipNameOnParent];
            }
        }
    }];

    [self removeDeleteFlagOnObject:newManagedObject];
    
    return newManagedObject;
}

#pragma mark - Connection Execute

- (void)executeConnectionOperationWithCompletionBlock:(void(^)(void))completionBlock
{
    NSMutableArray *operations = [NSMutableArray array];
    
    for (AWSyncMappingObject *mObject in self.registeredClassesToSync) {
        NSString *className = mObject.className;
        AWAFParseAPIClient *parseAPIClient = [[AWAFParseAPIClient alloc] initWithBaseURL:self.baseUrl];
        
        NSMutableURLRequest *request = [NSMutableURLRequest new];
        if (self.requestMethod == kPOST) {
            request = [parseAPIClient POSTRequestToUrl:mObject.requestAPIResource parameters:mObject.postDataDictionary];
        }else if (self.requestMethod == kGET){
            request = [parseAPIClient GETRequest:mObject.requestAPIResource parameters:nil];
        }
        
        AFHTTPRequestOperation *operation = [parseAPIClient HTTPRequestOperationWithRequest:request
                                                                                    success:^(AFHTTPRequestOperation *operation, id responseObject)
                                                                                    {
                                                                                        if ([responseObject isKindOfClass:[NSDictionary class]]) {
                                                                                            [self.syncFileManager writeJSONResponse:responseObject toDiskForClassWithName:className atKey:mObject.jsonRootAttribute];
                                                                                        }
                                                                                    }
                                                                                    failure:^(AFHTTPRequestOperation *operation, NSError *error)
                                                                                    {
                                                                                        NSLog(@"Failed operation: %@ - %@",operation, error);
                                                                                    }];
        
        [operations addObject:operation];
    }
    
    
    NSArray *batches= [AFURLConnectionOperation batchOfRequestOperations:operations
                                                           progressBlock:^(NSUInteger numberOfCompletedOperations, NSUInteger totalNumberOfOperations)
                                                           {
                                                               //                       NSLog(@"%lu of %lu complete", (unsigned long)numberOfCompletedOperations, (unsigned long)totalNumberOfOperations);
                                                           }
                                                         completionBlock:^(NSArray *operations) {
                                                             NSLog(@"All operations in batch complete Push");
                                                             // Processing data into core data
                                                             for (AWSyncMappingObject* mObject in self.registeredClassesToSync) {
                                                                 NSString *className = [mObject className];
                                                                 NSDictionary *JSONDictionary = [self.syncFileManager JSONDictionaryForClassWithName:className];
                                                                 NSArray *records = [JSONDictionary objectForKey:mObject.jsonRootAttribute];
                                                                 
                                                                 if (kGET) {
                                                                     if (![self initialSyncComplete]){
                                                                         for (NSDictionary *record in records) {
                                                                             [self createManagedObjectForObject:mObject forRecord:record];
                                                                         }
                                                                     } else {
                                                                         [self setDeleteFlagForClass:mObject.moClass
                                                                                            inContext:_backgroundManagedObjectContext];
                                                                         [self updateOrInsertObject:mObject
                                                                                  forRecordsInArray:records];
                                                                         [self deleteFlagedRecordsForClass:mObject.moClass
                                                                                                  inContext:_backgroundManagedObjectContext];
                                                                     }
                                                                 }else if (kPOST) {
                                                                     [self updateOrInsertObject:mObject forRecordsInArray:records];
                                                                 }
                                                                     
//
                                                                 
                                                                 [self saveManagedObjectContext:_backgroundManagedObjectContext];
                                                                 //#warning commented logic
                                                                 [self.syncFileManager deleteJSONDataRecordsForClassWithName:className];
                                                                 
                                                             }
                                                             completionBlock();
                                                         }];
    [[NSOperationQueue mainQueue] addOperations:batches waitUntilFinished:NO];
}

- (BOOL)initialSyncComplete
{
    return [[[NSUserDefaults standardUserDefaults] valueForKey:kSDSyncEngineInitialCompleteKey] boolValue];
}

- (void)setInitialSyncCompleted
{
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kSDSyncEngineInitialCompleteKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - delete

- (void)setDeleteFlagForClass:(Class)mClass inContext:(NSManagedObjectContext*)context
{
    objc_property_t prop = class_getProperty(mClass, "delete");
    if (prop != NULL) {
        [context performBlockAndWait:^{
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass(mClass)];
            NSError *error;
            NSArray *objects = [context executeFetchRequest:request error:&error];
            if (!objects) {
                NSLog(@"Error fetching entity: %@",error);
            }
            [objects setValue:@YES forKey:@"delete"];
            //now save your changes back.
            [context save:&error];
        }];
    }
}

- (NSManagedObject*)removeDeleteFlagOnObject:(NSManagedObject*)object
{
    if ([object respondsToSelector:NSSelectorFromString(@"delete")])
        [object setValue:@NO forKey:@"delete"];
    return object;
}

- (void)deleteFlagedRecordsForClass:(Class)mClass inContext:(NSManagedObjectContext*)context
{
    objc_property_t prop = class_getProperty(mClass, "delete");
    if (prop != NULL) {
        [context performBlockAndWait:^{
            NSFetchRequest * request = [[NSFetchRequest alloc] initWithEntityName:NSStringFromClass(mClass)];
            [request setIncludesPropertyValues:NO];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"delete == %@", @YES];
            request.predicate = predicate;
            
            NSError * error = nil;
            NSArray * objectsToDelete = [context executeFetchRequest:request error:&error];
            
            if (!objectsToDelete)
                NSLog(@"Error fetching entity: %@",error);
            
            for (NSManagedObject * entity in objectsToDelete) {
                [context deleteObject:entity];
            }
        }];
    }
}



#pragma mark - update MangedObject

/**
 Fetches records from the data store matching recors in a array of json records. 
 The rules for a match are set in the mapping object
 
 @brief  Returns objects from data store which match objects in a array of JsonObjects
 @returns A dictionary of matching NSManagedObjects
 */
- (NSDictionary*)getMatchingRecordsForObject:(AWSyncMappingObject*)object andJsonRecords:(NSArray*)records
{
    NSFetchRequest *fetchRequest = [self fetchRequestForObject:object andJsonRecords:records];
    
    // Make sure the results are sorted as well.
    NSError *error;
    NSArray *matchingEntities = [_backgroundManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!matchingEntities) {
        NSLog(@"Error fetching object: %@",error);
    }
    
    // when property is not objectId results are already sorted via fetchrequest
    if ([matchingEntities count]>0 && [object.uniquePropertyName isEqualToString:@"objectId"]) {
        matchingEntities = [self sortManagedObjectArrayByObjectID:matchingEntities];
    }

    return [NSDictionary dictionaryWithObjects:matchingEntities forKeys:[matchingEntities valueForKey:object.uniquePropertyName]];
}

- (NSFetchRequest*)fetchRequestForObject:(AWSyncMappingObject*)mObject andJsonRecords:(NSArray*)records
{
    NSArray *filteredJsonPropertyValues = [records valueForKey:mObject.uniqueJsonAttributeName];
    NSArray *downloadedRecords = [filteredJsonPropertyValues sortedArrayUsingSelector:@selector(compare:)];
    

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:mObject.className inManagedObjectContext:_backgroundManagedObjectContext]];
    NSPredicate *predicate;
    if ([mObject.uniquePropertyName isEqualToString:@"objectId"]) {
        NSMutableArray *objectIdArray = [NSMutableArray new];
        for (NSString *objectIdStr in downloadedRecords) {
            NSManagedObjectID *objId = [[_backgroundManagedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:objectIdStr]];
            [objectIdArray addObject:objId];
        }
        predicate = [NSPredicate predicateWithFormat:@"(self IN %@)", objectIdArray];
    } else{
        predicate = [NSPredicate predicateWithFormat: @"(self.%@ IN %@)",mObject.uniquePropertyName, downloadedRecords];
        [fetchRequest setSortDescriptors:@[ [[NSSortDescriptor alloc] initWithKey: mObject.uniquePropertyName ascending:YES] ]];
    }
    [fetchRequest setPredicate: predicate];
    return fetchRequest;
}

- (id)getPropertyValueForUniqueProperty:(NSString*)prop ofObject:(NSManagedObject*)obj
{
    id updateKeyPropertyValue;
    if ([prop isEqualToString:@"objectId"]) {
        NSURL *objectIdUrl = [obj.objectID URIRepresentation];
        updateKeyPropertyValue = [objectIdUrl absoluteString];
    }else
        updateKeyPropertyValue = [obj valueForKey:prop];
    return updateKeyPropertyValue;
}

- (BOOL)jsonValue:(id)jsonValue isEqualTo:(id)key;
{
    BOOL isEqual;
    if ([jsonValue isKindOfClass:[NSString class]]) {
        isEqual = [jsonValue isEqualToString:key] == NSOrderedSame;
    }
    if ([jsonValue isKindOfClass:[NSNumber class]]) {
        isEqual = [jsonValue isEqualToNumber:[NSNumber numberWithInt:[key intValue]]] == NSOrderedSame;
    }
    return isEqual;
}

- (NSDictionary*)getJsonObjectInRecords:(NSArray*)records forKey:(NSString*)key andValue:(id)value
{
    NSPredicate *p = [NSPredicate predicateWithFormat:@"self.%@ = %@", key, value];
    NSArray *matchedDicts = [records filteredArrayUsingPredicate:p];
    return [matchedDicts objectAtIndex:0]; // we only expect one result, dictionary of one json object
}

- (NSManagedObject*)getMatchingObjectInSet:(NSSet*)set inRecord:(NSDictionary*)record forMappingObject:(AWSyncMappingObject*)mObject
{
    // getting matching object in existing object set
    NSString *uniqueJsonValue = [record valueForKey:mObject.uniqueJsonAttributeName];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.%@ ==[c] %@",mObject.uniquePropertyName, uniqueJsonValue];
    // set of max one object
    NSSet *filteredSet = [set filteredSetUsingPredicate:predicate];
    return filteredSet.count == 0 ? nil : [[filteredSet allObjects]objectAtIndex:0];
}

- (void)updateOrInsertRelatedObject:(AWSyncMappingObject*)relatedMappingObject forExistingObject:(NSManagedObject*)existingObject withRecord:(NSArray*)records
{
    if(relatedMappingObject.doUpdate){
        // get a set of all existinc related objects
        NSSet *existingRelatedObjects = [existingObject valueForKey:relatedMappingObject.relatedJsonRootAttributeName];
        // set delete flag for all related objects
        [self setDeleteFlagForObjectsInSet:existingRelatedObjects forObjectClass:relatedMappingObject.moClass];
        
        NSMutableSet *set = [NSMutableSet new];
        
        // loop over json objects which are nested in the base object itmes:[{obj},{obj},...],
        [records enumerateObjectsUsingBlock:^(id record, NSUInteger idx, BOOL *stop) {
            
            NSManagedObject* existingRelatedObject = [self getMatchingObjectInSet:existingRelatedObjects inRecord:record forMappingObject:relatedMappingObject];
            
            if (existingRelatedObjects == nil) {
                existingRelatedObject = [self createManagedObjectForObject:relatedMappingObject forRecord:record];
            }else { // object does exist -> update values
                [self setAttributes:relatedMappingObject.attributesMappingDictionary fromRecords:record forObject:existingRelatedObject];
            }
            [self removeDeleteFlagOnObject:existingRelatedObject];
            [set addObject:existingRelatedObject];
        }];
        if ([set count] != 0)
            [existingObject setValue:set forKey:relatedMappingObject.relatedJsonRootAttributeName];
        [self deleteFlagedRecordsForClass:relatedMappingObject.moClass inContext:_backgroundManagedObjectContext];
    }

}

- (void)updateOrInsertObject:(AWSyncMappingObject *)mObject forRecordsInArray:(NSArray*)records
{
    // Get the names to parse in sorted order.
    // create array from updateKeyJsonProperty value
    NSArray *filteredJsonPropertyValues = [records valueForKey:mObject.uniqueJsonAttributeName];
    NSArray *jsonPropertyValues = [filteredJsonPropertyValues sortedArrayUsingSelector:@selector(compare:)];

    NSDictionary *matchingRecords = [self getMatchingRecordsForObject:mObject andJsonRecords:records];
    
    //?todo: is it possible to skip creating array of json values and use the object instead?
    
    // Iterate over both arrays to find inserts and updates
    BOOL isUpdate = YES;
    NSManagedObject *existingObject;
    id existingObjectKey;
    
    NSEnumerator *matchingObjectsEnum = [matchingRecords keyEnumerator];
    for (id jsonValue in jsonPropertyValues) {
        // go only to the next object when there was an update / was there an insert before deal with same object again
        if (isUpdate) {
            existingObjectKey = [matchingObjectsEnum nextObject];
            existingObject = [matchingRecords objectForKey:existingObjectKey];
        }
        isUpdate = [self jsonValue:jsonValue isEqualTo:existingObjectKey];
//        // Todo: unused at the moment, find what was the perpuse of that
//        id updateKeyPropertyValue = [self getPropertyValueForUniqueProperty:mObject.uniquePropertyName ofObject:existingObject];
        
        NSDictionary *jsonRecord = [self getJsonObjectInRecords:records forKey:mObject.uniqueJsonAttributeName andValue:jsonValue];
        
        if (isUpdate) {
            /* update objects without relation */
            if ([mObject.relatedMappingObjects count] == 0) {
                [self setAttributes:mObject.attributesMappingDictionary fromRecords:jsonRecord forObject:existingObject];
                [self setAttributes:mObject.setKeysToValuesOnUpdate forObject:existingObject];
                [self removeDeleteFlagOnObject:existingObject];
            }
            /* update objects with relation */
            else {
                if (mObject.doUpdate) {
#warning missing logic
                    // TODO: update parent object = yes  do update partent object todo: add parent update logic (like above?)
                }
                /* Updating related object */
                else if (mObject.relatedMappingObjects != nil){
                    for (AWSyncMappingObject *relatedMappingObject in mObject.relatedMappingObjects) {
                        [self updateOrInsertRelatedObject:relatedMappingObject
                                        forExistingObject:existingObject
                                               withRecord:[jsonRecord objectForKey:relatedMappingObject.jsonRootAttribute]];
                    }
                }
            }
        }else
            [self createManagedObjectForObject:mObject forRecord:jsonRecord];
    }
}


- (void)setDeleteFlagForObjectsInSet:(NSSet*)objectSet forObjectClass:(Class)class
{
    objc_property_t prop = class_getProperty(class, "delete");
    if (prop != NULL) {
        [objectSet setValue:@YES forKey:@"delete"];
    }
}

#pragma markg - helper

- (void)saveManagedObjectContext:(NSManagedObjectContext*)context
{
    [context performBlockAndWait:^{
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Unable to save context");
        }
    }];
}

- (NSArray *)sortManagedObjectArrayByObjectID:(NSArray *) array{
    
    NSArray *compareResult = [array sortedArrayUsingComparator:^NSComparisonResult(NSManagedObject *obj1, NSManagedObject *obj2) {
        
        NSString *s = [obj1.objectID.URIRepresentation lastPathComponent];
        NSString *r = [obj2.objectID.URIRepresentation lastPathComponent];
        return [s compare:r];
        
    }];
    
    return compareResult;
}

- (void)setAttributes:(NSDictionary*)attributes  fromRecords:(NSDictionary*)record forObject:(NSManagedObject*)object
{
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setValue:[record valueForKey:obj] forKey:key forManagedObject:object];
    }];
}

- (void)setAttributes:(NSDictionary*)attributes forObject:(NSManagedObject*)object
{
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setValue:obj forKey:key forManagedObject:object];
    }];
}

- (void)setValue:(id)value forKey:(NSString *)key forManagedObject:(NSManagedObject *)managedObject
{
    id convertedValue;
    if ([value isKindOfClass:[NSDictionary class]]) {
#warning incompleete  - not sure what i intended here but it works like it is
    } else {
        convertedValue = [self convertValue:value toPropertyTypeforKey:key ofClass:managedObject];
        [managedObject setValue:convertedValue forKey:key];
    }
}

/** we need to convert to type of porperty because value seems to be always NSString **/
- (id)convertValue:(id)value toPropertyTypeforKey:(NSString*)key ofClass:(NSManagedObject*)managedObject
{
    if(![value isKindOfClass:[NSNumber class]] && [value length]!= 0 ){
        NSEntityDescription *entityDescr = managedObject.entity;
        NSAttributeDescription *attr = [[entityDescr attributesByName] objectForKey:key];
        if ([[attr attributeValueClassName] isEqualToString:NSStringFromClass([NSNumber class])]) {
            NSScanner* scan = [NSScanner scannerWithString:value];
            int intValue;
            double doubleValue;
            if ([scan scanInt:&intValue] && [scan isAtEnd])
                value = [NSNumber numberWithLong:[value longValue]];
            if ([scan scanDouble:&doubleValue] && [scan isAtEnd]) {
                value = [NSNumber numberWithDouble:[value doubleValue] ];
            }
        }else if([self isDateTimeFormat:value]){
            value = [self parseDate:value];
        }
    }
    return value;
}

- (NSDate*)parseDate:(NSString*)value
{
    BOOL isDateOnly = [self isDateOnly:value];
    
    NSDate*d=nil;
    NSError *error = nil;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeDate error:&error];
    NSArray *matches = [detector matchesInString:value options:0 range:NSMakeRange(0, [value length])];
    for (NSTextCheckingResult *match in matches) {
        unsigned int flags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit;
        NSCalendar* calendar = [NSCalendar currentCalendar];
        NSDateComponents* components = [calendar components:flags fromDate:match.date];
        if (isDateOnly) {
            components.hour = 0;
            components.minute = 0;
            components.second = 0;
        }
        d = [calendar dateFromComponents:components];
    }
    return d;
}

- (BOOL)isDateTimeFormat:(NSString*)value
{
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"^(\\d{4}-\\d{2}-\\d{2})$|^(\\d{4}-\\d{2}-\\d{2}) (\\d{2}:\\d{2}:\\d{2})$"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:nil];
    
    NSUInteger num = [regex numberOfMatchesInString:value
                                     options:0
                                       range:NSMakeRange(0, [value length])];
    return num == 1;
}

- (BOOL)isDateOnly:(NSString*)value
{
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"^(\\d{4}-\\d{2}-\\d{2})$"
                                  options:NSRegularExpressionCaseInsensitive
                                  error:nil];
    
    NSUInteger num = [regex numberOfMatchesInString:value
                                     options:0
                                       range:NSMakeRange(0, [value length])];
    return num == 1;
}

- (NSString *)dateStringForAPIUsingDate:(NSDate *)date
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    
    NSString *dateString = [dateFormatter stringFromDate:date];
    
    dateFormatter = nil;
    return dateString;
}


@end

@implementation AWErrorHandling


+ (NSError*)errorWithCode:(AWErrorCodes)code
{
    NSString *desc;
    switch (code) {
        case AWErrorMissingBaseUrl:
            desc = @"Sync can't get initialized. Missing base URL, request can't get exicuted";
            break;
        case AWErrorNoRegisteredClasses:
            desc = @"Sync can't get initialized. No registered classes, nothing to sync";
            break;
        case AWErrorSyncInProgress:
            desc = @"Sync can't get initialized. Sync already in progress";
            break;
        default:
            desc = @"Unknown error";
            break;
    }
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc };
    return [NSError errorWithDomain:kAppDomain code:code userInfo:userInfo];
}
@end
