//
//  UserPrefsConstants.h
//  blecontrol
//
//  Created by Anson Liu on 9/5/17.
//  Copyright © 2017 Anson Liu. All rights reserved.
//

#ifndef UserPrefsConstants_h
#define UserPrefsConstants_h

#define kBCGenericErrorDomain @"BCGenericErrorDomain"

#define kSavedPin @"UserPin"
#define kServicePreference @"service_preference"
#define kCharacteristicPreference @"characteristic_preference"

#define kConnectionCategory 0x31
#define kConnectionValidatePIN 0x31
#define kConnectionSetPIN 0x32

#define kSecurityCategory 0x32
#define kSecurityLockControl 0x31
#define kSecurityUnlockControl 0x32
#define kSecurityAlarmControl 0x33

#define kNoDetail 0x30
#define kTwiceDetail 0x31

#define kResponseSuccess 0x30
#define kResponseError 0x31

#endif /* UserPrefsConstants_h */
