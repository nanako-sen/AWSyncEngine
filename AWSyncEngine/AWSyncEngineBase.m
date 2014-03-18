//
//  CCCSyncEngineBase.m
//  CCCKerbside
//
//  Created by Anna Walser on 1/21/14.
//  Copyright (c) 2014 Anna Walser. All rights reserved.
//

#import "AWSyncEngineBase.h"



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


- (NSDate*)lastSynced
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults valueForKey:@"lastSynced"];
}


# pragma mark - ManagedObject mapping

- (void)newManagedObjectForObject:(AWSyncMappingObject *)mObject forRecord:(NSDictionary *)record
{
    (void)[self createManagedObjectForObject:mObject forRecord:record];
}

- (NSManagedObject*)createManagedObjectForObject:(AWSyncMappingObject *)mObject forRecord:(NSDictionary *)record
{
    
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[mObject stringClassName]
                                                                      inManagedObjectContext:_backgroundManagedObjectContext];
    
    [self setAttributes:mObject.attributeMappingDictionary fromRecords:record forObject:newManagedObject];
    
    [mObject.relatedObjects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
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
                                                             
                                                             for (AWSyncMappingObject* mObject in self.registeredClassesToSync) {
                                                                 NSString *className = [mObject stringClassName];
                                                                 
//                                                                 if (![self initialSyncComplete]) { // todo: would this imove something? import all downloaded data to Core Data for initial sync
                                                                 
                                                                     NSDictionary *JSONDictionary = [self.syncFileManager JSONDictionaryForClassWithName:className];
                                                                     NSArray *records = [JSONDictionary objectForKey:mObject.jsonRootAttribute];
                                                                     
                                                                     if (kGET) {
                                                                         [self setDeleteFlagForObject:mObject
                                                                                            inContext:_backgroundManagedObjectContext];
                                                                         [self updateOrInsertObject:mObject
                                                                                  forRecordsInArray:records];
                                                                         [self deleteFlagedRecordsForObject:mObject
                                                                                                  inContext:_backgroundManagedObjectContext];
                                                                     }else if (kPOST) {
                                                                         [self updateOrInsertObject:mObject forRecordsInArray:records];
                                                                     }
                                                                     
//                                                                 }
                                                                 
                                                                 [self saveManagedObjectContext:_backgroundManagedObjectContext];
                                                                 //#warning commented logic
                                                                 [self.syncFileManager deleteJSONDataRecordsForClassWithName:className];
                                                                 
                                                             }
                                                             completionBlock();
                                                         }];
    [[NSOperationQueue mainQueue] addOperations:batches waitUntilFinished:NO];
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

- (void)saveManagedObjectContext:(NSManagedObjectContext*)context
{
    [context performBlockAndWait:^{
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Unable to save context");
        }
    }];
}

#pragma mark - update MangedObject

