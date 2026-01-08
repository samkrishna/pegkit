#import "TDTestScaffold.h"
#import "PGParserFactory.h"
#import "PGParserGenVisitor.h"
#import "PGRootNode.h"
#import "ElementAssignParser.h"

@interface RecoverySingleTokenDeletionTest : XCTestCase
@property (nonatomic, strong) PGParserFactory *factory;
@property (nonatomic, strong) PGRootNode *root;
@property (nonatomic, strong) PGParserGenVisitor *visitor;
@property (nonatomic, strong) ElementAssignParser *parser;
@end

@implementation RecoverySingleTokenDeletionTest

- (void)setUp {
    self.parser = [[ElementAssignParser alloc] initWithDelegate:self];
}

- (void)tearDown {
    self.factory = nil;
}

- (void)testCorrectExpr {
    NSError *err = nil;
    PKAssembly *res = nil;
    NSString *input = nil;
    
    input = @"[3];[2];";
    res = [_parser parseString:input error:&err];
    TDEqualObjects(TDAssembly(@"[[, 3, ;, [, 2, ;][/3/]/;/[/2/]/;^"), [res description]);
}

- (void)testExtraBracket {
    NSError *err = nil;
    PKAssembly *res = nil;
    NSString *input = nil;
    
    _parser.enableAutomaticErrorRecovery = NO;
    
    input = @"[3]];";
    res = [_parser parseString:input error:&err];
    TDNotNil(err);
    TDNil(res);
}

- (void)testExtraBracketWithRecovery {
    NSError *err = nil;
    PKAssembly *res = nil;
    NSString *input = nil;
    
    _parser.enableAutomaticErrorRecovery = YES;
    
    input = @"[3]];";
    res = [_parser parseString:input error:&err];
    TDEqualObjects(TDAssembly(@"[[, 3, ], ;][/3/]/]/;^"), [res description]);
}

@end
