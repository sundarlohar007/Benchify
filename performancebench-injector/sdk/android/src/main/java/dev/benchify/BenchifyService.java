package dev.benchify;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.IBinder;
import android.view.WindowManager;

/**
 * Android foreground service that manages the FPS overlay window lifecycle.
 *
 * Per D-13: Always-on from app start. SDK loads at Application.onCreate(),
 * begins streaming metrics. This service keeps the overlay alive.
 *
 * Threat mitigations (T-04-10):
 * - Foreground service type is "specialUse" — documented for profiling tools.
 * - Notification clearly labels "PerformanceBench profiling active".
 * - User can stop via Android notification shade.
 *
 * Broadcast receiver for automation commands (intent filter com.benchify.COMMAND).
 * Receiver skeleton registered here — full implementation in Plan 04-04.
 */
public class BenchifyService extends Service {

    private static final String CHANNEL_ID = "performancebench_profiling";
    private static final int NOTIFICATION_ID = 4242;
    private static final String ACTION_COMMAND = "com.benchify.COMMAND";

    private FpsOverlayView overlayView;
    private BroadcastReceiver commandReceiver;

    // Static reference for SdkLoader to start the service
    private static FpsOverlayView staticOverlay;

    /**
     * Start the BenchifyService foreground service with the given overlay view.
     * Called from SdkLoader.init().
     */
    public static void start(Context context, FpsOverlayView overlay) {
        staticOverlay = overlay;
        Intent intent = new Intent(context, BenchifyService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent);
        } else {
            context.startService(intent);
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();

        // Register broadcast receiver for automation commands (skeleton for Plan 04-04)
        commandReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                if (ACTION_COMMAND.equals(action)) {
                    // Skeleton: log received command
                    // Full dispatching implemented in Plan 04-04 (ADB broadcast automation)
                    android.util.Log.d("Benchify", "Received automation command");
                }
            }
        };
        IntentFilter filter = new IntentFilter(ACTION_COMMAND);
        registerReceiver(commandReceiver, filter);
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // Create and attach the FPS overlay to the window
        if (staticOverlay != null) {
            overlayView = staticOverlay;
            try {
                WindowManager wm = (WindowManager) getSystemService(WINDOW_SERVICE);
                wm.addView(overlayView, overlayView.getLayoutParams());
            } catch (WindowManager.BadTokenException | SecurityException e) {
                android.util.Log.e("Benchify", "Failed to add overlay: " + e.getMessage());
            }
        }

        // Start native metric streaming
        SdkLoader.nativeStart();

        // Show persistent notification
        startForeground(NOTIFICATION_ID, buildNotification());

        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        // Stop native SDK
        SdkLoader.nativeStop();

        // Remove overlay from window
        if (overlayView != null) {
            try {
                WindowManager wm = (WindowManager) getSystemService(WINDOW_SERVICE);
                wm.removeView(overlayView);
            } catch (Exception e) {
                android.util.Log.e("Benchify", "Failed to remove overlay: " + e.getMessage());
            }
            overlayView = null;
        }

        // Unregister broadcast receiver
        if (commandReceiver != null) {
            try {
                unregisterReceiver(commandReceiver);
            } catch (Exception e) {
                // Already unregistered
            }
        }

        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null; // Not a bound service
    }

    // --- Notification ---

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "PerformanceBench Profiling",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Shown while PerformanceBench is actively profiling this app.");
            channel.setShowBadge(false);

            NotificationManager nm = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
            nm.createNotificationChannel(channel);
        }
    }

    private Notification buildNotification() {
        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            builder = new Notification.Builder(this, CHANNEL_ID);
        } else {
            builder = new Notification.Builder(this);
        }

        return builder
                .setContentTitle("PerformanceBench Profiling")
                .setContentText("PerformanceBench profiling active")
                .setSmallIcon(android.R.drawable.ic_menu_info_details)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_LOW)
                .build();
    }
}
