Squash Client Library: iOS (Objective-C)
========================================

This client library reports exceptions to Squash, the Squarish exception
reporting and management system.

Documentation
-------------

Comprehensive documentation is written in YARD- and Markdown-formatted comments
throughout the source. To view this documentation as an HTML site, run Doxygen
with `doxygen Doxyfile`. Doxygen and Graphviz must be installed.

For an overview of the various components of Squash, see the website
documentation at https://github.com/SquareSquash/web.

Compatibility
-------------

This library is compatible with projects targeting iOS version 5.0 and above,
and written using Objective-C 2.0 or above.

Requirements
------------

This library has no external third-party dependencies. It uses the
SystemConfiguration, CoreLocation, UIKit, and Foundation frameworks.

Usage
-----

Compile the code with the correct scheme and architecture, creating a
libSquashCocoa.a library. Add this library to your project, being sure it is
included in your project's Link Binary With Libraries build phase. Add the
SquashCocoa.h header file to your project and import it:

```` objective-c
#import "SquashCocoa.h"
````

Add the following code somewhere in your application that gets invoked on
startup, such as your app delegate's `application:didFinishLaunchingWithOptions:`
method:

```` objective-c
[SquashCocoa sharedClient].APIKey = @"YOUR_API_KEY";
[SquashCocoa sharedClient].environment = @"production";
[SquashCocoa sharedClient].host = @"https://your.squash.host";
[SquashCocoa sharedClient].revision = @"GIT_REVISION_OF_RELEASED_PRODUCT";
[[SquashCocoa sharedClient] reportErrors];
[[SquashCocoa sharedClient] hook];
````

The `reportErrors` method loads any errors recorded from previous crashes and
transmits them to Squash. Errors are only removed from this queue when Squash
successfully receives them.

the `hook` method adds the uncaught-exception and default signal handlers that
allow Squash to record new crashes.

Configuration
-------------

You can configure the client using the properties of the
`[SquashCocoa sharedClient]` singleton instance. The following properties are
available:

### General

* `disabled`: If `YES`, the Squash client will not report any errors.
* `APIKey`: The API key of the project that exceptions will be associated with.
  This configuration option is required. The value can be found by going to the
  project's home page on Squash.
* `environment`: The environment that exceptions will be associated with.
* `revision`: The revision of the Git repository that was compiled to make this
  build. This field is required.

### Error Transmission

* `host`: The host on which Squash is running. This field is required.
* `notifyPath`: The path to post new exception notifications to. By default it's
  set to `/api/1.0/notify`.
* `notifyPath`: The path to post new exception notifications to. By default it's
  set to `/api/1.0/notify`.
* `timeout`: The amount of time to wait before giving up on trasmitting an
  error. By default it's 15 seconds.

### Exception Filtering

* `ignoredExceptions`: A set of `NSException` names that will not be reported to
  Squash.
* `handledSignals`: A set of signals (represented as `NSNumber`s) that Squash
  will trap. By default it's `SIGABRT`, `SIGBUS`, `SIGFPE`, `SIGILL`, `SIGSEGV`,
  and `SIGTRAP`.
* `filterUserInfoKeys`: Keys to remove from the `userInfo` dictionary of any
  `NSException`. These keys might contain sensitive or personal information, for
  example.

Error Transmission
------------------

Exceptions are transmitted to Squash using JSON-over-HTTPS. A default API
endpoint is pre-configured, though you can always set your own (see
**Configuration** above).
