#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "SystemServices.h"
#import "NVCReportCreator.h"
#import "Critic.h"

@implementation NVCReportCreator

@synthesize attachmentFilePaths;
@synthesize description;
@synthesize metadata;

- (instancetype)init {
    self = [super init];
    metadata = [NSMutableDictionary new];
    attachmentFilePaths = [NSMutableArray new];
    return self;
}

- (void)create:(void (^)(BOOL success, NSError *))completionBlock{

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", [Critic API_BASE_URL], @"/api/v2/bug_reports"]];
    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    
    NSMutableURLRequest *request = nil;
    @try {
        request = [[NSMutableURLRequest alloc] initWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
        
        if(!metadata){
            metadata = [NSMutableDictionary new];
        }
        [self addStandardMetadata];
        
        if(!attachmentFilePaths){
            attachmentFilePaths = [NSMutableArray new];
        }
        if([[Critic instance] shouldLogToFile]){
            [attachmentFilePaths addObject:[[Critic instance] getLogFilePath]];
        }
        
        NSDictionary *params = [self generateParams];
        NSData *httpBody = [self createBodyWithBoundary:boundary parameters:params];
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionTask *task = [session uploadTaskWithRequest:request fromData:httpBody completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if(error){
                NSLog(@"Critic - Failed to upload report: %@", error);
                completionBlock(NO, error);
            }
            else{
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                long code = (long)[httpResponse statusCode];
                if(code == 201){
                    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSLog(@"Critic - Report has been uploaded successfully: %@", result);
                    completionBlock(YES, error);
                }
                else{
                    NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSLog(@"Critic - Request failed. Server returned response code[%ld]. Result: %@", code, result);
                    completionBlock(NO, error);
                }
            }
        }];
        [task resume];
    }
    @catch (NSError *error) {
        NSLog(@"Critic - Error encountered forming request: %@", error);
        completionBlock(NO, error);
    }
}

- (void)addStandardMetadata{
    SystemServices* systemServices = [SystemServices sharedServices];
    
    NSMutableDictionary* app = [NSMutableDictionary new];
    NSBundle* bundle = [NSBundle mainBundle];
    [app setObject:[bundle objectForInfoDictionaryKey:@"CFBundleName"] forKey:@"name"];
    [app setObject:[bundle bundleIdentifier] forKey:@"package"];
    [app setObject:[bundle objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey] forKey:@"version_code"];
    [app setObject:[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"version_name"];
    [metadata setObject:app forKey:@"ic_application"];
    
    UIDevice *myDevice = [UIDevice currentDevice];
    [myDevice setBatteryMonitoringEnabled:YES];
    
    NSString* batteryStateString = nil;
    switch([myDevice batteryState]) {
        case UIDeviceBatteryStateUnknown:
            batteryStateString = @"Unknown";
            break;
        case UIDeviceBatteryStateFull:
            batteryStateString = @"Full";
            break;
        case UIDeviceBatteryStateCharging:
            batteryStateString = @"Charging";
            break;
        case UIDeviceBatteryStateUnplugged:
            batteryStateString = @"Unplugged";
        default:
            batteryStateString = @"Unknown";
            break;
    }
    
    NSMutableDictionary* battery = [NSMutableDictionary new];
    [battery setObject:@([SSHardwareInfo pluggedIn]) forKey:@"charging_status"];
    [battery setObject:[NSNumber numberWithFloat:[systemServices batteryLevel]] forKey:@"percentage"];
    [battery setObject:batteryStateString forKey:@"state"];
    
    NSMutableDictionary* build = [NSMutableDictionary new];
    [build setObject:@"Apple" forKey:@"manufacturer"];
    [build setObject:[systemServices deviceModel] forKey:@"model"];
    [build setObject:[systemServices systemsVersion] forKey:@"version"];
    
    NSMutableDictionary *disk = [NSMutableDictionary new];
    [disk setObject:[NSNumber numberWithLongLong:[systemServices longDiskSpace]] forKey:@"total" ];
    [disk setObject:[NSNumber numberWithLongLong:[systemServices longFreeDiskSpace]] forKey:@"free" ];
    
    NSMutableDictionary *memory = [NSMutableDictionary new];
    [memory setObject:[NSNumber numberWithDouble:[systemServices totalMemory]] forKey:@"total" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices activeMemoryinRaw]] forKey:@"active" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices freeMemoryinRaw]] forKey:@"free" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices inactiveMemoryinRaw]] forKey:@"inactive" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices purgableMemoryinRaw]] forKey:@"purgable" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices wiredMemoryinRaw]] forKey:@"wired" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices inactiveMemoryinRaw]] forKey:@"inactive" ];
    [memory setObject:[NSNumber numberWithDouble:[systemServices wiredMemoryinRaw]] forKey:@"wired" ];
    
    NSMutableDictionary *network = [NSMutableDictionary new];
    [network setObject:@([systemServices connectedToCellNetwork]) forKey:@"cell_connected" ];
    [network setObject:@([systemServices connectedToWiFi]) forKey:@"wifi_connected" ];
    NSString* carrierName = [systemServices carrierName];
    if(carrierName){
        [network setObject:carrierName forKey:@"carrier_name" ];
    } else {
        [network setObject:@"N/A" forKey:@"carrier_name" ];
    }
    
    NSMutableDictionary* device = [NSMutableDictionary new];
    [device setObject:battery forKey:@"battery"];
    [device setObject:build forKey:@"build"];
    [device setObject:disk forKey:@"disk"];
    [device setObject:[[myDevice identifierForVendor] UUIDString] forKey:@"identifier"];
    [device setObject:memory forKey:@"memory"];
    [device setObject:network forKey:@"network"];
    [device setObject:[systemServices processorsUsage] forKey:@"processors"];
    [device setObject:[myDevice systemName] forKey:@"platform"];
    [metadata setObject:device forKey:@"ic_device"];
    
    NSMutableDictionary* productMetadata = [[Critic instance] productMetadata];
    if(productMetadata && [[productMetadata allKeys] count] > 0) {
        for(id key in productMetadata) {
            id value = [productMetadata objectForKey:key];
            [metadata setObject:value forKey:key];
        }
    }
}

