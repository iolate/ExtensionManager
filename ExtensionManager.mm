#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>
#import <Foundation/NSTask.h>
#import <AppSupport/CPDistributedMessagingCenter.h>

#define sortedKeyArray( dic ) [[dic allKeys] sortedArrayUsingSelector:@selector(compare:)]
#define initVar( var ) if (var) { [var release]; var = nil; }

@interface EMViewController: UITableViewController {
}
@property (nonatomic, retain) NSMutableDictionary* extensions;
@property (nonatomic, retain) NSMutableDictionary* packageInfo;
@property (nonatomic, retain) NSMutableDictionary* tableExt;
@property (nonatomic, retain) NSMutableArray* singleExtensions;

-(void) searchPackage:(NSString *)dylibName Enable:(BOOL)ena;
-(void)loadExtensions;
-(void)rearrangeDataForTable;
@end


static BOOL didFinishLoading = NO;
static BOOL loadingState = 0;

@implementation EMViewController
@synthesize extensions, packageInfo, tableExt, singleExtensions;

- (id)specifiers { return nil; }
- (id)specifier { return nil; }
-(void)setRootController:(id)controller {  }
-(void)setParentController:(id)controller { }
-(void)setSpecifier:(PSSpecifier *)spec { }

#pragma mark view life

-(id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    
    if (self) {
    }
    
    return self;
}

- (void)loadView {
    [super loadView];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    didFinishLoading = NO;
    loadingState = 0;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    loadingState = 1;
    [self.tableView reloadData];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self loadExtensions];
    });
}
-(void)respringSpringboard
{
    system("killall -9 backboardd SpringBoard");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"ExtensionManager";
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStyleDone target:self action:@selector(respringSpringboard)] autorelease];
    
}

- (void)viewDidUnload
{
    [packageInfo release];
    [extensions release];
    [tableExt release];
    [singleExtensions release];
    
    [super viewDidUnload];
}

-(void)dealloc {
    
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark package

-(void)loadExtensions
{
    initVar(extensions)
    initVar(packageInfo)
    
    extensions = [[NSMutableDictionary alloc] init];
    packageInfo = [[NSMutableDictionary alloc] init];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *fileName in [fileManager contentsOfDirectoryAtPath:@"/Library/MobileSubstrate/DynamicLibraries/" error:NULL]) {
        
        if (![fileName hasPrefix:@"."] && ([[fileName pathExtension] isEqualToString:@"dylib"] || [[fileName pathExtension] isEqualToString:@"disabled"]))
        {
            //dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self searchPackage:fileName Enable:[[fileName pathExtension] isEqualToString:@"dylib"] ? YES : NO];
            //});
        }
    }
    
    loadingState = 2;
    dispatch_async(dispatch_get_main_queue(), ^{ [self.tableView reloadData]; });
    
    [self rearrangeDataForTable];
}

-(NSString *)dpkgTask:(NSString *)arg1 :(NSString *)arg2
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: @"/usr/bin/dpkg"];
    
    NSArray *arguments = [NSArray arrayWithObjects:arg1, arg2, nil];
    [task setArguments: arguments];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    
    NSString *result = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    
    [task release];
    
    return [result autorelease];
}


