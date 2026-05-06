package dev.benchify;

import android.content.Context;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Draggable FPS overlay pill widget.
 *
 * Per D-12: Small pill in top-right corner, color-coded FPS display,
 * draggable, tap to show/hide details. Monospace font.
 *
 * Color logic:
 *   fps > 55  => green  (#4CAF50 text, #CC1B5E20 background)
 *   30-55 fps  => yellow (#FFC107 text, #CC827717 background)
 *   fps < 30  => red    (#F44336 text, #CCB71C1C background)
 */
public class FpsOverlayView extends LinearLayout {

    private static final int COLOR_GREEN_TEXT = 0xFF4CAF50;
    private static final int COLOR_GREEN_BG = 0xCC1B5E20;
    private static final int COLOR_YELLOW_TEXT = 0xFFFFC107;
    private static final int COLOR_YELLOW_BG = 0xCC827717;
    private static final int COLOR_RED_TEXT = 0xFFF44336;
    private static final int COLOR_RED_BG = 0xCCB71C1C;

    private final WindowManager windowManager;
    private final WindowManager.LayoutParams layoutParams;
    private final Handler mainHandler;

    private final TextView fpsText;
    private final LinearLayout detailPanel;
    private final TextView avgFpsText;
    private final TextView minFpsText;
    private final TextView maxFpsText;
    private final TextView jankText;

    private double currentFps = 0.0;
    private int currentJank = 0;
    private double fpsSum = 0.0;
    private double fpsMin = Double.MAX_VALUE;
    private double fpsMax = 0.0;
    private int frameCount = 0;
    private boolean detailVisible = false;

    // Touch drag state
    private float initialTouchX;
    private float initialTouchY;
    private float initialLayoutX;
    private float initialLayoutY;
    private boolean isDragging = false;
    private static final float DRAG_THRESHOLD_DP = 10f;

    public FpsOverlayView(Context context) {
        super(context);

        windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
        mainHandler = new Handler(Looper.getMainLooper());

        // Inflate layout
        LayoutInflater.from(context).inflate(R.layout.overlay_pill, this, true);

        fpsText = findViewById(R.id.fpsText);
        detailPanel = findViewById(R.id.detailPanel);
        avgFpsText = findViewById(R.id.avgFpsText);
        minFpsText = findViewById(R.id.minFpsText);
        maxFpsText = findViewById(R.id.maxFpsText);
        jankText = findViewById(R.id.jankText);

        fpsText.setTypeface(Typeface.MONOSPACE);

        // Window layout params for overlay
        layoutParams = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
        );

        // Default position: top-right corner
        layoutParams.gravity = Gravity.TOP | Gravity.START;
        int screenWidth = context.getResources().getDisplayMetrics().widthPixels;
        layoutParams.x = Math.max(screenWidth - 200, 0);
        layoutParams.y = 100;

        setOnTouchListener(new PillTouchListener());
        setOnClickListener(v -> toggleDetail());

        applyColor(COLOR_GREEN_BG, COLOR_GREEN_TEXT);
    }

    public WindowManager.LayoutParams getLayoutParams() {
        return layoutParams;
    }

    /**
     * Update FPS display. Called from JNI via main thread handler.
     * @param fps the current FPS value
     * @param jankCount total jank frames in current window
     */
    public void update(final double fps, final int jankCount) {
        mainHandler.post(() -> {
            currentFps = fps;
            currentJank = jankCount;

            // Update rolling stats
            fpsSum += fps;
            if (fps < fpsMin) fpsMin = fps;
            if (fps > fpsMax) fpsMax = fps;
            frameCount++;

            int displayFps = (int) Math.round(fps);
            fpsText.setText(displayFps + " FPS");

            // Color logic
            if (fps > 55) {
                applyColor(COLOR_GREEN_BG, COLOR_GREEN_TEXT);
            } else if (fps >= 30) {
                applyColor(COLOR_YELLOW_BG, COLOR_YELLOW_TEXT);
            } else {
                applyColor(COLOR_RED_BG, COLOR_RED_TEXT);
            }

            // Update detail panel if visible
            if (detailVisible && frameCount > 0) {
                avgFpsText.setText(String.format("Avg: %.1f", fpsSum / frameCount));
                minFpsText.setText(String.format("Min: %.1f", fpsMin));
                maxFpsText.setText(String.format("Max: %.1f", fpsMax));
                jankText.setText("Jank: " + jankCount);
            }
        });
    }

    /**
     * Toggle detail panel visibility. Auto-collapses after 3 seconds.
     */
    private void toggleDetail() {
        detailVisible = !detailVisible;
        detailPanel.setVisibility(detailVisible ? VISIBLE : GONE);

        if (detailVisible) {
            // Refresh detail text
            if (frameCount > 0) {
                avgFpsText.setText(String.format("Avg: %.1f", fpsSum / frameCount));
                minFpsText.setText(String.format("Min: %.1f", fpsMin));
                maxFpsText.setText(String.format("Max: %.1f", fpsMax));
                jankText.setText("Jank: " + currentJank);
            }

            // Auto-collapse after 3 seconds
            mainHandler.postDelayed(() -> {
                if (detailVisible) {
                    detailVisible = false;
                    detailPanel.setVisibility(GONE);
                }
            }, 3000);
        }
    }

    private void applyColor(int bgColor, int textColor) {
        setBackgroundColor(bgColor);
        fpsText.setTextColor(textColor);
    }

    /**
     * Touch listener for drag-to-move functionality.
     */
    private class PillTouchListener implements OnTouchListener {
        @Override
        public boolean onTouch(View v, MotionEvent event) {
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    initialTouchX = event.getRawX();
                    initialTouchY = event.getRawY();
                    initialLayoutX = layoutParams.x;
                    initialLayoutY = layoutParams.y;
                    isDragging = false;
                    return false; // Allow click event to fire

                case MotionEvent.ACTION_MOVE:
                    float dx = event.getRawX() - initialTouchX;
                    float dy = event.getRawY() - initialTouchY;

                    // Require minimum drag distance to start moving
                    if (!isDragging && (Math.abs(dx) > dpToPx(DRAG_THRESHOLD_DP)
                            || Math.abs(dy) > dpToPx(DRAG_THRESHOLD_DP))) {
                        isDragging = true;
                    }

                    if (isDragging) {
                        layoutParams.x = (int) (initialLayoutX + dx);
                        layoutParams.y = (int) (initialLayoutY + dy);
                        windowManager.updateViewLayout(FpsOverlayView.this, layoutParams);
                        return true;
                    }
                    return false;

                case MotionEvent.ACTION_UP:
                    if (isDragging) {
                        return true; // Consume event — was a drag, not a click
                    }
                    return false; // Was a click — let OnClickListener handle

                default:
                    return false;
            }
        }
    }

    private float dpToPx(float dp) {
        return dp * getContext().getResources().getDisplayMetrics().density;
    }

    /**
     * Reset rolling statistics (e.g., when detail panel is shown fresh).
     */
    public void resetStats() {
        fpsSum = 0.0;
        fpsMin = Double.MAX_VALUE;
        fpsMax = 0.0;
        frameCount = 0;
    }
}
