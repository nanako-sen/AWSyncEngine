//
//  RDUMapping.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/8/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncMappingObject.h"

@implementation AWSyncMappingObject
@synthesize className = _className;
@synthesize attributeMappingDictionary = _attributeMappingDictionary;
@synthesize relatedMappingObjects = _relatedMappingObjects;
@synthesize apiQuery = _apiQuery;
@synthesize jsonRootAttribute = _jsonRootAttribute;
@synthesize uniquePropertyName = _uniquePropertyName;

@synthesize updateObject = _updateObject;
//@synthesize uniquePropertyJSONAttributeMappingDict = _uniquePropertyJSONAttributeMappingDict;
//@synthesize relatedMappingObject = _relatedMappingObject;
//@synthesize updatePredicateFormat = _updatePredicateFormat;
//@synthesize updatePredicateJsonAttribute = _updatePredicateJsonAttribute;
@synthesize resetValuesOnUpdate = _resetValuesOnUpdate;
@synthesize relatedJSONAttributeName = _relatedAttributeName;
@synthesize uniqueJsonAttribute = _uniqueJsonAttribute;

//TODO: refactor/ cleanup / improve



// needsDeletion removed


+ (AWSyncMappingObject*)mappingForPost:(NSDictionary*)params fromURL:(NSString*)urlString
{
    AWSyncMappingObject *mo = [AWSyncMappingObject new];
    mo.postDataDictionary = params;
    mo.apiQuery = urlString;

    
    return  mo;
}

//+ (RDUSyncMappingObject*)mappingForPostForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del postParams:(NSDictionary*)params
//{
//    RDUSyncMappingObject *mapping = [[RDUSyncMappingObject alloc] initForPostForClass:mClassName
//                                                                  fromResource:(NSString*)mResource
//                                                                         atKey:(NSString*)key
//                                                              attributeMapping:mMapping
//                                                                relatedObjects:mRelatedObjects
//                                                                   forProperty:prop
//                                                                  uniqueIdName:uid
//                                                                 needsDeletion:del
//                                                                    postParams:params];
//    return mapping;
//}


+ (AWSyncMappingObject*)simpleMappingForClass:(Class)mClassName fromResource:(NSString*)mResource
{
    AWSyncMappingObject *mapping = [[AWSyncMappingObject alloc] initForClass:mClassName
                                                                  fromResource:(NSString*)mResource
                                                                         atKey:@"data"
                                                              attributeMapping:nil
                                                                relatedObjects:nil
                                                                   forProperty:nil
                                                                  uniqueIdName:nil
                                                                 needsDeletion:NO];
    return mapping;
    
}


+ (AWSyncMappingObject*)mappSingleRelationForClass:(Class)mClassName atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping forProperty:(NSString *)prop
{
    AWSyncMappingObject *mapping = [[AWSyncMappingObject alloc] initForClass:mClassName
                                                                  fromResource:nil
                                                                         atKey:(NSString*)key
                                                              attributeMapping:mMapping
                                                                relatedObjects:nil
                                                                   forProperty:prop
                                                                  uniqueIdName:nil
                                                                 needsDeletion:NO];
    return mapping;
    
}


+ (AWSyncMappingObject*)mappingForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del
{
    AWSyncMappingObject *mapping = [[AWSyncMappingObject alloc] initForClass:mClassName
                                                                  fromResource:(NSString*)mResource
                                                                         atKey:(NSString*)key
                                                              attributeMapping:mMapping
                                                                relatedObjects:mRelatedObjects
                                                                   forProperty:prop
                                                                  uniqueIdName:uid
                                                                 needsDeletion:del];
    return mapping;
    
}

// ---------
- (void)setUpdateObjectAtUniqueProperty:(NSString*)uniquePropertyName mappedToJsonAttribute:(NSString*)jsonAttribute
{
    self.updateObject = YES;
    self.uniquePropertyName = uniquePropertyName;
    self.uniqueJsonAttribute = jsonAttribute;
}


// -----------



- (AWSyncMappingObject*)initForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del
{
    if (self = [super init]) {
        self.className = mClassName;
        self.attributeMappingDictionary = mMapping;
        self.relatedMappingObjects = mRelatedObjects;
        self.relatedObjectsFroProperty = prop;
        self.apiQuery = mResource;
        self.jsonRootAttribute = key;
        self.uniquePropertyName = uid;
    }
    return self;
}

- (AWSyncMappingObject*)initForPostForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del postParams:(NSDictionary*)params
{
    if (self = [super init]) {
        self.className = mClassName;
        self.attributeMappingDictionary = mMapping;
        self.relatedMappingObjects = mRelatedObjects;
        self.relatedObjectsFroProperty = prop;
        self.apiQuery = mResource;
        self.jsonRootAttribute = key;
        self.uniquePropertyName = uid;
        self.postDataDictionary = params;
    }
    return self;
}


- (id)init
{
    if (self = [super init]) {
        
    }
    return self;
}

- (NSString*)stringClassName
{
    return NSStringFromClass(self.className);
}

@end


@implementation NSMutableArray (findObjects)

- (BOOL)containsObjectWithClass:(Class)c
{
    for (AWSyncMappingObject* m in self) {
        if (m.className == c ) {
            return YES;
        }
    }
    return NO;
}


@end
