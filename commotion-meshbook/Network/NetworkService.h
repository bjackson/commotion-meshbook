//
//  NetworkService.h
//  commotion-meshbook
//
//  Created by Brad : Scal.io, LLC - http://scal.io
//

#import <Foundation/Foundation.h>

@class CWInterface, CWConfiguration, CWNetwork, SFAuthorizationView, CWChannel;

@interface NetworkService : NSObject {
    
    // Networking lib CoreWLAN
    CWInterface *currentInterface;
    
    // User Wifi Data
    BOOL powerState;
    NSString *ip;
    NSString *ssid;
    NSString *bssid;
    CWChannel *channel;
    // Scanned Networks Data
    //NSDictionary *scannedNetworkData;
    //NSMutableDictionary *scannedNetworks;
    NSMutableSet *scannedNetworks;
    
}

@property (readwrite, retain) CWInterface *currentInterface;
@property (readwrite, retain) NSMutableSet *scanResults;

#pragma mark -
#pragma mark Initialization
-(id) init;

#pragma mark -
#pragma mark CoreWLAN Fetch & Processing
- (void) scanUserWifiSettings;
- (NSMutableArray *)scanAvailableNetworks;
- (CWNetwork *)checkAvailableNetwork:(NSString *)networkName;

#pragma mark -
#pragma mark Network Management
- (BOOL) createIBSSNetwork:(NSString *)networkName withChannel:(NSString*)passedChannel;
- (BOOL) joinIBSSNetwork:(NSString *)networkName;

#pragma mark -
#pragma mark Wifi Network Data Polling
- (void) executeWifiDataPolling;

@end
