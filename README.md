[![Version](https://img.shields.io/cocoapods/v/Critic.svg?style=flat)](http://cocoapods.org/pods/Critic)
[![License](https://img.shields.io/cocoapods/l/Critic.svg?style=flat)](http://cocoapods.org/pods/Critic)
[![Platform](https://img.shields.io/cocoapods/p/Critic.svg?style=flat)](http://cocoapods.org/pods/Critic)

# Inventiv Critic iOS Library

Use this library to add [Inventiv Critic](https://inventiv.io/critic/) to your iOS app.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Installation

1. Add the Critic pod to your `Podfile`.
```ruby
pod 'Critic'
```
2. Find your Product Access Token in the [Critic Web Portal](https://critic.inventiv.io/products) by viewing your Product's details.
3. Initialize Critic by starting it from your `AppDelegate`.
```swift
// Swift
Critic.instance().start("YOUR_PRODUCT_ACCESS_TOKEN")
```

```objective-c
// Objective-C
[[Critic instance] start:@"YOUR_PRODUCT_ACCESS_TOKEN"];
```
### Configuration

By default, devices that are not connected to a debug session will pipe console output (`stderr` and `stdout`) to a log file, which is 
included with submitted Reports. You can disable this behavior prior to starting Critic.
```swift
// Swift
Critic.instance().shouldLogToFile = false;
Critic.instance().start("YOUR_PRODUCT_ACCESS_TOKEN")
```

```objective-c
// Objective-C
[Critic instance].shouldLogToFile = false;
[[Critic instance] start:@"YOUR_PRODUCT_ACCESS_TOKEN"];
```

## Sending Customer Feedback Reports

You can show the default feedback report screen any time you like by calling the following method from a `UIViewController`.
```swift
// Swift
Critic.instance().showDefaultFeedbackScreen(self)
```

```objective-c
// Objective-C
[[Critic instance] showDefaultFeedbackScreen:self];
```

## Customizing Feedback Reports

Use the `NVCReportCreator` to build your own reports for custom user experiences or other use cases. Perform `NVCReportCreator` work on a background thread.
```swift
// Swift
let reportCreator = NVCReportCreator()
reportCreator.description = "This is user-entered text about the idea or experience they wish to report."
reportCreator.metadata = NSMutableDictionary()
reportCreator.metadata["Whatever key you want"] = "Whatever value you want"
reportCreator.attachmentFilePaths = NSMutableArray()
reportCreator.attachmentFilePaths.add("/absolute/path/to/desired/file.txt")
reportCreator.create({(success: Bool, error: Error?) in
    if success {
        NSLog("Feedback has been submitted!")
    }
    else {
        NSLog("Feedback submission failed.")
    }
})
```

```objective-c
// Objective-C
NVCReportCreator *reportCreator = [NVCReportCreator new];
reportCreator.description = @"This is user-entered text about the idea or experience they wish to report.";
report.metadata = [NSMutableDictionary new];
[report.metadata setObject:@"Whatever value you like" forKey:@"Whatever key you want"];
report.attachmentFilePaths = [NSMutableArray new];
[report.attachmentFilePaths addObject:@"/absolute/path/to/desired/file.txt"];
[reportCreator create:^(BOOL success, NSError *error){
    if(success){
        NSLog(@"Feedback has been submitted!");
    } else {
        NSLog(@"Feedback submission failed.");
    }
}];
```

## License

This library is released under the MIT License.
