package dev.benchify;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

/**
 * BroadcastReceiver for ADB automation commands.
 *
 * Per D-22: Full command set via ADB broadcast:
 *   START_SESSION, STOP_SESSION, PAUSE, RESUME, MARKER, SCREENSHOT, EXPORT
 *
 * Per D-23: Command via {@code com.benchify.COMMAND} intent action.
 * Payload passed as {@code payload} String extra (JSON).
 * SDK responds via {@code com.benchify.RESPONSE} broadcast with JSON status.
 *
 * Registered in AndroidManifest.xml by manifest_patcher.py during APK injection.
 * The intent filter matches {@code com.benchify.COMMAND}.
 *
 * Threat mitigations:
 * - T-04-18 (Spoofing): Broadcast intents are device-local by design for CI/CD.
 *   No authentication on broadcasts — accepted per threat model.
 * - T-04-22 (Info Disclosure): Response broadcast contains only session metadata
 *   (marker IDs, file paths, sample counts). No sensitive user data.
 */
public class BenchifyBroadcastReceiver extends BroadcastReceiver {

    private static final String TAG = "BenchifyReceiver";
    private static final String ACTION_COMMAND = "com.benchify.COMMAND";
    private static final String RESPONSE_BROADCAST = "com.benchify.RESPONSE";

    /**
     * JNI native handler: dispatches to Rust automation module.
     *
     * @param action       The command action string (e.g., "START_SESSION")
     * @param payloadJson  JSON payload string (e.g., {@code {"session_id":"abc"}})
     * @return JSON response string with status
     */
    public static native String nativeHandleCommand(String action, String payloadJson);

    @Override
    public void onReceive(Context context, Intent intent) {
        String intentAction = intent.getAction();
        if (!ACTION_COMMAND.equals(intentAction)) {
            Log.w(TAG, "Ignoring unexpected action: " + intentAction);
            return;
        }

        Bundle extras = intent.getExtras();
        if (extras == null) {
            Log.w(TAG, "No extras in broadcast intent");
            sendErrorResponse(context, "No extras in command broadcast");
            return;
        }

        String action = extras.getString("action", "");
        if (action.isEmpty()) {
            Log.w(TAG, "No 'action' extra in broadcast");
            sendErrorResponse(context, "Missing 'action' extra");
            return;
        }

        String payload = extras.getString("payload", "{}");
        Log.d(TAG, "Received command: action=" + action + " payload=" + payload);

        try {
            // Delegate to Rust native handler
            String responseJson = nativeHandleCommand(action, payload);
            Log.d(TAG, "Native response: " + responseJson);

            // Send response broadcast back
            Intent responseIntent = new Intent(RESPONSE_BROADCAST);
            responseIntent.putExtra("status", responseJson);
            context.sendBroadcast(responseIntent);

        } catch (Exception e) {
            Log.e(TAG, "Error handling command: " + e.getMessage(), e);
            sendErrorResponse(context, "Internal error: " + e.getMessage());
        }
    }

    /**
     * Send an error response broadcast when command handling fails.
     */
    private void sendErrorResponse(Context context, String detail) {
        try {
            String errorJson = String.format(
                "{\"status\":\"error\",\"detail\":\"%s\"}",
                detail.replace("\"", "\\\"")
            );
            Intent responseIntent = new Intent(RESPONSE_BROADCAST);
            responseIntent.putExtra("status", errorJson);
            context.sendBroadcast(responseIntent);
        } catch (Exception e) {
            Log.e(TAG, "Failed to send error response: " + e.getMessage());
        }
    }
}
