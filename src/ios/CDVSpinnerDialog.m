//
//  CDVSpinnerDialog.m
//
//  Created by Domonkos Pál on 2014.01.27..
//

#import "CDVSpinnerDialog.h"

static NSString * const CDVLegacyHostedOwnerToken = @"__legacy_hosted_spinner_owner__";

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
@property (nonatomic, retain) UIView *hostedOverlay;
@property (nonatomic, retain) UIActivityIndicatorView *hostedIndicator;
@property (nonatomic, weak) UIView *hostedHostView;
@property (nonatomic, copy) NSString *hostedOwnerToken;
@property (nonatomic, assign) BOOL hostedAccessibilityAnnounced;

- (void)showGlobal:(CDVInvokedUrlCommand *)command;
- (BOOL)showHostedOnMainThread:(UIView *)host ownerToken:(NSString *)ownerToken;
- (void)hideGlobal;
- (void)clearHostedOnMainThread;
- (void)removeHostedPresentationIfDetached;
- (BOOL)isEligibleHostedHost:(UIView *)host;
- (void)performOnMainThread:(dispatch_block_t)block;

@end

@implementation CDVSpinnerDialog

@synthesize indicator = _indicator;
@synthesize overlay = _overlay;
@synthesize messageView = _messageView;
@synthesize hostedOverlay = _hostedOverlay;
@synthesize hostedIndicator = _hostedIndicator;
@synthesize hostedHostView = _hostedHostView;
@synthesize hostedOwnerToken = _hostedOwnerToken;
@synthesize hostedAccessibilityAnnounced = _hostedAccessibilityAnnounced;

- (void)performOnMainThread:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (CGRect)rectForView {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    BOOL landscape = (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight);
    if (landscape) {
        return CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    return CGRectMake(0.0f, 0.0f, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
}

- (void)handleTapGesture:(UITapGestureRecognizer *)gesture {
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [result setKeepCallbackAsBool:true];
    if (!isFixed.boolValue) {
        [result setKeepCallbackAsBool:false];
        [self hideGlobal];
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

        _messageView = [[UILabel alloc] initWithFrame:self.rectForView];
        [_messageView setText:message == nil ? title : message];
        [_messageView setTextColor:[UIColor colorWithRed:[red floatValue] green:[green floatValue] blue:[blue floatValue] alpha:0.65]];
        [_messageView setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0]];
        [_messageView setTextAlignment:NSTextAlignmentCenter];
        _messageView.center = (CGPoint){_overlay.center.x, _overlay.center.y + 40};
        _messageView.font = [UIFont fontWithName:@"Helvetica" size:10.0];
        _messageView.lineBreakMode = NSLineBreakByCharWrapping;
        _messageView.numberOfLines = 0;
        [_overlay addSubview:_messageView];

        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        [_overlay addGestureRecognizer:tapRecognizer];
    }
    return _overlay;
}

- (void)show:(CDVInvokedUrlCommand *)command {
    [self performOnMainThread:^{
        [self showGlobal:command];
    }];
}

- (void)showGlobal:(CDVInvokedUrlCommand *)command {
    callbackId = command.callbackId;

    // Global spinner state is deliberately separate from hosted state.
    [self hideGlobal];

    title = [command argumentAtIndex:0];
    message = [command argumentAtIndex:1];
    isFixed = [NSNumber numberWithBool:[[command argumentAtIndex:2] boolValue]];
    alpha = [command argumentAtIndex:3];
    red = [command argumentAtIndex:4];
    green = [command argumentAtIndex:5];
    blue = [command argumentAtIndex:6];

    UIViewController *rootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    UIView *presentationView = rootViewController.view;
    if (presentationView == nil) {
        return;
    }

    self.overlay.frame = presentationView.bounds;
    [presentationView addSubview:self.overlay];
}

- (BOOL)showHosted:(UIView *)host ownerToken:(NSString *)ownerToken {
    if (host == nil || ownerToken.length == 0) {
        return NO;
    }
    if ([NSThread isMainThread]) {
        return [self showHostedOnMainThread:host ownerToken:ownerToken];
    }
    __block BOOL shown = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        shown = [self showHostedOnMainThread:host ownerToken:ownerToken];
    });
    return shown;
}

