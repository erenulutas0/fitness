package app.forma.forma_pose

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/**
 * FORMA pose plugin — Android entry point.
 *
 * Channels:
 *  - `forma_pose/methods`: start / stop / setModel / hasCameraPermission / requestCameraPermission
 *  - `forma_pose/frames`:  binary [PoseFrame]s (see [FrameEncoder] / Dart `PoseFrameCodec`)
 *  - platform view `forma_pose/preview`: CameraX PreviewView
 *
 * Camera pixels stay inside [PoseEngine]; only landmarks cross the channel (docs/00 D3).
 */
class FormaPosePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var context: Context
    private lateinit var assets: FlutterPlugin.FlutterAssets
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activityBinding: ActivityPluginBinding? = null
    private var engine: PoseEngine? = null
    private var sink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val previewHolder = PreviewHolder()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        assets = binding.flutterAssets
        methods = MethodChannel(binding.binaryMessenger, "forma_pose/methods")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "forma_pose/frames")
        events.setStreamHandler(this)
        binding.platformViewRegistry.registerViewFactory("forma_pose/preview", PreviewViewFactory(previewHolder))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        engine?.stop()
        engine = null
    }

    // ---- ActivityAware ------------------------------------------------------

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        engine?.stop()
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        engine?.stop()
        engine = null
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    // ---- MethodChannel ------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "stop" -> {
                engine?.stop()
                engine = null
                result.success(null)
            }
            "setModel" -> {
                val model = call.argument<String>("model") ?: "lite"
                val e = engine
                if (e == null) {
                    result.error("NOT_RUNNING", "call start() first", null)
                } else {
                    try {
                        e.setModel(model)
                        result.success(null)
                    } catch (t: Throwable) {
                        result.error("MODEL_LOAD_FAILED", t.message, null)
                    }
                }
            }
            "hasCameraPermission" -> result.success(hasCameraPermission())
            "requestCameraPermission" -> requestCameraPermission(result)
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (engine != null) {
            result.error("ALREADY_RUNNING", "pose engine already running; call stop() first", null)
            return
        }
        if (!hasCameraPermission()) {
            result.error("PERMISSION_DENIED", "camera permission not granted", null)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null || activity !is LifecycleOwner) {
            result.error("CAMERA_UNAVAILABLE", "no activity to bind the camera to", null)
            return
        }
        if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            result.error("CAMERA_UNAVAILABLE", "device has no camera", null)
            return
        }
        val options = PoseEngine.Options(
            lens = call.argument<String>("lens") ?: "back",
            model = call.argument<String>("model") ?: "lite",
            gpu = call.argument<Boolean>("gpu") ?: true,
            targetWidth = call.argument<Int>("targetWidth") ?: 640,
            targetHeight = call.argument<Int>("targetHeight") ?: 480,
            minDetectionConfidence = (call.argument<Double>("minDetectionConfidence") ?: 0.5).toFloat(),
            minTrackingConfidence = (call.argument<Double>("minTrackingConfidence") ?: 0.5).toFloat(),
            minPresenceConfidence = (call.argument<Double>("minPresenceConfidence") ?: 0.5).toFloat(),
        )
        val e = PoseEngine(
            context = context,
            lifecycleOwner = activity,
            assetResolver = { name -> assets.getAssetFilePathByName("assets/models/$name") },
            previewHolder = previewHolder,
            listener = object : PoseEngine.Listener {
                override fun onFrame(bytes: ByteArray) {
                    mainHandler.post { sink?.success(bytes) }
                }

                override fun onError(code: String, message: String) {
                    mainHandler.post { sink?.error(code, message, null) }
                }
            },
        )
        try {
            e.start(options) { info ->
                engine = e
                mainHandler.post { result.success(info) }
            }
        } catch (t: Throwable) {
            e.stop()
            val code = if (t is PoseEngine.ModelException) "MODEL_LOAD_FAILED" else "CAMERA_UNAVAILABLE"
            result.error(code, t.message ?: t.toString(), null)
        }
    }

    // ---- EventChannel -------------------------------------------------------

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        this.sink = sink
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    // ---- Permissions --------------------------------------------------------

    private fun hasCameraPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun requestCameraPermission(result: MethodChannel.Result) {
        if (hasCameraPermission()) {
            result.success(true)
            return
        }
        val activity: Activity? = activityBinding?.activity
        if (activity == null) {
            result.success(false)
            return
        }
        if (pendingPermission != null) {
            result.error("PERMISSION_PENDING", "a permission request is already in progress", null)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
        return true
    }

    private companion object {
        const val PERMISSION_REQUEST_CODE = 0xF0A5
    }
}
