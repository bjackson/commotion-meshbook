//
//  NetworkService.m
//  commotion-meshbook
//
//  Created by Brad : Scal.io, LLC - http://scal.io
//

#import <Growl/Growl.h>
#import <CoreWLAN/CoreWLAN.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import "BLAuthentication.h"
#import <Foundation/Foundation.h>

#import "NetworkService.h"

@implementation NetworkService

@synthesize currentInterface = _currentInterface;
@synthesize scanResults = scanResults;

//==========================================================
#pragma mark Initialization & Run Loop
//==========================================================

-(id) init {
    //NSLog(@"NetworkService.h: init");
    
	if (![super init]) return nil;
    
    /**
    // setup notifications
    // listen for successful return of olsrd shell process starting
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(shellCommandExecuteSuccess:)
                                                 name:BLshellCommandExecuteSuccessNotification
                                               object:[BLAuthentication sharedInstance]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(shellCommandExecuteFailure:)
                                                 name:BLshellCommandExecuteFailureNotification
                                               object:[BLAuthentication sharedInstance]];
    **/
    
    
    // get interface array (common == 'en1')
    
    NSSet *supportedInterfaces = [CWInterface interfaceNames];
    //NSLog(@"[supportedInterfaces objectAtIndex:0: %@", [supportedInterfaces objectAtIndex:0]);
    
    // init network interface with 'en1'
    currentInterface = [CWInterface interfaceWithName:[[supportedInterfaces allObjects] objectAtIndex:0]];
    //NSLog(@"currentInterface: %@", currentInterface);
    
    return self;
}

//==========================================================
#pragma mark CoreWLAN Fetch & Processing
//==========================================================

- (void) scanUserWifiSettings {

    // get data from CoreWLAN wireless interface
    powerState = [currentInterface powerOn];
    NSString *power;
    if (powerState==NO) { power=@"Off"; } else { power=@"On";}
    
    ssid = ([currentInterface ssid] ? : @"");
    bssid = ([currentInterface bssid] ? : @"");
    channel = ([currentInterface wlanChannel] ? : 0);
    
    // get scanned wifi networks
    NSArray *availableNetworks = [self scanAvailableNetworks];
    
    //NSLog(@"powerState: %i", powerState);
    //NSLog(@"Network (SSID): %@", ssid);
    //NSLog(@"BSSID: %@", bssid);
    //NSLog(@"Channel: %@", channel);
    
	NSDictionary *userWifiData = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         power, @"state",
                                         ssid, @"ssid",
                                         bssid, @"bssid",
                                         (channel ? : @""), @"channel",
                                         availableNetworks, @"openNetworks",
                                         nil];
    
    // send notification to all listening classes that data is ready -- as a json dict
    [[NSNotificationCenter defaultCenter] postNotificationName:@"wifiDataProcessingComplete" object:nil userInfo:userWifiData];
}

