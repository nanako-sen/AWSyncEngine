//
//  RDUMapping.h
//  RDULoyalty
//
//  Created by Anna Walser on 10/8/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface AWSyncMappingObject : NSObject

@property (nonatomic, assign) Class className;
@property (nonatomic, strong) NSString *apiQuery;
@property (nonatomic, strong) NSString *jsonRootAttribute;
@property (nonatomic, strong) NSDictionary *attributeMappingDictionary;
/*  NSSet of RRDUMapping ojbects*/
// relation
@property (nonatomic, strong) NSString *relatedObjectsFroProperty;
@property (nonatomic, strong) NSSet *relatedObjects;


//@property (nonatomic, assign) BOOL needsDeletion;

//post
@property (nonatomic, strong) NSDictionary *postDataDictionary;

//update
@property (nonatomic, assign) BOOL updateObject;
@property (nonatomic, strong) NSDictionary *uniquePropertyJSONAttributeMappingDict;
@property (nonatomic, strong) NSString *uniquePropertyName;
@property (nonatomic, strong) NSString *uniqueAttributeJsonName;
@property (nonatomic, strong) NSString *updatePredicateFormat;
@property (nonatomic, strong) NSString *updatePredicateJsonAttribute;
@property (nonatomic, strong) NSDictionary *resetValuesOnUpdate;

//relation
@property (nonatomic, strong) AWSyncMappingObject *relatedMappingObject;
@property (nonatomic, strong) NSString *relatedJSONAttributeName;

/**
 * GET REQUEST
 * uniqueIdName only needed if needs deletion NO (-> only records which are not in the store are getting inserted - no update fo existing records)
 */
+ (AWSyncMappingObject*)simpleMappingForClass:(Class)mClassName fromResource:(NSString*)mResource;

+ (AWSyncMappingObject*)mappSingleRelationForClass:(Class)mClassName
                                              atKey:(NSString*)key
                                   attributeMapping:(NSDictionary*)mMapping
                                        forProperty:(NSString *)prop;


+ (AWSyncMappingObject*)mappingForClass:(Class)mClassName
                  fromResource:(NSString*)mResource
                         atKey:(NSString*)key
              attributeMapping:(NSDictionary*)mMapping
                relatedObjects:(NSSet*)mRelatedObjects
                   forProperty:(NSString*)prop
                  uniqueIdName:(NSString*)uid
                 needsDeletion:(BOOL)del;

//+ (RDUSyncMappingObject*)mappingToExistingObjectForClass:(Class)mClassName fromURL:(NSString *)urlString atJsonRootKey:(NSString *)key attributeMapping:(NSDictionary *)mMapping relatedToExistingObject:(Class)existingObject objectIdProperty:(NSString*)objectIdProp;

/**
 *  POST
 */

+ (AWSyncMappingObject*)mappingForPost:(NSDictionary*)params fromURL:(NSString*)urlString;
//+ (RDUSyncMappingObject*)mappingForPostForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del postParams:(NSDictionary*)params;


- (AWSyncMappingObject*)initForClass:(Class)mClassName
               fromResource:(NSString*)mResource
                      atKey:(NSString*)key
           attributeMapping:(NSDictionary*)mMapping
             relatedObjects:(NSSet*)mRelatedObjects
                forProperty:(NSString*)prop
               uniqueIdName:(NSString*)uid
              needsDeletion:(BOOL)del;

- (AWSyncMappingObject*)initForPostForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del postParams:(NSDictionary*)params;

- (NSString*)stringClassName;
@end

@interface NSMutableArray (findObjects)
- (BOOL)containsObjectWithClass:(Class)c;

@end
