package com.example.fitface

import android.os.Handler
import android.os.Looper
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fitface/local_gemma"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
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
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        executor.execute { closeEngine() }
        executor.shutdown()
        super.onDestroy()
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
        private const val MAX_IMAGES = 10
    }
}
