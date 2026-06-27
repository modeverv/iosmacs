package com.example.iosmacs_flutter

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
  private val nativeEmacsBridge by lazy {
    AndroidNativeEmacsBridge(this)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      AndroidNativeEmacsBridge.channelName,
    ).setMethodCallHandler(nativeEmacsBridge::handle)
  }
}

private class AndroidNativeEmacsBridge(
  private val context: Context,
) {
  companion object {
    const val channelName = "iosmacs/native_emacs"
  }

  private var lifecycleState = "iosmacs Android native bridge: idle"
  private var cols = 80
  private var rows = 24
  private var inputBytes = 0
  private var officialTerminalStarted = false
  private val output = ByteArrayOutputStream()
  private val nativeRuntime = AndroidNativeEmacsRuntime
  private val officialRuntime = OfficialAndroidEmacsRuntime

  fun handle(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> start(result)
      "stop" -> stop(result)
      "redraw" -> redraw(result)
      "sendBytes" -> sendBytes(call, result)
      "resize" -> resize(call, result)
      "drainOutput" -> result.success(drainOutput())
      "pasteSystemClipboard" -> pasteSystemClipboard(result)
      "listWorkspace" -> listWorkspace(result)
      "importWorkspace" -> importWorkspace(call, result)
      "exportWorkspace" -> exportWorkspace(result)
      "selectWorkspaceRoot" -> selectWorkspaceRoot(result)
      "clearWorkspaceRoot" -> clearWorkspaceRoot(result)
      else -> result.notImplemented()
    }
  }

  private fun start(result: MethodChannel.Result) {
    // Prefer the NW (no-window-system) Emacs text-terminal binary when available.
    // This binary is built without HAVE_ANDROID restrictions and supports full PTY.
    val nwBinary = NwEmacsRuntime.executablePath(context)
    if (nwBinary != null && !officialTerminalStarted) {
      val dataDir = NwEmacsRuntime.ensureDataExtracted(context)
      lifecycleState = "iosmacs Android native bridge: GNU Emacs NW PTY terminal starting"
      val nwOutput = nativeRuntime.startNwEmacs(
        nwBinary,
        dataDir?.let { File(it, "lisp").absolutePath } ?: "",
        dataDir?.let { File(it, "etc").absolutePath } ?: "",
        prepareWorkspaceRoot().absolutePath,
        context.cacheDir.absolutePath,
        cols,
        rows,
      )
      officialTerminalStarted =
        nwOutput.toString(Charsets.UTF_8).contains("iosmacs Android GNU Emacs NW PTY session started")
      if (officialTerminalStarted) {
        lifecycleState = "iosmacs Android native bridge: GNU Emacs NW PTY terminal running"
      }
      appendOutput(nwOutput)
      result.success(status())
      return
    }

    // Fall back to diagnostics and the HAVE_ANDROID comparison probes when the
    // separate NW binary is absent.  The official Android port is still useful
    // as packaged-runtime evidence, but not as the active interactive -nw route.
    lifecycleState = if (officialRuntime.isAvailable) {
      if (officialRuntime.javaBridgeAvailable) {
        "iosmacs Android native bridge: GNU Emacs NDK libraries and Java bridge packaged; using fallback diagnostic frame"
      } else {
        "iosmacs Android native bridge: GNU Emacs NDK libraries packaged; using fallback diagnostic frame"
      }
    } else {
      "iosmacs Android native bridge: fallback diagnostic frame running"
    }
    appendOutput(nativeRuntime.start(cols, rows))
    if (officialRuntime.isAvailable) {
      appendOutput("iosmacs Android GNU Emacs NDK runtime libraries loaded\r\n")
    }
    if (officialRuntime.javaBridgeAvailable) {
      appendOutput(
        "iosmacs Android GNU Emacs Java bridge ready: ${officialRuntime.javaBridgeFingerprint}\r\n",
      )
    }
    if (officialRuntime.wrapperExecutableAvailable(context)) {
      appendOutput(
        "iosmacs Android GNU Emacs wrapper executable ready: ${officialRuntime.wrapperExecutablePath(context)}\r\n",
      )
      appendOutput("${officialRuntime.processProbe(context).terminalLine}\r\n")
      val officialOutput = nativeRuntime.startOfficialEmacs(
        officialRuntime.wrapperExecutablePath(context),
        context.applicationInfo.sourceDir,
        context.filesDir.absolutePath,
        context.cacheDir.absolutePath,
        cols,
        rows,
      )
      officialTerminalStarted =
        officialOutput.toString(Charsets.UTF_8).contains("iosmacs Android GNU Emacs PTY session started")
      if (officialTerminalStarted) {
        lifecycleState = "iosmacs Android native bridge: official GNU Emacs PTY terminal running"
      }
      appendOutput(officialOutput)
    }
    result.success(status())
  }

  private fun stop(result: MethodChannel.Result) {
    nativeRuntime.stopOfficialEmacs()
    officialTerminalStarted = false
    lifecycleState = "iosmacs Android native bridge: stopped"
    appendOutput("iosmacs Android native bridge stopped\r\n")
    result.success(status())
  }

  private fun redraw(result: MethodChannel.Result) {
    lifecycleState = "iosmacs Android native bridge: redrew Emacs terminal frame"
    if (officialTerminalStarted) {
      appendOutput(nativeRuntime.resizeOfficial(cols, rows))
    } else {
      appendOutput(nativeRuntime.redraw(cols, rows))
    }
    result.success(status())
  }

  private fun sendBytes(call: MethodCall, result: MethodChannel.Result) {
    val bytes = call.argument<ByteArray>("bytes") ?: ByteArray(0)
    inputBytes += bytes.size
    lifecycleState = "iosmacs Android native bridge: accepted ${bytes.size} byte(s)"
    if (officialTerminalStarted) {
      appendOutput(nativeRuntime.sendOfficialBytes(bytes))
    } else {
      appendOutput(nativeRuntime.sendBytes(bytes))
    }
    result.success(status())
  }

  private fun resize(call: MethodCall, result: MethodChannel.Result) {
    cols = call.argument<Int>("cols") ?: cols
    rows = call.argument<Int>("rows") ?: rows
    lifecycleState = "iosmacs Android native bridge: resized ${cols}x${rows}"
    if (officialTerminalStarted) {
      appendOutput(nativeRuntime.resizeOfficial(cols, rows))
    }
    result.success(status())
  }

  private fun pasteSystemClipboard(result: MethodChannel.Result) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val text = clipboard.primaryClip?.getItemAt(0)?.firstText() ?: ""
    if (text.isEmpty()) {
      result.success(mapOf("accepted" to false, "byteCount" to 0))
      return
    }
    val bytes = text.replace("\n", "\r").toByteArray(Charsets.UTF_8)
    inputBytes += bytes.size
    lifecycleState = "iosmacs Android native bridge: pasted clipboard"
    if (officialTerminalStarted) {
      appendOutput(nativeRuntime.sendOfficialBytes(bytes))
    } else {
      appendOutput(nativeRuntime.pasteBytes(bytes))
    }
    result.success(mapOf("accepted" to true, "byteCount" to bytes.size))
  }

  private fun listWorkspace(result: MethodChannel.Result) {
    val root = prepareWorkspaceRoot()
    val entries = root.listFiles()
      ?.sortedBy { it.name }
      ?.map { file ->
        mapOf(
          "name" to file.name,
          "path" to file.absolutePath,
          "isDirectory" to file.isDirectory,
          "sizeBytes" to file.length(),
        )
      }
      ?: emptyList()
    lifecycleState = "iosmacs Android native bridge: listed ${entries.size} workspace item(s)"
    result.success(entries)
  }

  private fun importWorkspace(call: MethodCall, result: MethodChannel.Result) {
    val uriStrings = call.argument<List<String>>("uris") ?: emptyList()
    val root = prepareWorkspaceRoot()
    var importedCount = 0
    try {
      for (uriString in uriStrings) {
        val sourceUri = Uri.parse(uriString)
        val name = sourceUri.lastPathSegment?.substringAfterLast('/') ?: continue
        val destination = File(root, name)
        context.contentResolver.openInputStream(sourceUri)?.use { input ->
          destination.outputStream().use { output ->
            input.copyTo(output)
          }
          importedCount += 1
        }
      }
      lifecycleState = "iosmacs Android native bridge: imported $importedCount workspace item(s)"
      result.success(importedCount)
    } catch (error: Exception) {
      result.error("workspace_import_failed", error.localizedMessage, null)
    }
  }

  private fun exportWorkspace(result: MethodChannel.Result) {
    val root = prepareWorkspaceRoot()
    val files = root.listFiles()?.sortedBy { it.name }.orEmpty()
    val uris = if (files.isEmpty()) {
      listOf(Uri.fromFile(root).toString())
    } else {
      files.map { Uri.fromFile(it).toString() }
    }
    lifecycleState = "iosmacs Android native bridge: exported ${uris.size} workspace item(s)"
    result.success(uris)
  }

  private fun selectWorkspaceRoot(result: MethodChannel.Result) {
    val path = prepareWorkspaceRoot().absolutePath
    lifecycleState = "iosmacs Android native bridge: using app-private workspace"
    result.success(
      mapOf("message" to "Android app-private workspace: $path"),
    )
  }

  private fun clearWorkspaceRoot(result: MethodChannel.Result) {
    val path = prepareWorkspaceRoot().absolutePath
    lifecycleState = "iosmacs Android native bridge: reset app-private workspace"
    result.success(
      mapOf("message" to "Android default app-private workspace: $path"),
    )
  }

  private fun status(): Map<String, Any> = mapOf(
    "lifecycleState" to lifecycleState,
    "cols" to cols,
    "rows" to rows,
    "inputBytes" to inputBytes,
    "outputBytes" to output.size(),
    "androidEmacsRuntimeAvailable" to officialRuntime.isAvailable,
    "androidEmacsRuntimeStatus" to officialRuntime.status,
    "androidEmacsJavaBridgeAvailable" to officialRuntime.javaBridgeAvailable,
    "androidEmacsJavaBridgeStatus" to officialRuntime.javaBridgeStatus,
    "androidEmacsJavaBridgeFingerprint" to officialRuntime.javaBridgeFingerprint,
    "androidEmacsWrapperExecutableAvailable" to officialRuntime.wrapperExecutableAvailable(context),
    "androidEmacsWrapperExecutablePath" to officialRuntime.wrapperExecutablePath(context),
    "androidEmacsProcessProbeStatus" to officialRuntime.processProbe(context).status,
    "androidEmacsProcessProbeOutput" to officialRuntime.processProbe(context).output,
    "androidEmacsOfficialTerminalStarted" to officialTerminalStarted,
  )

  private fun appendOutput(text: String) {
    output.write(text.toByteArray(Charsets.UTF_8))
  }

  private fun appendOutput(bytes: ByteArray) {
    if (bytes.isEmpty()) {
      return
    }
    output.write(bytes)
  }

  private fun drainOutput(): ByteArray {
    if (officialTerminalStarted) {
      appendOutput(nativeRuntime.drainOfficialOutput())
    }
    val bytes = output.toByteArray()
    output.reset()
    return bytes
  }

  private fun prepareWorkspaceRoot(): File {
    val root = File(context.filesDir, "iosmacs/workspace")
    root.mkdirs()
    return root
  }

  private fun ClipData.Item.firstText(): String =
    coerceToText(context)?.toString() ?: ""
}

