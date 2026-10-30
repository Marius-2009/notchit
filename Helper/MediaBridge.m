#import <AppKit/AppKit.h>
#include <dlfcn.h>

typedef void (*GetInfo)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetBool)(dispatch_queue_t, void (^)(Boolean));
typedef void (*GetPID)(dispatch_queue_t, void (^)(int));
typedef void (*Register)(dispatch_queue_t);
typedef Boolean (*SendCommand)(int, NSDictionary *);
typedef void (*SetElapsed)(double);

static GetInfo getInfo;
static GetBool getPlaying;
static GetPID getPID;
static SendCommand sendCommand;
static SetElapsed setElapsed;
static NSString *lastLine;
static NSString *lastArtworkKey;

static void emit(void) {
    getInfo(dispatch_get_main_queue(), ^(NSDictionary *info) {
        getPlaying(dispatch_get_main_queue(), ^(Boolean playing) {
            getPID(dispatch_get_main_queue(), ^(int pid) {
                NSMutableDictionary *out = [NSMutableDictionary dictionary];
                NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"] ?: @"";
                NSString *artist = info[@"kMRMediaRemoteNowPlayingInfoArtist"] ?: @"";
                out[@"title"] = title;
                out[@"artist"] = artist;
                out[@"album"] = info[@"kMRMediaRemoteNowPlayingInfoAlbum"] ?: @"";
                out[@"duration"] = info[@"kMRMediaRemoteNowPlayingInfoDuration"] ?: @0;
                out[@"elapsed"] = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"] ?: @0;
                out[@"rate"] = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"] ?: @0;
                NSDate *stamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                out[@"timestamp"] = @(stamp ? stamp.timeIntervalSince1970 : NSDate.date.timeIntervalSince1970);
                out[@"playing"] = @(playing);
                out[@"pid"] = @(pid);
                NSString *key = [NSString stringWithFormat:@"%d|%@|%@", pid, title, artist];
                NSData *art = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                NSString *base = [[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingSortedKeys error:nil] base64EncodedStringWithOptions:0];
                BOOL newArt = ![key isEqualToString:lastArtworkKey] && (art.length > 0 || title.length == 0);
                if (!newArt && [base isEqualToString:lastLine]) return;
                lastLine = base;
                if (newArt) {
                    lastArtworkKey = key;
                    out[@"artwork"] = art.length > 0 ? [art base64EncodedStringWithOptions:0] : @"";
                }
                NSData *json = [NSJSONSerialization dataWithJSONObject:out options:0 error:nil];
                if (!json) return;
                fwrite(json.bytes, 1, json.length, stdout);
                fputc('\n', stdout);
                fflush(stdout);
            });
        });
    });
}

static void readCommands(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        char buf[256];
        while (fgets(buf, sizeof buf, stdin)) {
            NSString *line = [[NSString stringWithUTF8String:buf] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([line isEqualToString:@"toggle"]) sendCommand(2, nil);
                else if ([line isEqualToString:@"next"]) sendCommand(4, nil);
                else if ([line isEqualToString:@"prev"]) sendCommand(5, nil);
                else if ([line hasPrefix:@"seek "]) setElapsed([[line substringFromIndex:5] doubleValue]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ emit(); });
            });
        }
        exit(0);
    });
}

void notchit_media_run(void *a, void *b) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!h) exit(2);
    getInfo = (GetInfo)dlsym(h, "MRMediaRemoteGetNowPlayingInfo");
    getPlaying = (GetBool)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    getPID = (GetPID)dlsym(h, "MRMediaRemoteGetNowPlayingApplicationPID");
    sendCommand = (SendCommand)dlsym(h, "MRMediaRemoteSendCommand");
    setElapsed = (SetElapsed)dlsym(h, "MRMediaRemoteSetElapsedTime");
    Register reg = (Register)dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (!getInfo || !getPlaying || !getPID || !sendCommand || !reg) exit(3);
    reg(dispatch_get_main_queue());
    NSArray *names = @[@"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                       @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                       @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
                       @"kMRMediaRemoteNowPlayingApplicationClientStateDidChange"];
    for (NSString *n in names) {
        [NSNotificationCenter.defaultCenter addObserverForName:n object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { emit(); }];
    }
    [NSTimer scheduledTimerWithTimeInterval:3 repeats:YES block:^(NSTimer *t) { emit(); }];
    readCommands();
    emit();
    CFRunLoopRun();
}
