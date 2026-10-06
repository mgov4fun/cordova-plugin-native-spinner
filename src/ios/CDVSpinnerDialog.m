//
//  CDVSpinnerDialog.m
//
//  Created by Domonkos Pál on 2014.01.27..
//
//

#import "CDVSpinnerDialog.h"

@interface CDVSpinnerDialog () {
    UIActivityIndicatorView *indicator;
    NSString *callbackId;
    NSString *title;
    NSString *message;
    NSNumber *isFixed;
    NSString *alpha;
    NSString *red;
    NSString *green;
    NSString *blue;
}

@property (nonatomic, retain) UIActivityIndicatorView *indicator;
@property (nonatomic, retain) UIView *overlay;
@property (nonatomic, retain) UILabel *messageView;
@property (nonatomic, weak) UIView *hostView;
@property (nonatomic, assign) BOOL hostedPresentation;
- (void)show:(CDVInvokedUrlCommand *)command
   inHostView:(UIView *)hostView
    forceFixed:(BOOL)forceFixed;
- (void)removeHostedPresentationIfDetached;


@end

@implementation CDVSpinnerDialog

@synthesize indicator = _indicator;
@synthesize overlay = _overlay;
@synthesize messageView = _messageView;

-(CGRect)rectForView {
    if (self.hostView != nil) {
        return self.hostView.bounds;
    }

    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight);
    if(landscape){
        return CGRectMake( 0.0f, 0.0f, [UIScreen mainScreen].bounds.size.height, [[UIScreen mainScreen]bounds].size.width);
    }
    return CGRectMake( 0.0f, 0.0f, [[UIScreen mainScreen]bounds].size.width, [UIScreen mainScreen].bounds.size.height);
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture
{
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool:true];
    if (!isFixed.boolValue) {
        [result setKeepCallbackAsBool:false];
        [self hide];
    }
    [self.commandDelegate sendPluginResult:result callbackId:callbackId];
}

- (UIView *)overlay {
    if (!_overlay) {
        _overlay = [[UIView alloc] initWithFrame:self.rectForView];
        _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _overlay.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:[alpha floatValue]];
        _indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        _indicator.center = _overlay.center;
        [_indicator startAnimating];
        [_overlay addSubview:_indicator];

        _messageView = [[UILabel alloc] initWithFrame: self.rectForView];
        [_messageView setText: message == nil ? title : message];
        [_messageView setTextColor: [UIColor colorWithRed:[red floatValue] green:[green floatValue] blue:[blue floatValue] alpha:0.65]];
        [_messageView setBackgroundColor: [UIColor colorWithRed:0 green:0 blue:0 alpha:0]];
        [_messageView setTextAlignment: NSTextAlignmentCenter];
        _messageView.center = (CGPoint){_overlay.center.x, _overlay.center.y + 40};
        _messageView.font = [UIFont fontWithName:@"Helvetica" size:(10.0)];
        _messageView.lineBreakMode = NSLineBreakByCharWrapping;
        _messageView.numberOfLines = 0;
        [_overlay addSubview:_messageView];

        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        [_overlay addGestureRecognizer: tapRecognizer];
    }
    return _overlay;
}


- (void) show:(CDVInvokedUrlCommand*)command {
    [self show:command inHostView:nil forceFixed:NO];
}

- (void)showInHostView:(UIView *)hostView {
    if (hostView == nil) {
        return;
    }
    CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc]
        initWithArguments:@[[NSNull null], [NSNull null], @YES, @0.35, @1.0, @1.0, @1.0]
        callbackId:nil
        className:@"SpinnerDialog"
        methodName:@"show"];
    [self show:command inHostView:hostView];
}

- (void) show:(CDVInvokedUrlCommand*)command inHostView:(UIView *)hostView {
    if (hostView == nil) {
        return;
    }
    [self show:command inHostView:hostView forceFixed:YES];
}

- (void) show:(CDVInvokedUrlCommand*)command
    inHostView:(UIView *)hostView
     forceFixed:(BOOL)forceFixed {

    callbackId = command.callbackId;
    
    //If there is a loading mask yet we hide it
    [self hide];

    title = [command argumentAtIndex:0];
    message = [command argumentAtIndex:1];
    isFixed = [NSNumber numberWithBool:forceFixed || [[command argumentAtIndex:2] boolValue]];
    alpha = [command argumentAtIndex:3];
    red = [command argumentAtIndex:4];
    green = [command argumentAtIndex:5];
    blue = [command argumentAtIndex:6];
    
    self.hostView = hostView;
    self.hostedPresentation = hostView != nil;
    UIView *presentationView = hostView;
    if (presentationView == nil) {
        UIViewController *rootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        presentationView = rootViewController.view;
    }
    if (presentationView == nil) {
        return;
    }

    self.overlay.frame = presentationView.bounds;
    [presentationView addSubview:self.overlay];

}

- (void) hide:(CDVInvokedUrlCommand*)command {
    [self hide];
}

- (void)hideInHostView {
    if (self.hostedPresentation) {
        [self hide];
    }
}

- (void)removeHostedPresentationIfDetached {
    if (self.hostedPresentation &&
        (self.hostView == nil || self.overlay == nil || self.overlay.superview == nil)) {
        [self hide];
    }
}

- (void) hide {
    if (_overlay) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
        [self.messageView removeFromSuperview];
        [self.overlay removeFromSuperview];
        _indicator = nil;
        _messageView = nil;
        _overlay = nil;
    }
    self.hostView = nil;
    self.hostedPresentation = NO;
}

- (void)onReset {
    [self removeHostedPresentationIfDetached];
    [super onReset];
}

- (void)dealloc {
    [self hide];
}


#pragma mark - PRIVATE METHODS

@end
