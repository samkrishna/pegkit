//
//  PKBaseSymbol.h
//  ParseKit
//
//  Created by Todd Ditchendorf on 3/16/13.
//
//

#import <Foundation/Foundation.h>

@protocol PKType;
@protocol PKScope;
@class PKDefinitionNode;

@interface PKBaseSymbol : NSObject <NSCopying>

+ (id)symbolWithName:(NSString *)name;
+ (id)symbolWithName:(NSString *)name type:(id <PKType>)type;

- (id)initWithName:(NSString *)name;
- (id)initWithName:(NSString *)name type:(id <PKType>)type;

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong) id <PKType>type;

// Forward Reference Support
@property (nonatomic, strong) PKDefinitionNode *def;
@property (nonatomic, strong) id <PKScope>scope;
@end
