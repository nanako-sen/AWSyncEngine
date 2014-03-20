//
//  RDUMapping.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/8/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncMappingObject.h"

@implementation AWSyncMappingObject
@synthesize moClass = _moClass;
@synthesize attributesMappingDictionary = _attributesMappingDictionary;
@synthesize relatedMappingObjects = _relatedMappingObjects;
@synthesize requestAPIResource = _requestAPIResource;
@synthesize jsonRootAttribute = _jsonRootAttribute;
@synthesize uniquePropertyName = _uniquePropertyName;

@synthesize doUpdateObject = _doUpdateObject;
@synthesize setKeysToValuesOnUpdate = _setKeysToValuesOnUpdate;
@synthesize relatedJsonRootAttributeName = _relatedAttributeName;
@synthesize uniqueJsonAttributeName = _uniqueJsonAttributeName;

//TODO: refactor/ cleanup / improve



// needsDeletion removed

//
+ (AWSyncMappingObject*)mappingForPost:(NSDictionary*)params fromURL:(NSString*)urlString
{
    AWSyncMappingObject *mo = [AWSyncMappingObject new];
    mo.postDataDictionary = params;
    mo.requestAPIResource = urlString;

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


//+ (AWSyncMappingObject*)simpleMappingForClass:(Class)mClassName fromResource:(NSString*)mResource
//{
//    AWSyncMappingObject *mapping = [[AWSyncMappingObject alloc] initForClass:mClassName
//                                                                  fromResource:(NSString*)mResource
//                                                                         atKey:@"data"
//                                                              attributeMapping:nil
//                                                                relatedObjects:nil
//                                                                   forProperty:nil
//                                                                  uniqueIdName:nil
//                                                                 needsDeletion:NO];
//    return mapping;
//    
//}
//
//
//+ (AWSyncMappingObject*)mappSingleRelationForClass:(Class)mClassName atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping forProperty:(NSString *)prop
//{
//    AWSyncMappingObject *mapping = [[AWSyncMappingObject alloc] initForClass:mClassName
//                                                                  fromResource:nil
//                                                                         atKey:(NSString*)key
//                                                              attributeMapping:mMapping
//                                                                relatedObjects:nil
//                                                                   forProperty:prop
//                                                                  uniqueIdName:nil
//                                                                 needsDeletion:NO];
//    return mapping;
//    
//}
//
//
//+ (AWSyncMappingObject*)mappingForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del
//{
//    AWSyncMappingObject *mapping = [[AWSyncMappingObject alloc] initForClass:mClassName
//                                                                  fromResource:(NSString*)mResource
//                                                                         atKey:(NSString*)key
//                                                              attributeMapping:mMapping
//                                                                relatedObjects:mRelatedObjects
//                                                                   forProperty:prop
//                                                                  uniqueIdName:uid
//                                                                 needsDeletion:del];
//    return mapping;
//    
//}

// ---------
- (void)setUpdateObjectAtUniqueProperty:(NSString*)uniquePropertyName mappedToJsonAttribute:(NSString*)jsonAttribute
{
    self.doUpdateObject = YES;
    self.uniquePropertyName = uniquePropertyName;
    self.uniqueJsonAttributeName = jsonAttribute;
}

/** Descripes the reationship to its parent.
 *  relationship property name on parent
 *  matching json root attribute
 **/
- (void)setRelationshipName:(NSString *)relationshipName atJsonAttributeKey:(NSString*)jsonAttribute
{
    self.relationshipNameOnParent = relationshipName;
    self.relatedJsonRootAttributeName = jsonAttribute;
}

// -----------



//- (AWSyncMappingObject*)initForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del
//{
//    if (self = [super init]) {
//        self.className = mClassName;
//        self.attributeMappingDictionary = mMapping;
//        self.relatedMappingObjects = mRelatedObjects;
//        self.relationshipNameOnParent = prop;
//        self.apiQuery = mResource;
//        self.jsonRootAttribute = key;
//        self.uniquePropertyName = uid;
//    }
//    return self;
//}
//
//- (AWSyncMappingObject*)initForPostForClass:(Class)mClassName fromResource:(NSString*)mResource atKey:(NSString*)key attributeMapping:(NSDictionary*)mMapping relatedObjects:(NSSet*)mRelatedObjects forProperty:(NSString *)prop uniqueIdName:(NSString*)uid needsDeletion:(BOOL)del postParams:(NSDictionary*)params
//{
//    if (self = [super init]) {
//        self.className = mClassName;
//        self.attributeMappingDictionary = mMapping;
//        self.relatedMappingObjects = mRelatedObjects;
//        self.relationshipNameOnParent = prop;
//        self.apiQuery = mResource;
//        self.jsonRootAttribute = key;
//        self.uniquePropertyName = uid;
//        self.postDataDictionary = params;
//    }
//    return self;
//}


- (NSString*)className
{
    return NSStringFromClass(self.moClass);
}

@end


@implementation NSMutableArray (findObjects)

- (BOOL)containsObjectWithClass:(Class)c
{
    for (AWSyncMappingObject* m in self) {
        if (m.moClass == c ) {
            return YES;
        }
    }
    return NO;
}


@end