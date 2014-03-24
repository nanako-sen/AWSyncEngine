//
//  RDUMapping.m
//  RDULoyalty
//
//  Created by Anna Walser on 10/8/13.
//  Copyright (c) 2013 Anna Walser. All rights reserved.
//

#import "AWSyncMappingObject.h"

@interface AWSyncMappingObject ()

@property (nonatomic, strong) NSString *resetProperty;
@property (nonatomic, strong) id resetToValue;

@property (nonatomic, strong) NSString *updateRuleProperty;
@property (nonatomic, strong) NSString *updateRuleAttribute;
@property (nonatomic, assign) NSComparisonResult updateComparisonResult;

@end

@implementation AWSyncMappingObject
@synthesize objectClass = _objectClass;
@synthesize attributeMapping = _attributeMapping;
@synthesize relatedMappingObjects = _relatedMappingObjects;
@synthesize requestAPIResource = _requestAPIResource;
@synthesize jsonRootAttribute = _jsonRootAttribute;
@synthesize uniquePropertyName = _uniquePropertyName;

@synthesize doUpdate = _doUpdate;
//@synthesize setKeysToValuesOnUpdate = _setKeysToValuesOnUpdate;
@synthesize relatedJsonRootAttributeName = _relatedAttributeName;
@synthesize uniqueJsonAttributeName = _uniqueJsonAttributeName;
@synthesize resetProperty = _resetProperty;
@synthesize resetToValue = _resetToValue;
@synthesize updateRuleProperty = updateRuleProperty;
@synthesize updateRuleAttribute = updateRuleAttribute;
@synthesize updateComparisonResult = _updateComparisonResult;


+ (AWSyncMappingObject*)baseMappingPOSTForClass:(Class)class fromApiResource:(NSString*)apiResource postParams:(NSDictionary*)params atKey:(NSString*)key
{
    AWSyncMappingObject *mo = [AWSyncMappingObject new];
    mo.postDataDictionary = params;
    mo.requestAPIResource = apiResource;
    mo.jsonRootAttribute = key;
    mo.objectClass = class;
    return  mo;
}

// ---------
- (void)setUpdateObjectAtUniqueProperty:(NSString*)uniquePropertyName mappedToJsonAttribute:(NSString*)jsonAttribute
{
    self.doUpdate = YES;
    self.uniquePropertyName = uniquePropertyName;
    self.uniqueJsonAttributeName = jsonAttribute;
}

- (void)defineUniqueProperty:(NSString*)uniquePropertyName mappedToJsonAttribute:(NSString*)jsonAttribute
{
    self.doUpdate = NO;
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


- (void)resetProperty:(NSString*)property toValue:(id)value
{
    self.resetToValue = value;
    self.resetProperty = property;
}

- (void)defineUpdateRuleForProperty:(NSString*)property andJsonAttribute:(NSString*)attribute comparisonResult:(NSComparisonResult)comparisonResult;
{
    self.updateRuleProperty = property;
    self.updateRuleAttribute = attribute;
    self.updateComparisonResult = comparisonResult;
}

// -----------


+ (AWSyncMappingObject*)baseMappingForClass:(Class)class fromApiResource:(NSString*)apiResource attributeMapping:(NSDictionary*)mappingDict atKey:(NSString*)key
{
    AWSyncMappingObject *mo = [AWSyncMappingObject new];
    mo.objectClass = class;
    mo.requestAPIResource = apiResource;
    mo.attributeMapping = mappingDict;
    mo.jsonRootAttribute = key;
    return mo;
}


- (NSString*)className
{
    return NSStringFromClass(self.objectClass);
}

@end


@implementation NSMutableArray (findObjects)

- (BOOL)containsObjectWithClass:(Class)c
{
    for (AWSyncMappingObject* m in self) {
        if (m.objectClass == c ) {
            return YES;
        }
    }
    return NO;
}


@end