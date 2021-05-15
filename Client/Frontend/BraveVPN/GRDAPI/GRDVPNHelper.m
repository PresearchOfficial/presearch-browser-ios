// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "GRDVPNHelper.h"
#import "VPNConstants.h"
#import "NSLogDisabler.h"

@implementation GRDVPNHelper

static NSString * const kGRDUseConfigAttributeIPSubnet = @"kGRDUseConfigAttributeIPSubnet";
static NSString * const kGRDWifiAssistEnableFallback = @"kGRDWifiAssistEnableFallback";

+ (void)saveAllInOneBoxHostname:(NSString *)host {
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:@"GatewayHostname-Override"];
    [[NSUserDefaults standardUserDefaults] setObject:host forKey:kGRDHostnameOverride];
}

+ (void)clearVpnConfiguration {
    [GRDKeychain removeGuardianKeychainItems];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kGRDHostnameOverride];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"GatewayHostname-Override"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"housekeepingTimezonesTimestamp"];
    
    // make sure Settings tab UI updates to not erroneously show name of cleared server
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDServerUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:kGRDLocationUpdatedNotification object:nil];
}

+ (BOOL)isPayingUser {
    // BRAVE TODO: This should always return true for our case
    return YES;
    //return [[NSUserDefaults standardUserDefaults] boolForKey:kGuardianSuccessfulSubscription];
}

+ (void)setIsPayingUser:(BOOL)isPaying {
    [[NSUserDefaults standardUserDefaults] setBool:isPaying forKey:kIsPremiumUser];
    [[NSUserDefaults standardUserDefaults] setBool:isPaying forKey:kGuardianSuccessfulSubscription];
}

+ (NSArray *)vpnOnDemandRules {
    // RULE: do not take action if certain types of inflight wifi, needed because they do not detect captive portal properly
    NEOnDemandRuleIgnore *onboardIgnoreRule = [[NEOnDemandRuleIgnore alloc] init];
    onboardIgnoreRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeWiFi;
    onboardIgnoreRule.SSIDMatch = @[@"gogoinflight", @"AA Inflight", @"AA-Inflight"];
    
    // RULE: disconnect if 'xfinitywifi' as they apparently block IPSec traffic (???)
    NEOnDemandRuleDisconnect *xfinityDisconnect = [[NEOnDemandRuleDisconnect alloc] init];
    xfinityDisconnect.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeWiFi;
    xfinityDisconnect.SSIDMatch = @[@"xfinitywifi"];
    
    // RULE: connect to VPN automatically if server reports that it is running OK
    NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
    vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeAny;
    vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [[NSUserDefaults standardUserDefaults] objectForKey:kGRDHostnameOverride], kSGAPI_ServerStatus]];
    
    NSArray *onDemandArr = @[onboardIgnoreRule, xfinityDisconnect, vpnServerConnectRule];
    return onDemandArr;
}

+ (NSArray *)vpnOnDemandRulesFree {
    // RULE: do not take action if certain types of inflight wifi, needed because they do not detect captive portal properly
    NEOnDemandRuleIgnore *onboardIgnoreRule = [[NEOnDemandRuleIgnore alloc] init];
    onboardIgnoreRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeWiFi;
    onboardIgnoreRule.SSIDMatch = @[@"gogoinflight", @"AA Inflight", @"AA-Inflight"];
    
    // RULE: disconnect if 'xfinitywifi' as they apparently block IPSec traffic (???)
    NEOnDemandRuleDisconnect *xfinityDisconnect = [[NEOnDemandRuleDisconnect alloc] init];
    xfinityDisconnect.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeWiFi;
    xfinityDisconnect.SSIDMatch = @[@"xfinitywifi"];
    
    // RULE: connect to VPN automatically if server reports that it is running OK
    NEOnDemandRuleConnect *vpnServerConnectRule = [[NEOnDemandRuleConnect alloc] init];
    // Only allowing free users to connect over WiFi to save on bandwidth costs
    vpnServerConnectRule.interfaceTypeMatch = NEOnDemandRuleInterfaceTypeWiFi; //FIX: won't disconnect as users roam among multiple Access Points on big wifi networks now
    vpnServerConnectRule.probeURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@%@", [[NSUserDefaults standardUserDefaults] objectForKey:kGRDHostnameOverride], kSGAPI_ServerStatus]];
    
    NSArray *onDemandArr = @[onboardIgnoreRule, xfinityDisconnect, vpnServerConnectRule];
    return onDemandArr;
}

