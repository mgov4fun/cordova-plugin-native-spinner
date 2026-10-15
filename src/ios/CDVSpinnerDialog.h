//
//  CDVSpinnerDialog.h
//
//  Created by Domonkos Pál on 2014.01.27..
//
//

#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>

@interface CDVSpinnerDialog : CDVPlugin

- (void)show:(CDVInvokedUrlCommand*)command;
- (BOOL)showHosted:(UIView *)host ownerToken:(NSString *)ownerToken;
- (void)hideHosted:(NSString *)ownerToken;
- (void)clearHosted;
- (void)showInHostView:(UIView *)hostView;
- (void)show:(CDVInvokedUrlCommand*)command inHostView:(UIView *)hostView;
- (void)hide:(CDVInvokedUrlCommand*)command;
- (void)hideInHostView;
    
@end
