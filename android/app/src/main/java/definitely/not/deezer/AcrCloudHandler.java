package definitely.not.deezer;

import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;

import com.acrcloud.rec.ACRCloudClient;
import com.acrcloud.rec.ACRCloudConfig;
import com.acrcloud.rec.ACRCloudResult;
import com.acrcloud.rec.IACRCloudListener;
// import com.acrcloud.rec.utils.ACRCloudLogger; // Optional

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.lang.ref.WeakReference;

public class AcrCloudHandler extends Service implements IACRCloudListener {

    private final static String TAG = "AcrCloudHandler";

    // --- Message Commands (MainActivity -> Service) ---
    public static final int MSG_ACR_REGISTER_CLIENT = 1;
    public static final int MSG_ACR_UNREGISTER_CLIENT = 2;
    public static final int MSG_ACR_CONFIGURE = 3;
    public static final int MSG_ACR_START = 4;
    public static final int MSG_ACR_CANCEL = 5;

    // --- Message Types (Service -> MainActivity) ---
    public static final int MSG_ACR_RESULT = 101;
    public static final int MSG_ACR_VOLUME = 102;
    public static final int MSG_ACR_ERROR = 103;
    public static final int MSG_ACR_STATE = 104;

    // --- Keys for Message Bundles ---
    // MainActivity -> Service
    public static final String KEY_ACR_HOST = "KEY_ACR_HOST";
    public static final String KEY_ACR_ACCESS_KEY = "KEY_ACR_ACCESS_KEY";
    public static final String KEY_ACR_ACCESS_SECRET = "KEY_ACR_ACCESS_SECRET";
    // Service -> MainActivity
    public static final String KEY_ACR_RESULT_JSON = "KEY_ACR_RESULT_JSON";
    public static final String KEY_ACR_VOLUME = "KEY_ACR_VOLUME";
    public static final String KEY_ACR_ERROR = "KEY_ACR_ERROR";
    public static final String KEY_ACR_STATE_INITIALIZED = "KEY_ACR_STATE_INITIALIZED";
    public static final String KEY_ACR_STATE_PROCESSING = "KEY_ACR_STATE_PROCESSING";

    // --- ACRCloud ---
    private ACRCloudClient mClient = null;
    private ACRCloudConfig mConfig = null;
    private boolean initState = false; // Indicates if the ACRCloud client is configured and initialized
    private boolean mProcessing = false; // Indicates if recognition is currently active
    private String path = ""; // Path for ACRCloud temporary files
    private long startTime = 0; // To measure recognition duration

    // --- Messenger Communication ---
    private Messenger activityMessenger = null; // Messenger to send messages to MainActivity
    // Messenger for this service, receives messages from MainActivity
    final Messenger serviceMessenger = new Messenger(new IncomingHandler(this));

    /**
     * Handler for incoming messages from MainActivity.
     * Uses a WeakReference to avoid memory leaks if the service is destroyed.
     */
    static class IncomingHandler extends Handler {
        private final WeakReference<AcrCloudHandler> mServiceRef;

        IncomingHandler(AcrCloudHandler service) {
            super(Looper.getMainLooper()); // Ensure handler runs on the main thread
            mServiceRef = new WeakReference<>(service);
        }

        @Override
        public void handleMessage(Message msg) {
            AcrCloudHandler service = mServiceRef.get();
            if (service == null) {
                Log.w(TAG, "Handler received message but Service is null");
                return;
            }

            Log.d(TAG, "Service IncomingHandler received message: " + msg.what);
            Bundle data = msg.getData(); // Data attached to the message

            switch (msg.what) {
                case MSG_ACR_REGISTER_CLIENT:
                    // Register the activity's messenger to allow replying
                    service.activityMessenger = msg.replyTo;
                    Log.i(TAG, "MainActivity Messenger registered.");
                    // Send initial state upon registration
                    service.sendStateMessage();
                    break;
                case MSG_ACR_UNREGISTER_CLIENT:
                    Log.i(TAG, "MainActivity Messenger unregistered.");
                    service.activityMessenger = null;
                    break;
                case MSG_ACR_CONFIGURE:
                    if (data != null) {
                        String host = data.getString(KEY_ACR_HOST);
                        String key = data.getString(KEY_ACR_ACCESS_KEY);
                        String secret = data.getString(KEY_ACR_ACCESS_SECRET);
                        if (host != null && !host.isEmpty() && key != null && !key.isEmpty() && secret != null && !secret.isEmpty()) {
                            service.configure(host, key, secret);
                        } else {
                            Log.e(TAG, "Configuration data missing or invalid in message data.");
                            service.sendErrorMessage("Configuration data missing or invalid.");
                        }
                    } else {
                        Log.e(TAG, "Configuration message data bundle is null.");
                        service.sendErrorMessage("Configuration data missing.");
                    }
                    // Always send state after a configuration attempt
                    service.sendStateMessage();
                    break;
                case MSG_ACR_START:
                    if (!service.initState) {
                        Log.w(TAG, "Cannot start recognition: Service not initialized/configured.");
                        service.sendErrorMessage("Cannot start: Service not initialized.");
                        service.sendStateMessage();
                    } else if (service.mProcessing) {
                        Log.w(TAG, "Start command received, but already processing.");
                        service.sendStateMessage(); // Reflect the current state
                    } else {
                        service.startRecognition();
                        // State will be sent from startRecognition or its callbacks
                    }
                    break;
                case MSG_ACR_CANCEL:
                    service.cancelRecognition();
                    // State will be sent from cancelRecognition or its callbacks
                    break;
                default:
                    super.handleMessage(msg);
            }
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Service onCreate");
        // No need for LocalBroadcastManager
        // No need for createNotificationChannel (Foreground service removed)

        // Initialize ACRCloud path (unchanged logic)
        path = getExternalFilesDir(null) != null ?
                getExternalFilesDir(null).getAbsolutePath() + "/acrcloud" :
                getFilesDir().getAbsolutePath() + "/acrcloud";
        Log.d(TAG, "ACRCloud path: " + path);
        File file = new File(path);
        if (!file.exists()) {
            if (!file.mkdirs()) {
                Log.e(TAG, "Failed to create ACRCloud directory at: " + path);
                // Consider sending an error or stopping the service if the path is essential
            } else {
                Log.i(TAG, "Created ACRCloud directory at: " + path);
            }
        }
        // ACR configuration is done via MSG_ACR_CONFIGURE from the Activity
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "Service onStartCommand received (should primarily use binding now)");
        // Logic is mostly moved to the Handler/Messenger interaction
        // onStartCommand is primarily useful if using startService in addition to bindService
        // to ensure the service stays alive even if the activity unbinds.
        // If only using bindService(BIND_AUTO_CREATE), the service will stop
        // when all activities unbind.