private object AndroidNativeEmacsRuntime {
  init {
    System.loadLibrary("iosmacs_android_runtime")
  }

  external fun start(cols: Int, rows: Int): ByteArray

  external fun redraw(cols: Int, rows: Int): ByteArray

  external fun sendBytes(bytes: ByteArray): ByteArray

  external fun pasteBytes(bytes: ByteArray): ByteArray

  external fun startOfficialEmacs(
    executablePath: String,
    classPath: String,
    homeDir: String,
    cacheDir: String,
    cols: Int,
    rows: Int,
  ): ByteArray

  external fun sendOfficialBytes(bytes: ByteArray): ByteArray

  external fun drainOfficialOutput(): ByteArray

  external fun resizeOfficial(cols: Int, rows: Int): ByteArray

  external fun stopOfficialEmacs()

  external fun startNwEmacs(
    executablePath: String,
    lispDir: String,
    etcDir: String,
    homeDir: String,
    cacheDir: String,
    cols: Int,
    rows: Int,
  ): ByteArray
}

// Manages the GNU Emacs NW (no-window-system) text-terminal binary.
// The binary is named libemacs_nw.so in jniLibs so Android extracts it
// to nativeLibraryDir where it can be executed.
private object NwEmacsRuntime {
  private const val TAG = "NwEmacsRuntime"
  // Asset directories for Emacs Lisp and etc data (from the Android build).
  private const val ASSETS_LISP = "lisp"
  private const val ASSETS_ETC  = "etc"
  // Version marker: bump this if the extracted data format changes.
  private const val DATA_VERSION = "1"
  private const val DATA_VERSION_FILE = ".iosmacs_nw_data_version"