-(void)getPackageInfo:(NSString *)packageID
{
    
    if ([packageID isEqualToString:@"Unknown"]) {
        
    }else{
        NSString* result = [self dpkgTask:@"-s" :packageID];
        
        if (result == nil) {
            [packageInfo setObject:[NSDictionary dictionary] forKey:packageID];
            
            return;
        }
        
        NSArray* infoFilter = [[NSArray alloc] initWithObjects:@"Version", @"Depends", @"Description", @"Author", @"Name", @"dev", @"Icon", nil];
        
        if ([result rangeOfString:@"\n"].length) {
            NSArray* lines = [result componentsSeparatedByString:@"\n"];
            NSMutableDictionary* keys = [[NSMutableDictionary alloc] init];
            
            for(unsigned int i = 0; i < [lines count]; i++) {
                NSString* line = [lines objectAtIndex:i];
                
                if (!line.length) continue;
                
                if ([line rangeOfString:@":"].length) {
                    int colonLocation = [line rangeOfString:@":"].location;
                    NSString* key = [[line substringToIndex:colonLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    NSString* value = [[line substringFromIndex:colonLocation+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    
                    if ([key isEqualToString:@"Depends"]) {
                        [keys setObject:value forKey:@"oDepends"];
                        
                        NSArray* depends = [value componentsSeparatedByString:@","];
                        NSMutableArray* newDepends = [[NSMutableArray alloc] init];
                        
                        for (NSString* dep in depends) {
                            if ([dep rangeOfString:@"("].length) {
                                
                                dep = [dep substringToIndex:[dep rangeOfString:@"("].location];
                            }
                            
                            dep = [dep stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                            
                            [newDepends addObject:dep];
                        }
                        
                        [keys setObject:newDepends forKey:key];
                        
                        continue;
                    }
                    
                    if ([infoFilter containsObject:key]) {
                        [keys setObject:value forKey:key];
                    }
                }else if (i > 0){
                    
                    for (int l = i-1; l >= 0; l--) {
                        NSString* prevLine = [lines objectAtIndex:l];
                        
                        if (!prevLine.length || ![prevLine rangeOfString:@":"].length) continue;
                        
                        int colonLocation = [prevLine rangeOfString:@":"].location;
                        NSString* key = [[prevLine substringToIndex:colonLocation] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        NSString* value = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                        
                        if ([key isEqualToString:@"Depends"]) {
                            break;
                        }
                        
                        if ([infoFilter containsObject:key])
                        {
                            NSString* newValue = [NSString stringWithFormat:@"%@\n%@", [keys objectForKey:key], value];
                            [keys setObject:newValue forKey:key];
                        }
                    }
                }else continue;
            }
            
            [packageInfo setObject:keys forKey:packageID];
        }
        
        [infoFilter release];
    }
}

-(void)searchPackage:(NSString *)dylibName Enable:(BOOL)ena
{
    NSString* dylibShortName = [dylibName stringByDeletingPathExtension];
    
    NSString* argument = [NSString stringWithFormat:@"/Library/MobileSubstrate/DynamicLibraries/%@.dylib", dylibShortName/* stringByAppendingPathExtension:@"dylib"]*/];
    
    NSString *result = [self dpkgTask:@"-S" :argument];
    
    NSString* package = nil;
    if (result.length > [result rangeOfString:@":"].location) {
        package = [result substringToIndex:[result rangeOfString:@":"].location];
    }else{
        package = @"Unknown";
    }
    
    //dylib disabled 공존시 처리
    if ([[extensions allKeys] containsObject:package]) {
        NSMutableArray* dArray = [extensions objectForKey:package];
        
        for (NSDictionary* cDic in dArray) {
            if ([dylibShortName isEqualToString:[cDic objectForKey:@"name"]]) {
                
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"/Library/MobileSubstrate/DynamicLibraries/%@.disabled", dylibShortName] error:nil];
                BOOL enable = [[cDic objectForKey:@"enable"] boolValue];
                
                if (enable) {
                    return;
                }else{
                    [dArray removeObject:cDic];
                    [extensions setObject:dArray forKey:package];
                }
            }
        }
    }
    
    if (![[packageInfo allKeys] containsObject:package]) {
        [packageInfo setObject:[NSDictionary dictionary] forKey:package];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self getPackageInfo:package];
        });
    }
    
    NSMutableArray* array = [extensions objectForKey:package] ?: [[NSMutableArray alloc] init];
    NSDictionary* dic = [NSDictionary dictionaryWithObjectsAndKeys:dylibShortName, @"name",
                         [NSNumber numberWithBool:ena], @"enable", nil];
    
    [array addObject:dic];
    
    [extensions setObject:array forKey:package];
    
}

#pragma mark table

-(void)checkDepends:(NSDictionary* )dylib
{
    
}

-(void)didChangedSwitch:(UISwitch *)tableSwitch 
{
    UITableViewCell *cell = (UITableViewCell *)tableSwitch.superview;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    int section = indexPath.section;
    int row = indexPath.row;
    BOOL isOn = tableSwitch.isOn;
    
    NSDictionary* dylib = nil;
    
    if (section < (int)[[tableExt allKeys] count]) {
        NSString* package = [sortedKeyArray(tableExt) objectAtIndex:section];
        dylib = [[tableExt objectForKey:package] objectAtIndex:row];
        
    }else {
        dylib = [singleExtensions objectAtIndex:row];
    }
    
    NSString* dylibShortName = [dylib objectForKey:@"name"];
    CPDistributedMessagingCenter *messagingCenter = [CPDistributedMessagingCenter centerNamed:@"kr.iolate.manager.center"];
    
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:dylibShortName, @"name", isOn ? @"enable" : @"disable", @"mode", nil];
    NSDictionary* result = [messagingCenter sendMessageAndReceiveReplyName:@"managerExtensionState" userInfo:info];
    
    if (result != nil) {
        NSMutableDictionary* dic = [NSMutableDictionary dictionaryWithDictionary:dylib];
        
        [dic setObject:[NSNumber numberWithBool:isOn] forKey:@"enable"];
        
        if (section < (int)[[tableExt allKeys] count]) {
            NSString* package = [sortedKeyArray(tableExt) objectAtIndex:section];
            
            NSMutableArray* sortedArray = [tableExt objectForKey:package];
            [sortedArray replaceObjectAtIndex:row withObject:dic];
            [tableExt setObject:sortedArray forKey:package];
        }else {
            [singleExtensions replaceObjectAtIndex:row withObject:dic];
        }
    }else{
        tableSwitch.on = !isOn;
        
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"ExtensionManager" message:@"Error" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
        [alert show];
        [alert release];
    }
}

