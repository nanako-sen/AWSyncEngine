//
//  CCCSyncEngineBase.m
//  CCCKerbside
//
//  Created by Anna Walser on 1/21/14.
//  Copyright (c) 2014 Anna Walser. All rights reserved.
//

#import "AWSyncEngineBase.h"

NSString * const kSDSyncEngineInitialCompleteKey = @"SDSyncEngineInitialSyncCompleted";


@interface AWSyncEngineBase () {
    NSManagedObjectContext *_backgroundManagedObjectContext;
}


@property (nonatomic, strong) NSMutableArray *registeredClassesToSync;

@end

@implementation AWSyncEngineBase

@synthesize registeredClassesToSync = _registeredClassesToSync,
                    syncFileManager = _syncFileManager,
                            baseUrl = _baseUrl,
                 coreDataController = _coreDataController;


- (id)init
{
    if (self = [super init]) {
        self.syncFileManager = [AWSyncEngineFileManager new];
        self.coreDataController = [AWCoreDataController new];
        _backgroundManagedObjectContext = [self.coreDataController backgroundManagedObjectContext];
    }
    return self;
}

#pragma mark - register objects to sync

- (void)registerNSManagedObjectToSync:(AWSyncMappingObject*)mObject
{
    if (!self.registeredClassesToSync) {
        self.registeredClassesToSync = [NSMutableArray array];
    }
    
    if ([mObject.className isSubclassOfClass:[NSManagedObject class]]) {
        if (![self.registeredClassesToSync containsObjectWithClass:mObject.className]) {
            [self.registeredClassesToSync addObject:mObject];
        } else {
            NSLog(@"Unable to register %@ as it is already registered", [mObject stringClassName]);
        }
    } else {
        NSLog(@"Unable to register %@ as it is not a subclass of NSManagedObject", NSStringFromClass(mObject.className));
    }
}

- (void)clearRegister
{
    self.registeredClassesToSync = nil;
}



# pragma mark - ManagedObject mapping


- (NSManagedObject*)createManagedObjectForObject:(AWSyncMappingObject *)mObject forRecord:(NSDictionary *)record
{
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[mObject stringClassName]
                                                                      inManagedObjectContext:_backgroundManagedObjectContext];
    
    [self setAttributes:mObject.attributeMappingDictionary fromRecords:record forObject:newManagedObject];
    
    [mObject.relatedMappingObjects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        AWSyncMappingObject *mo = (AWSyncMappingObject*)obj;
        if ([record objectForKey:mo.jsonRootAttribute] != nil) {
            if ([[record objectForKey:mo.jsonRootAttribute] isKindOfClass:[NSArray class]]) {
                NSMutableSet *set = [NSMutableSet new];
                for (NSDictionary *subRecord in [record objectForKey:mo.jsonRootAttribute]) {
                    [set addObject:[self createManagedObjectForObject:mo forRecord:subRecord]];
                    [newManagedObject setValue:[set copy] forKey:mo.relatedObjectsFroProperty];
                }
            }
            else {
                NSManagedObject* managedObject =  [self createManagedObjectForObject:mo forRecord:[record objectForKey:mo.jsonRootAttribute]];
                [newManagedObject setValue:managedObject forKey:mo.relatedObjectsFroProperty];
            }
        }
    }];

    [self removeDeleteFlagOnObject:newManagedObject];
    
    return newManagedObject;
}

#pragma mark - Connection Execute