- (BOOL)showHostedOnMainThread:(UIView *)host ownerToken:(NSString *)ownerToken {
    [self removeHostedPresentationIfDetached];
    [host setNeedsLayout];
    [host layoutIfNeeded];
    if (![self isEligibleHostedHost:host]) {
        return NO;
    }
    if (self.hostedOwnerToken != nil) {
        if ([self.hostedOwnerToken isEqualToString:ownerToken]) {
            // The current owner is idempotent.
            return self.hostedOverlay.superview == host;
        }
        // A different owner must not replace the current owner.
        return NO;
    }

    UIView *hostedOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    hostedOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    hostedOverlay.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.16f];
    hostedOverlay.userInteractionEnabled = YES;
    hostedOverlay.isAccessibilityElement = YES;
    hostedOverlay.accessibilityLabel = @"Laden";
    hostedOverlay.accessibilityTraits = UIAccessibilityTraitUpdatesFrequently;

    UIActivityIndicatorView *hostedIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    hostedIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    hostedIndicator.color = [UIColor whiteColor];
    hostedIndicator.isAccessibilityElement = NO;
    [hostedIndicator startAnimating];
    [hostedOverlay addSubview:hostedIndicator];

    [host addSubview:hostedOverlay];
    [NSLayoutConstraint activateConstraints:@[
        [hostedOverlay.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
        [hostedOverlay.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
        [hostedOverlay.topAnchor constraintEqualToAnchor:host.topAnchor],
        [hostedOverlay.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
        [hostedIndicator.centerXAnchor constraintEqualToAnchor:hostedOverlay.centerXAnchor],
        [hostedIndicator.centerYAnchor constraintEqualToAnchor:hostedOverlay.centerYAnchor]
    ]];
    [host layoutIfNeeded];
    if (hostedOverlay.window == nil || CGRectIsEmpty(hostedOverlay.bounds)) {
        [hostedIndicator stopAnimating];
        [hostedOverlay removeFromSuperview];
        return NO;
    }
    self.hostedOverlay = hostedOverlay;
    self.hostedIndicator = hostedIndicator;
    self.hostedHostView = host;
    self.hostedOwnerToken = ownerToken;
    if (!self.hostedAccessibilityAnnounced) {
        self.hostedAccessibilityAnnounced = YES;
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, @"Laden");
    }
    return YES;
}

- (BOOL)isEligibleHostedHost:(UIView *)host {
    if (host.window == nil || CGRectIsEmpty(host.bounds)) {
        return NO;
    }
    UIView *candidate = host;
    while (candidate != nil) {
        if (candidate.hidden || candidate.alpha <= 0.01f) {
            return NO;
        }
        candidate = candidate.superview;
    }
    return YES;
}

- (void)hide:(CDVInvokedUrlCommand *)command {
    [self performOnMainThread:^{
        [self hideGlobal];
    }];
}

- (void)hideGlobal {
    if (_overlay) {
        [self.indicator stopAnimating];
        [self.indicator removeFromSuperview];
        [self.messageView removeFromSuperview];
        [self.overlay removeFromSuperview];
        _indicator = nil;
        _messageView = nil;
        _overlay = nil;
    }
}

- (void)hideHosted:(NSString *)ownerToken {
    if (ownerToken.length == 0) {
        return;
    }
    [self performOnMainThread:^{
        if ([self.hostedOwnerToken isEqualToString:ownerToken]) {
            [self clearHostedOnMainThread];
        }
    }];
}

- (void)clearHosted {
    [self performOnMainThread:^{
        [self clearHostedOnMainThread];
    }];
}

- (void)clearHostedOnMainThread {
    [self.hostedIndicator stopAnimating];
    [self.hostedIndicator removeFromSuperview];
    [self.hostedOverlay removeFromSuperview];
    self.hostedIndicator = nil;
    self.hostedOverlay = nil;
    self.hostedHostView = nil;
    self.hostedOwnerToken = nil;
    self.hostedAccessibilityAnnounced = NO;
}

- (void)showInHostView:(UIView *)hostView {
    [self showHosted:hostView ownerToken:CDVLegacyHostedOwnerToken];
}

- (void)show:(CDVInvokedUrlCommand *)command inHostView:(UIView *)hostView {
    if (hostView != nil) {
        [self showHosted:hostView ownerToken:CDVLegacyHostedOwnerToken];
    } else {
        [self show:command];
    }
}

- (void)hideInHostView {
    [self hideHosted:CDVLegacyHostedOwnerToken];
}

- (void)removeHostedPresentationIfDetached {
    if (self.hostedOwnerToken != nil &&
        (self.hostedHostView == nil || self.hostedOverlay == nil || self.hostedOverlay.superview == nil)) {
        [self clearHostedOnMainThread];
    }
}

- (void)onReset {
    [self clearHosted];
    [super onReset];
}

- (void)dealloc {
    // Cordova tears plugins down on the main thread in normal operation.
    // Keep the fallback main-thread dispatch for native teardown callers.
    if ([NSThread isMainThread]) {
        [self clearHostedOnMainThread];
        [self hideGlobal];
    } else {
        UIView *hostedOverlay = _hostedOverlay;
        UIActivityIndicatorView *hostedIndicator = _hostedIndicator;
        UIView *globalOverlay = _overlay;
        UIActivityIndicatorView *globalIndicator = _indicator;
        UILabel *globalMessageView = _messageView;
        dispatch_sync(dispatch_get_main_queue(), ^{
            [hostedIndicator stopAnimating];
            [hostedOverlay removeFromSuperview];
            [globalIndicator stopAnimating];
            [globalMessageView removeFromSuperview];
            [globalOverlay removeFromSuperview];
        });
    }
}

@end