  // Returns the path to the NW Emacs binary if it has been extracted, else null.
  fun executablePath(context: Context): String? {
    val path = File(context.applicationInfo.nativeLibraryDir, "libemacs_nw.so")
    return if (path.isFile && path.canExecute()) path.absolutePath else null
  }

  // Ensures Emacs Lisp/etc data is extracted from APK assets to filesDir.
  // Returns the root data directory, or null on failure.
  fun ensureDataExtracted(context: Context): File? {
    val dataRoot = File(context.filesDir, "iosmacs/emacs-data")
    val versionFile = File(dataRoot, DATA_VERSION_FILE)
    if (versionFile.exists() && versionFile.readText().trim() == DATA_VERSION) {
      return dataRoot
    }
    return try {
      Log.i(TAG, "extracting Emacs Lisp/etc assets to ${dataRoot.absolutePath}")
      dataRoot.deleteRecursively()
      dataRoot.mkdirs()
      extractAssetDir(context, ASSETS_LISP, File(dataRoot, "lisp"))
      extractAssetDir(context, ASSETS_ETC,  File(dataRoot, "etc"))
      versionFile.writeText(DATA_VERSION)
      Log.i(TAG, "iosmacs Android GNU Emacs NW data extracted ok: ${dataRoot.absolutePath}")
      dataRoot
    } catch (e: Exception) {
      Log.e(TAG, "asset extraction failed: ${e.message}")
      null
    }
  }

