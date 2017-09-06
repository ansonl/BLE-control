//
//  ViewController.m
//  blecontrol
//
//  Created by Anson Liu on 8/29/17.
//  Copyright © 2017 Anson Liu. All rights reserved.
//

@import CoreBluetooth;
@import AudioToolbox;

#import "ViewController.h"

#import "Constants.h"
#import "BLEArrayConstants.h"
#import "ValidateTextFieldDelegate.h"

@interface ViewController () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property CBCentralManager *centralManager;
@property CBPeripheral *targetPeripheral;
@property CBCharacteristic *targetCharacteristic;

@property NSArray<UIButton *> *allControlButtons;
@property NSString *futurePIN; //hold PIN when validating and setting

@property ValidateTextFieldDelegate *validateTextFieldDelegate;

@property UIAlertController *sendingAlertController;

@property (weak, nonatomic) IBOutlet UILabel *connectedLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *rssiIndicator;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIButton *lockOnceButton;
@property (weak, nonatomic) IBOutlet UIButton *lockTwiceButton;
@property (weak, nonatomic) IBOutlet UIButton *unlockOnceButton;
@property (weak, nonatomic) IBOutlet UIButton *unlockTwiceButton;
- (IBAction)setPinAction:(id)sender;
- (IBAction)lockOnceAction:(id)sender;
- (IBAction)lockTwiceAction:(id)sender;
- (IBAction)unlockOnceAction:(id)sender;
- (IBAction)unlockTwiceAction:(id)sender;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;

@end

@implementation ViewController

#pragma mark - UI methods
- (void)addNewLog:(NSString *)newLog {
    _logTextView.text = [NSString stringWithFormat:@"%@\n%@", _logTextView.text, newLog];
    if(_logTextView.text.length > 0 ) {
        NSRange bottom = NSMakeRange(_logTextView.text.length -1, 1);
        [_logTextView scrollRangeToVisible:bottom];
    }
}

