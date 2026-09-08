package app.forma.forma_pose

import android.graphics.Bitmap
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Serialises a [PoseLandmarkerResult] into the binary layout decoded by
 * Dart `PoseFrameCodec` (packages/forma_pose/lib/src/frame_codec.dart).
 *
 * header 40 bytes: int64 ts, int32 w, int32 h, f32 fps, f32 inferenceMs,
 * f32 brightness, int32 rotationDeg, int32 hasPose, int32 hasWorld
 * body: 33 × (x,y,z,visibility,presence) f32 [+ 33 × (x,y,z) f32 world]
 */
object FrameEncoder {
    private const val LANDMARKS = 33
    private const val HEADER = 40
    private const val BODY = LANDMARKS * 5 * 4
    private const val WORLD = LANDMARKS * 3 * 4

    fun encode(
        result: PoseLandmarkerResult,
        timestampMs: Long,
        width: Int,
        height: Int,
        fps: Float,
        inferenceMs: Float,
        brightness: Float,
        rotationDeg: Int,
    ): ByteArray {
        val poses = result.landmarks()
        val hasPose = poses.isNotEmpty() && poses[0].size >= LANDMARKS
        val worlds = result.worldLandmarks()
        val hasWorld = hasPose && worlds.isNotEmpty() && worlds[0].size >= LANDMARKS
        val size = if (!hasPose) HEADER else HEADER + BODY + (if (hasWorld) WORLD else 0)
        val buf = ByteBuffer.allocate(size).order(ByteOrder.LITTLE_ENDIAN)
        buf.putLong(timestampMs)
        buf.putInt(width)
        buf.putInt(height)
        buf.putFloat(fps)
        buf.putFloat(inferenceMs)
        buf.putFloat(brightness)
        buf.putInt(rotationDeg)
        buf.putInt(if (hasPose) 1 else 0)
        buf.putInt(if (hasWorld) 1 else 0)
        if (hasPose) {
            val lms = poses[0]
            for (i in 0 until LANDMARKS) {
                val l = lms[i]
                buf.putFloat(l.x())
                buf.putFloat(l.y())
                buf.putFloat(l.z())
                buf.putFloat(l.visibility().orElse(1f))
                buf.putFloat(l.presence().orElse(1f))
            }
            if (hasWorld) {
                val ws = worlds[0]
                for (i in 0 until LANDMARKS) {
                    val w = ws[i]
                    buf.putFloat(w.x())
                    buf.putFloat(w.y())
                    buf.putFloat(w.z())
                }
            }
        }
        return buf.array()
    }

    /** Cheap mean luma (0..1) from a sparse pixel sample; used for the light check. */
    fun meanLuma(bitmap: Bitmap, step: Int = 16): Float {
        val w = bitmap.width
        val h = bitmap.height
        if (w == 0 || h == 0) return -1f
        var sum = 0L
        var n = 0
        var y = 0
        while (y < h) {
            var x = 0
            while (x < w) {
                val p = bitmap.getPixel(x, y)
                val r = (p shr 16) and 0xFF
                val g = (p shr 8) and 0xFF
                val b = p and 0xFF
                sum += (299 * r + 587 * g + 114 * b) / 1000
                n++
                x += step
            }
            y += step
        }
        return if (n == 0) -1f else sum.toFloat() / (n * 255f)
    }
}