  private fun extractAssetDir(context: Context, assetPath: String, dest: File) {
    val assets = context.assets
    val entries = try { assets.list(assetPath) } catch (_: Exception) { null }

    if (entries != null && entries.isNotEmpty()) {
      // Non-empty listing → directory: recurse into each entry.
      dest.mkdirs()
      for (entry in entries) {
        extractAssetDir(context, "$assetPath/$entry", File(dest, entry))
      }
      return
    }

    // entries is null or empty: either a file, or a directory that
    // AssetManager failed to list (common for compressed subdirectories).
    // Try opening as a file first.
    try {
      val bytes = assets.open(assetPath).use { it.readBytes() }
      // If we get here it IS a file — copy it.
      dest.parentFile?.mkdirs()
      dest.writeBytes(bytes)
      return
    } catch (_: Exception) {
      // Opening failed → treat as directory and try APK-level listing.
    }

    // Fallback: the path is a directory but assets.list() returned empty.
    // Enumerate the APK's ZIP entries whose names start with "assets/$assetPath/"
    // and extract them directly.
    dest.mkdirs()
    try {
      val apkPath = context.applicationInfo.sourceDir
      java.util.zip.ZipFile(apkPath).use { zip ->
        val prefix = "assets/$assetPath/"
        zip.entries().asSequence()
          .filter { it.name.startsWith(prefix) && it.name.length > prefix.length }
          .forEach { entry ->
            val relativePath = entry.name.removePrefix(prefix)
            if (!relativePath.contains('/')) {
              // Direct child file
              val outFile = File(dest, relativePath)
              outFile.parentFile?.mkdirs()
              zip.getInputStream(entry).use { input ->
                outFile.outputStream().use { input.copyTo(it) }
              }
            }
          }
      }
    } catch (e: Exception) {
      Log.w(TAG, "fallback ZIP extraction for $assetPath failed: ${e.message}")
    }
  }
}

private object OfficialAndroidEmacsRuntime {
  val isAvailable: Boolean
  val status: String
  val javaBridgeAvailable: Boolean
  val javaBridgeStatus: String
  val javaBridgeFingerprint: String
  val flutterApplicationId = "com.example.iosmacs_flutter"
  private var cachedProcessProbe: AndroidEmacsProcessProbe? = null

