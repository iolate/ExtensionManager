
#include <sys/stat.h>
#import <AppSupport/CPDistributedMessagingCenter.h>


@interface ExtensionManD : NSObject

@end

static ExtensionManD* instance = nil;

@implementation ExtensionManD

+(ExtensionManD *)sharedInstance {
    return instance;
}

-(id)init {
    
    self = [super init];
    
    if (self) {
        
        CPDistributedMessagingCenter *messagingCenter;
        messagingCenter = [CPDistributedMessagingCenter centerNamed:@"kr.iolate.manager.center"];
        
        [messagingCenter registerForMessageName:@"managerExtensionState" target:self selector:@selector(managerExtensionStateNamed:withUserInfo:)];
        
        [messagingCenter runServerOnCurrentThread];
    }
    
    return self;
}

- (NSDictionary *)managerExtensionStateNamed:(NSString *)name withUserInfo:(NSDictionary *)stat {
    NSString* mode = [stat objectForKey:@"mode"];
    NSString* dName = [stat objectForKey:@"name"];

    BOOL on = TRUE;

    if (mode == nil || dName == nil) return NO;

    if ([mode isEqualToString:@"enable"])
    {
        on = TRUE;
    }else{
        on = FALSE;
    }

    NSString* fromPath = [NSString stringWithFormat:@"/Library/MobileSubstrate/DynamicLibraries/%@.%@", dName, !on ? @"dylib" : @"disabled"];
    NSString* toPath = [NSString stringWithFormat:@"/Library/MobileSubstrate/DynamicLibraries/%@.%@", dName, !on ? @"disabled" : @"dylib"];

    [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:nil];

    return [NSDictionary dictionary];
}

@end


int main(int argc, char **argv, char **envp) {
    
    umask(0);
    setsid();
    
    if ((chdir("/")) < 0) {
        exit(EXIT_FAILURE);
    }
    
    close(STDIN_FILENO);
    close(STDOUT_FILENO);
    close(STDERR_FILENO);
    
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    instance = [[ExtensionManD alloc] init];
    
    CFRunLoopRun();
    
    [pool drain];
    
	return 0;
}

// vim:ft=objc
