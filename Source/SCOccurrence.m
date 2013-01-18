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

#import "SCOccurrence.h"

#if TARGET_OS_MAC
	#import <sys/sysctl.h>
#endif

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
	static NSDictionary *batteryStates;
	static NSDictionary *orientations;
#endif

@interface SCOccurrenceLocationDelegate : NSObject <CLLocationManagerDelegate> {
    SCOccurrence *occurrence;
}

@property (retain) SCOccurrence *occurrence;

@end

#pragma mark -

@interface SCOccurrence (Private)

#pragma mark Updates

- (void) didReceiveNewData;

#pragma mark Serialization

- (NSString *) filePath;
- (NSData *) asJSON;
- (NSString *) description;

@end

#pragma mark -

@implementation SCOccurrence

#pragma mark Properties

@synthesize UUID;
@synthesize symbolicationID;

@synthesize revision;
@synthesize occurredAt;
@synthesize client;

@synthesize exceptionClassName;
@synthesize message;
@synthesize backtraces;
@synthesize userData;
@synthesize parentExceptions;
@synthesize envVars;
@synthesize arguments;

@synthesize hostname;

@synthesize version;
@synthesize build;
@synthesize deviceID;
@synthesize deviceType;
@synthesize operatingSystem;

@synthesize physicalMemory;
@synthesize powerState;
@synthesize orientation;

@synthesize lat;
@synthesize lon;
@synthesize altitude;
@synthesize locationPrecision;
@synthesize heading;
@synthesize speed;

@synthesize networkOperator;
@synthesize networkType;
@synthesize connectivity;

#pragma mark Initializers

+ (void) initialize {
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    batteryStates = [NSDictionary dictionaryWithObjectsAndKeys:
                                          @"UIDeviceBatteryStateUnknown", [NSNumber numberWithInt:UIDeviceBatteryStateUnknown],
                                          @"UIDeviceBatteryStateUnplugged", [NSNumber numberWithInt:UIDeviceBatteryStateUnplugged],
                                          @"UIDeviceBatteryStateCharging", [NSNumber numberWithInt:UIDeviceBatteryStateCharging],
                                          @"UIDeviceBatteryStateFull", [NSNumber numberWithInt:UIDeviceBatteryStateFull],
                                          NULL];
    orientations = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"UIDeviceOrientationUnknown", [NSNumber numberWithInt:UIDeviceOrientationUnknown],
                                         @"UIDeviceOrientationPortrait", [NSNumber numberWithInt:UIDeviceOrientationPortrait],
                                         @"UIDeviceOrientationPortraitUpsideDown", [NSNumber numberWithInt:UIDeviceOrientationPortraitUpsideDown],
                                         @"UIDeviceOrientationLandscapeLeft", [NSNumber numberWithInt:UIDeviceOrientationLandscapeLeft],
                                         @"UIDeviceOrientationLandscapeRight", [NSNumber numberWithInt:UIDeviceOrientationLandscapeRight],
                                         @"UIDeviceOrientationFaceUp", [NSNumber numberWithInt:UIDeviceOrientationFaceUp],
                                         @"UIDeviceOrientationFaceDown", [NSNumber numberWithInt:UIDeviceOrientationFaceDown],
                                         NULL];
#endif
}

- (id) initWithException:(NSException *)exception {
    if (self = [self init]) {
        self.exceptionClassName = [exception name];
        self.message = [exception reason];
        self.userData = SCValueify([exception userInfo]);
        
        NSMutableArray *bt = [[NSMutableArray alloc] initWithCapacity:[[exception callStackReturnAddresses] count]];
        for (NSString *line in [exception callStackReturnAddresses])
            [bt addObject:[NSArray arrayWithObjects:@"_RETURN_ADDRESS_", line, NULL]];

        self.backtraces = [NSArray arrayWithObject:[NSArray arrayWithObjects:@"Crashed Thread", [NSNumber numberWithBool:YES], bt, NULL]];
        [bt release];
    }
    return self;
}

