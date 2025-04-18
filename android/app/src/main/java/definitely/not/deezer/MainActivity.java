package definitely.not.deezer;

import android.content.ComponentName;
import android.content.ContentValues;
import android.content.Context; // Ajouté pour BIND_AUTO_CREATE
import android.content.Intent;
import android.content.ServiceConnection;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
// import android.net.Uri; // Pas directement utilisé pour ACR
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Message;
import android.os.Messenger;
import android.os.Parcelable;
import android.os.RemoteException;
// import android.provider.Settings; // Pas utilisé ici
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.ryanheise.audioservice.AudioServiceActivity;

import java.lang.ref.WeakReference;
// import java.security.KeyManagementException; // Relatif à SSL, pas ACR
// import java.security.NoSuchAlgorithmException; // Relatif à SSL, pas ACR
// import java.security.cert.X509Certificate; // Relatif à SSL, pas ACR
import java.util.ArrayList;
import java.util.HashMap;

// import javax.net.ssl.HttpsURLConnection; // Relatif à SSL, pas ACR
// import javax.net.ssl.SSLContext; // Relatif à SSL, pas ACR
// import javax.net.ssl.TrustManager; // Relatif à SSL, pas ACR
// import javax.net.ssl.X509TrustManager; // Relatif à SSL, pas ACR

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends AudioServiceActivity {
    private static final String NATIVE_CHANNEL = "definitely.not.deezer/native"; // Renommé pour clarté
    private static final String EVENT_CHANNEL = "definitely.not.deezer/events"; // Renommé pour inclure tous les events
    private static final String TAG = "MainActivity"; // Ajout d'un TAG pour les logs
    EventChannel.EventSink eventSink;

    // --- Download Service ---
    boolean downloadServiceBound = false; // Renommé
    Messenger downloadServiceMessenger; // Renommé
    Messenger activityMessengerForDownload; // Renommé

    // --- ACRCloud Service ---
    boolean acrServiceBound = false;
    Messenger acrServiceMessenger; // Messenger pour envoyer à AcrCloudHandler
    Messenger activityMessengerForAcr; // Messenger pour recevoir de AcrCloudHandler

    SQLiteDatabase db;
    StreamServer streamServer; // Si toujours utilisé

    String intentPreload;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        Log.d(TAG, "onCreate");
        Intent intent = getIntent();
        intentPreload = intent.getStringExtra("preload");
        super.onCreate(savedInstanceState);
        // Initialiser le messenger pour ACR ici (ou dans onStart)
        // Le Handler a besoin du Looper principal, qui est disponible ici.
        activityMessengerForAcr = new Messenger(new IncomingHandler(this));
        // Initialiser aussi celui pour le Download Service
        activityMessengerForDownload = new Messenger(new IncomingHandler(this)); // Utilise le même Handler
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        Log.d(TAG, "configureFlutterEngine");
        // Méthodes pour DownloadService (inchangées, juste adapter les noms de variables si nécessaire)
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), NATIVE_CHANNEL).setMethodCallHandler(((call, result) -> {
            Log.d(TAG, "MethodChannel received: " + call.method);
            // --- Download Service Methods ---
            if (call.method.equals("addDownloads")) {
                ArrayList<HashMap<String, Object>> downloads = call.arguments();
                if (downloads != null) {
                    db.beginTransaction();
                    try {
                        for (int i = 0; i < downloads.size(); i++) {
                            Cursor cursor = db.rawQuery("SELECT id, state, quality FROM Downloads WHERE trackId == ? AND path == ?",
                                    new String[]{(String) downloads.get(i).get("trackId"), (String) downloads.get(i).get("path")});
                            if (cursor.getCount() > 0) {
                                cursor.moveToNext();
                                if (cursor.getInt(1) >= 3) { // DONE, ERROR, DEEZER_ERROR
                                    ContentValues values = new ContentValues();
                                    values.put("state", 0); // Reset to NONE
                                    values.put("quality", cursor.getInt(2));
                                    db.update("Downloads", values, "id == ?", new String[]{Integer.toString(cursor.getInt(0))});
                                    Log.d(TAG, "Download exists, resetting state to NONE: " + downloads.get(i).get("trackId"));
                                } else {
                                    Log.d(TAG, "Download already in progress or queued: " + downloads.get(i).get("trackId"));
                                }
                                cursor.close();
                                continue; // Skip insertion
                            }
                            cursor.close();
                            ContentValues row = Download.flutterToSQL(downloads.get(i));
                            db.insert("Downloads", null, row);
                            Log.d(TAG, "Inserting new download: " + downloads.get(i).get("trackId"));
                        }
                        db.setTransactionSuccessful();
                    } finally {
                        db.endTransaction();
                    }
                    sendMessageToDownloadService(DownloadService.SERVICE_LOAD_DOWNLOADS, null);
                    result.success(null);
                } else {
                    result.error("INVALID_ARGS", "Downloads list is null", null);
                }
                return;
            }
            if (call.method.equals("getDownloads")) {
                ArrayList<HashMap<?, ?>> downloadsList = new ArrayList<>();
                db.beginTransaction();
                try (Cursor cursor = db.query("Downloads", null, null, null, null, null, null)) {
                    while (cursor.moveToNext()) {
                        Download download = Download.fromSQL(cursor);
                        downloadsList.add(download.toHashMap());
                    }
                    db.setTransactionSuccessful();
                } finally {
                    db.endTransaction();
                }
                result.success(downloadsList);
                return;
            }
            if (call.method.equals("updateSettings")) {
                 Bundle bundle = new Bundle();
                 bundle.putString("json", call.argument("json").toString());
                 sendMessageToDownloadService(DownloadService.SERVICE_SETTINGS_UPDATE, bundle);
                 result.success(null);
                 return;
            }
            if (call.method.equals("loadDownloads")) {
                sendMessageToDownloadService(DownloadService.SERVICE_LOAD_DOWNLOADS, null);
                result.success(null);
                return;
            }
             if (call.method.equals("start")) {
                 sendMessageToDownloadService(DownloadService.SERVICE_START_DOWNLOAD, null);
                 result.success(downloadServiceBound); // Indicate if binding seems ok
                 return;
             }
             if (call.method.equals("stop")) {
                 sendMessageToDownloadService(DownloadService.SERVICE_STOP_DOWNLOADS, null);
                 result.success(null);
                 return;
             }
             if (call.method.equals("removeDownload")) {
                 Bundle bundle = new Bundle();
                 bundle.putInt("id", (int)call.argument("id"));
                 sendMessageToDownloadService(DownloadService.SERVICE_REMOVE_DOWNLOAD, bundle);
                 result.success(null);
                 return;
             }
             if (call.method.equals("retryDownloads")) {
                 sendMessageToDownloadService(DownloadService.SERVICE_RETRY_DOWNLOADS, null);
                 result.success(null);
                 return;
             }
             if (call.method.equals("removeDownloads")) {
                 Bundle bundle = new Bundle();
                 bundle.putInt("state", (int)call.argument("state"));
                 sendMessageToDownloadService(DownloadService.SERVICE_REMOVE_DOWNLOADS, bundle);
                 result.success(null);
                 return;
             }
             // --- Common/Other Methods ---
             if (call.method.equals("getPreloadInfo")) {
                result.success(intentPreload);
                intentPreload = null;
                return;
             }
             if (call.method.equals("arch")) {
                result.success(System.getProperty("os.arch"));
                return;
             }
            // --- Stream Server Methods --- (si applicable)
            if (call.method.equals("startServer")) {
                 if (streamServer == null) {
                    String offlinePath = getExternalFilesDir("offline").getAbsolutePath();
                    streamServer = new StreamServer(call.argument("arl"), offlinePath);
                    streamServer.start();
                 }
                 result.success(null);
                 return;
             }
            if (call.method.equals("getStreamInfo")) {
                 if (streamServer == null) {
                    result.success(null);
                    return;
                 }
                 StreamServer.StreamInfo info = streamServer.streams.get(call.argument("id").toString());
                 if (info != null)
                    result.success(info.toJSON());
                 else
                    result.success(null);
                 return;
            }
             if (call.method.equals("kill")) {
                 Log.d(TAG, "Kill command received");
                 // Stop Download Service
                 Intent dlIntent = new Intent(this, DownloadService.class);
                 stopService(dlIntent);
                 // Stop ACR Service (optionnel, unbind suffit s'il n'est pas démarré avec startService)
                 Intent acrIntent = new Intent(this, AcrCloudHandler.class);
                 stopService(acrIntent);
                 // Stop Stream Server
                 if (streamServer != null) {
                     streamServer.stop();
                     streamServer = null;
                 }
                 // Force close ? Usually not recommended. Let onDestroy handle unbinding.
                 // System.exit(0);
                 result.success(null);
                 return;
             }

            // --- ACRCloud Service Methods ---
            if (call.method.equals("acrConfigure")) {
                 String host = call.argument("host");
                 String key = call.argument("accessKey");
                 String secret = call.argument("accessSecret");
                 if (host != null && key != null && secret != null) {
                    Bundle bundle = new Bundle();
                    bundle.putString(AcrCloudHandler.KEY_ACR_HOST, host);
                    bundle.putString(AcrCloudHandler.KEY_ACR_ACCESS_KEY, key);
                    bundle.putString(AcrCloudHandler.KEY_ACR_ACCESS_SECRET, secret);
                    sendMessageToAcrService(AcrCloudHandler.MSG_ACR_CONFIGURE, bundle);
                    result.success(true); // Indicate command sent
                 } else {
                    result.error("INVALID_ARGS", "Missing ACR configuration arguments", null);
                 }
                 return;
            }
            if (call.method.equals("acrStart")) {
                sendMessageToAcrService(AcrCloudHandler.MSG_ACR_START, null);
                result.success(acrServiceBound); // Indicate if binding seems ok
                return;
            }
            if (call.method.equals("acrCancel")) {
                sendMessageToAcrService(AcrCloudHandler.MSG_ACR_CANCEL, null);
                result.success(null);
                return;
            }

            // Méthode non reconnue
            Log.w(TAG, "Unknown method called: " + call.method);
            result.notImplemented();
        }));

        // Event channel (pour les màj de téléchargement ET les events ACR)
        EventChannel eventChannel = new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler((new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                Log.i(TAG, "Event Sink Listening");
                eventSink = events;
                // Request current state from services when Flutter starts listening
                // sendMessageToDownloadService(DownloadService.SERVICE_GET_CURRENT_STATE, null); // If implemented
                 sendMessageToAcrService(AcrCloudHandler.MSG_ACR_STATE, null); // Request ACR state
            }

            @Override
            public void onCancel(Object arguments) {
                Log.i(TAG, "Event Sink Cancelled");
                eventSink = null;
            }
        }));
    }

    // Connexion au DownloadService
    private void connectDownloadService() {
        if (downloadServiceBound) {
             Log.d(TAG, "Already bound to DownloadService.");
             return;
        }
        // Le Messenger est déjà créé dans onCreate
        Intent intent = new Intent(this, DownloadService.class);
        intent.putExtra("activityMessenger", activityMessengerForDownload); // Passer le messenger de l'activité
        // Utiliser startService pour que le service survive même si l'activité est détruite
        startService(intent);
        // Binder pour la communication directe
        bindService(intent, downloadConnection, Context.BIND_AUTO_CREATE);
        Log.i(TAG, "Attempting to bind DownloadService...");
    }

    // Connexion au AcrCloudHandler
    private void connectAcrService() {
        if (acrServiceBound) {
             Log.d(TAG, "Already bound to AcrCloudHandler.");
             return;
        }
        // Le Messenger est déjà créé dans onCreate
        Intent intent = new Intent(this, AcrCloudHandler.class);
        // On n'utilise PAS startService ici, car on veut que le service s'arrête
        // si l'activité se déconnecte (BIND_AUTO_CREATE s'en charge).
        // Si on utilisait startService, il faudrait explicitement appeler stopService.
        // intent.putExtra("activityMessenger", activityMessengerForAcr); // Le messenger est envoyé via msg.replyTo après connexion
        bindService(intent, acrConnection, Context.BIND_AUTO_CREATE);
        Log.i(TAG, "Attempting to bind AcrCloudHandler...");
    }


    @Override
    protected void onStart() {
        Log.d(TAG, "onStart");
        super.onStart();
        // Get DB (and leave open!)
        try {
            DownloadsDatabase dbHelper = new DownloadsDatabase(getApplicationContext());
            // S'assurer que la base de données n'est ouverte qu'une seule fois
            if (db == null || !db.isOpen()) {
                 db = dbHelper.getWritableDatabase();
                 Log.i(TAG, "Database opened.");
            } else {
                 Log.w(TAG, "Database already open.");
            }
        } catch (Exception e) {
             Log.e(TAG, "Error opening database", e);
             // Handle error appropriately - maybe show a message to the user
             return; // Stop further execution if DB fails
        }

        // Connect to services
        connectDownloadService(); // Se connecter au service de téléchargement
        connectAcrService();      // Se connecter au service ACR

        // Trust all SSL Certs (si nécessaire pour Deezer API ou autre)
        // ... (le code SSL peut rester ici s'il est utilisé ailleurs)
    }

    @Override
    protected void onResume() {
        Log.d(TAG, "onResume");
        super.onResume();
        // Re-binding might happen automatically if needed, or can be forced here
        // if (downloadServiceMessenger == null) connectDownloadService();
        // if (acrServiceMessenger == null) connectAcrService();
    }

    @Override
    protected void onPause() {
        Log.d(TAG, "onPause");
        super.onPause();
    }


    @Override
    protected void onStop() {
        Log.d(TAG, "onStop");
        super.onStop();
        // Ne pas fermer la DB ou unbind ici, car l'activité peut revenir (onStart)
        // La fermeture/unbind se fait dans onDestroy
    }

    @Override
    protected void onDestroy() {
        Log.i(TAG, "onDestroy");
        super.onDestroy();
        // Arrêter le serveur de stream
        if (streamServer != null) {
            Log.i(TAG, "Stopping StreamServer");
            streamServer.stop();
            streamServer = null;
        }
        // Se déconnecter des services
        if (downloadServiceBound) {
            Log.i(TAG, "Unbinding DownloadService");
            try {
                // Informer le service que le client part (optionnel mais propre)
                // sendMessageToDownloadService(DownloadService.SERVICE_UNREGISTER_CLIENT, null);
                unbindService(downloadConnection);
            } catch (IllegalArgumentException e) {
                 Log.w(TAG, "Error unbinding DownloadService (already unbound?): " + e.getMessage());
            }
            downloadServiceBound = false;
            downloadServiceMessenger = null;
        }
        if (acrServiceBound) {
            Log.i(TAG, "Unbinding AcrCloudHandler");
             try {
                // Informer le service ACR que le client part
                sendMessageToAcrService(AcrCloudHandler.MSG_ACR_UNREGISTER_CLIENT, null);
                unbindService(acrConnection);
             } catch (IllegalArgumentException e) {
                 Log.w(TAG, "Error unbinding AcrCloudHandler (already unbound?): " + e.getMessage());
             }
            acrServiceBound = false;
            acrServiceMessenger = null;
        }
        // Fermer la base de données
        if (db != null && db.isOpen()) {
             Log.i(TAG, "Closing Database");
             db.close();
             db = null; // Important to nullify after closing
        }
    }

    // --- Service Connections ---

    // Connexion pour DownloadService
    private final ServiceConnection downloadConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            Log.i(TAG, "DownloadService Bound!");
            downloadServiceMessenger = new Messenger(iBinder);
            downloadServiceBound = true;
             // Si DownloadService implémente un système d'enregistrement client similaire à ACR:
             // Message msg = Message.obtain(null, DownloadService.SERVICE_REGISTER_CLIENT);
             // msg.replyTo = activityMessengerForDownload;
             // sendMessageToDownloadService(msg); // Utilise une fonction dédiée pour envoyer le message complet
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            Log.w(TAG, "DownloadService Disconnected unexpectedly!");
            downloadServiceMessenger = null;
            downloadServiceBound = false;
            // Optionnel: Tenter de reconnecter ?
            // connectDownloadService();
        }
    };

    // Connexion pour AcrCloudHandler
    private final ServiceConnection acrConnection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName componentName, IBinder iBinder) {
            Log.i(TAG, "AcrCloudHandler Bound!");
            acrServiceMessenger = new Messenger(iBinder);
            acrServiceBound = true;
            // Enregistrer ce client auprès du service ACR pour qu'il sache à qui répondre
            Message msg = Message.obtain(null, AcrCloudHandler.MSG_ACR_REGISTER_CLIENT);
            msg.replyTo = activityMessengerForAcr; // Le messenger que le service utilisera pour répondre
            sendMessageToAcrService(msg); // Utiliser une fonction dédiée pour envoyer le message complet
        }

        @Override
        public void onServiceDisconnected(ComponentName componentName) {
            Log.w(TAG, "AcrCloudHandler Disconnected unexpectedly!");
            acrServiceMessenger = null;
            acrServiceBound = false;
             // Optionnel: Tenter de reconnecter ?
             // connectAcrService();
        }
    };

    // --- Incoming Message Handler (from Services) ---
    private static class IncomingHandler extends Handler {
        private final WeakReference<MainActivity> weakReference;

        IncomingHandler(MainActivity activity) {
            super(Looper.getMainLooper()); // Assure l'exécution sur le thread UI
            this.weakReference = new WeakReference<>(activity);
        }

        @Override
        public void handleMessage(@NonNull Message msg) {
            MainActivity activity = weakReference.get();
            if (activity == null) {
                Log.w(TAG, "IncomingHandler: Activity is null, ignoring message: " + msg.what);
                return;
            }
            if (activity.eventSink == null) {
                 // Peut arriver si un message arrive avant que Flutter ne soit prêt à écouter
                 Log.w(TAG, "IncomingHandler: EventSink is null, cannot forward message: " + msg.what);
                 return;
            }

            EventChannel.EventSink eventSink = activity.eventSink;
            Bundle data = msg.getData(); // Obtenir les données une seule fois
            HashMap<String, Object> eventData = new HashMap<>(); // Données à envoyer à Flutter

            Log.d(TAG, "IncomingHandler received message: " + msg.what);

            try { // Encapsuler pour attraper les erreurs potentielles de traitement/envoi
                switch (msg.what) {
                    // --- Messages de DownloadService ---
                    case DownloadService.SERVICE_ON_PROGRESS:
                        eventData.put("eventType", "downloadProgress"); // Identifier le type d'événement
                        ArrayList<Bundle> downloads = getParcelableArrayList(data, "downloads", Bundle.class);
                        if (downloads != null && !downloads.isEmpty()) {
                            ArrayList<HashMap<String, Number>> progressData = new ArrayList<>();
                            for (Bundle bundle : downloads) {
                                HashMap<String, Number> item = new HashMap<>();
                                item.put("id", bundle.getInt("id"));
                                item.put("state", bundle.getInt("state"));
                                item.put("received", bundle.getLong("received"));
                                item.put("filesize", bundle.getLong("filesize"));
                                item.put("quality", bundle.getInt("quality"));
                                progressData.add(item);
                            }
                            eventData.put("data", progressData);
                            eventSink.success(eventData);
                        } else {
                             Log.w(TAG, "Received download progress but no data bundles found.");
                        }
                        break;
                    case DownloadService.SERVICE_ON_STATE_CHANGE:
                         eventData.put("eventType", "downloadState");
                         HashMap<String, Object> stateData = new HashMap<>();
                         stateData.put("running", data.getBoolean("running"));
                         stateData.put("queueSize", data.getInt("queueSize"));
                         eventData.put("data", stateData);
                         eventSink.success(eventData);
                        break;

                    // --- Messages de AcrCloudHandler ---
                    case AcrCloudHandler.MSG_ACR_RESULT:
                        eventData.put("eventType", "acrResult");
                        eventData.put("resultJson", data.getString(AcrCloudHandler.KEY_ACR_RESULT_JSON));
                        eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_VOLUME:
                         eventData.put("eventType", "acrVolume");
                         eventData.put("volume", data.getDouble(AcrCloudHandler.KEY_ACR_VOLUME));
                         eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_ERROR:
                        eventData.put("eventType", "acrError");
                        eventData.put("error", data.getString(AcrCloudHandler.KEY_ACR_ERROR));
                        eventSink.success(eventData);
                        break;
                    case AcrCloudHandler.MSG_ACR_STATE:
                        eventData.put("eventType", "acrState");
                         HashMap<String, Object> acrStateData = new HashMap<>();
                         acrStateData.put("initialized", data.getBoolean(AcrCloudHandler.KEY_ACR_STATE_INITIALIZED));
                         acrStateData.put("processing", data.getBoolean(AcrCloudHandler.KEY_ACR_STATE_PROCESSING));
                         eventData.put("data", acrStateData);
                         eventSink.success(eventData);
                        break;

                    default:
                         Log.w(TAG, "IncomingHandler: Unhandled message type: " + msg.what);
                        super.handleMessage(msg); // Laisser le Handler parent gérer si nécessaire
                }
            } catch (Exception e) {
                 Log.e(TAG, "Error handling message or sending to EventSink: " + msg.what, e);
                 // Optionnel: Envoyer une erreur à Flutter ?
                 // HashMap<String, Object> errorEvent = new HashMap<>();
                 // errorEvent.put("eventType", "nativeError");
                 // errorEvent.put("message", "Error processing message " + msg.what + ": " + e.getMessage());
                 // eventSink.error("NATIVE_ERROR", "Error handling message " + msg.what, e.toString());
            }
        }
    }

    // --- Send Message Helper Methods ---

    // Envoyer un message au DownloadService
    void sendMessageToDownloadService(int type, Bundle data) {
        if (!downloadServiceBound) {
            Log.w(TAG, "Cannot send message to DownloadService - not bound.");
            // Optionnel: Tenter de binder à nouveau?
            // connectDownloadService();
            return;
        }
         if (downloadServiceMessenger == null) {
            Log.e(TAG, "Cannot send message to DownloadService - messenger is null despite being bound!");
            return;
        }

        Message msg = Message.obtain(null, type);
        if (data != null) {
             msg.setData(data);
        }
        // msg.replyTo = activityMessengerForDownload; // Généralement pas nécessaire pour les commandes simples
        try {
            Log.d(TAG, "Sending message to DownloadService: " + type);
            downloadServiceMessenger.send(msg);
        } catch (RemoteException e) {
            Log.e(TAG, "Failed to send message to DownloadService", e);
            // Le service distant est peut-être mort
            downloadServiceBound = false; // Marquer comme non lié
            downloadServiceMessenger = null;
        }
    }

    // Envoyer un message à AcrCloudHandler (avec type et data)
    void sendMessageToAcrService(int type, Bundle data) {
        if (!acrServiceBound) {
             Log.w(TAG, "Cannot send message to AcrCloudHandler - not bound.");
             // Optionnel: Tenter de binder à nouveau?
             // connectAcrService();
             return;
        }
        if (acrServiceMessenger == null) {
             Log.e(TAG, "Cannot send message to AcrCloudHandler - messenger is null despite being bound!");
             return;
        }

        Message msg = Message.obtain(null, type);
        if (data != null) {
            msg.setData(data);
        }
        // Important : Indiquer qui envoie pour que le service puisse enregistrer le client (MSG_ACR_REGISTER_CLIENT)
        // ou pour qu'il puisse répondre (même si non utilisé pour les réponses simples ici).
        msg.replyTo = activityMessengerForAcr;
        sendMessageToAcrService(msg); // Appelle la méthode qui gère l'envoi réel
    }

     // Envoyer un objet Message complet à AcrCloudHandler (utilisé pour enregistrer le client)
     void sendMessageToAcrService(Message msg) {
         if (!acrServiceBound) {
             Log.w(TAG, "Cannot send message object to AcrCloudHandler - not bound.");
             return;
         }
         if (acrServiceMessenger == null) {
             Log.e(TAG, "Cannot send message object to AcrCloudHandler - messenger is null despite being bound!");
             return;
         }
         try {
             Log.d(TAG, "Sending message object to AcrCloudHandler: " + msg.what);
             acrServiceMessenger.send(msg);
         } catch (RemoteException e) {
             Log.e(TAG, "Failed to send message object to AcrCloudHandler", e);
             // Le service distant est peut-être mort
             acrServiceBound = false; // Marquer comme non lié
             acrServiceMessenger = null;
         }
     }

    // --- Utility Methods ---

    // Fonction utilitaire getParcelableArrayList (inchangée)
    @Nullable
    public static <T extends Parcelable> ArrayList<T> getParcelableArrayList(@Nullable Bundle bundle, @Nullable String key, @NonNull Class<T> clazz) {
         if (bundle == null || key == null) return null;
         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
             // La nouvelle méthode est type-safe
             return bundle.getParcelableArrayList(key, clazz);
         } else {
             // L'ancienne méthode nécessite une suppression d'avertissement
             @SuppressWarnings("deprecation")
             ArrayList<T> list = bundle.getParcelableArrayList(key);
             // Vérification manuelle du type (optionnelle mais plus sûre)
             if (list != null && !list.isEmpty()) {
                if (!clazz.isInstance(list.get(0))) {
                    Log.e(TAG, "getParcelableArrayList: Type mismatch for key '" + key + "'. Expected " + clazz.getName() + " but got " + list.get(0).getClass().getName());
                    return new ArrayList<>(); // Retourne une liste vide en cas d'erreur de type
                }
             }
             return list;
         }
    }
}