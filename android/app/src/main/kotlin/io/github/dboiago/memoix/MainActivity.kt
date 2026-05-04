package io.github.dboiago.memoix

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity : FlutterActivity() {

    private val channelName = "memoix/share"
    private var channel: MethodChannel? = null

    /// Holds a share event that arrived before the Flutter engine was ready.
    private var pendingShare: Map<String, String>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        processShareIntent(intent)
    }

    /// Called when Memoix is already running and a new intent arrives (singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        processShareIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        // Drain any share that arrived before the engine was ready.
        pendingShare?.let { share ->
            channel?.invokeMethod("onShareReceived", share)
            pendingShare = null
        }
    }

    /// Routes an incoming intent to the correct share handler.
    /// ACTION_VIEW is intentionally ignored here — it is handled by app_links.
    private fun processShareIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        val type = intent.type ?: return

        when {
            action == Intent.ACTION_SEND && type == "text/plain" ->
                handleTextShare(intent)
            action == Intent.ACTION_SEND && type.startsWith("image/") ->
                handleSingleImageShare(intent)
            action == Intent.ACTION_SEND_MULTIPLE && type.startsWith("image/") ->
                handleMultipleImageShare(intent)
        }
    }

    // ── Text share ──────────────────────────────────────────────────────────

    private fun handleTextShare(intent: Intent) {
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim() ?: return
        // SECURITY: reject empty or excessively long payloads (AGENTS.md: 4096-char limit on
        // user-supplied text; images use the 10 MB byte-stream limit enforced separately).
        if (text.isEmpty() || text.length > 4096) return
        val shareType = if (
            text.startsWith("http://", ignoreCase = true) ||
            text.startsWith("https://", ignoreCase = true)
        ) "url" else "text"
        dispatchToFlutter(mapOf("type" to shareType, "content" to text))
    }

    // ── Image share ─────────────────────────────────────────────────────────

    private fun handleSingleImageShare(intent: Intent) {
        val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
        if (uri == null) return
        copyUriToTemp(uri)?.let { path ->
            dispatchToFlutter(mapOf("type" to "image", "path" to path))
        }
    }

    /// For multi-image shares, only the first image is processed; the rest are silently ignored.
    private fun handleMultipleImageShare(intent: Intent) {
        @Suppress("DEPRECATION")
        val uris: ArrayList<Parcelable>? = intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
        val firstUri = uris?.firstOrNull() as? Uri ?: return
        copyUriToTemp(firstUri)?.let { path ->
            dispatchToFlutter(mapOf("type" to "image", "path" to path))
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /// Copies a content URI to a temporary cache file readable by Flutter.
    /// Enforces a 10 MB limit per AGENTS.md HTTP response limits policy.
    /// Returns the absolute path of the temp file, or null on failure.
    private fun copyUriToTemp(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val tempFile = File(cacheDir, "memoix_share_${System.currentTimeMillis()}.jpg")
            FileOutputStream(tempFile).use { output ->
                inputStream.use { input ->
                    val buffer = ByteArray(8192)
                    var bytesRead: Int
                    var totalRead = 0L
                    val maxBytes = 10L * 1024L * 1024L // 10 MB — AGENTS.md limit
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        totalRead += bytesRead
                        if (totalRead > maxBytes) return null // Oversized — reject
                        output.write(buffer, 0, bytesRead)
                    }
                }
            }
            tempFile.absolutePath
        } catch (_: IOException) {
            null
        }
    }

    /// Sends a share payload to Flutter, or queues it if the engine is not yet ready.
    private fun dispatchToFlutter(share: Map<String, String>) {
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("onShareReceived", share)
        } else {
            // Engine not initialised yet; the payload will be drained in configureFlutterEngine.
            pendingShare = share
        }
    }
}