- (id) initWithSignal:(int)signal addresses:(NSArray *)backtrace {
    if (self = [self init]) {
        self.exceptionClassName = [NSString stringWithUTF8String:strsignal(signal)];
        self.message = @"Signal trapped";
        
        NSMutableArray *bt = [[NSMutableArray alloc] initWithCapacity:[backtrace count]];
        for (NSString *line in backtrace)
            [bt addObject:[NSArray arrayWithObjects:@"_RETURN_ADDRESS_", line, NULL]];
        
        self.backtraces = [NSArray arrayWithObject:[NSArray arrayWithObjects:@"Crashed Thread", [NSNumber numberWithBool:YES], bt, NULL]];
        [bt release];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        UUID = [[coder decodeObjectForKey:@"SCUUID"] retain];
        symbolicationID = [[coder decodeObjectForKey:@"SCSymbolicationID"] retain];
        
        self.revision = [coder decodeObjectForKey:@"SCRevision"];
        self.occurredAt = [coder decodeObjectForKey:@"SCOccurredAt"];
        self.client = [coder decodeObjectForKey:@"SCClient"];
        
        self.exceptionClassName = [coder decodeObjectForKey:@"SCClassName"];
        self.message = [coder decodeObjectForKey:@"SCMessage"];
        self.backtraces = [coder decodeObjectForKey:@"SCBacktraces"];
        self.userData = [coder decodeObjectForKey:@"SCUserData"];
        self.parentExceptions = [coder decodeObjectForKey:@"SCParentExceptions"];
        self.envVars = [coder decodeObjectForKey:@"SCEnvVars"];
        self.arguments = [coder decodeObjectForKey:@"SCArguments"];
        
        self.hostname = [coder decodeObjectForKey:@"SCHostname"];
        
        self.version = [coder decodeObjectForKey:@"SCVersion"];
        self.build = [coder decodeObjectForKey:@"SCBuild"];
        self.deviceID = [coder decodeObjectForKey:@"SCDeviceID"];
        self.deviceType = [coder decodeObjectForKey:@"SCDeviceType"];
        self.operatingSystem = [coder decodeObjectForKey:@"SCOperatingSystem"];
        
        self.physicalMemory = [coder decodeObjectForKey:@"SCPhysicalMemory"];
        self.powerState = [coder decodeObjectForKey:@"SCPowerState"];
        self.orientation = [coder decodeObjectForKey:@"SCOrientation"];
        
        self.lat = [coder decodeObjectForKey:@"SCLatitude"];
        self.lon = [coder decodeObjectForKey:@"SCLongitude"];
        self.altitude = [coder decodeObjectForKey:@"SCAltitude"];
        self.locationPrecision = [coder decodeObjectForKey:@"SCLocationPrecision"];
        self.heading = [coder decodeObjectForKey:@"SCHeading"];
        self.speed = [coder decodeObjectForKey:@"SCSpeed"];
        
        self.networkOperator = [coder decodeObjectForKey:@"SCNetworkOperator"];
        self.networkType = [coder decodeObjectForKey:@"SCNetworkType"];
        self.connectivity = [coder decodeObjectForKey:@"SCConnectivity"];
    }
    return self;
}

#pragma mark Serialization

- (void) writeToFile {
    [[NSFileManager defaultManager] createDirectoryAtPath:[[SquashCocoa sharedClient] occurrencesDirectory] withIntermediateDirectories:YES attributes:NULL error:NULL];
    [NSKeyedArchiver archiveRootObject:self toFile:[self filePath]];
}

