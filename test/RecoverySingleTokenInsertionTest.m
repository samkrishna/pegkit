#import "TDTestScaffold.h"
#import "PGParserFactory.h"
#import "PGParserGenVisitor.h"
#import "PGRootNode.h"
#import "ElementAssignParser.h"

@interface RecoverySingleTokenInsertionTest : XCTestCase
@property (nonatomic, strong) PGParserFactory *factory;
@property (nonatomic, strong) PGRootNode *root;
@property (nonatomic, strong) PGParserGenVisitor *visitor;
@property (nonatomic, strong) ElementAssignParser *parser;
@end

@implementation RecoverySingleTokenInsertionTest

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

- (void)testMissingBracket {
    NSError *err = nil;
    PKAssembly *res = nil;
    NSString *input = nil;
    
    _parser.enableAutomaticErrorRecovery = NO;
    
    input = @"[3;";
    res = [_parser parseString:input error:&err];
    TDNotNil(err);
    TDNil(res);
}

- (void)testMissingBracketWithRecovery {
    NSError *err = nil;
    PKAssembly *res = nil;
    NSString *input = nil;
    
    _parser.enableAutomaticErrorRecovery = YES;
    
    input = @"[3;";
    res = [_parser parseString:input error:&err];
    TDEqualObjects(TDAssembly(@"[[, 3, ;][/3/;^"), [res description]);
}

- (void)testMissingBracketWithRecovery2 {
    NSError *err = nil;
    PKAssembly *res = nil;
    NSString *input = nil;
    
    _parser.enableAutomaticErrorRecovery = YES;
    
    input = @"[3[";
    res = [_parser parseString:input error:&err];
//    TDNotNil(err);
//    TDNil(res);

    // this one works but not because of single token insertion. it works because of resyncSet
    TDEqualObjects(TDAssembly(@"[[, 3, [][/3/[^"), [res description]);
}

@end