- (void)createFreshUserWithSubscriberCredential:(NSString *)subscriberCredential completion:(void (^)(GRDVPNHelperStatusCode, NSString * _Nullable))completion {
    // remove previous authentication details
    [GRDKeychain removeGuardianKeychainItems];
    
    [[GRDGatewayAPI sharedAPI] registerAndCreateWithSubscriberCredential:subscriberCredential completion:^(NSDictionary * _Nullable credentials, BOOL success, NSString * _Nullable errorMessage) {
        if (success == NO && errorMessage != nil) {
            completion(GRDVPNHelperFail, errorMessage);
            return;
            
        } else {
            // These values will never be nil if the API request was successful
            NSString *eapUsername = [credentials objectForKey:@"eap-username"];
            NSString *eapPassword = [credentials objectForKey:@"eap-password"];
            NSString *apiAuthToken = [credentials objectForKey:@"api-auth-token"];
            
            OSStatus usernameStatus = [GRDKeychain storePassword:eapUsername forAccount:kKeychainStr_EapUsername retry:YES];
            if (usernameStatus != errSecSuccess) {
                NSLog(@"[createFreshUserWithSubscriberCredential] Failed to store eap username: %d", usernameStatus);
                if (completion) completion(GRDVPNHelperFail, @"Failed to store EAP Username");
                return;
            }
            
            OSStatus passwordStatus = [GRDKeychain storePassword:eapPassword forAccount:kKeychainStr_EapPassword retry:YES];
            if (passwordStatus != errSecSuccess) {
                NSLog(@"[createFreshUserWithSubscriberCredential] Failed to store eap password: %d", passwordStatus);
                if (completion) completion(GRDVPNHelperFail, @"Failed to store EAP Password");
                return;
            }
            
            OSStatus apiAuthTokenStatus = [GRDKeychain storePassword:apiAuthToken forAccount:kKeychainStr_APIAuthToken retry:YES];
            if (apiAuthTokenStatus != errSecSuccess) {
                NSLog(@"[createFreshUserWithSubscriberCredential] Failed to store api auth token: %d", apiAuthTokenStatus);
                if (completion) completion(GRDVPNHelperFail, @"Failed to store API Auth Token");
                return;
            }
            [[GRDGatewayAPI sharedAPI] setAPIAuthToken:apiAuthToken];
            [[GRDGatewayAPI sharedAPI] setDeviceIdentifier:eapUsername];
            
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kAppNeedsSelfRepair];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GRDCurrentUserChanged" object:nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GRDShouldConfigureVPN" object:nil];
            NSLog(@"[DEBUG][createFreshUserWithCompletion][provision] posted GRDCurrentUserChanged and GRDShouldConfigureVPN");
            
            completion(GRDVPNHelperSuccess, nil);
        }
    }];
}

- (void)configureAndConnectVPNWithCompletion:(void (^_Nullable)(NSString * _Nullable, GRDVPNHelperStatusCode))completion {
    __block NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    __block NSString *vpnServer = [defaults objectForKey:kGRDHostnameOverride];
    
    if ([defaults boolForKey:kAppNeedsSelfRepair] == YES) {
        if (completion) completion(nil, GRDVPNHelperDoesNeedMigration);
        return;
    }
    
    if ([vpnServer hasSuffix:@".guardianapp.com"] == NO && [vpnServer hasSuffix:@".sudosecuritygroup.com"] == NO) {
        NSLog(@"[DEBUG] something went wrong! bad server (%@)", vpnServer);
		if (completion) completion(@"This server name is not allowed. If this issue persists please select Contact Technical Support in the Settings tab.", GRDVPNHelperFail);
        return;
    }
    
    [[GRDGatewayAPI sharedAPI] getServerStatusWithCompletion:^(GRDGatewayAPIResponse *apiResponse) {
        // GRDGatewayAPIEndpointNotFound exists for VPN node legacy reasons but will never be hit
        // It will be removed in the next iteration
        if (apiResponse.responseStatus == GRDGatewayAPIServerOK || apiResponse.responseStatus == GRDGatewayAPIEndpointNotFound) {
			NSString *apiAuthToken = [GRDKeychain getPasswordStringForAccount:kKeychainStr_APIAuthToken];
			NSString *eapUsername = [GRDKeychain getPasswordStringForAccount:kKeychainStr_EapUsername];
			NSData *eapPassword = [GRDKeychain getPasswordRefForAccount:kKeychainStr_EapPassword];
            
			if (eapUsername == nil || eapPassword == nil || apiAuthToken == nil) {
                completion(nil, GRDVPNHelperDoesNeedMigration);
				return;
			}

            
        } else if (apiResponse.responseStatus == GRDGatewayAPIServerInternalError || apiResponse.responseStatus == GRDGatewayAPIServerNotOK) {
            NSMutableArray *knownHostnames = [NSMutableArray arrayWithArray:[defaults objectForKey:@"kKnownGuardianHosts"]];
            for (int i = 0; i < [knownHostnames count]; i++) {
                NSDictionary *serverObject = [knownHostnames objectAtIndex:i];
                if ([[serverObject objectForKey:@"hostname"] isEqualToString:vpnServer]) {
                    [knownHostnames removeObject:serverObject];
                }
            }
            
            [defaults setObject:[NSArray arrayWithArray:knownHostnames] forKey:@"kKnownGuardianHosts"];
			if (completion) completion(nil, GRDVPNHelperDoesNeedMigration);
            return;
            
        } else if (apiResponse.responseStatus == GRDGatewayAPIUnknownError) {
            NSLog(@"[DEBUG][configureVPN] GRDGatewayAPIUnknownError");
            
			if (apiResponse.error.code == NSURLErrorTimedOut) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] timeout error!");
				if (completion) completion(nil, GRDVPNHelperDoesNeedMigration);
            } else if (apiResponse.error.code == NSURLErrorServerCertificateHasBadDate) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] certificate expiration error! attempting to migrate user...");
				if (completion) completion(nil, GRDVPNHelperDoesNeedMigration);
            } else if (apiResponse.error.code == GRDVPNHelperDoesNeedMigration) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] could not find host! attempting to migrate user...");
				if (completion) completion(nil, GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorNotConnectedToInternet) {
                // probably should not reach here, due to use of Reachability, but leaving this as a fallback
                NSLog(@"[DEBUG][createFreshUserWithCompletion] not connected to internet!");
				if (completion) completion(@"Your device is not connected to the internet. Please check your Settings.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorNetworkConnectionLost) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] connection lost!");
				if (completion) completion(@"Connection failed, potentially due to weak network signal. Please ty again.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorInternationalRoamingOff) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] international roaming is off!");
				if (completion) completion(@"Your device is not connected to the internet. Please turn Roaming on in your Settings.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorDataNotAllowed) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] data not allowed!");
				if (completion) completion(@"Your device is not connected to the internet. Your cellular network did not allow this connection to complete.", GRDVPNHelperFail);
            } else if (apiResponse.error.code == NSURLErrorCallIsActive) {
                NSLog(@"[DEBUG][createFreshUserWithCompletion] phone call active!");
				if (completion) completion(@"The connection could not be completed due to an active phone call. Please try again after completing your phone call.", GRDVPNHelperFail);
            } else {
				if (completion) completion(@"Unknown error occured. Please contact support@guardianapp.com if this issue persists.", GRDVPNHelperFail);
            }
        }
    }];
}

