// cordova-plugin-native-spinner
package com.greybax.spinnerdialog;

import java.util.Stack;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.json.JSONArray;
import org.json.JSONException;

import android.content.Context;
import android.app.ProgressDialog;
import android.content.DialogInterface;
import android.content.res.ColorStateList;
import android.os.Looper;
import android.widget.ProgressBar;
import android.widget.FrameLayout;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewParent;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;

public class SpinnerDialog extends CordovaPlugin {

  public Stack<ProgressDialog> spinnerDialogStack = new Stack<ProgressDialog>();
  private FrameLayout hostedSpinnerView;
  private ViewGroup hostedSpinnerHost;
  private String hostedOwnerToken;

  private static final String LEGACY_HOSTED_OWNER_TOKEN = "__legacy_hosted_spinner_owner__";

  public SpinnerDialog() {
  }

  /**
   * Presents the standard spinner inside the caller's content host for the
   * supplied owner. Hosted state is independent from the global dialog stack.
   */
  public void showInHostView(final ViewGroup hostView) {
    showHosted(hostView, LEGACY_HOSTED_OWNER_TOKEN);
  }

  /**
   * Presents a fixed, non-modal content view owned by ownerToken. There is one
   * hosted owner slot: the current owner is idempotent, while another owner is
   * ignored and can never replace it.
   */
  public boolean showHosted(final ViewGroup hostView, final String ownerToken) {
    if (hostView == null) {
      return false;
    }
    if (ownerToken == null || ownerToken.length() == 0) {
      return false;
    }
    if (Looper.myLooper() != Looper.getMainLooper()) {
      return false;
    }
    removeHostedSpinnerIfDetached();
    if (!hostView.isAttachedToWindow() || !hostView.isShown() ||
            hostView.getWidth() <= 0 || hostView.getHeight() <= 0) {
      return false;
    }
    if (hostedOwnerToken != null) {
      return hostedOwnerToken.equals(ownerToken) && hostedSpinnerView != null &&
              hostedSpinnerView.getParent() == hostView;
    }

        FrameLayout overlay = new FrameLayout(hostView.getContext());
        overlay.setBackgroundColor(Color.argb(41, 0, 0, 0));
        overlay.setClickable(true);
        overlay.setFocusable(true);
        overlay.setFocusableInTouchMode(true);
        overlay.setContentDescription("Laden");
        overlay.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE);
        overlay.setOnClickListener(new View.OnClickListener() {
          @Override
          public void onClick(View view) {
            // Consume touches without dismissing the fixed hosted spinner.
          }
        });