  init {
    var loaded = false
    var message = "Android GNU Emacs NDK libraries are not packaged"
    var javaLoaded = false
    var javaMessage = "Android GNU Emacs Java bridge classes are not packaged"
    var fingerprint = "unavailable"
    try {
      System.loadLibrary("emacs")
      System.loadLibrary("android-emacs")
      loaded = true
      message = "Android GNU Emacs NDK libraries loaded"
    } catch (error: UnsatisfiedLinkError) {
      message = "Android GNU Emacs NDK libraries unavailable: ${error.localizedMessage}"
    }
    if (loaded) {
      try {
        val nativeClass = Class.forName("org.gnu.emacs.EmacsNative")
        val getFingerprint = nativeClass.getMethod("getFingerprint")
        fingerprint = getFingerprint.invoke(null)?.toString() ?: "unknown"
        javaLoaded = fingerprint.isNotBlank()
        javaMessage = "Android GNU Emacs Java bridge loaded"
      } catch (error: Throwable) {
        val cause = error.cause ?: error
        javaMessage = "Android GNU Emacs Java bridge unavailable: ${cause.localizedMessage}"
      }
    }
    isAvailable = loaded
    status = message
    javaBridgeAvailable = javaLoaded
    javaBridgeStatus = javaMessage
    javaBridgeFingerprint = fingerprint
  }

  fun wrapperExecutablePath(context: Context): String =
    File(context.applicationInfo.nativeLibraryDir, "libandroid-emacs.so").absolutePath

  fun wrapperExecutableAvailable(context: Context): Boolean {
    val wrapper = File(wrapperExecutablePath(context))
    return wrapper.isFile && wrapper.canExecute()
  }

  fun processProbe(context: Context): AndroidEmacsProcessProbe {
    cachedProcessProbe?.let { return it }
    val wrapper = File(wrapperExecutablePath(context))
    val result = if (!isAvailable || !javaBridgeAvailable || !wrapper.canExecute()) {
      AndroidEmacsProcessProbe(
        status = "unavailable",
        output = "Android GNU Emacs process probe skipped",
      )
    } else {
      runProcessProbe(context, wrapper)
    }
    cachedProcessProbe = result
    return result
  }

  private fun runProcessProbe(context: Context, wrapper: File): AndroidEmacsProcessProbe {
    val output = ByteArrayOutputStream()
    return try {
      val process = ProcessBuilder(
        wrapper.absolutePath,
        "--batch",
        "--eval",
        "(progn (princ \"iosmacs-android-emacs-process-probe\") (terpri))",
      )
        .redirectErrorStream(true)
        .apply {
          environment()["EMACS_CLASS_PATH"] = context.applicationInfo.sourceDir
          environment()["HOME"] = context.filesDir.absolutePath
          environment()["TMPDIR"] = context.cacheDir.absolutePath
        }
        .start()
      val outputThread = Thread {
        try {
          process.inputStream.use { input ->
            input.copyTo(output)
          }
        } catch (_: Exception) {
          // The timeout path closes the stream while this thread is blocked.
        }
      }
      outputThread.name = "iosmacs Android Emacs process probe output"
      outputThread.start()
      val finished = process.waitFor(8, TimeUnit.SECONDS)
      if (!finished) {
        process.destroyForcibly()
        outputThread.join(500)
        AndroidEmacsProcessProbe(
          status = "timeout",
          output = output.toTerminalSnippet(),
        )
      } else {
        outputThread.join(500)
        AndroidEmacsProcessProbe(
          status = "exit=${process.exitValue()} marker=${output.probeMarkerStatus()}",
          output = output.toTerminalSnippet(),
        )
      }
    } catch (error: Exception) {
      AndroidEmacsProcessProbe(
        status = "error",
        output = error.localizedMessage ?: error.javaClass.simpleName,
      )
    }
  }

  private fun ByteArrayOutputStream.toTerminalSnippet(): String {
    val sanitized = toString(Charsets.UTF_8.name())
      .replace("\r", "\\r")
      .replace("\n", "\\n")
      .take(1000)
    return sanitized.ifBlank { "<empty>" }
  }

  private fun ByteArrayOutputStream.probeMarkerStatus(): String =
    if (toString(Charsets.UTF_8.name()).contains("iosmacs-android-emacs-process-probe")) {
      "ok"
    } else {
      "missing"
    }
}

private data class AndroidEmacsProcessProbe(
  val status: String,
  val output: String,
) {
  val terminalLine: String
    get() = "iosmacs Android GNU Emacs process probe: $status output=$output"
}