- (void) encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.UUID forKey:@"SCUUID"];
    [coder encodeObject:self.symbolicationID forKey:@"SCSymbolicationID"];
    
    [coder encodeObject:self.revision forKey:@"SCRevision"];
    [coder encodeObject:self.occurredAt forKey:@"SCOccurredAt"];
    [coder encodeObject:self.client forKey:@"SCClient"];
    
    [coder encodeObject:self.exceptionClassName forKey:@"SCClassName"];
    [coder encodeObject:self.message forKey:@"SCMessage"];
    [coder encodeObject:self.backtraces forKey:@"SCBacktraces"];
    [coder encodeObject:self.userData forKey:@"SCUserData"];
    [coder encodeObject:self.parentExceptions forKey:@"SCParentExceptions"];
    [coder encodeObject:self.envVars forKey:@"SCEnvVars"];
    [coder encodeObject:self.arguments forKey:@"SCArguments"];
    
    [coder encodeObject:self.hostname forKey:@"SCHostname"];
    
    [coder encodeObject:self.version forKey:@"SCVersion"];
    [coder encodeObject:self.build forKey:@"SCBuild"];
    [coder encodeObject:self.deviceID forKey:@"SCDeviceID"];
    [coder encodeObject:self.deviceType forKey:@"SCDeviceType"];
    [coder encodeObject:self.operatingSystem forKey:@"SCOperatingSystem"];
    
    [coder encodeObject:self.physicalMemory forKey:@"SCPhysicalMemory"];
    [coder encodeObject:self.powerState forKey:@"SCPowerState"];
    [coder encodeObject:self.orientation forKey:@"SCOrientation"];
    
    [coder encodeObject:self.lat forKey:@"SCLatitude"];
    [coder encodeObject:self.lon forKey:@"SCLongitude"];
    [coder encodeObject:self.altitude forKey:@"SCAltitude"];
    [coder encodeObject:self.locationPrecision forKey:@"SCLocationPrecision"];
    [coder encodeObject:self.heading forKey:@"SCHeading"];
    [coder encodeObject:self.speed forKey:@"SCSpeed"];
    
    [coder encodeObject:self.networkOperator forKey:@"SCNetworkOperator"];
    [coder encodeObject:self.networkType forKey:@"SCNetworkType"];
    [coder encodeObject:self.connectivity forKey:@"SCConnectivity"];
}

#pragma mark Reporting

- (BOOL) report {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[[SquashCocoa sharedClient] notifyURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"Accept-Encoding"];
    [request setHTTPBody:[self asJSON]];
    [request setTimeoutInterval:[SquashCocoa sharedClient].timeout];
    
    NSHTTPURLResponse *response = NULL;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
    [request release];
    
    return response && [response statusCode]/100 == 2;
}

@end

#pragma mark -

@implementation SCOccurrence (Private)

#pragma mark Initializers

- (id) init {
    if (self = [super init]) {
        CFUUIDRef UUIDObject = CFUUIDCreate(NULL);
        UUID = (NSString *)CFUUIDCreateString(NULL, UUIDObject);
        CFRelease(UUIDObject);
        
        symbolicationID = SCExecutableUUID();
        
        self.revision = [[SquashCocoa sharedClient] revision];
        self.occurredAt = [NSDate date];
        self.client = [[SquashCocoa sharedClient] clientName];
        
        NSProcessInfo *info = [NSProcessInfo processInfo];
        self.arguments = [info arguments];
        self.envVars = [info environment];
        self.hostname = [info hostName];
        self.operatingSystem = [info operatingSystemVersionString];
        self.physicalMemory = [NSNumber numberWithLongLong:[info physicalMemory]];
        
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
        UIDevice *device = [UIDevice currentDevice];
        self.powerState = [batteryStates objectForKey:[NSNumber numberWithInt:device.batteryState]];
        self.deviceType = device.model;
        self.orientation = [orientations objectForKey:[NSNumber numberWithInt:device.orientation]];
#elif TARGET_OS_MAC
		size_t len = 0;
		sysctlbyname("hw.model", NULL, &len, NULL, 0);
		if (len) {
			char *model = malloc(len * sizeof(char));
			sysctlbyname("hw.model", model, &len, NULL, 0);
			self.deviceType = [NSString stringWithUTF8String:model];
			free(model);
		} else {
			self.deviceType = @"";
		}
#endif
        
        self.version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        self.build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
            CLLocationManager *locationManager = [[CLLocationManager alloc] init];
            SCOccurrenceLocationDelegate *delegate = [[SCOccurrenceLocationDelegate alloc] init];
            delegate.occurrence = self;
            locationManager.delegate = [delegate autorelease];
            locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
            [locationManager startUpdatingHeading];
#endif
            [locationManager startUpdatingLocation];
            [locationManager autorelease];
        }
        
        Reachability *currentReachability = [[Reachability reachabilityForInternetConnection] retain];
        NetworkStatus status = [currentReachability currentReachabilityStatus];
        [currentReachability release];
        switch (status) {
            case NotReachable: self.connectivity = @"none"; break;
            case ReachableViaWWAN: self.connectivity = @"wwan"; break;
            case ReachableViaWiFi: self.connectivity = @"wifi"; break;
        }
    }
    return self;
}

#pragma mark Updates

- (void) didReceiveNewData {
    [self writeToFile];
}