- (void)executeConnectionOperationWithRequestType:(AWRequestType)type completionBlock:(void(^)(void))completionBlock
{
    NSMutableArray *operations = [NSMutableArray array];
    
    for (AWSyncMappingObject *mObject in self.registeredClassesToSync) {
        NSString *className = mObject.stringClassName;
        AWAFParseAPIClient *parseAPIClient = [[AWAFParseAPIClient alloc] initWithBaseURL:self.baseUrl];
        
        NSMutableURLRequest *request = [NSMutableURLRequest new];
        if (type == kPOST) {
            request = [parseAPIClient POSTRequestToUrl:mObject.apiQuery parameters:mObject.postDataDictionary];
        }else if (type == kGET){
            request = [parseAPIClient GETRequest:mObject.apiQuery parameters:nil];
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
                                                                 NSString *className = [mObject stringClassName];
                                                                 NSDictionary *JSONDictionary = [self.syncFileManager JSONDictionaryForClassWithName:className];
                                                                 NSArray *records = [JSONDictionary objectForKey:mObject.jsonRootAttribute];
                                                                 
                                                                 if (kGET) {
                                                                     if (![self initialSyncComplete]){
                                                                         for (NSDictionary *record in records) {
                                                                             [self createManagedObjectForObject:mObject forRecord:record];
                                                                         }
                                                                     } else {
                                                                         [self setDeleteFlagForObject:mObject
                                                                                            inContext:_backgroundManagedObjectContext];
                                                                         [self updateOrInsertObject:mObject
                                                                                  forRecordsInArray:records];
                                                                         [self deleteFlagedRecordsForObject:mObject
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

- (void)setDeleteFlagForObject:(AWSyncMappingObject*)object inContext:(NSManagedObjectContext*)context
{
    objc_property_t prop = class_getProperty(object.className, "delete");
    if (prop != NULL) {
        [context performBlockAndWait:^{
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:object.stringClassName];
            NSError *error;
            NSArray *objects = [context executeFetchRequest:request error:&error];
            if (error) {
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

- (void)deleteFlagedRecordsForObject:(AWSyncMappingObject*)object inContext:(NSManagedObjectContext*)context
{
    objc_property_t prop = class_getProperty(object.className, "delete");
    if (prop != NULL) {
        [context performBlockAndWait:^{
            NSFetchRequest * request = [[NSFetchRequest alloc] initWithEntityName:object.stringClassName];
            [request setIncludesPropertyValues:NO];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"delete == %@", @YES];
            request.predicate = predicate;
            
            NSError * error = nil;
            NSArray * objectsToDelete = [context executeFetchRequest:request error:&error];
            
            if (error)
                NSLog(@"Error fetching entity: %@",error);
            
            for (NSManagedObject * entity in objectsToDelete) {
                [context deleteObject:entity];
            }
        }];
    }
}



#pragma mark - update MangedObject

- (NSArray*)getMatchingRecordsForObject:(AWSyncMappingObject*)mObject andJsonRecords:(NSArray*)records
{
    NSFetchRequest *fetchRequest = [self fetchRequestForObject:mObject andJsonRecords:records];
    
    // Make sure the results are sorted as well.
    NSError *error;
    NSArray *matchingEntities = [_backgroundManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"Error fetching object: %@",error);
    }
    
    // when property is not objectId results are already sorted via fetchrequest
    if ([matchingEntities count]>0 && [mObject.uniquePropertyName isEqualToString:@"objectId"]) {
        matchingEntities = [self sortManagedObjectArrayByObjectID:matchingEntities];
    }
    return matchingEntities;
}

- (NSFetchRequest*)fetchRequestForObject:(AWSyncMappingObject*)mObject andJsonRecords:(NSArray*)records
{
    NSArray *filteredJsonPropertyValues = [records valueForKey:mObject.uniqueJsonAttribute];
    NSArray *downloadedRecords = [filteredJsonPropertyValues sortedArrayUsingSelector:@selector(compare:)];

    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:mObject.stringClassName inManagedObjectContext:_backgroundManagedObjectContext]];
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

- (BOOL)jsonValue:(id)jsonValue isEqualTo:(AWSyncMappingObject*)mObject;
{
    BOOL isEqual;
    if ([jsonValue isKindOfClass:[NSString class]]) {
        isEqual = [jsonValue isEqualToString:mObject.uniqueJsonAttribute] == NSOrderedSame;
    }
    if ([jsonValue isKindOfClass:[NSNumber class]]) {
        isEqual = [jsonValue isEqualToNumber:[NSNumber numberWithInt:[mObject.uniqueJsonAttribute intValue]]] == NSOrderedSame;
    }
    return isEqual;
}

- (void)updateOrInsertObject:(AWSyncMappingObject *)mObject forRecordsInArray:(NSArray*)records
{

    // Get the names to parse in sorted order.
    // create array from updateKeyJsonProperty value
    NSArray *filteredJsonPropertyValues = [records valueForKey:mObject.uniqueJsonAttribute];
    NSArray *jsonPropertyValues = [filteredJsonPropertyValues sortedArrayUsingSelector:@selector(compare:)];

    NSArray *matchingEntities = [self getMatchingRecordsForObject:mObject andJsonRecords:records];
    
    //todo: is it possible to skip creating array of json values and use the object instead?
    
    // Iterate over both arrays to find inserts and updates
    BOOL isUpdate = YES;
    NSManagedObject *existingEntity;
    NSEnumerator *otherEnum = [matchingEntities objectEnumerator];
    for (id jsonValue in jsonPropertyValues) {
        // go only to the next object when there was an update / was there an insert before deal with same object again
        if (isUpdate) {
            existingEntity = [otherEnum nextObject];
        }
        
        id updateKeyPropertyValue = [self getPropertyValueForUniqueProperty:mObject.uniquePropertyName ofObject:existingEntity];
        
        // get json object by the json unique value
        NSPredicate *p = [NSPredicate predicateWithFormat:@"self.%@ = %@", mObject.uniqueJsonAttribute, jsonValue];
        NSArray *matchedDicts = [records filteredArrayUsingPredicate:p];
        NSDictionary *jsonRecord = [matchedDicts objectAtIndex:0]; // dictionary of one json object
        
#warning potential BUG!
        // should check if existing value and json value are same
        
        isUpdate = [self jsonValue:jsonValue isEqualTo:mObject];
        
        if (isUpdate) {
            //We have found a pair of same objects. - update
            // update objects without relation
            if ([mObject.relatedJSONAttributeName length] == 0) {
                [self setAttributes:mObject.attributeMappingDictionary fromRecords:jsonRecord forObject:existingEntity];
                [self setAttributes:mObject.resetValuesOnUpdate forObject:existingEntity];
                [self removeDeleteFlagOnObject:existingEntity];
            }
            // update objects with relation
            else {
                if (mObject.updateObject) {
#warning missing logic
                    // TODO: update parent object = yes  do update partent object todo: add parent update logic (like above?)
                }
                // Updating related object
                else if (mObject.relatedMappingObjects != nil){
#warning potential BUG! looping through related objects does not work as realtedjsonattribute is missing
                    for (AWSyncMappingObject *relatedMappingObject in mObject.relatedMappingObjects) {
                        
                        if(relatedMappingObject.updateObject){
                            // get a set of all existinc related objects
                            NSSet *existingRelatedObjects = [existingEntity valueForKey:mObject.relatedJSONAttributeName];
                            // set delete flag for all related objects
                            [self setDeleteFlagForSet:existingRelatedObjects forObjectClass:relatedMappingObject.className];
                            
                            NSMutableSet *set = [NSMutableSet new];
                            
                            // loop over json objects which are nested in the base object itmes:[{obj},{obj},...],
                            [[jsonRecord objectForKey:relatedMappingObject.jsonRootAttribute] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            
                                // getting matching object in existing object set
                                NSString *uniqueJsonValue = [obj valueForKey:relatedMappingObject.uniqueJsonAttribute];
                                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.%@ ==[c] %@",relatedMappingObject.uniquePropertyName, uniqueJsonValue];
                                // set of max one object
                                NSSet *filteredSet = [existingRelatedObjects filteredSetUsingPredicate:predicate];
                                
                                // Object does not exist
                                if ([filteredSet count] == 0) {
                                    NSManagedObject *relatedObject = [self createManagedObjectForObject:relatedMappingObject forRecord:obj];
                                    [self removeDeleteFlagOnObject:relatedObject];
                                    [set addObject:relatedObject];
                                }else { // object does exist -> update values
                                    // we expecting only one result back
                                    NSManagedObject* existingRelatedObject = [[filteredSet allObjects]objectAtIndex:0];
                                    [self setAttributes:relatedMappingObject.attributeMappingDictionary fromRecords:obj forObject:existingRelatedObject];
                                    [self removeDeleteFlagOnObject:existingRelatedObject];
                                    [set addObject:existingRelatedObject];
                                    
                                }
                            }];
                            if ([set count] != 0)
                                [existingEntity setValue:set forKey:mObject.relatedJSONAttributeName];
                            [self deleteFlagedRecordsForObject:relatedMappingObject inContext:_backgroundManagedObjectContext];
                        }
                    }
                }
                
            }
        }else
            [self createManagedObjectForObject:mObject forRecord:jsonRecord];

    }
//    }
}

- (void)updateObject:(NSManagedObjectContext*)existingEntity
{

}

- (void)setDeleteFlagForSet:(NSSet*)objectSet forObjectClass:(Class)class
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

- (NSArray *) sortManagedObjectArrayByObjectID:(NSArray *) array {
    
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