#pragma mark - CBCentralManagerDelegate methods
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *state;
    if (central.state == CBManagerStateUnknown) {
        state = @"Unknown";
    } else if (central.state == CBManagerStateResetting) {
        state = @"Resetting";
    } else if (central.state == CBManagerStateUnsupported) {
        state = @"Unsupported";
    } else if (central.state == CBManagerStateUnauthorized) {
        state = @"Unauthorized";
    } else if (central.state == CBManagerStatePoweredOff) {
        state = @"PoweredOff";
    } else if (central.state == CBManagerStatePoweredOn) {
        state = @"PoweredOn";
    } else {
        state = [NSString stringWithFormat:@"%ld", (long)central.state];
    }
    
    [self addNewLog:[NSString stringWithFormat:@"Manager updated state: %@", state]];
    
    if (central.state == CBManagerStatePoweredOn) {
        
        [central scanForPeripheralsWithServices:@[[CBUUID UUIDWithData:[NSData dataWithBytes:dogeService length:2]]] options:nil];
        [self addNewLog:[NSString stringWithFormat:@"Scanning for peripherals with service %#2x%2x", dogeService[0], dogeService[1]]];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    [self addNewLog:[NSString stringWithFormat:@"Discovered %@ with RSSI %@", peripheral.name, RSSI]];
    self.targetPeripheral = peripheral;
    peripheral.delegate = self;
    
    [central connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self addNewLog:[NSString stringWithFormat:@"Connected %@", peripheral.name]];
    
    _connectedLabel.text = peripheral.name;
    
    [peripheral readRSSI];
    
    [peripheral discoverServices:@[[CBUUID UUIDWithData:[NSData dataWithBytes:dogeService length:2]]]];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self addNewLog:[NSString stringWithFormat:@"Disconnected %@", peripheral.name]];
    if (error)
        [self addNewLog:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
    
    _connectedLabel.text = @"N/A";
    [_rssiIndicator setProgress:0 animated:YES];
    
    [self disableAllControlButtons];
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        [self addNewLog:[NSString stringWithFormat:@"Found service %@", service.UUID]];
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithData:[NSData dataWithBytes:dataCharacteristic length:2]]] forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        [self addNewLog:[NSString stringWithFormat:@"Found service %@ characteristic %@", service.UUID, characteristic.UUID]];
        
        //Subsribe to characteristic 0x0001
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithData:[NSData dataWithBytes:dataCharacteristic length:2]]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            _targetCharacteristic = characteristic;
            [self enableAllControlButtons];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [self addNewLog:[NSString stringWithFormat:@"Updated notification state for %@ %d", characteristic.UUID, characteristic.isNotifying]];
    if (error)
        [self addNewLog:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    [self addNewLog:[NSString stringWithFormat:@"Updated characteristic data for %@ %@ %@", peripheral.name, characteristic.UUID, characteristic.value]];
    if (error)
        [self addNewLog:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
    
    if (characteristic.value.length >= 4) {
        Byte response[characteristic.value.length];
        memcpy(response, [characteristic.value bytes], characteristic.value.length);
        
        NSLog(@"%#x", response[0]);
        
        
        
        switch (response[0]) {
            case kConnectionCategory:
                switch (response[1]) {
                    case kConnectionValidatePIN:
                        switch (response[3]) {
                            case kResponseSuccess:
                                [self getNewPIN];
                                //Save validated PIN to user defaults
                                [self savePIN:_futurePIN];
                                break;
                            case kResponseError:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Incorrect PIN."}]];
                            default:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:response[3] userInfo:@{NSLocalizedDescriptionKey : @"Error validating PIN."}]];
                                break;
                        }
                        break;
                        
                    case kConnectionSetPIN:
                        switch (response[3]) {
                            case kResponseSuccess:
                                [self showSuccessAlert:@"PIN successfully set."];
                                //Save set PIN to user defaults
                                [self savePIN:_futurePIN];
                                break;
                            case kResponseError:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Incorrect old PIN."}]];
                            default:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:response[3] userInfo:@{NSLocalizedDescriptionKey : @"Error setting new PIN."}]];
                                break;
                        }
                        break;
                        
                    default:
                        break;
                }
                break;
            
            case kSecurityCategory:
                switch (response[1]) {
                    case kSecurityLockControl:
                        switch (response[3]) {
                            case kResponseSuccess:
                                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
                                break;
                            case kResponseError:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Incorrect PIN."}]];
                            default:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:response[3] userInfo:@{NSLocalizedDescriptionKey : @"Error locking door."}]];
                                break;
                        }
                        break;
                    case kSecurityUnlockControl:
                        switch (response[3]) {
                            case kResponseSuccess:
                                AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
                                break;
                            case kResponseError:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey : @"Incorrect PIN."}]];
                            default:
                                [self showErrorAlert:[[NSError alloc] initWithDomain:kBCGenericErrorDomain code:response[3] userInfo:@{NSLocalizedDescriptionKey : @"Error unlocking door."}]];
                                break;
                        }
                        break;
                        
                    default:
                        break;
                }
                [self enableAllControlButtons];
                break;
                
            default:
                break;
        }
    }
    
}


- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    [self addNewLog:[NSString stringWithFormat:@"Write characteristic data for %@ %@ %@", peripheral.name, characteristic.UUID, characteristic.value]];
    if (error)
        [self addNewLog:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
}

- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    [_rssiIndicator setProgress:(1 - ([RSSI floatValue]/ -100)) animated:YES];
    
    if (error)
        [self addNewLog:[NSString stringWithFormat:@"Error: %@", error.localizedDescription]];
}

#pragma mark - Utility methods

- (NSString *)createCommandWithCategory:(char)category withControl:(char)control withDetail:(char)detail withPIN:(NSString *)pin withParams:(NSString *)params {
    return [NSString stringWithFormat:@"%c%c%c%@%@", category, control, detail, pin ? pin : @"", params ? params : @""];
}

- (void)savePIN:(NSString *)pin {
    [[NSUserDefaults standardUserDefaults] setObject:_futurePIN forKey:kSavedPin];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)retrieveSavedPIN {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kSavedPin];
}