#pragma mark Serialization

- (NSString *) filePath {
    NSString *path = [[SquashCocoa sharedClient] occurrencesDirectory];
    path = [path stringByAppendingPathComponent:[self.UUID stringByAppendingString:@".occurrence"]];
    return path;
}

- (NSData *) asJSON {
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:31];
    [dictionary setObject:[SquashCocoa sharedClient].APIKey forKey:@"api_key"];
    [dictionary setObject:[SquashCocoa sharedClient].environment forKey:@"environment"];
    [dictionary setObject:self.symbolicationID forKey:@"symbolication_id"];
    [dictionary setObject:self.revision forKey:@"revision"];
    [dictionary setObject:[[[ISO8601DateFormatter alloc] init] stringFromDate:self.occurredAt] forKey:@"occurred_at"];
    [dictionary setObject:self.client forKey:@"client"];
    [dictionary setObject:self.exceptionClassName forKey:@"class_name"];
    [dictionary setObject:self.message forKey:@"message"];
    [dictionary setObject:self.backtraces forKey:@"backtraces"];
    if (self.userData) [dictionary setObject:userData forKey:@"user_data"];
    if (self.parentExceptions) [dictionary setObject:parentExceptions forKey:@"parent_exceptions"];
    if (self.envVars) [dictionary setObject:envVars forKey:@"env_vars"];
    if (self.arguments) [dictionary setObject:arguments forKey:@"arguments"];
    if (self.hostname) [dictionary setObject:hostname forKey:@"hostname"];
    if (self.version) [dictionary setObject:version forKey:@"version"];
    if (self.build) [dictionary setObject:build forKey:@"build"];
    if (self.deviceID) [dictionary setObject:deviceID forKey:@"device_id"];
    if (self.deviceType) [dictionary setObject:deviceType forKey:@"device_type"];
    if (self.operatingSystem) [dictionary setObject:operatingSystem forKey:@"operating_system"];
    if (self.physicalMemory) [dictionary setObject:physicalMemory forKey:@"physical_memory"];
    if (self.powerState) [dictionary setObject:powerState forKey:@"power_state"];
    if (self.orientation) [dictionary setObject:orientation forKey:@"orientation"];
    if (self.lat) [dictionary setObject:lat forKey:@"lat"];
    if (self.lon) [dictionary setObject:lon forKey:@"lon"];
    if (self.altitude) [dictionary setObject:altitude forKey:@"altitude"];
    if (self.locationPrecision) [dictionary setObject:locationPrecision forKey:@"location_precision"];
    if (self.heading) [dictionary setObject:heading forKey:@"heading"];
    if (self.speed) [dictionary setObject:speed forKey:@"speed"];
    if (self.networkOperator) [dictionary setObject:networkOperator forKey:@"network_operator"];
    if (self.networkType) [dictionary setObject:networkType forKey:@"network_type"];
    if (self.connectivity) [dictionary setObject:connectivity forKey:@"connectivity"];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    [dictionary release];
    return data;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"<SCOccurrence: className = %@, message = %@>", self.exceptionClassName, self.message];
}

@end

#pragma mark -

@implementation SCOccurrenceLocationDelegate

#pragma mark Properties

@synthesize occurrence;

#pragma mark SCLocationDelegate (implemented)

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
- (void) locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    [manager stopUpdatingHeading];
    occurrence.heading = [NSNumber numberWithDouble:[newHeading trueHeading]];
    [occurrence didReceiveNewData];
}
#endif

- (void) locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
	[manager stopUpdatingLocation];
    occurrence.lat = [NSNumber numberWithDouble:newLocation.coordinate.latitude];
    occurrence.lon = [NSNumber numberWithDouble:newLocation.coordinate.longitude];
    occurrence.altitude = [NSNumber numberWithDouble:newLocation.altitude];
    occurrence.locationPrecision = [NSNumber numberWithDouble:newLocation.horizontalAccuracy];
    occurrence.speed = [NSNumber numberWithDouble:newLocation.speed];
    [occurrence didReceiveNewData];
}

#pragma mark SCLocationDelegate (ignored)

- (void) locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
}

- (void) locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    
}

- (void) locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    
}

- (void) locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
}

- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    
}

- (void) locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    
}

@end
