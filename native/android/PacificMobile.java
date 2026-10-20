package dev.pacificrush.platform;

import android.app.Activity;
import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Handler;
import android.os.Looper;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/** OS callbacks publish small values; Godot consumes them on its own thread. */
public final class PacificMobile extends GodotPlugin {
    private final Handler main = new Handler(Looper.getMainLooper());
    private volatile int focusState = 0;
    private boolean active;
    private boolean requested;
    private AudioManager audio;
    private AudioFocusRequest request;

    public PacificMobile(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PacificMobile"; }
    private static native boolean initializeIrohNative(Context context);
    @UsedByGodot public boolean initializeIroh() {
        Activity activity = getActivity();
        if (activity == null) return false;
        try {
            System.loadLibrary("pacific_iroh.android.arm64");
            return initializeIrohNative(activity.getApplicationContext());
        } catch (LinkageError | RuntimeException ignored) { return false; }
    }

    private void requestFocus() {
        Activity activity = getActivity();
        if (!active || activity == null) return;
        try {
            if (audio == null) audio = (AudioManager) activity.getSystemService(Context.AUDIO_SERVICE);
            if (audio == null) { focusState = 0; return; }
            if (request == null) {
                request = new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(new AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build())
                    .setAcceptsDelayedFocusGain(true)
                    .setWillPauseWhenDucked(true)
                    .setOnAudioFocusChangeListener(change -> { if (active) focusState = change; }, main)
                    .build();
            }
            int outcome = audio.requestAudioFocus(request);
            requested = outcome != AudioManager.AUDIOFOCUS_REQUEST_FAILED;
            focusState = outcome == AudioManager.AUDIOFOCUS_REQUEST_GRANTED ? AudioManager.AUDIOFOCUS_GAIN
                : outcome == AudioManager.AUDIOFOCUS_REQUEST_DELAYED ? 100 : 0;
        } catch (RuntimeException ignored) { focusState = 0; }
    }

    private void setActiveOnMain(boolean value) {
        if (active == value) return;
        active = value;
        if (value) requestFocus();
        else {
            focusState = 0;
            if (audio != null && request != null && requested) {
                try { audio.abandonAudioFocusRequest(request); } catch (RuntimeException ignored) { }
            }
            requested = false;
        }
    }

    @UsedByGodot public void setActive(boolean value) { main.post(() -> setActiveOnMain(value)); }
    @UsedByGodot public void retryAudioFocus() { main.post(this::requestFocus); }
    @UsedByGodot public int getFocusState() { return focusState; }
    @Override public void onMainResume() { setActiveOnMain(true); }
    @Override public void onMainPause() { setActiveOnMain(false); }
    @Override public void onMainDestroy() { setActiveOnMain(false); main.removeCallbacksAndMessages(null); }

    private ConnectivityManager connectivity() {
        Activity activity = getActivity();
        return activity == null ? null : (ConnectivityManager) activity.getSystemService(Context.CONNECTIVITY_SERVICE);
    }
    @UsedByGodot public long getRouteHandle() {
        try {
            ConnectivityManager manager = connectivity();
            Network network = manager == null ? null : manager.getActiveNetwork();
            return network == null ? 0 : network.getNetworkHandle();
        } catch (RuntimeException ignored) { return 0; }
    }
    @UsedByGodot public String getRouteKind() {
        try {
            ConnectivityManager manager = connectivity();
            Network network = manager == null ? null : manager.getActiveNetwork();
            if (network == null) return "none";
            NetworkCapabilities capabilities = manager.getNetworkCapabilities(network);
            if (capabilities == null) return "unknown";
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) return "cellular";
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return "wifi";
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) return "ethernet";
            return "other";
        } catch (RuntimeException ignored) { return "unknown"; }
    }
}