-(void)rearrangeDataForTable {
    initVar(tableExt)
    initVar(singleExtensions);
    
    tableExt = [[NSMutableDictionary alloc] init];
    singleExtensions = [[NSMutableArray alloc] init];
    
    NSMutableDictionary* singleExt = [[NSMutableDictionary alloc] init];
    
    for (NSString* packageID in [extensions allKeys]) {
        NSArray* dylibs = [extensions objectForKey:packageID];
        
        if ([packageID isEqualToString:@"Unknown"]) {
            for (NSDictionary* dylib in dylibs) {
                NSString* fileName = [dylib objectForKey:@"name"];
                BOOL enabled = [[dylib objectForKey:@"enable"] boolValue];
                
                NSDictionary* newDylib = [NSDictionary dictionaryWithObjectsAndKeys:fileName, @"name",
                                          [NSNumber numberWithBool:enabled], @"enable",
                                          packageID, @"packageID", packageID, @"packageName",
                                          @"", @"imagePath", [NSArray array], @"packageDepends", nil];
                
                [singleExt setObject:newDylib forKey:fileName];
            }
        }else if ([dylibs count] > 1) {
            NSMutableDictionary* dy = [[NSMutableDictionary alloc] init];
            NSString* packageName = nil;
            for (NSDictionary* dylib in dylibs) {
                NSString* fileName = [dylib objectForKey:@"name"];
                BOOL enabled = [[dylib objectForKey:@"enable"] boolValue];
                
                NSDictionary* package = [packageInfo objectForKey:packageID];
                
                packageName = [package objectForKey:@"Name"] ?: packageID;
                NSString* packageImage = [package objectForKey:@"Icon"] ?: @"";
                NSArray* packageDepends = [package objectForKey:@"Depends"] ?: [NSArray array];
                NSString* oDepends = [package objectForKey:@"oDepends"] ?: @"";
                
                NSDictionary* newDylib = [NSDictionary dictionaryWithObjectsAndKeys:fileName, @"name",
                                          [NSNumber numberWithBool:enabled], @"enable",
                                          packageID, @"packageID", packageName, @"packageName",
                                          packageImage, @"imagePath", packageDepends, @"packageDepends",
                                          oDepends, @"oDepends", nil];
                
                [dy setObject:newDylib forKey:fileName];
                
            }
            
            NSMutableArray* sortedArray = [[NSMutableArray alloc] init];
            for (NSString* fileName in sortedKeyArray(dy)) {
                [sortedArray addObject:[dy objectForKey:fileName]];
            }
            
            [tableExt setObject:[sortedArray autorelease] forKey:packageName ?: packageID];
            
            [dy release];
        }else if ([dylibs count] == 1) {
            NSDictionary* dylib = [dylibs objectAtIndex:0];
            
            NSString* fileName = [dylib objectForKey:@"name"];
            BOOL enabled = [[dylib objectForKey:@"enable"] boolValue];
            
            NSDictionary* package = [packageInfo objectForKey:packageID];
            
            NSString* packageName = [package objectForKey:@"Name"] ?: packageID;
            NSString* packageImage = [package objectForKey:@"Icon"] ?: @"";
            NSArray* packageDepends = [package objectForKey:@"Depends"] ?: [NSArray array];
            NSString* oDepends = [package objectForKey:@"oDepends"] ?: @"";
            
            NSDictionary* newDylib = [NSDictionary dictionaryWithObjectsAndKeys:fileName, @"name",
                                      [NSNumber numberWithBool:enabled], @"enable",
                                      packageID, @"packageID", packageName, @"packageName",
                                      packageImage, @"imagePath", packageDepends, @"packageDepends",
                                      oDepends, @"oDepends", nil];
            
            [singleExt setObject:newDylib forKey:fileName];
        }
    }
    
    for (NSString* fileName in sortedKeyArray(singleExt)) {
        [singleExtensions addObject:[singleExt objectForKey:fileName]];
    }
    
    [singleExt release];
    
    didFinishLoading = YES;
    dispatch_async(dispatch_get_main_queue(), ^{ [self.tableView reloadData]; });
}
#pragma mark Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (didFinishLoading) {
        return [[tableExt allKeys] count] + ([singleExtensions count] ? 1 : 0);
    }else{
        return 1;
    }
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (didFinishLoading) {
        if (section < (int)[[tableExt allKeys] count]) {
            return [[tableExt objectForKey:[sortedKeyArray(tableExt) objectAtIndex:section]] count];
        }else {
            return [singleExtensions count];
        }
    }else{
        return 1;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (didFinishLoading) {
        if (section < (int)[[tableExt allKeys] count]) {
            NSString* package = [sortedKeyArray(tableExt) objectAtIndex:section];
            
            NSString* header = [NSString stringWithFormat:@"%@ (%@)", package, [[[tableExt objectForKey:package] objectAtIndex:0] objectForKey:@"packageID"]];
            return header;
        }else return nil;
    }else{
        return nil;
    }
}