        // Return START_NOT_STICKY to match old behavior and
        // not restart automatically if killed by the system.
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        Log.i(TAG, "Service onBind - Returning Messenger Binder");
        // Return the service's Messenger Binder so MainActivity can send messages
        return serviceMessenger.getBinder();
    }

    @Override
    public boolean onUnbind(Intent intent) {
        Log.i(TAG, "Service onUnbind");
        // Optional: Reset activityMessenger here if needed, although
        // MSG_ACR_UNREGISTER_CLIENT sent from the Activity is a better explicit approach.
        // activityMessenger = null;
        return super.onUnbind(intent); // Returns false by default (no rebind needed)
    }


    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.i(TAG, "Service onDestroy");
        cancelRecognition(); // Ensure recognition stops and resources are freed
        if (this.mClient != null) {
            this.mClient.release();
            this.mClient = null;
            this.initState = false;
            Log.i(TAG, "ACRCloudClient released.");
        }
        // No need for stopForegroundServiceInternal (Foreground service removed)
    }

    // --- ACRCloud Configuration and Control ---

    /**
     * Configures and initializes the ACRCloud client.
     * Releases any existing client before creating a new one.
     * @param host ACRCloud host address.
     * @param accessKey ACRCloud access key.
     * @param accessSecret ACRCloud access secret.
     * @return true if initialization was successful, false otherwise.
     */
    private boolean configure(String host, String accessKey, String accessSecret) {
        Log.i(TAG, "Configuring ACRCloud...");
        // Release previous client if reconfiguring
        if (mClient != null) {
            mClient.release();
            mClient = null;
            initState = false;
            mProcessing = false; // Reset processing state on reconfiguration
            Log.d(TAG, "Released previous ACRCloudClient instance.");
        }

        mConfig = new ACRCloudConfig();
        mConfig.context = getApplicationContext();
        mConfig.host = host;
        mConfig.accessKey = accessKey;
        mConfig.accessSecret = accessSecret;
        mConfig.acrcloudListener = this; // 'this' (AcrCloudHandler) implements IACRCloudListener
        mConfig.recorderConfig.rate = 8000;
        mConfig.recorderConfig.channels = 1;
        mConfig.recorderConfig.isVolumeCallback = true; // Enable volume callbacks
        // mConfig.acrCloudLogPath = path; // Optional: Specify log path
        // ACRCloudLogger.setLog(true); // Optional: Enable detailed SDK logging

        mClient = new ACRCloudClient();
        this.initState = mClient.initWithConfig(mConfig);
        if (initState) {
            Log.i(TAG, "ACRCloud configured and initialized successfully.");
        } else {
            Log.e(TAG, "ACRCloud configuration or initialization failed!");
            sendErrorMessage("ACRCloud initialization failed."); // Send error via Messenger
        }
        return initState;
    }

    /**
     * Starts the audio recognition process if the client is initialized and not already processing.
     */
    private void startRecognition() {
        Log.d(TAG, "Attempting to start recognition...");
        if (!initState) {
            Log.e(TAG, "Cannot start recognition - not initialized.");
            sendErrorMessage("Cannot start: Service not initialized.");
            sendStateMessage();
            return;
        }
        if (mProcessing) {
            Log.w(TAG, "Start recognition called, but already processing.");
            sendStateMessage(); // Send the current state
            return;
        }


        Log.i(TAG, "Starting ACRCloud Recognition...");
        if (mClient == null || !mClient.startRecognize()) {
            Log.e(TAG, "mClient.startRecognize() failed.");
            mProcessing = false; // Ensure correct state
            sendErrorMessage("ACRCloud startRecognize failed.");
            sendStateMessage();
        } else {
            mProcessing = true;
            startTime = System.currentTimeMillis();
            Log.d(TAG, "ACRCloud recognition successfully started.");
            sendStateMessage(); // Notify that processing has started
        }
    }

    /**
     * Cancels the ongoing recognition process if active.
     */
    private void cancelRecognition() {
        Log.d(TAG, "Attempting to cancel recognition...");
        if (mProcessing && mClient != null) {
            mClient.cancel();
            mProcessing = false;
            Log.i(TAG, "ACRCloud recognition cancelled.");
            // No stopForegroundServiceInternal needed
            sendStateMessage(); // Notify that processing has stopped
        } else {
            Log.w(TAG, "Cancel called but not processing or client is null.");
            // No stopForegroundServiceInternal needed
            sendStateMessage(); // Send current state just in case
        }
    }

    // --- IACRCloudListener Callbacks ---

    @Override
    public void onResult(ACRCloudResult results) {
        long duration = System.currentTimeMillis() - startTime;
        Log.i(TAG, "ACR Result Received. Time: " + duration + " ms");
        if (!mProcessing) {
            Log.w(TAG, "onResult received but mProcessing was already false. Ignoring duplicate?");
            return; // Avoid processing result if cancel was called just before
        }

        mProcessing = false;

        String resultJson = results.getResult();
        if (resultJson == null) {
            Log.e(TAG, "Received null result from ACRCloud SDK.");
            sendErrorMessage("Received null result.");
        } else {
            Log.d(TAG, "Result JSON: " + resultJson); // Log raw result if needed
            try {
                // Basic JSON validation (optional but recommended)
                new JSONObject(resultJson);
                sendResultMessage(resultJson);
            } catch (JSONException e) {
                Log.e(TAG, "Failed to parse result JSON", e);
                sendErrorMessage("Failed to parse result JSON: " + e.getMessage());
            }
        }
        sendStateMessage(); // Notify that processing has stopped
    }

    @Override
    public void onVolumeChanged(double volume) {
        // Log.v(TAG, "Volume changed: " + volume); // Very frequent log
        // Only send volume updates during active processing
        if (mProcessing) {
            sendVolumeMessage(volume);
        }
    }

    // --- Helper Methods for Sending Messages ---

    /**
     * Sends a Message object to the registered MainActivity Messenger.
     * Handles potential RemoteException if the activity is no longer available.
     * @param msg The Message to send.
     */
    private void sendMessageToActivity(Message msg) {
        if (activityMessenger == null) {
            Log.w(TAG, "Cannot send message to MainActivity - activityMessenger is null (Activity might have unbound or crashed)");
            return;
        }
        try {
            activityMessenger.send(msg);
        } catch (RemoteException e) {
            Log.e(TAG, "Failed to send message to MainActivity", e);
            // The activity might have crashed or unbound unexpectedly
        }
    }

    /** Sends the recognition result JSON string to MainActivity. */
    private void sendResultMessage(String jsonResult) {
        Bundle bundle = new Bundle();
        bundle.putString(KEY_ACR_RESULT_JSON, jsonResult);
        Message msg = Message.obtain(null, MSG_ACR_RESULT);
        msg.setData(bundle);
        sendMessageToActivity(msg);
        Log.d(TAG, "Sent result message.");
    }

    /** Sends the current volume level to MainActivity. */
    private void sendVolumeMessage(double volume) {
        Bundle bundle = new Bundle();
        bundle.putDouble(KEY_ACR_VOLUME, volume);
        Message msg = Message.obtain(null, MSG_ACR_VOLUME);
        msg.setData(bundle);
        sendMessageToActivity(msg);
        // Log.v(TAG, "Sent volume message: " + volume); // Frequent log
    }

    /** Sends an error message string to MainActivity. */
    private void sendErrorMessage(String message) {
        Bundle bundle = new Bundle();
        bundle.putString(KEY_ACR_ERROR, message);
        Message msg = Message.obtain(null, MSG_ACR_ERROR);
        msg.setData(bundle);
        sendMessageToActivity(msg);
        Log.e(TAG, "Sent error message: " + message);
    }

    /** Sends the current service state (initialized, processing) to MainActivity. */
    private void sendStateMessage() {
        Bundle bundle = new Bundle();
        bundle.putBoolean(KEY_ACR_STATE_INITIALIZED, initState);
        bundle.putBoolean(KEY_ACR_STATE_PROCESSING, mProcessing);
        Message msg = Message.obtain(null, MSG_ACR_STATE);
        msg.setData(bundle);
        sendMessageToActivity(msg);
        Log.d(TAG, "Sent state message: Initialized=" + initState + ", Processing=" + mProcessing);
    }
}