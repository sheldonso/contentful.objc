//
//  CDAFieldValueTransformer.m
//  ContentfulSDK
//
//  Created by Boris Bügling on 09/03/14.
//
//

@import MapKit;

#import <ISO8601DateFormatter/ISO8601DateFormatter.h>

#import "CDAClient+Private.h"
#import "CDAFieldValueTransformer.h"
#import "CDAResource+Private.h"
#import "CDAUtilities.h"

@interface CDAFieldValueTransformer ()

@property (nonatomic, weak) CDAClient* client;
@property (nonatomic) BOOL localizationAvailable;
@property (nonatomic) CDAFieldType type;

@end

#pragma mark -

@implementation CDAFieldValueTransformer

+(BOOL)allowsReverseTransformation {
    return NO;
}

+(instancetype)transformerOfType:(CDAFieldType)type
                          client:(CDAClient*)client
           localizationAvailable:(BOOL)localizationAvailable {
    return [[[self class] alloc] initWithType:type client:client localizationAvailable:localizationAvailable];
}

#pragma mark -

-(id)initWithType:(CDAFieldType)type
           client:(CDAClient*)client
localizationAvailable:(BOOL)localizationAvailable {
    self = [super init];
    if (self) {
        NSParameterAssert(client);
        self.client = client;
        
        self.itemType = CDAFieldTypeNone;
        self.type = type;
    }
    return self;
}

-(id)locationFromDictionary:(NSDictionary*)dictionary {
    CLLocationCoordinate2D location;
    if ([dictionary isKindOfClass:[NSDictionary class]]) {
        location.latitude = [dictionary[@"lat"] doubleValue];
        location.longitude = [dictionary[@"lon"] doubleValue];
    }
    return [NSData dataWithBytes:&location length:sizeof(CLLocationCoordinate2D)];
}

-(id)transformArrayValue:(id)arrayValue {
    CDAFieldValueTransformer* transformer = [CDAFieldValueTransformer transformerOfType:self.itemType
                                                                                 client:self.client
                                                                  localizationAvailable:self.localizationAvailable];
    
    NSMutableArray* array = [@[] mutableCopy];
    for (id value in arrayValue) {
        id transformedValue = [transformer transformedValue:value];
        if(transformedValue) {
            [array addObject:transformedValue];
        }
    }
    
    return [array copy];
}

-(id)transformedValue:(id)value {
    switch (self.type) {
        case CDAFieldTypeArray:
            if (value == [NSNull null] || ![value isKindOfClass:[NSArray class]]) {
                return @[];
            }
            
            return [self transformArrayValue:value];
            
        case CDAFieldTypeDate:
            if (value == [NSNull null] || ![value isKindOfClass:[NSString class]]) {
                return nil;
            }
            
            return [[ISO8601DateFormatter new] dateFromString:value];
            
        case CDAFieldTypeBoolean:
        case CDAFieldTypeInteger:
        case CDAFieldTypeNumber:
            if (value == [NSNull null] || ![value isKindOfClass:[NSNumber class]]) {
                return @0;
            }
            
            return value;
            
        case CDAFieldTypeObject:
            if (value == [NSNull null]) {
                return nil;
            }
            
            return value;

        case CDAFieldTypeAsset:
        case CDAFieldTypeEntry:
        case CDAFieldTypeLink:
            if (value == [NSNull null]) {
                return nil;
            }
            
            return [CDAResource resourceObjectForDictionary:value
                                                     client:self.client
                                      localizationAvailable:self.localizationAvailable];
            
        case CDAFieldTypeLocation:
            if (value == [NSNull null]) {
                return nil;
            }
            
            return [self locationFromDictionary:value];
            
        case CDAFieldTypeSymbol:
        case CDAFieldTypeText:
            if (value == [NSNull null]) {
                return @"";
            }
            
            if ([value isKindOfClass:[NSString class]]) {
                return value;
            } else {
                if (![value respondsToSelector:@selector(stringValue)]) {
                    return @"";
                }
                return [value stringValue];
            }

        case CDAFieldTypeNone:
            break;
    }
    
    NSAssert(false, @"Unhandled field type '%ld'", (long)self.type);
    return nil;
}

@end