- (NSDictionary *)generateParams{
    NSMutableDictionary *params = [NSMutableDictionary new];
    [params setObject:[[Critic instance] productAccessToken] forKey:@"api_token"];
    [params setObject:[[Critic instance] appInstallId] forKey:@"app_install[id]"];
    [params setObject:description forKey:@"bug_report[description]"];
    if([[Critic instance] productMetadata] != nil){
        NSData *metadataData = [NSJSONSerialization dataWithJSONObject:[[Critic instance] productMetadata] options:0 error:nil];
        [params setObject:[[NSString alloc] initWithData:metadataData encoding:NSUTF8StringEncoding] forKey:@"bug_report[metadata]"];
    }
    NSData *deviceStatusData = [NSJSONSerialization dataWithJSONObject:[[Critic instance] generateDeviceStatus] options:0 error:nil];
    [params setObject:[[NSString alloc] initWithData:deviceStatusData encoding:NSUTF8StringEncoding] forKey:@"device_status"];
    
    return params;
}

- (NSData *)createBodyWithBoundary:(NSString *)boundary parameters:(NSDictionary *)parameters {
    NSMutableData *httpBody = [NSMutableData data];
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSString *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        if([parameterKey isEqualToString:@"device_status"]) {
            [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n", @"application/json"] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"%@\r\n", parameterValue] dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    
    if(attachmentFilePaths && [attachmentFilePaths count] > 0) {
        for(id path in attachmentFilePaths){
            NSString *filename = [path lastPathComponent];
            NSData *data = [NSData dataWithContentsOfFile:path];
            NSString *mimetype = [self mimeTypeForPath:path];
            
            NSLog(@"Critic - sending %@ with mimetype of %@", filename, mimetype);
            [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
            [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", @"bug_report[attachments][]", filename] dataUsingEncoding:NSUTF8StringEncoding]];
            [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
            [httpBody appendData:data];
            [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    return httpBody;
}

- (NSString *)mimeTypeForPath:(NSString *)path {
    
    CFStringRef extension = (__bridge CFStringRef)[path pathExtension];
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extension, NULL);
    NSString *mimetype = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType));
    CFRelease(UTI);
    return mimetype;
}
@end