#pragma mark - UI Alert methods

- (void)showErrorAlert:(NSError *)error {
    UIAlertController *errorAlert = [UIAlertController
                                      alertControllerWithTitle:@"Something went wrong."
                                      message:error.localizedDescription
                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Dismiss"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action)
                                   {
                                       [errorAlert dismissViewControllerAnimated:YES completion:nil];
                                   }];
    
    [errorAlert addAction:cancelAction];
    
    [self presentViewController:errorAlert animated:YES completion:nil];
}

- (void)showSuccessAlert:(NSString *)message {
    UIAlertController *successAlert = [UIAlertController
                                     alertControllerWithTitle:@"Success"
                                     message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Dismiss"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action)
                                   {
                                       [successAlert dismissViewControllerAnimated:YES completion:nil];
                                   }];
    
    [successAlert addAction:cancelAction];
    
    [self presentViewController:successAlert animated:YES completion:nil];
}

- (void)getNewPIN {
    UIAlertController *newPinAlert = [UIAlertController
                                      alertControllerWithTitle:@"Enter New PIN"
                                      message:nil
                                      preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *sendAction = [UIAlertAction
                                 actionWithTitle:@"Set"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     NSString *pin = newPinAlert.textFields.firstObject.text;
                                     _futurePIN = pin;
                                     NSString *command = [self createCommandWithCategory:kConnectionCategory withControl:kConnectionSetPIN withDetail:kNoDetail withPIN:[[NSUserDefaults standardUserDefaults] stringForKey:kSavedPin] withParams:pin];
                                     [self addNewLog:command];
                                     
                                     [_targetPeripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_targetCharacteristic
                                                              type:CBCharacteristicWriteWithoutResponse];
                                     
                                     [newPinAlert dismissViewControllerAnimated:YES completion:^(){
                                         _sendingAlertController = [UIAlertController
                                                                    alertControllerWithTitle:@"Setting new PIN"
                                                                    message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];
                                         [self presentViewController:_sendingAlertController animated:YES completion:nil];
                                     }];
                                     
                                 }];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action)
                                   {
                                       [newPinAlert dismissViewControllerAnimated:YES completion:nil];
                                   }];
    
    [newPinAlert addTextFieldWithConfigurationHandler:^(UITextField *textfield) {
        _validateTextFieldDelegate = [[ValidateTextFieldDelegate alloc] init];
        _validateTextFieldDelegate.createAction = sendAction;
        textfield.delegate = _validateTextFieldDelegate;
        textfield.placeholder = @"New PIN";
        textfield.keyboardAppearance = UIKeyboardAppearanceAlert;
        textfield.keyboardType = UIKeyboardTypeNumberPad;
        sendAction.enabled = NO;
    }];
    
    [newPinAlert addAction:sendAction];
    [newPinAlert addAction:cancelAction];
    
    [self presentViewController:newPinAlert animated:YES completion:nil];
}

- (void)validatePIN {
    UIAlertController *pinAlert = [UIAlertController
                                   alertControllerWithTitle:@"Enter Old PIN"
                                   message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *sendAction = [UIAlertAction
                                 actionWithTitle:@"Validate"
                                 style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction * action)
                                 {
                                     NSString *pin = pinAlert.textFields.firstObject.text;
                                     _futurePIN = pin;
                                     NSString *command = [self createCommandWithCategory:kConnectionCategory withControl:kConnectionValidatePIN withDetail:kNoDetail withPIN:pin withParams:nil];
                                     [self addNewLog:command];
                                     
                                     [_targetPeripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_targetCharacteristic
                                                              type:CBCharacteristicWriteWithoutResponse];
                                     
                                     [pinAlert dismissViewControllerAnimated:YES completion:^(){
                                         _sendingAlertController = [UIAlertController
                                                                    alertControllerWithTitle:@"Validating"
                                                                    message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];
                                         [self presentViewController:_sendingAlertController animated:YES completion:nil];
                                     }];
                                     
                                 }];
    
    UIAlertAction *cancelAction = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleCancel
                                   handler:^(UIAlertAction * action)
                                   {
                                       [pinAlert dismissViewControllerAnimated:YES completion:nil];
                                   }];
    
    [pinAlert addTextFieldWithConfigurationHandler:^(UITextField *textfield) {
        _validateTextFieldDelegate = [[ValidateTextFieldDelegate alloc] init];
        _validateTextFieldDelegate.createAction = sendAction;
        textfield.delegate = _validateTextFieldDelegate;
        textfield.placeholder = @"Old PIN";
        textfield.keyboardAppearance = UIKeyboardAppearanceAlert;
        textfield.keyboardType = UIKeyboardTypeNumberPad;
        sendAction.enabled = NO;
    }];
    
    [pinAlert addAction:sendAction];
    [pinAlert addAction:cancelAction];
    
    [self presentViewController:pinAlert animated:YES completion:nil];
}