- (void)updateOrInsertObject:(AWSyncMappingObject *)mObject forRecordsInArray:(NSArray*)records
{

    NSString *updateKeyPropertyName = [[mObject.uniquePropertyJSONAttributeMappingDict allKeys]objectAtIndex:0];
    NSString *updateKeyJsonPropertyName = [mObject.uniquePropertyJSONAttributeMappingDict objectForKey:updateKeyPropertyName];

    // Get the names to parse in sorted order.
    // create array from updateKeyJsonProperty value
    NSArray *filteredJsonPropertyValues = [records valueForKey:updateKeyJsonPropertyName];
    NSArray *sortedFilteredJsonPropertyValues = [filteredJsonPropertyValues sortedArrayUsingSelector:@selector(compare:)];

    // create the fetch request to get all Employees matching the IDs
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:mObject.stringClassName inManagedObjectContext:_backgroundManagedObjectContext]];

    NSPredicate *predicate;
    if ([updateKeyPropertyName isEqualToString:@"objectId"]) {
        NSMutableArray *objectIdArray = [NSMutableArray new];
        for (NSString *objectIdStr in sortedFilteredJsonPropertyValues) {
            NSManagedObjectID *objId = [[_backgroundManagedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:objectIdStr]];
            [objectIdArray addObject:objId];
        }
        predicate = [NSPredicate predicateWithFormat:@"(self IN %@)", objectIdArray];
    } else{
        predicate = [NSPredicate predicateWithFormat: @"(self.%@ IN %@)",updateKeyPropertyName, sortedFilteredJsonPropertyValues];
        [fetchRequest setSortDescriptors:@[ [[NSSortDescriptor alloc] initWithKey: updateKeyPropertyName ascending:YES] ]];
    }
    [fetchRequest setPredicate: predicate];
    
    // Make sure the results are sorted as well.
    NSError *error;
    NSArray *matchingEntities = [_backgroundManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {
        NSLog(@"Error fetching object: %@",error);
    }
    
    if ([matchingEntities count]>0 && [updateKeyPropertyName isEqualToString:@"objectId"]) {
        matchingEntities = [self sortManagedObjectArrayByObjectID:matchingEntities];
    }
    
    // Iterate over both arrays to find inserts and updates
    NSEnumerator *otherEnum = [matchingEntities objectEnumerator];
    for (id value in sortedFilteredJsonPropertyValues) {
        NSManagedObject *existingEntity = [otherEnum nextObject];
        id updateKeyPropertyValue;
        if ([updateKeyPropertyName isEqualToString:@"objectId"]) {
            NSURL *objectIdUrl = [existingEntity.objectID URIRepresentation];
            updateKeyPropertyValue = [objectIdUrl absoluteString];
        }else
            updateKeyPropertyValue = [existingEntity valueForKey:updateKeyPropertyName];
        
        // get record dictionary in records for value
        NSPredicate *p = [NSPredicate predicateWithFormat:@"self.%@ = %@", updateKeyJsonPropertyName, value];
        NSArray *matchedDicts = [records filteredArrayUsingPredicate:p];
        NSDictionary *jsonRecord = [matchedDicts objectAtIndex:0];
        
        BOOL areSame;
        if ([value isKindOfClass:[NSString class]]) {
            areSame = [value isEqualToString:updateKeyJsonPropertyName] == NSOrderedSame;
        }
        if ([value isKindOfClass:[NSNumber class]]) {
            areSame = [value isEqualToNumber:[NSNumber numberWithInt:[updateKeyJsonPropertyName intValue]]] == NSOrderedSame;
        }
        
        if (areSame) {
            //We have found a pair of same objects. - update
            // update objects with relation
            if (mObject.relatedJSONAttributeName.length != 0) {
                if (mObject.updateObject) {
                    // update parent object = yes  do update partent object todo: add parent update logic
                }
                // Updating related object
                if (mObject.relatedMappingObject.updateObject) {
                    
                    NSSet *existingRelatedObjects = [existingEntity valueForKey:mObject.relatedJSONAttributeName];
                    objc_property_t prop = class_getProperty(mObject.relatedMappingObject.className, "delete");
                    if (prop != NULL) {
                        [existingRelatedObjects setValue:@YES forKey:@"delete"];
                    }
                    
                    NSMutableSet *set = [NSMutableSet new];
                    
                    [[jsonRecord objectForKey:mObject.relatedMappingObject.jsonRootAttribute] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    
                        NSString *uniqueValue = [obj valueForKey:mObject.relatedMappingObject.uniqueAttributeJsonName];
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self.%@ ==[c] %@",mObject.relatedMappingObject.uniquePropertyName, uniqueValue];
                            
                        NSSet *filteredSet = [existingRelatedObjects filteredSetUsingPredicate:predicate];
                        // Object does not exist
                        if ([filteredSet count] == 0) {
                            NSManagedObject *relatedObject = [self createManagedObjectForObject:mObject.relatedMappingObject forRecord:obj];
                            [self removeDeleteFlagOnObject:relatedObject];
                            [set addObject:relatedObject];
                        }else { // object does exist -> update values
                            NSManagedObject* existingObject = [[filteredSet allObjects]objectAtIndex:0];
                            [self setAttributes:mObject.relatedMappingObject.attributeMappingDictionary fromRecords:obj forObject:existingObject];
                            [self removeDeleteFlagOnObject:existingObject];
                            [set addObject:existingObject];
                            
                        }

                    }];
                    if ([set count] != 0)
                        [existingEntity setValue:set forKey:mObject.relatedJSONAttributeName];
                    // ??? is this even nessaserly? setting the set of related object on the main object removes existing ones
                    [self deleteFlagedRecordsForObject:mObject.relatedMappingObject inContext:_backgroundManagedObjectContext];
                }
                
            }else {
                // update objects without relation
                [self setAttributes:mObject.attributeMappingDictionary fromRecords:jsonRecord forObject:existingEntity];
                [self setAttributes:mObject.resetValuesOnUpdate forObject:existingEntity];
                [self removeDeleteFlagOnObject:existingEntity];
            }
        }else
            [self newManagedObjectForObject:mObject forRecord:jsonRecord];

    }
//    }
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
