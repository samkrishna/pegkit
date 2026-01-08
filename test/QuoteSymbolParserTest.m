#import "TDTestScaffold.h"
#import "PGParserFactory.h"
#import "PGParserGenVisitor.h"
#import "PGRootNode.h"
#import "QuoteSymbolParser.h"

@interface QuoteSymbolParserTest : XCTestCase
@property (nonatomic, strong) PGParserFactory *factory;
@property (nonatomic, strong) PGRootNode *root;
@property (nonatomic, strong) PGParserGenVisitor *visitor;
@property (nonatomic, strong) QuoteSymbolParser *parser;
@end

@implementation QuoteSymbolParserTest

- (void)dealloc {
    self.factory = nil;
    self.root = nil;
    self.visitor = nil;
    self.parser = nil;
}


- (void)setUp {
    self.factory = [PGParserFactory factory];
    _factory.collectTokenKinds = YES;

    NSError *err = nil;
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"quote_symbol" ofType:@"grammar"];
    NSString *g = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&err];
    
    err = nil;
    self.root = (id)[_factory ASTFromGrammar:g error:&err];
    _root.grammarName = @"QuoteSymbol";
    
    self.visitor = [[PGParserGenVisitor alloc] init];
    _visitor.enableMemoization = NO;
    
    [_root visit:_visitor];
    
#if TD_EMIT
    path = [[NSString stringWithFormat:@"%s/test/QuoteSymbolParser.h", getenv("PWD")] stringByExpandingTildeInPath];
    err = nil;
    if (![_visitor.interfaceOutputString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        NSLog(@"%@", err);
    }

    path = [[NSString stringWithFormat:@"%s/test/QuoteSymbolParser.m", getenv("PWD")] stringByExpandingTildeInPath];
    err = nil;
    if (![_visitor.implementationOutputString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
        NSLog(@"%@", err);
    }
#endif

    self.parser = [[QuoteSymbolParser alloc] initWithDelegate:nil];
}

- (void)tearDown {
    self.factory = nil;
}

- (void)testSingleSpaceSingleSpaceSingle {
    NSString *s = @"' ' '";
    
    NSError *err = nil;
    PKAssembly *res = [_parser parseString:s error:&err];
    TDNil(err);
    
    TDEqualObjects(TDAssembly(@"[', ', ']'/'/'^"), [res description]);
}

- (void)testSingleSingleSingle {
    NSString *s = @"'''";
    
    NSError *err = nil;
    PKAssembly *res = [_parser parseString:s error:&err];
    TDNil(err);
    
    TDEqualObjects(TDAssembly(@"[', ', ']'/'/'^"), [res description]);
}

- (void)testDoubleDoubleDouble {
    NSString *s = @"\"\"\"";
    
    NSError *err = nil;
    PKAssembly *res = [_parser parseString:s error:&err];
    TDNil(err);
    
    TDEqualObjects(TDAssembly(@"[\", \", \"]\"/\"/\"^"), [res description]);
}

- (void)testDoubleSpaceDoubleSpaceDouble {
    NSString *s = @"\" \" \"";
    
    NSError *err = nil;
    PKAssembly *res = [_parser parseString:s error:&err];
    TDNil(err);
    
    TDEqualObjects(TDAssembly(@"[\", \", \"]\"/\"/\"^"), [res description]);
}

- (void)testBackBackBack {
    NSString *s = @"\\\\\\";
    
    NSError *err = nil;
    PKAssembly *res = [_parser parseString:s error:&err];
    TDNil(err);
    
    TDEqualObjects(TDAssembly(@"[\\, \\, \\]\\/\\/\\^"), [res description]);
}

- (void)testBackSpaceBackSpaceBack {
    NSString *s = @"\\ \\ \\";
    
    NSError *err = nil;
    PKAssembly *res = [_parser parseString:s error:&err];
    TDNil(err);
    
    TDEqualObjects(TDAssembly(@"[\\, \\, \\]\\/\\/\\^"), [res description]);
}

@end