+ (nullable NSString *)serverLocationForHostname:(NSString *)hostname {
    if([hostname hasPrefix:@"sanjose-"]) {
        return @"San Jose, CA, USA";
    } else if([hostname hasPrefix:@"sanfrancisco-"]) {
        return @"San Francisco, CA, USA";
    } else if([hostname hasPrefix:@"newjersey-"]) {
        return @"Parsippany, NJ, USA";
    } else if([hostname hasPrefix:@"newyork-"]) {
        return @"New York, NY, USA";
    } else if([hostname hasPrefix:@"boston-"]) {
        return @"Boston, MA, USA";
    } else if([hostname hasPrefix:@"chicago-"]) {
        return @"Chicago, IL, USA";
    } else if([hostname hasPrefix:@"virginia-"]) {
        return @"Ashburn, VA, USA";
    } else if([hostname hasPrefix:@"losangeles-"]) {
        return @"Los Angeles, CA, USA";
    } else if([hostname hasPrefix:@"atlanta-"]) {
        return @"Atlanta, GA, USA";
    } else if([hostname hasPrefix:@"dallas-"]) {
        return @"Dallas, TX, USA";
    } else if([hostname hasPrefix:@"seattle-"]) {
        return @"Seattle, WA, USA";
    } else if([hostname hasPrefix:@"latam-cw-"]) {
        return @"Curaçao";
    } else if([hostname hasPrefix:@"amsterdam-"]) {
        return @"Amsterdam, Netherlands";
    } else if([hostname hasPrefix:@"frankfurt-"]) {
        return @"Frankfurt, Germany";
    } else if([hostname hasPrefix:@"france-"]) {
        return @"France";
    } else if([hostname hasPrefix:@"london-"]) {
        return @"London, UK";
    } else if([hostname hasPrefix:@"helsinki-"]) {
        return @"Helsinki, Finland";
    } else if([hostname hasPrefix:@"swiss-"]) {
        return @"Switzerland";
    } else if([hostname hasPrefix:@"stockholm-"]) {
        return @"Stockholm, Sweden";
    } else if([hostname hasPrefix:@"sydney-"]) {
        return @"Sydney, Australia";
    } else if([hostname hasPrefix:@"singapore-"]) {
        return @"Singapore";
    } else if([hostname hasPrefix:@"tokyo-"]) {
        return @"Tokyo, Japan";
    } else if([hostname hasPrefix:@"taipei-"]) {
        return @"Taipei, Taiwan";
    } else if([hostname hasPrefix:@"bangalore-"]) {
        return @"Bangalore, India";
    } else if([hostname hasPrefix:@"hongkong-"]) {
        return @"Hong Kong";
    } else if([hostname hasPrefix:@"dubai-"]) {
        return @"Dubai, UAE";
    } else if([hostname hasPrefix:@"jeddah-"]) {
        return @"Jeddah, Saudi Arabia";
    } else if([hostname hasPrefix:@"riyadh-"]) {
        return @"Riyadh, Saudi Arabia";
    } else if([hostname hasPrefix:@"toronto-"]) {
        return @"Toronto, Canada";
    } else if([hostname hasPrefix:@"beauharnois-"]) {
        return @"Beauharnois, QC, Canada";
    } else {
        return nil;
    }
}

@end
