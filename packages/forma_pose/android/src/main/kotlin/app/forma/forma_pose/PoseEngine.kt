package app.forma.forma_pose

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.SystemClock
import android.util.Log
import android.util.Size
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * CameraX + MediaPipe Pose Landmarker (LIVE_STREAM) → binary frames.
 *
 * Frames are analysed on a single background thread with
 * [ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST]. Rotation is applied here, and so
 * is front-camera mirroring: PreviewView shows the front lens mirrored (what
 * people expect of a selfie), so the landmarks Dart receives are in that same
 * space and an overlay can be drawn straight onto the preview without
 * flipping anything.
 */
class PoseEngine(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val assetResolver: (String) -> String,
    private val previewHolder: PreviewHolder,
    private val listener: Listener,
) {
    class Options(
        val lens: String,
        val model: String,
        val gpu: Boolean,
        val targetWidth: Int,
        val targetHeight: Int,
        val minDetectionConfidence: Float,
        val minTrackingConfidence: Float,
        val minPresenceConfidence: Float,
    )

    interface Listener {
        fun onFrame(bytes: ByteArray)
        fun onError(code: String, message: String)
    }

    class ModelException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)

    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)
    private var cameraProvider: ProcessCameraProvider? = null
    private var landmarker: PoseLandmarker? = null
    private var options: Options? = null
    private var boundPreview: PreviewView? = null
    private var usingGpu = false
    private var mirror = false
    private var lastWidth = 0
    private var lastHeight = 0
    private var lastBrightness = -1f
    private var lastRotation = 0
    private var lastInferenceStartMs = 0L
    private var frameIndex = 0
    private val fpsCounter = FpsCounter()

    /** Starts camera + landmarker; [onReady] receives the info map for Dart. */
    fun start(opts: Options, onReady: (Map<String, Any?>) -> Unit) {
        options = opts
        mirror = opts.lens == "front"
        // Reading a 6 MB model blocks for a few hundred ms; do it while the
        // camera provider is still starting up rather than on the main thread.
        val landmarkerFuture = java.util.concurrent.FutureTask { createLandmarker(opts.model, opts) }
        analysisExecutor.execute(landmarkerFuture)
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                landmarker = landmarkerFuture.get()
                val provider = future.get()
                cameraProvider = provider
                bind(provider, opts)
                running.set(true)
                onReady(
                    mapOf(
                        "engine" to "mediapipe",
                        "model" to opts.model,
                        "gpu" to usingGpu,
                        "width" to opts.targetWidth,
                        "height" to opts.targetHeight,
                        "device" to "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}",
                    ),
                )
            } catch (t: Throwable) {
                val cause = (t as? java.util.concurrent.ExecutionException)?.cause ?: t
                Log.e(TAG, "start failed", cause)
                val code = if (cause is ModelException) "MODEL_LOAD_FAILED" else "CAMERA_UNAVAILABLE"
                listener.onError(code, cause.message ?: cause.toString())
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun bind(provider: ProcessCameraProvider, opts: Options) {
        provider.unbindAll()
        val selector = if (opts.lens == "front") {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        val resolution = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    Size(opts.targetWidth, opts.targetHeight),
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER,
                ),
            )
            .build()
        val analysis = ImageAnalysis.Builder()
            .setResolutionSelector(resolution)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
        analysis.setAnalyzer(analysisExecutor) { image -> analyze(image) }

        val useCases = mutableListOf<androidx.camera.core.UseCase>(analysis)
        val previewView = previewHolder.view
        if (previewView != null) {
            val preview = Preview.Builder().build()
            preview.surfaceProvider = previewView.surfaceProvider
            useCases.add(preview)
        }
        boundPreview = previewView
        provider.bindToLifecycle(lifecycleOwner, selector, *useCases.toTypedArray())

        // The Flutter platform view may be created after start(); rebind once
        // it shows up so the preview is not stuck black.
        previewHolder.onViewAvailable = { view ->
            if (running.get() && boundPreview !== view) {
                ContextCompat.getMainExecutor(context).execute { rebindPreview(view) }
            }
        }
    }

    private fun rebindPreview(view: PreviewView) {
        val provider = cameraProvider ?: return
        val opts = options ?: return
        if (boundPreview === view) return
        try {
            bind(provider, opts)
        } catch (t: Throwable) {
            Log.w(TAG, "preview rebind failed", t)
        }
    }

    private fun createLandmarker(model: String, opts: Options): PoseLandmarker {
        val assetPath = try {
            assetResolver("pose_landmarker_$model.task")
        } catch (t: Throwable) {
            throw ModelException("model asset pose_landmarker_$model.task not found", t)
        }
        val delegates = if (opts.gpu) listOf(Delegate.GPU, Delegate.CPU) else listOf(Delegate.CPU)
        var lastError: Throwable? = null
        for (delegate in delegates) {
            try {
                val base = BaseOptions.builder()
                    .setModelAssetPath(assetPath)
                    .setDelegate(delegate)
                    .build()
                val lmOptions = PoseLandmarker.PoseLandmarkerOptions.builder()
                    .setBaseOptions(base)
                    .setRunningMode(RunningMode.LIVE_STREAM)
                    .setNumPoses(1)
                    .setMinPoseDetectionConfidence(opts.minDetectionConfidence)
                    .setMinTrackingConfidence(opts.minTrackingConfidence)
                    .setMinPosePresenceConfidence(opts.minPresenceConfidence)
                    .setOutputSegmentationMasks(false)
                    .setResultListener { result, _ -> onResult(result) }
                    .setErrorListener { e -> listener.onError("INFERENCE_ERROR", e.message ?: e.toString()) }
                    .build()
                val lm = PoseLandmarker.createFromOptions(context, lmOptions)
                usingGpu = delegate == Delegate.GPU
                return lm
            } catch (t: Throwable) {
                Log.w(TAG, "landmarker init failed with $delegate", t)
                lastError = t
            }
        }
        throw ModelException("could not initialise PoseLandmarker ($model)", lastError)
    }

    /** Swap lite/full/heavy without touching the camera. */
    fun setModel(model: String) {
        val opts = options ?: return
        val fresh = createLandmarker(model, opts)
        val old = landmarker
        landmarker = fresh
        options = Options(
            opts.lens, model, opts.gpu, opts.targetWidth, opts.targetHeight,
            opts.minDetectionConfidence, opts.minTrackingConfidence, opts.minPresenceConfidence,
        )
        old?.close()
    }

    private fun analyze(image: ImageProxy) {
        image.use { proxy ->
            val lm = landmarker
            if (!running.get() || lm == null) return
            try {
                val bitmap = toUprightBitmap(proxy)
                lastWidth = bitmap.width
                lastHeight = bitmap.height
                lastRotation = proxy.imageInfo.rotationDegrees
                // Sampling every frame would cost more than the inference does.
                if (frameIndex++ % BRIGHTNESS_EVERY_N_FRAMES == 0) {
                    lastBrightness = FrameEncoder.meanLuma(bitmap)
                }
                val mpImage = BitmapImageBuilder(bitmap).build()
                lastInferenceStartMs = SystemClock.uptimeMillis()
                lm.detectAsync(mpImage, lastInferenceStartMs)
            } catch (t: Throwable) {
                Log.w(TAG, "analyze failed", t)
            }
        }
    }

    /** RGBA buffer → Bitmap, rotated to upright and mirrored for the front camera. */
    private fun toUprightBitmap(proxy: ImageProxy): Bitmap {
        val plane = proxy.planes[0]
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride
        val width = proxy.width
        val height = proxy.height
        val bitmap: Bitmap
        if (rowStride == width * pixelStride) {
            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            buffer.rewind()
            bitmap.copyPixelsFromBuffer(buffer)
        } else {
            // Padded rows: copy into a bitmap as wide as the stride, then crop.
            val padded = Bitmap.createBitmap(rowStride / pixelStride, height, Bitmap.Config.ARGB_8888)
            buffer.rewind()
            padded.copyPixelsFromBuffer(buffer)
            bitmap = Bitmap.createBitmap(padded, 0, 0, width, height)
        }
        val rotation = proxy.imageInfo.rotationDegrees
        if (rotation == 0 && !mirror) return bitmap
        val matrix = Matrix()
        matrix.postRotate(rotation.toFloat())
        if (mirror) matrix.postScale(-1f, 1f, width / 2f, height / 2f)
        return Bitmap.createBitmap(bitmap, 0, 0, width, height, matrix, true)
    }

    private fun onResult(result: PoseLandmarkerResult) {
        if (!running.get()) return
        val now = SystemClock.uptimeMillis()
        // The timestamp we passed to detectAsync is the capture time of *this*
        // result, so it measures latency without racing the next frame.
        val inferenceMs = (now - result.timestampMs()).toFloat().coerceAtLeast(0f)
        val fps = fpsCounter.tick(now)
        val bytes = FrameEncoder.encode(
            result = result,
            timestampMs = result.timestampMs(),
            width = lastWidth,
            height = lastHeight,
            fps = fps,
            inferenceMs = inferenceMs,
            brightness = lastBrightness,
            rotationDeg = lastRotation,
        )
        listener.onFrame(bytes)
    }

    fun stop() {
        running.set(false)
        previewHolder.onViewAvailable = null
        boundPreview = null
        try {
            cameraProvider?.unbindAll()
        } catch (t: Throwable) {
            Log.w(TAG, "unbind failed", t)
        }
        cameraProvider = null
        landmarker?.close()
        landmarker = null
        analysisExecutor.shutdown()
    }

    private class FpsCounter {
        private var windowStart = 0L
        private var frames = 0
        private var fps = 0f

        fun tick(nowMs: Long): Float {
            if (windowStart == 0L) windowStart = nowMs
            frames++
            val elapsed = nowMs - windowStart
            if (elapsed >= 1000) {
                fps = frames * 1000f / elapsed
                frames = 0
                windowStart = nowMs
            }
            return fps
        }
    }

    private companion object {
        const val TAG = "FormaPose"
        const val BRIGHTNESS_EVERY_N_FRAMES = 15
    }
}
