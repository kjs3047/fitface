package com.example.fitface

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var loadedModelPath: String? = null
    private var loadedWithVision = false
    private var engine: Engine? = null
    private var pendingImportResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fitface/local_gemma"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "importModel" -> importModel(result)
                "openUrl" -> openUrl(call.argument("url"), result)
                "analyzeSnapshot" -> runInference(
                    prompt = call.argument("prompt"),
                    modelPath = call.argument("modelPath"),
                    imagePaths = listOfNotNull(call.argument("imagePath")),
                    includeImages = true,
                    result = result
                )
                "compareSnapshots" -> runInference(
                    prompt = call.argument("prompt"),
                    modelPath = call.argument("modelPath"),
                    imagePaths = call.argument<List<String>>("imagePaths") ?: emptyList(),
                    includeImages = true,
                    result = result
                )
                "analyzeText",
                "compareText" -> runInference(
                    prompt = call.argument("prompt"),
                    modelPath = call.argument("modelPath"),
                    imagePaths = emptyList(),
                    includeImages = false,
                    result = result
                )
                "analyzePersonalColor" -> runInference(
                    prompt = call.argument("prompt"),
                    modelPath = call.argument("modelPath"),
                    imagePaths = listOfNotNull(call.argument("imagePath")),
                    includeImages = true,
                    result = result
                )
                "analyzePersonalColorText" -> runInference(
                    prompt = call.argument("prompt"),
                    modelPath = call.argument("modelPath"),
                    imagePaths = emptyList(),
                    includeImages = false,
                    result = result
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun openUrl(url: String?, result: MethodChannel.Result) {
        val normalizedUrl = url?.trim().orEmpty()
        if (normalizedUrl.isEmpty()) {
            result.error("OPEN_URL_INVALID_ARGUMENT", "URL is empty.", null)
            return
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(normalizedUrl)).apply {
            addCategory(Intent.CATEGORY_BROWSABLE)
        }
        try {
            startActivity(intent)
            result.success(null)
        } catch (error: Throwable) {
            result.error(
                "OPEN_URL_FAILED",
                error.message ?: "Could not open URL.",
                null
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_IMPORT_MODEL) {
            return
        }

        val result = pendingImportResult ?: return
        pendingImportResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }

        executor.execute {
            try {
                val imported = copyModelToAppStorage(uri)
                mainHandler.post { result.success(imported) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "LOCAL_GEMMA_IMPORT_FAILED",
                        error.message ?: "Local Gemma model import failed.",
                        null
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        executor.execute { closeEngine() }
        executor.shutdown()
        super.onDestroy()
    }

    private fun importModel(result: MethodChannel.Result) {
        if (pendingImportResult != null) {
            result.error(
                "LOCAL_GEMMA_IMPORT_ACTIVE",
                "A Local Gemma model import is already in progress.",
                null
            )
            return
        }

        pendingImportResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/octet-stream",
                    "application/x-litertlm",
                    "application/vnd.litertlm"
                )
            )
        }
        try {
            startActivityForResult(intent, REQUEST_IMPORT_MODEL)
        } catch (error: Throwable) {
            pendingImportResult = null
            result.error(
                "LOCAL_GEMMA_IMPORT_UNAVAILABLE",
                error.message ?: "Android document picker is unavailable.",
                null
            )
        }
    }

    private fun copyModelToAppStorage(uri: Uri): Map<String, Any> {
        val displayName = queryDisplayName(uri)
        val safeFileName = sanitizeFileName(displayName)
        val modelDir = getExternalFilesDir("models") ?: File(filesDir, "models")
        if (!modelDir.exists() && !modelDir.mkdirs()) {
            throw IllegalStateException("Could not create model directory: ${modelDir.absolutePath}")
        }

        val target = File(modelDir, safeFileName)
        closeEngine()
        if (target.exists() && !target.delete()) {
            throw IllegalStateException("Could not replace existing model file: ${target.absolutePath}")
        }

        val copiedBytes = contentResolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalStateException("Could not open selected model file.")
            }
            target.outputStream().use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var totalBytes = 0L
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) {
                        break
                    }
                    output.write(buffer, 0, read)
                    totalBytes += read.toLong()
                }
                totalBytes
            }
        }

        if (copiedBytes <= 0L) {
            target.delete()
            throw IllegalStateException("Selected model file is empty.")
        }

        return mapOf(
            "path" to target.absolutePath,
            "name" to displayName,
            "bytes" to copiedBytes
        )
    }

    private fun queryDisplayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) {
                        val name = cursor.getString(index)
                        if (!name.isNullOrBlank()) {
                            return name
                        }
                    }
                }
            }
        return "gemma-model.litertlm"
    }

    private fun sanitizeFileName(fileName: String): String {
        val baseName = fileName
            .trim()
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('_')
            .ifBlank { "gemma-model" }
        return if (baseName.endsWith(".litertlm", ignoreCase = true)) {
            baseName
        } else {
            "$baseName.litertlm"
        }
    }

    private fun runInference(
        prompt: String?,
        modelPath: String?,
        imagePaths: List<String>,
        includeImages: Boolean,
        result: MethodChannel.Result
    ) {
        executor.execute {
            try {
                val normalizedPrompt = prompt?.trim().orEmpty()
                if (normalizedPrompt.isEmpty()) {
                    throw LocalGemmaException("LOCAL_GEMMA_INVALID_ARGUMENT", "Prompt is empty.")
                }

                val normalizedModelPath = modelPath?.trim().orEmpty()
                if (normalizedModelPath.isEmpty()) {
                    throw LocalGemmaException(
                        "LOCAL_GEMMA_MODEL_MISSING",
                        "Local Gemma model path is not configured."
                    )
                }
                if (!File(normalizedModelPath).isFile) {
                    throw LocalGemmaException(
                        "LOCAL_GEMMA_MODEL_MISSING",
                        "Local Gemma model file was not found: $normalizedModelPath"
                    )
                }

                val normalizedImagePaths = if (includeImages) {
                    imagePaths.filter { it.isNotBlank() }.take(MAX_IMAGES)
                } else {
                    emptyList()
                }
                if (includeImages && normalizedImagePaths.isEmpty()) {
                    throw LocalGemmaException(
                        "LOCAL_GEMMA_IMAGE_MISSING",
                        "Image input was requested but no image path was provided."
                    )
                }
                normalizedImagePaths.forEach { imagePath ->
                    if (!File(imagePath).isFile) {
                        throw LocalGemmaException(
                            "LOCAL_GEMMA_IMAGE_MISSING",
                            "Image file was not found: $imagePath"
                        )
                    }
                }

                val response = generateResponse(
                    modelPath = normalizedModelPath,
                    prompt = normalizedPrompt,
                    imagePaths = normalizedImagePaths,
                    includeImages = includeImages
                )
                mainHandler.post { result.success(extractJsonObject(response)) }
            } catch (error: LocalGemmaException) {
                mainHandler.post { result.error(error.code, error.message, null) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "LOCAL_GEMMA_INFERENCE_FAILED",
                        error.message ?: "Local Gemma inference failed.",
                        null
                    )
                }
            }
        }
    }

    private fun generateResponse(
        modelPath: String,
        prompt: String,
        imagePaths: List<String>,
        includeImages: Boolean
    ): String {
        val currentEngine = ensureEngine(modelPath, includeImages)
        val contents = mutableListOf<Content>()
        for (imagePath in imagePaths) {
            contents.add(Content.ImageFile(imagePath))
        }
        contents.add(Content.Text(prompt))

        currentEngine.createConversation(
            ConversationConfig(
                samplerConfig = SamplerConfig(
                    topK = 32,
                    topP = 0.95,
                    temperature = 0.35
                )
            )
        ).use { conversation ->
            return conversation.sendMessage(Contents.of(contents)).toString()
        }
    }

    private fun ensureEngine(modelPath: String, includeVision: Boolean): Engine {
        val currentEngine = engine
        if (
            currentEngine != null &&
            loadedModelPath == modelPath &&
            loadedWithVision == includeVision
        ) {
            return currentEngine
        }

        closeEngine()
        val newEngine = Engine(
            EngineConfig(
                modelPath = modelPath,
                backend = Backend.GPU(),
                visionBackend = if (includeVision) Backend.GPU() else null,
                maxNumTokens = 4096,
                cacheDir = cacheDir.absolutePath
            )
        )
        newEngine.initialize()
        engine = newEngine
        loadedModelPath = modelPath
        loadedWithVision = includeVision
        return newEngine
    }

    private fun closeEngine() {
        try {
            engine?.close()
        } finally {
            engine = null
            loadedModelPath = null
            loadedWithVision = false
        }
    }

    private fun extractJsonObject(response: String): String {
        val trimmed = response.trim()
        if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
            return trimmed
        }

        val start = trimmed.indexOf('{')
        val end = trimmed.lastIndexOf('}')
        if (start >= 0 && end > start) {
            return trimmed.substring(start, end + 1)
        }
        return trimmed
    }

    private class LocalGemmaException(
        val code: String,
        override val message: String
    ) : Exception(message)

    companion object {
        private const val REQUEST_IMPORT_MODEL = 7041
        private const val MAX_IMAGES = 10
    }
}
