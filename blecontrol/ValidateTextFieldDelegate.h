//
//  CreateNoteTextFieldDelegate.h
//  Peer
//
//  Created by Anson Liu on 9/28/16.
//  Copyright © 2016 Anson Liu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ValidateTextFieldDelegate : NSObject <UITextFieldDelegate>

@property (nonatomic) UIAlertAction *createAction;

@end
