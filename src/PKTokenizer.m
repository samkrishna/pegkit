// The MIT License (MIT)
// 
// Copyright (c) 2014 Todd Ditchendorf
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy 
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is 
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <PEGKit/PEGKit.h>

#define STATE_COUNT 256

@interface PKToken ()
@property (nonatomic, readwrite) NSUInteger lineNumber;
@end

@interface PKTokenizerState ()
- (PKTokenizerState *)nextTokenizerStateFor:(PKUniChar)c tokenizer:(PKTokenizer *)t;
@end

@interface PKTokenizer ()
- (instancetype)initWithString:(NSString *)str stream:(NSInputStream *)stm;
- (PKTokenizerState *)tokenizerStateFor:(PKUniChar)c;
- (PKTokenizerState *)defaultTokenizerStateFor:(PKUniChar)c;
- (NSInteger)tokenKindForStringValue:(NSString *)str;
@property (nonatomic, strong) PKReader *reader;
@property (nonatomic, strong) NSMutableArray *tokenizerStates;
@property (nonatomic, strong) NSMutableArray *enumerationTokens;
@property (nonatomic, readwrite) NSUInteger lineNumber;
@end

@implementation PKTokenizer

+ (PKTokenizer *)tokenizer {
    return [self tokenizerWithString:nil];
}


+ (PKTokenizer *)tokenizerWithString:(NSString *)s {
    return [[self alloc] initWithString:s];
}


+ (PKTokenizer *)tokenizerWithStream:(NSInputStream *)s {
    return [[self alloc] initWithStream:s];
}


- (instancetype)init {
    return [self initWithString:nil stream:nil];
}


- (instancetype)initWithString:(NSString *)s {
    self = [self initWithString:s stream:nil];
    return self;
}


- (instancetype)initWithStream:(NSInputStream *)s {
    self = [self initWithString:nil stream:s];
    return self;
}


- (instancetype)initWithString:(NSString *)str stream:(NSInputStream *)stm {
    self = [super init];
    if (self) {
        self.string = str;
        self.stream = stm;
        self.reader = [[PKReader alloc] init];

        self.numberState     = [[PKNumberState alloc] init];
        self.quoteState      = [[PKQuoteState alloc] init];
        self.commentState    = [[PKCommentState alloc] init];
        self.symbolState     = [[PKSymbolState alloc] init];
        self.whitespaceState = [[PKWhitespaceState alloc] init];
        self.wordState       = [[PKWordState alloc] init];
        self.delimitState    = [[PKDelimitState alloc] init];
        self.URLState        = [[PKURLState alloc] init];
#if PK_PLATFORM_EMAIL_STATE
        self.emailState      = [[PKEmailState alloc] init];
#endif
        _numberState.fallbackState = _symbolState;
        _quoteState.fallbackState = _symbolState;
#if PK_PLATFORM_EMAIL_STATE
        _URLState.fallbackState = _emailState;
        _emailState.fallbackState = _wordState;
#else
        _URLState.fallbackState = _wordState;
#endif

#if PK_PLATFORM_TWITTER_STATE
        self.twitterState    = [[PKTwitterState alloc] init];
        _twitterState.fallbackState = symbolState;

        self.hashtagState    = [[PKHashtagState alloc] init];
        _hashtagState.fallbackState = symbolState;
#endif

        self.tokenizerStates = [NSMutableArray arrayWithCapacity:STATE_COUNT];
        
        for (NSInteger i = 0; i < STATE_COUNT; i++) {
            [_tokenizerStates addObject:[self defaultTokenizerStateFor:(PKUniChar)i]];
        }

        [_symbolState add:@"<="];
        [_symbolState add:@">="];
        [_symbolState add:@"!="];
        [_symbolState add:@"=="];
        
        [_commentState addSingleLineStartMarker:@"//"];
        [_commentState addMultiLineStartMarker:@"/*" endMarker:@"*/"];
        [self setTokenizerState:_commentState from:'/' to:'/'];

//        
//        // Twitter handles
//        NSMutableCharacterSet *set = [NSMutableCharacterSet characterSetWithCharactersInString:@"_"];
//        [set formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
//        [self setTokenizerState:delimitState from:'@' to:'@'];
//        [_delimitState addStartMarker:@"@" endMarker:nil allowedCharacterSet:[[set copy] autorelease]];
//
//        // Hashtags
//        [set addCharactersInString:@"%"];
//        [self setTokenizerState:_delimitState from:'#' to:'#'];
//        [_delimitState addStartMarker:@"#" endMarker:nil allowedCharacterSet:set];
//
//        _delimitState.allowsUnbalancedStrings = YES;
    }
    return self;
}


