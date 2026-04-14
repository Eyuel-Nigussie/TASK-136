//
//  CMCaptchaChallenge.m
//  CourierMatch
//

#import "CMCaptchaChallenge.h"
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>

static NSTimeInterval const kChallengeTTL = 60.0;
static NSUInteger       const kNonceBytes  = 32;

@interface CMCaptchaChallenge ()
@property (nonatomic, copy,   readwrite) NSString *challengeId;
@property (nonatomic, copy,   readwrite) NSString *question;
@property (nonatomic, strong, readwrite) NSDate *expiresAt;
@property (nonatomic, strong) NSData *nonce;             // 32 bytes, memory-only
@property (nonatomic, strong) NSData *expectedHmac;      // HMAC(nonce, answer)
@property (nonatomic, assign) BOOL consumed;
@end

@implementation CMCaptchaChallenge
@end

@interface CMCaptchaService ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, CMCaptchaChallenge *> *active;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation CMCaptchaService

+ (instancetype)shared {
    static CMCaptchaService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [CMCaptchaService new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _active = [NSMutableDictionary new];
        _lock = [NSLock new];
    }
    return self;
}

- (NSData *)randomBytes:(NSUInteger)len {
    NSMutableData *b = [NSMutableData dataWithLength:len];
    (void)SecRandomCopyBytes(kSecRandomDefault, len, b.mutableBytes);
    return b;
}

- (NSData *)hmacWithNonce:(NSData *)nonce answer:(NSString *)answer {
    NSData *ans = [(answer ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *mac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256,
           nonce.bytes, nonce.length,
           ans.bytes, ans.length,
           mac.mutableBytes);
    return mac;
}

- (CMCaptchaChallenge *)issueChallenge {
    [self sweepExpired];

    // Small numbers so accessibility isn't wrecked by arithmetic difficulty.
    uint8_t buf[2];
    SecRandomCopyBytes(kSecRandomDefault, 2, buf);
    int a = (buf[0] % 9) + 1;          // 1..9
    int b = (buf[1] % 9) + 1;          // 1..9
    int op = (a + b) % 2;              // choose + or *
    int answer = 0;
    NSString *q = nil;
    if (op == 0) {
        answer = a + b;
        q = [NSString stringWithFormat:@"%d + %d", a, b];
    } else {
        answer = a * b;
        q = [NSString stringWithFormat:@"%d × %d", a, b];
    }
    NSString *answerStr = [NSString stringWithFormat:@"%d", answer];

    CMCaptchaChallenge *c = [CMCaptchaChallenge new];
    c.challengeId  = [[NSUUID UUID] UUIDString];
    c.question     = q;
    c.expiresAt    = [NSDate dateWithTimeIntervalSinceNow:kChallengeTTL];
    c.nonce        = [self randomBytes:kNonceBytes];
    c.expectedHmac = [self hmacWithNonce:c.nonce answer:answerStr];
    c.consumed     = NO;

    [self.lock lock];
    self.active[c.challengeId] = c;
    [self.lock unlock];
    return c;
}

- (BOOL)verifyChallengeId:(NSString *)challengeId answer:(NSString *)answer {
    if (challengeId.length == 0) { return NO; }
    [self.lock lock];
    CMCaptchaChallenge *c = self.active[challengeId];
    if (!c || c.consumed) {
        [self.active removeObjectForKey:challengeId];
        [self.lock unlock];
        return NO;
    }
    if ([[NSDate date] timeIntervalSinceDate:c.expiresAt] >= 0) {
        [self.active removeObjectForKey:challengeId];
        [self.lock unlock];
        return NO;
    }
    NSData *candidate = [self hmacWithNonce:c.nonce
                                      answer:[answer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    BOOL equal = (candidate.length == c.expectedHmac.length);
    if (equal) {
        const unsigned char *x = candidate.bytes;
        const unsigned char *y = c.expectedHmac.bytes;
        unsigned char diff = 0;
        for (NSUInteger i = 0; i < candidate.length; i++) { diff |= (unsigned char)(x[i] ^ y[i]); }
        equal = (diff == 0);
    }
    c.consumed = YES;
    [self.active removeObjectForKey:challengeId];
    [self.lock unlock];
    return equal;
}

- (void)sweepExpired {
    NSDate *now = [NSDate date];
    [self.lock lock];
    NSArray *ids = [self.active.allKeys copy];
    for (NSString *k in ids) {
        if ([now timeIntervalSinceDate:self.active[k].expiresAt] >= 0) {
            [self.active removeObjectForKey:k];
        }
    }
    [self.lock unlock];
}

@end
