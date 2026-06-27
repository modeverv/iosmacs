package com.example.iosmacs_flutter

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

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

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    if (nativeEmacsBridge.handleActivityResult(requestCode, resultCode, data)) {
      return
    }
    super.onActivityResult(requestCode, resultCode, data)
  }
}

private class AndroidNativeEmacsBridge(
  private val activity: MainActivity,
) {
  companion object {
    const val channelName = "iosmacs/native_emacs"
    private const val exportDocumentRequestCode = 44017
  }

  private val context: Context
    get() = activity
  private var lifecycleState = "iosmacs Android native bridge: idle"
  private var cols = 80
  private var rows = 24
  private var inputBytes = 0
  private var officialTerminalStarted = false
  private val output = ByteArrayOutputStream()
  private val nativeRuntime = AndroidNativeEmacsRuntime
  private val officialRuntime = OfficialAndroidEmacsRuntime
  private var pendingExportResult: MethodChannel.Result? = null
  private var pendingExportFile: File? = null

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
      "exportWorkspace" -> exportWorkspace(call, result)
      "selectWorkspaceRoot" -> selectWorkspaceRoot(result)
      "clearWorkspaceRoot" -> clearWorkspaceRoot(result)
      else -> result.notImplemented()
    }
  }

  fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode != exportDocumentRequestCode) {
      return false
    }
    val result = pendingExportResult ?: return true
    val exportFile = pendingExportFile
    pendingExportResult = null
    pendingExportFile = null

    val destinationUri = data?.data
    if (resultCode != Activity.RESULT_OK || destinationUri == null || exportFile == null) {
      lifecycleState = "iosmacs Android native bridge: user export cancelled"
      result.success(emptyList<String>())
      return true
    }

    try {
      context.contentResolver.openOutputStream(destinationUri, "wt")?.use { output ->
        exportFile.inputStream().use { input ->
          input.copyTo(output)
        }
      } ?: throw IllegalStateException("document provider returned no output stream")
      lifecycleState = "iosmacs Android native bridge: user exported workspace document"
      Log.i(
        "IOSMacsWorkspaceExport",
        "iosmacs Android user document export: uri=$destinationUri bytes=${exportFile.length()}",
      )
      result.success(listOf(destinationUri.toString()))
    } catch (error: Exception) {
      result.error("workspace_export_failed", error.localizedMessage, null)
    }
    return true
  }

  private fun start(result: MethodChannel.Result) {
    // Prefer the NW (no-window-system) Emacs text-terminal binary when available.
    // This binary is built without HAVE_ANDROID restrictions and supports full PTY.
    val nwBinary = NwEmacsRuntime.executablePath(context)
    if (nwBinary != null && !officialTerminalStarted) {
      val dataDir = NwEmacsRuntime.ensureDataExtracted(context)
      val workspaceRoot = prepareWorkspaceRoot()
      val pdumpFile = dataDir?.let {
        NwEmacsRuntime.ensurePdump(
          context,
          File(nwBinary),
          it,
          workspaceRoot,
          context.cacheDir,
        )
      }
      lifecycleState = "iosmacs Android native bridge: GNU Emacs NW PTY terminal starting"
      val nwOutput = nativeRuntime.startNwEmacs(
        nwBinary,
        dataDir?.let { NwEmacsRuntime.loadPath(it) } ?: "",
        dataDir?.let { File(it, "etc").absolutePath } ?: "",
        workspaceRoot.absolutePath,
        context.cacheDir.absolutePath,
        pdumpFile?.absolutePath ?: "",
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
    val bytes = normalizeTerminalInputText(text).toByteArray(Charsets.UTF_8)
    inputBytes += bytes.size
    lifecycleState = "iosmacs Android native bridge: pasted clipboard"
    if (officialTerminalStarted) {
      appendOutput(nativeRuntime.sendOfficialBytes(bytes))
    } else {
      appendOutput(nativeRuntime.pasteBytes(bytes))
    }
    result.success(mapOf("accepted" to true, "byteCount" to bytes.size))
  }

  private fun normalizeTerminalInputText(text: String): String =
    text
      .replace("\r\n", "\n")
      .replace("\r", "\n")
      .replace("\n", "\r")

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

  private fun exportWorkspace(call: MethodCall, result: MethodChannel.Result) {
    val nonInteractive = call.argument<Boolean>("nonInteractive") ?: false
    val root = prepareWorkspaceRoot()
    val exportFiles = prepareWorkspaceExportFiles(root)
    if (!nonInteractive) {
      startUserDocumentExport(exportFiles, result)
      return
    }
    val uris = exportFiles.mapNotNull { file ->
      exportWorkspaceFileToDocumentProvider(file)
    }
    lifecycleState = "iosmacs Android native bridge: exported ${uris.size} workspace item(s)"
    result.success(uris.map { it.toString() })
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

  private fun status(): Map<String, Any> {
    val processProbe = if (officialTerminalStarted) {
      AndroidEmacsProcessProbe(
        status = "deferred",
        output = "Android GNU Emacs process probe deferred while NW PTY terminal is active",
      )
    } else {
      officialRuntime.processProbe(context)
    }
    return mapOf(
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
      "androidEmacsProcessProbeStatus" to processProbe.status,
      "androidEmacsProcessProbeOutput" to processProbe.output,
      "androidEmacsOfficialTerminalStarted" to officialTerminalStarted,
    )
  }

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

  private fun createWorkspaceRootExport(root: File): File {
    val file = File(root, "workspace-root.txt")
    if (!file.exists()) {
      file.writeText("iosmacs Android workspace root: ${root.absolutePath}\n")
    }
    return file
  }

  private fun prepareWorkspaceExportFiles(root: File): List<File> {
    val files = root.listFiles()?.sortedBy { it.name }.orEmpty().filter { it.isFile }
    return when {
      files.isEmpty() -> listOf(createWorkspaceRootExport(root))
      files.size == 1 -> files
      else -> listOf(createWorkspaceZipExport(files))
    }
  }

  private fun createWorkspaceZipExport(files: List<File>): File {
    val zipFile = File(context.cacheDir, "iosmacs/workspace-export.zip")
    zipFile.parentFile?.mkdirs()
    ZipOutputStream(zipFile.outputStream()).use { zip ->
      for (file in files) {
        zip.putNextEntry(ZipEntry(file.name))
        file.inputStream().use { input ->
          input.copyTo(zip)
        }
        zip.closeEntry()
      }
    }
    return zipFile
  }

  private fun startUserDocumentExport(
    exportFiles: List<File>,
    result: MethodChannel.Result,
  ) {
    val exportFile = exportFiles.firstOrNull() ?: createWorkspaceRootExport(prepareWorkspaceRoot())
    if (pendingExportResult != null) {
      result.error("workspace_export_in_progress", "another Android document export is already active", null)
      return
    }
    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
      addCategory(Intent.CATEGORY_OPENABLE)
      type = if (exportFile.extension == "zip") "application/zip" else "application/octet-stream"
      putExtra(Intent.EXTRA_TITLE, exportFile.name)
    }
    pendingExportResult = result
    pendingExportFile = exportFile
    lifecycleState = "iosmacs Android native bridge: presenting document export picker"
    try {
      activity.startActivityForResult(intent, exportDocumentRequestCode)
    } catch (error: Exception) {
      pendingExportResult = null
      pendingExportFile = null
      result.error("workspace_export_picker_unavailable", error.localizedMessage, null)
    }
  }

  private fun exportWorkspaceFileToDocumentProvider(file: File): Uri? {
    val uri = WorkspaceExportProvider.uriFor(context, file.name)
    return try {
      context.contentResolver.openOutputStream(uri, "wt")?.use { output ->
        file.inputStream().use { input ->
          input.copyTo(output)
        }
      } ?: return null
      Log.i(
        "IOSMacsWorkspaceExport",
        "iosmacs Android document-provider export: uri=$uri bytes=${file.length()}",
      )
      uri
    } catch (error: Exception) {
      Log.e(
        "IOSMacsWorkspaceExport",
        "iosmacs Android document-provider export failed: ${error.localizedMessage}",
      )
      null
    }
  }

  private fun ClipData.Item.firstText(): String =
    coerceToText(context)?.toString() ?: ""
}

class WorkspaceExportProvider : ContentProvider() {
  companion object {
    private const val EXPORT_SEGMENT = "exports"

    fun uriFor(context: Context, fileName: String): Uri =
      Uri.Builder()
        .scheme("content")
        .authority("${context.packageName}.workspace_export")
        .appendPath(EXPORT_SEGMENT)
        .appendPath(fileName)
        .build()

    private fun exportRoot(context: Context): File =
      File(context.cacheDir, "iosmacs/document-provider-export").apply {
        mkdirs()
      }
  }

  override fun onCreate(): Boolean = true

  override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
    val context = context ?: throw IllegalStateException("provider context unavailable")
    val file = resolveFile(context, uri)
    val accessMode = if (mode.contains("w")) {
      file.parentFile?.mkdirs()
      ParcelFileDescriptor.MODE_CREATE or
        ParcelFileDescriptor.MODE_TRUNCATE or
        ParcelFileDescriptor.MODE_WRITE_ONLY
    } else {
      ParcelFileDescriptor.MODE_READ_ONLY
    }
    return ParcelFileDescriptor.open(file, accessMode)
  }

  override fun query(
    uri: Uri,
    projection: Array<out String>?,
    selection: String?,
    selectionArgs: Array<out String>?,
    sortOrder: String?,
  ): Cursor {
    val context = context ?: throw IllegalStateException("provider context unavailable")
    val file = resolveFile(context, uri)
    val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
    return MatrixCursor(columns).apply {
      val row = arrayOfNulls<Any>(columns.size)
      columns.forEachIndexed { index, column ->
        row[index] = when (column) {
          OpenableColumns.DISPLAY_NAME -> file.name
          OpenableColumns.SIZE -> file.length()
          else -> null
        }
      }
      addRow(row)
    }
  }

  override fun getType(uri: Uri): String = "application/octet-stream"

  override fun insert(uri: Uri, values: ContentValues?): Uri? = null

  override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

  override fun update(
    uri: Uri,
    values: ContentValues?,
    selection: String?,
    selectionArgs: Array<out String>?,
  ): Int = 0

  private fun resolveFile(context: Context, uri: Uri): File {
    val segments = uri.pathSegments
    require(segments.size == 2 && segments[0] == EXPORT_SEGMENT) {
      "Unsupported workspace export URI: $uri"
    }
    val root = exportRoot(context)
    val file = File(root, segments[1])
    val rootPath = root.canonicalPath
    val filePath = file.canonicalPath
    require(filePath == rootPath || filePath.startsWith("$rootPath/")) {
      "Workspace export URI escapes export root: $uri"
    }
    return file
  }
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
    dumpFile: String,
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
  private const val ASSET_PDUMPER_ENABLED = "iosmacs-nw-pdumper-enabled"
  // Version marker: bump this if the extracted data format changes.
  private const val DATA_VERSION = "6"
  private const val DATA_VERSION_FILE = ".iosmacs_nw_data_version"
  private const val PDUMP_STATUS_FILE = "emacs.pdmp.status"

  // Returns the path to the NW Emacs binary if it has been extracted, else null.
  fun executablePath(context: Context): String? {
    val path = File(context.applicationInfo.nativeLibraryDir, "libemacs_nw.so")
    return if (path.isFile && path.canExecute()) path.absolutePath else null
  }

  fun loadPath(dataRoot: File): String {
    val lispRoot = File(dataRoot, "lisp")
    if (!lispRoot.isDirectory) {
      return ""
    }
    val dirs = mutableListOf(lispRoot)
    lispRoot.listFiles()
      ?.filter { it.isDirectory }
      ?.sortedBy { it.name }
      ?.forEach { dirs += it }
    return dirs.joinToString(File.pathSeparator) { it.absolutePath }
  }

  fun ensurePdump(
    context: Context,
    executable: File,
    dataRoot: File,
    homeDir: File,
    cacheDir: File,
  ): File? {
    if (!pdumperEnabled(context)) {
      return null
    }

    val dumpDir = File(context.filesDir, "iosmacs/emacs-pdmp").apply { mkdirs() }
    val dumpFile = File(dumpDir, "emacs.pdmp")
    val statusFile = File(dumpDir, PDUMP_STATUS_FILE)
    val key = "${executable.length()}:${executable.lastModified()}:$DATA_VERSION"
    val oldStatus = statusFile.takeIf { it.isFile }?.readText().orEmpty()
    if (dumpFile.isFile && oldStatus.contains("key=$key") && oldStatus.contains("status=ok")) {
      Log.i(
        TAG,
        "iosmacs Android GNU Emacs NW pdump reused: ${dumpFile.absolutePath} bytes=${dumpFile.length()}",
      )
      return dumpFile
    }
    if (oldStatus.contains("key=$key") && oldStatus.contains("status=failed")) {
      Log.w(TAG, "Android NW pdump disabled after previous failure: ${statusFile.absolutePath}")
      return null
    }

    dumpDir.listFiles()
      ?.filter { it.name.endsWith(".pdmp") || it.name == PDUMP_STATUS_FILE }
      ?.forEach { it.delete() }

    val lispPath = loadPath(dataRoot)
    val etcDir = File(dataRoot, "etc")
    val dumpRelativeEtcDir = File(dumpDir.parentFile, "etc").apply { mkdirs() }
    val sourceDoc = File(etcDir, "DOC")
    if (sourceDoc.isFile) {
      sourceDoc.copyTo(File(dumpRelativeEtcDir, "DOC"), overwrite = true)
    }
    val startedAt = System.nanoTime()
    val captured = ByteArrayOutputStream()
    return try {
      val process = ProcessBuilder(
        executable.absolutePath,
        "--batch",
        "-l",
        "loadup",
        "--temacs=pdump",
        "--android-nw-pdump-output",
        dumpFile.absolutePath,
        "--bin-dest",
        "not-set",
        "--eln-dest",
        "not-set",
      )
        .directory(dumpDir)
        .redirectErrorStream(true)
        .apply {
          environment()["EMACSLOADPATH"] = lispPath
          environment()["EMACSDATA"] = etcDir.absolutePath
          environment()["EMACSDOC"] = etcDir.absolutePath
          environment()["TERM"] = "dumb"
          environment()["HOME"] = homeDir.absolutePath
          environment()["TMPDIR"] = cacheDir.absolutePath
          environment()["LC_ALL"] = "C"
          environment()["IOSMACS_ANDROID_NW_PDUMP_USE_EMACSLOADPATH"] = "1"
          environment()["IOSMACS_PDMP_ALLOW_REQUIRE_DURING_DUMP"] = "1"
          environment()["IOSMACS_ANDROID_NW_PDUMP_OUTPUT"] = dumpFile.absolutePath
        }
        .start()
      val outputThread = Thread {
        try {
          process.inputStream.use { input -> input.copyTo(captured) }
        } catch (_: Exception) {
          // The timeout path closes the stream while this thread is blocked.
        }
      }
      outputThread.name = "iosmacs Android NW pdump output"
      outputThread.start()
      val finished = process.waitFor(90, TimeUnit.SECONDS)
      if (!finished) {
        process.destroyForcibly()
      }
      outputThread.join(1000)
      val elapsedMs = TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - startedAt)
      if (finished && process.exitValue() == 0 && dumpFile.isFile) {
        statusFile.writeText("status=ok\nkey=$key\nelapsed_ms=$elapsedMs\nbytes=${dumpFile.length()}\n")
        Log.i(
          TAG,
          "iosmacs Android GNU Emacs NW pdump ready: ${dumpFile.absolutePath} bytes=${dumpFile.length()} elapsed_ms=$elapsedMs",
        )
        dumpFile
      } else {
        val status = if (finished) "exit=${process.exitValue()}" else "timeout"
        val snippet = captured.toString(Charsets.UTF_8.name())
          .replace("\r", "\\r")
          .replace("\n", "\\n")
          .take(1000)
        statusFile.writeText("status=failed\nkey=$key\nresult=$status\noutput=$snippet\n")
        Log.w(TAG, "Android NW pdump generation failed: $status output=$snippet")
        null
      }
    } catch (error: Exception) {
      statusFile.writeText("status=failed\nkey=$key\nerror=${error.localizedMessage}\n")
      Log.w(TAG, "Android NW pdump generation error: ${error.localizedMessage}")
      null
    }
  }

  private fun pdumperEnabled(context: Context): Boolean =
    try {
      context.assets.open(ASSET_PDUMPER_ENABLED).use { input ->
        input.readBytes().toString(Charsets.UTF_8).trim() == "1"
      }
    } catch (_: Exception) {
      false
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
