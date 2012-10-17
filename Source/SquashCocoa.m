// Copyright 2012 Square Inc.
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

#import "SquashCocoa.h"

#pragma mark Constants

static NSString *SCDirectory = @"Squash Occurrences";
static SquashCocoa *sharedClient = NULL;

#pragma mark -

@interface SquashCocoa (Private)

@end

#pragma mark -

@implementation SquashCocoa

@synthesize disabled;
@synthesize APIKey;
@synthesize environment;
@synthesize host;
@synthesize notifyPath;
@synthesize timeout;
@synthesize ignoredExceptions;
@synthesize handledSignals;
@synthesize filterUserInfoKeys;
@synthesize revision;

#pragma mark Singleton

+ (SquashCocoa *) sharedClient {
    if (sharedClient == NULL) sharedClient = [[super allocWithZone:NULL] init];
    return sharedClient;
}

+ (id) allocWithZone:(NSZone *)zone {
    return [[self sharedClient] retain];
}

- (id) copyWithZone:(NSZone *)zone {
    return self;
}

- (id) retain {
    return self;
}

- (NSUInteger) retainCount {
    return NSUIntegerMax;
}

- (oneway void) release {
    // do nothing
}

- (id) autorelease {
    return self;
}

- (id) init {
    if (self = [super init]) {
        disabled = NO;
        notifyPath = @"/api/1.0/notify";
        timeout = 15;
        ignoredExceptions = [[NSMutableSet alloc] init];
        handledSignals = [[NSMutableSet alloc] initWithObjects:
                          [NSNumber numberWithInteger:SIGABRT],
                          [NSNumber numberWithInteger:SIGBUS],
                          [NSNumber numberWithInteger:SIGFPE],
                          [NSNumber numberWithInteger:SIGILL],
                          [NSNumber numberWithInteger:SIGSEGV],
                          [NSNumber numberWithInteger:SIGTRAP],
                          nil];
        filterUserInfoKeys = [[NSMutableSet alloc] init];
        
    }
    return self;
}

#pragma mark Configuration

- (oneway void) hook {
    // register NSException handler
    NSSetUncaughtExceptionHandler(&SCHandleException);
    
    // register signal handler
    for (NSNumber *signal in handledSignals) {
        NSInteger sig = [signal integerValue];
        struct sigaction action;
        sigemptyset(&action.sa_mask);
        action.sa_handler = SCHandleSignal;
        if (sigaction(sig, &action, NULL))
            NSLog(@"[SquashCocoa] Could not register %s signal handler", strsignal(sig));
    }
}

- (oneway void) unhook {
    //unregister NSException handler
    NSSetUncaughtExceptionHandler(NULL);
    
    //unregister signal handler
    for (NSNumber *signal in handledSignals) {
        NSInteger sig = [signal integerValue];
        struct sigaction action;
        sigemptyset(&action.sa_mask);
        action.sa_handler = SIG_DFL;
        sigaction(sig, &action, NULL);
    }
}

- (BOOL) isConfigured {
    return (self.host && self.revision && self.APIKey && self.environment);
}

- (NSString *) clientName {
    return @"ios";
}

#pragma mark Routes

- (NSURL *) notifyURL {
    NSURL *baseURL = [[NSURL alloc] initWithString:self.host];
    NSURL *URL = [[NSURL alloc] initWithString:self.notifyPath relativeToURL:baseURL];
    [baseURL release];
    return [URL autorelease];
}

#pragma mark Recording

- (oneway void) recordException:(NSException *)exception {
    if (self.disabled) return;
    
    if ([self.ignoredExceptions containsObject:[exception name]]) return;
    SCOccurrence *occurrence = [[SCOccurrence alloc] initWithException:exception];
    [occurrence writeToFile];
    [occurrence release];
}

- (oneway void) recordSignal:(int)signal addresses:(NSArray *)addresses {
    if (self.disabled) return;
    
    SCOccurrence *occurrence = [[SCOccurrence alloc] initWithSignal:signal addresses:addresses];
    [occurrence writeToFile];
    [occurrence release];
}

#pragma mark Reporting

- (NSString *) occurrencesDirectory {
    NSArray *folders = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *path;
    if ([folders count]) path = [folders objectAtIndex:0];
    else path = NSTemporaryDirectory();
    path = [path stringByAppendingPathComponent:[[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleIdentifier"]];
    path = [path stringByAppendingPathComponent:SCDirectory];
    return path;
}

- (oneway void) reportErrors {
    Reachability *reachability = [Reachability reachabilityWithHostName:[[self notifyURL] host]];
    if ([reachability currentReachabilityStatus] == NotReachable) return;
    
    NSError *error = NULL;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self occurrencesDirectory] error:&error];
    if (!files) return;
    
    NSOperationQueue *queue = [[[NSOperationQueue alloc] init] autorelease];
    
    for (NSString *file in files) {
        if ([[file pathExtension] isEqualToString:@"occurrence"]) {
            [queue addOperationWithBlock:^{
                SCOccurrence *occurrence;
                NSString *path = [[self occurrencesDirectory] stringByAppendingPathComponent:file];
                occurrence = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
                if (!occurrence) return;
                if ([occurrence report])
                    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
            }];
        }
    }
}

@end

#pragma mark -

@implementation SquashCocoa (Private)

@end
