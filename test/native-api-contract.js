const assert = require('assert');
const fs = require('fs');
const path = require('path');

const pluginRoot = path.resolve(__dirname, '..');
const iosHeader = fs.readFileSync(path.join(pluginRoot, 'src/ios/CDVSpinnerDialog.h'), 'utf8');
const iosSource = fs.readFileSync(path.join(pluginRoot, 'src/ios/CDVSpinnerDialog.m'), 'utf8');
const androidSource = fs.readFileSync(path.join(pluginRoot, 'src/android/SpinnerDialog.java'), 'utf8');

assert.match(iosHeader, /\(BOOL\)showHosted:\(UIView \*\)host ownerToken:\(NSString \*\)ownerToken/);
assert.match(iosHeader, /hideHosted:\(NSString \*\)ownerToken/);
assert.match(iosHeader, /clearHosted/);
assert.match(iosSource, /hostedOwnerToken/);
assert.match(iosSource, /if \(\[self\.hostedOwnerToken isEqualToString:ownerToken\]\)/);
assert.match(iosSource, /\[self hideGlobal\];/);
assert.match(iosSource, /\[self clearHostedOnMainThread\];/);
assert.match(iosSource, /dispatch_get_main_queue\(\)/);
assert.match(iosSource, /isEligibleHostedHost/);
assert.match(iosSource, /while \(candidate != nil\)[\s\S]*candidate\.hidden/);
assert.match(iosSource, /colorWithWhite:0\.0f alpha:0\.16f/);
assert.match(iosSource, /hostedIndicator\.centerXAnchor[\s\S]*hostedIndicator\.centerYAnchor/);
assert.match(iosSource, /hostedOverlay\.leadingAnchor[\s\S]*hostedOverlay\.bottomAnchor/);
assert.doesNotMatch(iosSource, /hostedOverlay\.backgroundColor = \[UIColor clearColor\]/);

assert.match(androidSource, /boolean showHosted\(final ViewGroup hostView, final String ownerToken\)/);
assert.match(androidSource, /hideHosted\(final String ownerToken\)/);
assert.match(androidSource, /public void clearHosted\(\)/);
assert.match(androidSource, /hostedOwnerToken/);
assert.match(androidSource, /hostedOwnerToken\.equals\(ownerToken\)/);
assert.match(androidSource, /if \(ownerToken\.equals\(hostedOwnerToken\)\)/);
assert.match(androidSource, /clearHosted\(\);/);
assert.match(androidSource, /runOnUiThread/);
assert.match(androidSource, /hostView\.isAttachedToWindow\(\)[\s\S]*hostView\.getWidth\(\) <= 0/);
assert.match(androidSource, /Color\.argb\(41, 0, 0, 0\)/);
assert.match(androidSource, /Gravity\.CENTER/);
assert.doesNotMatch(androidSource, /overlay\.setBackgroundColor\(Color\.TRANSPARENT\)/);
assert.match(androidSource, /overlay\.setContentDescription\("Laden"\)/);
assert.match(androidSource, /setAccessibilityLiveRegion\(View\.ACCESSIBILITY_LIVE_REGION_POLITE\)/);
assert.match(androidSource, /if \(shown\)[\s\S]*announceForAccessibility\("Laden"\)/);
assert.match(iosSource, /hostedAccessibilityAnnounced/);
assert.match(iosSource, /if \(!self\.hostedAccessibilityAnnounced\)[\s\S]*UIAccessibilityAnnouncementNotification/);

// Hosted ownership remains independent from the legacy global dialog state.
assert.match(iosSource, /Global spinner state is deliberately separate from hosted state/);
assert.match(androidSource, /hostedSpinnerView/);
assert.match(androidSource, /spinnerDialogStack/);

console.log('native hosted API contract passed');