        ProgressBar progressBar = createProgressBar(hostView.getContext());
        FrameLayout.LayoutParams progressParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER);
        overlay.addView(progressBar, progressParams);

        try {
          hostView.addView(overlay, new ViewGroup.LayoutParams(
                  ViewGroup.LayoutParams.MATCH_PARENT,
                  ViewGroup.LayoutParams.MATCH_PARENT));
        } catch (RuntimeException ignored) {
          return false;
        }
        hostedSpinnerView = overlay;
        hostedSpinnerHost = hostView;
        hostedOwnerToken = ownerToken;
        overlay.bringToFront();
        boolean shown = overlay.getParent() == hostView;
        if (shown) {
          // showHosted is called only after the caller's defer; a new owner gets one announcement.
          overlay.announceForAccessibility("Laden");
        }
        return shown;
  }

  /** Removes only the native hosted spinner view, if one is currently attached. */
  public void hideInHostView() {
    hideHosted(LEGACY_HOSTED_OWNER_TOKEN);
  }

  /** Removes the hosted spinner only when ownerToken owns the hosted slot. */
  public void hideHosted(final String ownerToken) {
    if (ownerToken == null || ownerToken.length() == 0) {
      return;
    }
    runOnUiThread(new Runnable() {
      @Override
      public void run() {
        if (ownerToken.equals(hostedOwnerToken)) {
          removeHostedSpinnerView();
        }
      }
    });
  }

  /** Clears the hosted spinner unconditionally; intended for owner teardown. */
  public void clearHosted() {
    runOnUiThread(new Runnable() {
      @Override
      public void run() {
        removeHostedSpinnerView();
      }
    });
  }

  private void runOnUiThread(Runnable runnable) {
    if (cordova == null || cordova.getActivity() == null) {
      return;
    }
    if (Looper.myLooper() == Looper.getMainLooper()) {
      runnable.run();
    } else {
      cordova.getActivity().runOnUiThread(runnable);
    }
  }

  private void removeHostedSpinnerView() {
    if (hostedSpinnerView != null) {
      ViewParent parent = hostedSpinnerView.getParent();
      if (parent instanceof ViewGroup) {
        ((ViewGroup) parent).removeView(hostedSpinnerView);
      }
    }
    hostedSpinnerView = null;
    hostedSpinnerHost = null;
    hostedOwnerToken = null;
  }

  private void removeHostedSpinnerIfDetached() {
    if (hostedSpinnerView == null) {
      return;
    }
    ViewParent parent = hostedSpinnerView.getParent();
    if (hostedSpinnerHost == null || parent != hostedSpinnerHost ||
            hostedSpinnerHost.getParent() == null) {
      removeHostedSpinnerView();
    }
  }

  private ProgressBar createProgressBar(Context context) {
    ProgressBar progressBar = new ProgressBar(context);
    progressBar.setIndeterminate(true);
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP &&
            preferences != null) {
      String colorName = preferences.getString("SplashScreenSpinnerColor", null);
      if (colorName != null) {
        int[][] states = new int[][] {
                new int[] { android.R.attr.state_enabled},
                new int[] {-android.R.attr.state_enabled},
                new int[] {-android.R.attr.state_checked},
                new int[] { android.R.attr.state_pressed}
        };
        int progressBarColor = Color.parseColor(colorName);
        int[] colors = new int[] {
                progressBarColor,
                progressBarColor,
                progressBarColor,
                progressBarColor
        };
        progressBar.setIndeterminateTintList(new ColorStateList(states, colors));
      }
    }
    return progressBar;
  }

  @Override
  public void onReset() {
    clearHosted();
    super.onReset();
  }

  @Override
  public void onDestroy() {
    clearHosted();
    super.onDestroy();
  }

  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    /*
		 * Don't run any of these if the current activity is finishing in order
		 * to avoid android.view.WindowManager$BadTokenException crashing the
		 * app.
		 */
		if (this.cordova.getActivity().isFinishing()) {
			return true;
		}
    
    if (action.equals("show")) {

      final String title = "null".equals(args.getString(0)) ? null : args.getString(0);
      final String message = "null".equals(args.getString(1)) ? null : args.getString(1);
      final boolean isFixed = args.getBoolean(2);
                
      final CordovaInterface cordova = this.cordova;
      Runnable runnable = new Runnable() {
        public void run() {
          
          DialogInterface.OnCancelListener onCancelListener = new DialogInterface.OnCancelListener() {
            public void onCancel(DialogInterface dialog) {
              if (!isFixed) {
                while (!SpinnerDialog.this.spinnerDialogStack.empty()) {
                  SpinnerDialog.this.spinnerDialogStack.pop().dismiss();
                  callbackContext.success();
                }
              }
            }
          };
          
          ProgressDialog dialog;
          if (isFixed) {
            //If there is a progressDialog yet change the text
            if (!SpinnerDialog.this.spinnerDialogStack.empty()) {
              dialog = SpinnerDialog.this.spinnerDialogStack.peek(); 
              if (title != null) {
                dialog.setTitle(title);	
              }
              if (message!=null) {
                dialog.setMessage(message);	
              }
            }
            else{
              dialog = CallbackProgressDialog.show(cordova.getActivity(), title, message, true, false, null, callbackContext);
              SpinnerDialog.this.spinnerDialogStack.push(dialog);
            }
          } else {
            //If there is a progressDialog yet change the text
            if (!SpinnerDialog.this.spinnerDialogStack.empty()) {
              dialog = SpinnerDialog.this.spinnerDialogStack.peek(); 
              if (title != null) {
                dialog.setTitle(title);	
              }
              if (message!=null) {
                dialog.setMessage(message);	
              }	
            }
            else{
              dialog = ProgressDialog.show(cordova.getActivity(), title, message, true, true, onCancelListener);
              SpinnerDialog.this.spinnerDialogStack.push(dialog);
            }
          }
          
          if (title == null && message == null) {
            ProgressBar progressBar = createProgressBar(cordova.getActivity());

            dialog.setContentView(progressBar);
            dialog.getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
          }
        }
      };
      this.cordova.getActivity().runOnUiThread(runnable);

    } else if (action.equals("hide")) {
      Runnable runnable = new Runnable() {
        public void run() {
          if (!SpinnerDialog.this.spinnerDialogStack.empty()) {
            SpinnerDialog.this.spinnerDialogStack.pop().dismiss();
          }
        }
      };
      this.cordova.getActivity().runOnUiThread(runnable);
    }
    
    return true;
  }
}