- (PKToken *)nextToken {
    NSAssert(_reader, @"");
    PKUniChar c = [_reader read]; //NSLog(@"%@", [[[NSString alloc] initWithBytes:&c length:1 encoding:4] autorelease]);

    PKToken *result = nil;
    
    if (PKEOF == c) {
        result = [PKToken EOFToken];
    } else {
        PKTokenizerState *state = [self tokenizerStateFor:c];
        if (state) {
            result = [state nextTokenFromReader:_reader startingWith:c tokenizer:self];
            result.lineNumber = _lineNumber;
        } else {
            result = [PKToken EOFToken];
        }
    }
    
    return result;
}


- (void)enumerateTokensUsingBlock:(void (^)(PKToken *tok, BOOL *stop))block {
    PKToken *eof = [PKToken EOFToken];

    PKToken *tok = nil;
    BOOL stop = NO;
    
    while ((tok = [self nextToken]) != eof) {
        block(tok, &stop);
        if (stop) break;
    }
}


- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id *)stackbuf count:(NSUInteger)len {
    NSUInteger count = 0;

    PKToken *tok = nil;
    PKToken *eof = [PKToken EOFToken];

    // Clear previous batch and prepare for new tokens
    if (!_enumerationTokens) {
        _enumerationTokens = [NSMutableArray array];
    }
    [_enumerationTokens removeAllObjects];

    if (0 == state->state) {
        tok = [self nextToken];
    } else {
        tok = (__bridge PKToken *)(void *)state->state;
    }

    while (tok != eof && count < len) {
        [_enumerationTokens addObject:tok];  // Keep strong reference
        stackbuf[count] = tok;
        tok = [self nextToken];
        count++;
    }

    state->state = (unsigned long)(__bridge void *)tok;
    state->itemsPtr = stackbuf;
    state->mutationsPtr = (unsigned long *)(__bridge void *)self;

    return count;
}


- (void)setTokenizerState:(PKTokenizerState *)state from:(PKUniChar)start to:(PKUniChar)end {
    NSParameterAssert(state);
    NSAssert(_tokenizerStates, @"");

    for (NSInteger i = start; i <= end; i++) {
        [_tokenizerStates replaceObjectAtIndex:i withObject:state];
    }
}


- (void)setReader:(PKReader *)r {
    if (_reader != r) {
        _reader = r;

        if (_string) {
            _reader.string = _string;
        } else {
            _reader.stream = _stream;
        }
    }
}


- (void)setString:(NSString *)s {
    if (_string != s) {
        _string = [s copy];
    }
    _reader.string = _string;
    self.lineNumber = 1;
}


- (void)setStream:(NSInputStream *)s {
    if (_stream != s) {
        _stream = s;
    }
    _reader.stream = _stream;
    self.lineNumber = 1;
}


#pragma mark -

- (PKTokenizerState *)tokenizerStateFor:(PKUniChar)c {
    PKTokenizerState *state = nil;
    
    if (c < 0 || c >= STATE_COUNT) {
        // customization above 255 is not supported, so fetch default.
        state = [self defaultTokenizerStateFor:c];
    } else {
        // customization below 255 is supported, so be sure to get the (possibly) customized state from `tokenizerStates`
        state = [_tokenizerStates objectAtIndex:c];
    }
    
    while (state.disabled) {
        state = [state nextTokenizerStateFor:c tokenizer:self];
    }
    
    NSAssert(state, @"");
    
    return state;
}


