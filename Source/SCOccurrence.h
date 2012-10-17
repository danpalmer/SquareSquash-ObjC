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

/*!
 An occurrence of an `NSException` being raised or a signal being trapped. This
 class stores data about the exception and the environment at the time of
 occurrence. It also knows how to collect that data, how to store itself for
 future transmission (SCOccurrence::writeToFile), and how to transmit itself to
 Squash (SCOccurrence::report).
 
 Each SCOccurrence automatically generates a UUID when instantiated. This UUID
 is used when storing and retrieving the occurrence.
 
 All initialized exceptions automatically load environment information when
 created. The developer need only supply the exception-specific information.
 */
@interface SCOccurrence : NSObject <NSCoding>

#pragma mark Properties

/*! A globally-unique ID, automatically generated upon initialization. */
@property (retain, readonly) NSString *UUID;

/*!
 The Mach-O linking UUID of the program, which is also used to uniquely identify
 this build's symbolication data.
 */
@property (retain, readonly) NSString *symbolicationID;

/*! The Git revision of the build. */
@property (retain) NSString *revision;

/*! The time at which the exception or signal occurred. */
@property (retain) NSDate *occurredAt;

/*! The Squash client library (should be "ios"). */
@property (retain) NSString *client;

/*! The name of the `NSException` or signal. */
@property (retain) NSString *exceptionClassName;

/*! For `NSException`s, the description. For signals, a constant string. */
@property (retain) NSString *message;

/*! The call stack return addresses (as `NSNumber`s) at the time of occurrence. */
@property (retain) NSArray *backtraces;

/*! The `NSException`'s `userInfo` dictionary. */
@property (retain) NSDictionary *userData;

/*! Unused. */
@property (retain) NSArray *parentExceptions;

/*! The environment variables. */
@property (retain) NSDictionary *envVars;

/*! The program's launch arguments. */
@property (retain) NSArray *arguments;

/*! The hostname of the device running the program. */
@property (retain) NSString *hostname;

/*! The human-readable version of the build (`CFBundleShortVersionString`). */
@property (retain) NSString *version;

/*! The internal build number (`CFBundleVersion`). */
@property (retain) NSString *build;

/*! Unused. */
@property (retain) NSString *deviceID;

/*! A string identifying the device's make and model. */
@property (retain) NSString *deviceType;

/*! A string identifying the operating system name and version. */
@property (retain) NSString *operatingSystem;

/*! The amount of physical memory on the device, in bytes. */
@property (retain) NSNumber *physicalMemory;

/*! The device's power state (charging, full, etc.) as a platform-specific string. */
@property (retain) NSString *powerState;

/*! The device's orientation as a platform-specific string. */
@property (retain) NSString *orientation;

/*! The device's latitude, in degrees decimal. */
@property (retain) NSNumber *lat;

/*! The device's longitude, in degrees decimal. */
@property (retain) NSNumber *lon;

/*! The device's altitude, in meters. */
@property (retain) NSNumber *altitude;

/*! The location precision of the fix (platform-specific). */
@property (retain) NSNumber *locationPrecision;

/*! The device's heading, in degrees decimal. */
@property (retain) NSNumber *heading;

/*! The device's velocity, in meters per second. */
@property (retain) NSNumber *speed;

/*! Unused. */
@property (retain) NSString *networkOperator;

/*! Unused. */
@property (retain) NSString *networkType;

/*! Unused. */
@property (retain) NSString *connectivity;

#pragma mark Initializers

/*!
 Creates a new Occurrence recording an instance of an `NSException` being
 caught by Squash.
 @param exception The exception that was caught.
 @return The initialized instance.
 */
- (id) initWithException:(NSException *)exception;

/*!
 Creates a new Occurrence recording an instance of a signal being trapped by
 Squash.
 @param signal The number for the signal that was trapped.
 @param backtraces The call stack return addresses at the time of the trap (as
 `NSNumber`s).
 @return The initialized instance.
 */
- (id) initWithSignal:(int)signal addresses:(NSArray *)backtraces;

#pragma mark Serialization

/*!
 Writes this occurrence to a file for later uploading.
 */
- (void) writeToFile;

#pragma mark Reporting

/*!
 Sends the occurrence data synchronously to the Squash host over HTTP(S).
 @return Whether or not the data was received successfully.
 */
- (BOOL) report;

@end
