#import "CometchatChatUikitPlugin.h"
#if __has_include(<cometchat_chat_uikit/cometchat_chat_uikit-Swift.h>)
#import <cometchat_chat_uikit/cometchat_chat_uikit-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "cometchat_chat_uikit-Swift.h"
#endif

@implementation CometchatChatUikitPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCometchatChatUikitPlugin registerWithRegistrar:registrar];
}
@end