- (PKTokenizerState *)defaultTokenizerStateFor:(PKUniChar)c {
    if (c >= 0 && c <= ' ') {            // From:  0 to: 32    From:0x00 to:0x20
        return _whitespaceState;
    } else if (c == 33) {
        return _symbolState;
    } else if (c == '"') {               // From: 34 to: 34    From:0x22 to:0x22
        return _quoteState;
    } else if (c == '#') {               // From: 35 to: 35    From:0x23 to:0x23
#if PK_PLATFORM_TWITTER_STATE
        return _hashtagState;
#else
        return _symbolState;
#endif
    } else if (c >= 36 && c <= 38) {
        return _symbolState;
    } else if (c == '\'') {              // From: 39 to: 39    From:0x27 to:0x27
        return _quoteState;
    } else if (c >= 40 && c <= 42) {
        return _symbolState;
    } else if (c == '+') {               // From: 43 to: 43    From:0x2B to:0x2B
        return _symbolState;
    } else if (c == 44) {
        return _symbolState;
    } else if (c == '-') {               // From: 45 to: 45    From:0x2D to:0x2D
        return _numberState;
    } else if (c == '.') {               // From: 46 to: 46    From:0x2E to:0x2E
        return _numberState;
    } else if (c == '/') {               // From: 47 to: 47    From:0x2F to:0x2F
        return _symbolState;
    } else if (c >= '0' && c <= '9') {   // From: 48 to: 57    From:0x30 to:0x39
        return _numberState;
    } else if (c >= 58 && c <= 63) {
        return _symbolState;
    } else if (c == '@') {               // From: 64 to: 64    From:0x40 to:0x40
#if PK_PLATFORM_TWITTER_STATE
        return _twitterState;
#else
        return _symbolState;
#endif
    } else if (c >= 'A' && c <= 'Z') {   // From: 65 to: 90    From:0x41 to:0x5A
        return _URLState;
    } else if (c >= 91 && c <= 96) {
        return _symbolState;
    } else if (c >= 'a' && c <= 'z') {   // From: 97 to:122    From:0x61 to:0x7A
        return _URLState;
    } else if (c >= 123 && c <= 191) {
        return _symbolState;
    } else if (c >= 0xC0 && c <= 0xFF) { // From:192 to:255    From:0xC0 to:0xFF
        return _wordState;
    } else if (c >= 0x19E0 && c <= 0x19FF) { // khmer symbols
        return _symbolState;
    } else if (c >= 0x2000 && c <= 0x2BFF) { // various symbols
        return _symbolState;
    } else if (c >= 0x2E00 && c <= 0x2E7F) { // supplemental punctuation
        return _symbolState;
    } else if (c >= 0x3000 && c <= 0x303F) { // cjk symbols & punctuation
        return _symbolState;
    } else if (c >= 0x3200 && c <= 0x33FF) { // enclosed cjk letters and months, cjk compatibility
        return _symbolState;
    } else if (c >= 0x4DC0 && c <= 0x4DFF) { // yijing hexagram symbols
        return _symbolState;
    } else if (c >= 0xFE30 && c <= 0xFE6F) { // cjk compatibility forms, small form variants
        return _symbolState;
    } else if (c >= 0xFF00 && c <= 0xFFFF) { // hiragana & katakana halfwitdh & fullwidth forms, Specials
        return _symbolState;
    } else {
        return _wordState;
    }
}


- (NSInteger)tokenKindForStringValue:(NSString *)str {
    NSInteger x = 0;
    if (_delegate) {
        x = [_delegate tokenizer:self tokenKindForStringValue:str];
    }
    return x;
}

@end