- (IBAction)setPinAction:(id)sender {
    [self validatePIN];
}

- (IBAction)lockOnceAction:(id)sender {
    NSString *command = [self createCommandWithCategory:kSecurityCategory withControl:kSecurityLockControl withDetail:kNoDetail withPIN:[self retrieveSavedPIN] withParams:nil];

    [_targetPeripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_targetCharacteristic type:CBCharacteristicWriteWithoutResponse];
    
    if ([sender isKindOfClass:[UIButton class]]) {
        ((UIButton *)sender).backgroundColor = [UIColor lightGrayColor];
    }
    [self disableAllControlButtons];
}

- (IBAction)lockTwiceAction:(id)sender {
    NSString *command = [self createCommandWithCategory:kSecurityCategory withControl:kSecurityLockControl withDetail:kTwiceDetail withPIN:[self retrieveSavedPIN] withParams:nil];
    
    [_targetPeripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_targetCharacteristic type:CBCharacteristicWriteWithoutResponse];
    
    if ([sender isKindOfClass:[UIButton class]]) {
        ((UIButton *)sender).backgroundColor = [UIColor lightGrayColor];
    }
    [self disableAllControlButtons];
}

- (IBAction)unlockOnceAction:(id)sender {
    NSString *command = [self createCommandWithCategory:kSecurityCategory withControl:kSecurityUnlockControl withDetail:kNoDetail withPIN:[self retrieveSavedPIN] withParams:nil];
    
    [_targetPeripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_targetCharacteristic type:CBCharacteristicWriteWithResponse];
    
    if ([sender isKindOfClass:[UIButton class]]) {
        ((UIButton *)sender).backgroundColor = [UIColor lightGrayColor];
    }
    [self disableAllControlButtons];
}

- (IBAction)unlockTwiceAction:(id)sender {
    NSString *command = [self createCommandWithCategory:kSecurityCategory withControl:kSecurityUnlockControl withDetail:kTwiceDetail withPIN:[self retrieveSavedPIN] withParams:nil];
    
    [_targetPeripheral writeValue:[command dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:_targetCharacteristic type:CBCharacteristicWriteWithoutResponse];
    
    if ([sender isKindOfClass:[UIButton class]]) {
        [UIView animateWithDuration:1.0 animations:^{
            ((UIButton *)sender).backgroundColor = [UIColor lightGrayColor];
        }];
    }
    [self disableAllControlButtons];
}

- (void)disableAllControlButtons {
    for (UIButton *button in _allControlButtons)
        button.enabled = NO;
    [_activityIndicator startAnimating];
}

- (void)enableAllControlButtons {
    for (UIButton *button in _allControlButtons) {
        button.enabled = YES;
        [UIView animateWithDuration:1.0 animations:^{
            button.backgroundColor = [UIColor clearColor];
        }];
    }
    [_activityIndicator stopAnimating];
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _centralManager  = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    
    _allControlButtons = [[NSArray alloc] initWithObjects:_lockOnceButton, _lockTwiceButton, _unlockOnceButton, _unlockTwiceButton, nil];
    
    [self disableAllControlButtons];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
