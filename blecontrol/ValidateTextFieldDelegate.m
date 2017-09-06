//
//  CreateNoteTextFieldDelegate.m
//  Peer
//
//  Created by Anson Liu on 9/28/16.
//  Copyright © 2016 Anson Liu. All rights reserved.
//

#import "ValidateTextFieldDelegate.h"

@implementation ValidateTextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    //Handle Case1: range>1 subtracting text Case2: range=0 adding text
    if ((range.length > 0 && textField.text.length - range.length == 6) || (range.length == 0 && textField.text.length + string.length == 6)) {
        _createAction.enabled = YES;
    } else {
        _createAction.enabled = NO;
    }
    return YES;
}

@end
