package app.forma.forma_pose

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Shares the single [PreviewView] between the platform view and [PoseEngine]. */
class PreviewHolder {
    @Volatile
    var view: PreviewView? = null
        private set

    /** Called when a preview view is attached, so a running engine can rebind. */
    @Volatile
    var onViewAvailable: ((PreviewView) -> Unit)? = null

    fun attach(view: PreviewView) {
        this.view = view
        onViewAvailable?.invoke(view)
    }

    fun detach(view: PreviewView) {
        if (this.view === view) this.view = null
    }
}

class PreviewViewFactory(private val holder: PreviewHolder) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        PreviewPlatformView(context, holder)
}

class PreviewPlatformView(context: Context, private val holder: PreviewHolder) : PlatformView {
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }

    init {
        holder.attach(previewView)
    }

    override fun getView(): View = previewView

    override fun dispose() {
        holder.detach(previewView)
    }
}