-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (didFinishLoading) {
        int endRow = [[tableExt allKeys] count] + ([singleExtensions count] ? 1 : 0) - 1;
        if (section == endRow) {
            return @"\n\nExtensionManager © 2012-2013 iolate\nTwitter: @iolate_e";
        }else return nil;
    }else{
        return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* Cell = @"SwitchCell";
    static NSString* LoadingCell = @"LoadingCell";
    
    if (!didFinishLoading) {
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:LoadingCell];
        if (cell == nil) {
            cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:LoadingCell] autorelease];
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.textAlignment = UITextAlignmentLeft;
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            UIActivityIndicatorView *activityView = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
            [activityView startAnimating];
            [cell setAccessoryView:activityView];
        }
        
        if (loadingState == 0) {
            cell.textLabel.text = @"Loading...";
        }else if (loadingState == 1) {
            cell.textLabel.text = @"Search Packages...";
        }else if (loadingState == 2) {
            cell.textLabel.text = @"Arrange Data...";
        }
        
        return cell;
    }
    
    UISwitch* tableSwitch = nil;
    UITableViewCell* cell = nil;
    
    cell = [tableView dequeueReusableCellWithIdentifier:Cell];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:Cell] autorelease];
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textAlignment = UITextAlignmentLeft;
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    if (cell.accessoryView == nil || ![cell.accessoryView isKindOfClass:[UISwitch class]]) {
        tableSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
        [tableSwitch addTarget:self action:@selector(didChangedSwitch:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = tableSwitch;
    }else{
        tableSwitch = (UISwitch *)cell.accessoryView;
    }
    
    NSDictionary* dylib = nil;
    
    if (indexPath.section < (int)[[tableExt allKeys] count]) {
        NSString* package = [sortedKeyArray(tableExt) objectAtIndex:indexPath.section];
        dylib = [[tableExt objectForKey:package] objectAtIndex:indexPath.row];
        
        cell.detailTextLabel.text = @"";
    }else {
        dylib = [singleExtensions objectAtIndex:indexPath.row];
        
        NSString* subtitle = [NSString stringWithFormat:@"%@ (%@)", [dylib objectForKey:@"packageName"], [dylib objectForKey:@"packageID"]];
        cell.detailTextLabel.text = subtitle;
    }
    
    cell.textLabel.text = [dylib objectForKey:@"name"];
    
    cell.imageView.image = nil;
    
    NSString* imagePath = [dylib objectForKey:@"imagePath"];
    
    if ([imagePath hasPrefix:@"file://"]) {
        imagePath = [imagePath substringFromIndex:7];
    }
    
    cell.imageView.image = [UIImage imageWithContentsOfFile:imagePath];
    
    if (tableSwitch != nil) {
        tableSwitch.on = [[dylib objectForKey:@"enable"] boolValue];
        
        NSString* pID = [dylib objectForKey:@"packageID"];
        if ([pID isEqualToString:@"preferenceloader"] || [pID isEqualToString:@"com.saurik.substrate.safemode"]) {
            tableSwitch.enabled = FALSE;
        }else{
            tableSwitch.enabled = TRUE;
        }
    }
    
    return cell;
    
}


@end

// vim:ft=objc