- (NSMutableSet *)scanAvailableNetworks {
    NSError *err = nil;
    CWNetwork *currentNetwork = nil;
	//NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:nil]; //unneeded now?
        

    scanResults = [[currentInterface scanForNetworksWithSSID:nil error:nil] mutableCopy];
    //NSLog(@"scanResults: %@",scanResults);
    
  	if( err ) {
		NSLog(@"%s-Cannot scan networks.  Was wifi power lost?  %@", __FUNCTION__, err);
    }
	else {
		[scanResults sortedArrayUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"ssid" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    }
    
    //scannedNetworkData = [NSDictionary dictionary];
    //scannedNetworks = [NSMutableDictionary dictionary];
    scannedNetworks = [[NSMutableSet alloc] init];
        
    for (currentNetwork in scanResults) {
        
        //NSLog(@"SSID %@ - BSSID %@ - CHANNEL %@", [currentNetwork ssid], [currentNetwork bssid], [currentNetwork channel]);
        //NSLog(@"SSID %@ - IBSS %i", [currentNetwork ssid], [currentNetwork ibss]);
        
        NSString * scannedSSIDString = [currentNetwork ssid];
        
        // we only want to grab open adhoc (ibss) networks
        if ([currentNetwork ibss]==1) {
            
            [scannedNetworks addObject:scannedSSIDString];
        
            /**  IF WE WANT TO STORE MORE INFO ABOUT THE IBSS (BSSID AND CHANNEL)
            scannedNetworkData = [NSDictionary dictionaryWithObjectsAndKeys: 
                                           [currentNetwork bssid], @"bssid",
                                           [currentNetwork channel], @"channel",
                                           nil];
            
            [scannedNetworks setObject: scannedNetworkData forKey:[currentNetwork ssid]];
             **/
        }
    }
    
    return scannedNetworks;
}

- (CWNetwork *)checkAvailableNetwork:(NSString *)networkName {
    NSError *err = nil;
    CWNetwork *currentNetwork = nil;
	//NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:nil]; //unneeded now?
    
	scanResults = [[currentInterface scanForNetworksWithSSID:nil error:nil] mutableCopy];
    //NSLog(@"scanResults: %@",scanResults);
    
  	if( err ) {
		NSLog(@"error: %@",err);
    }
	else {
		[scanResults sortedArrayUsingDescriptors:[NSArray arrayWithObject:[[NSSortDescriptor alloc] initWithKey:@"ssid" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    }
        
    for (currentNetwork in scanResults) {
        
        NSString * scannedSSIDString = [currentNetwork ssid];
        
        // we only want to grab open adhoc (ibss) networks
        if ([currentNetwork ibss]==1) {
            
            // we look at passed method var to see if we're trying to return a single object
            if ((networkName != nil) && ([networkName isEqualToString:scannedSSIDString]) ) {
                
                return currentNetwork;
            }
        }
    }
    return nil;
}


//==========================================================
#pragma mark Network Management
//==========================================================
- (BOOL) createIBSSNetwork:(NSString *)networkName withChannel:(NSString*)passedChannel {
    
    [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                description:[NSString stringWithFormat:@"Attempting to create: %@", networkName]
                           notificationName:@"meshbookGrowlNotification"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
    
    // convert channel to number
    NSNumberFormatter * format = [[NSNumberFormatter alloc] init];
    [format setNumberStyle:NSNumberFormatterDecimalStyle];
    NSNumber * channelNumber = [format numberFromString:passedChannel];
    
    // we set no security here?
    NSString *passphrase = @"";
    
	NSMutableDictionary *ibssParamsForCreate = [NSMutableDictionary dictionaryWithCapacity:0];
	if( networkName && [networkName length] ) {
		[ibssParamsForCreate setValue:networkName forKey:@"kCWIBSSKeySSID"];
    }
    
	if( channelNumber && [channelNumber intValue] > 0 ) {
		[ibssParamsForCreate setValue:channelNumber forKey:@"kCWIBSSKeyChannel"];
    }
    else {
        NSRunAlertPanel(@"Error: Can't Create Mesh", @"Invalid Channel. Please ensure you entered a channel, 1-11.", @"OK", nil, nil);
        return NO;
    }
    if( passphrase && [passphrase length] ) {
		[ibssParamsForCreate setValue:passphrase forKey:@"kCWIBSSKeyPassphrase"];
    }
    
    //NSLog(@"networkName: %@", networkName);
    //NSLog(@"channel: %@", passedChannel);
    //NSLog(@"ibssParams: %@", ibssParamsForCreate);
    
    
	NSError *error = nil;
    //BOOL created = [currentInterface enableIBSSWithParameters:[NSDictionary dictionaryWithDictionary:ibssParamsForCreate] error:&error];
    BOOL created = [currentInterface startIBSSModeWithSSID:[ibssParamsForCreate objectForKey:@"kCWIBSSKeySSID"] security:kCWIBSSModeSecurityWEP104 channel:[ibssParamsForCreate objectForKey:@"kCWIBSSKeyChannel"] password:[ibssParamsForCreate objectForKey:@"kCWIBSSKeyPassphrase"] error:nil];
    
	if( !created )
	{
		[[NSAlert alertWithError:error] runModal];
        
        return NO;
	}
    else {
    
        // growl notification
        [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                    description:[NSString stringWithFormat:@"Successfully created: %@", networkName]
                               notificationName:@"meshbookGrowlNotification"
                                       iconData:nil
                                       priority:0
                                       isSticky:NO
                                   clickContext:nil];
        return YES;
    }
}


- (BOOL) joinIBSSNetwork:(NSString *)networkName {
    
    [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                description:[NSString stringWithFormat:@"Attempting to join: %@", networkName]
                           notificationName:@"meshbookGrowlNotification"
                                   iconData:nil
                                   priority:0
                                   isSticky:NO
                               clickContext:nil];
    
    // we need to get a CW object for passed network name
    CWNetwork *selectedNetwork = [self checkAvailableNetwork:networkName];
    //NSLog(@"selectedNetwork: %@", scannedItems);
    
    if (selectedNetwork) {
        
        NSMutableDictionary *ibssParamsForJoin = [NSMutableDictionary dictionaryWithCapacity:0];
        if( networkName ) {
            [ibssParamsForJoin setValue:networkName forKey:@"kCWIBSSKeySSID"];
        }
        //[ibssParamsForJoin setValue:passphrase forKey:kCWAssocKeyPassphrase];
        
        //NSLog(@"networkName: %@", networkName);

        NSError *error = nil;
        //BOOL joined = [currentInterface associateToNetwork:selectedNetwork parameters:[NSDictionary dictionaryWithDictionary:ibssParamsForJoin] error:&error];
#warning need to handle password somehow
        BOOL joined = [currentInterface associateToNetwork:selectedNetwork password:nil error:nil];
        //BOOL joined = [currentInterface associateToNetwork:selectedNetwork password:[ibssParamsForJoin objectForKey:kCWAssocKeyPassphrase] error:nil];
        
        if( !joined )
        {
            [[NSAlert alertWithError:error] runModal];
            
            return NO;
        }
        else {
            
            // growl notification
            [GrowlApplicationBridge notifyWithTitle:@"Network Stauts"
                                        description:[NSString stringWithFormat:@"Successfully joined: %@", networkName]
                                   notificationName:@"meshbookGrowlNotification"
                                           iconData:nil
                                           priority:0
                                           isSticky:NO
                                       clickContext:nil];
            return YES;
        }
    }
    else {
        // passed network didnt show up in scan, could it have disappeared?
        NSRunAlertPanel(@"Network Connection Error", [NSString stringWithFormat:@"There was a problem connecting to %@. \n The network may now be out of range.", networkName], @"OK", nil, nil);
        return NO;
    }
}

//==========================================================
#pragma mark Wifi Network Data Polling
//==========================================================

- (void) executeWifiDataPolling {
    
    /**
    [GrowlApplicationBridge notifyWithTitle:@"Executing Process"
                                description:@"Starting wifi data polling"
                           notificationName:@"meshbookGrowlNotification"
                                   iconData:nil
                                   priority:0 // -2 == Low priority. +2 == High Priority. 0 == Neutral
                                   isSticky:NO
                               clickContext:nil];
    **/
    
    // our olsrd shell command executed successfully -- now ok to fetch (poll) json data from localhost:9090
    // BEGIN POLLING
    
    // Note: runs on main thread - I dont see any reason to spin up a new thread as no UI blocking occuring that I can tell
    //[NSTimer scheduledTimerWithTimeInterval:8 target:self selector:@selector(scanUserWifiSettings) userInfo:nil repeats:YES];
    
    /** METHOD 1 of updating menu **/
    
    // use "scheduledTimer..." to have it already scheduled in NSRunLoopCommonModes, it will fire when the menu is closed
    NSTimer *menuTimer = [NSTimer scheduledTimerWithTimeInterval:8 target:self selector:@selector(scanUserWifiSettings) userInfo:nil repeats:YES];
    
    // add the timer to the run loop in NSEventTrackingRunLoopMode to have it fired even when menu is open
    [[NSRunLoop currentRunLoop] addTimer:menuTimer forMode:NSEventTrackingRunLoopMode];
    
    /** METHOD 2 of updating menu **/
    /**
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature: [self methodSignatureForSelector:@selector(scanUserWifiSettings)]];
    [invocation setTarget:self];
    [invocation setSelector:@selector(scanUserWifiSettings)];
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:5 invocation:invocation repeats:YES] forMode:NSRunLoopCommonModes];
     **/
}


@end
