package com.example.inkframe

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.inkframe/torrent"
    private val TAG = "MainActivity"
    private var torrentService: TorrentStreamingService? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        torrentService = TorrentStreamingService(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startStreaming" -> {
                    val magnetLink = call.argument<String>("magnetLink")
                    if (magnetLink != null) {
                        startTorrentStreaming(magnetLink, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "Magnet link is required", null)
                    }
                }
                "stopStreaming" -> {
                    stopTorrentStreaming(result)
                }
                "getProgress" -> {
            // Return Int directly, not in a map!
                result.success(torrentService?.getDownloadProgress())
            }
            // Fix 2: Add missing getConnectionStats method call
                "getConnectionStats" -> {
                    result.success(torrentService?.getConnectionStats() ?: "No active torrent")
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun startTorrentStreaming(magnetLink: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                Log.d(TAG, "Starting torrent streaming for: $magnetLink")
                
                val streamUrl = torrentService?.startTorrentStreaming(magnetLink)
                
                withContext(Dispatchers.Main) {
                    if (streamUrl != null) {
                        Log.d(TAG, "Streaming started successfully: $streamUrl")
                        result.success(mapOf(
                            "success" to true,
                            "streamUrl" to streamUrl,
                            "message" to "Streaming started successfully"
                        ))
                    } else {
                        Log.e(TAG, "Failed to start streaming")
                        result.success(mapOf(
                            "success" to false,
                            "message" to "Failed to start torrent streaming"
                        ))
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in startTorrentStreaming", e)
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to false,
                        "message" to "Error: ${e.message}"
                    ))
                }
            }
        }
    }
    
    private fun stopTorrentStreaming(result: MethodChannel.Result) {
        scope.launch {
            try {
                Log.d(TAG, "Stopping torrent streaming")
                torrentService?.stopStreaming()
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "message" to "Streaming stopped successfully"
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping streaming", e)
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to false,
                        "message" to "Error stopping streaming: ${e.message}"
                    ))
                }
            }
        }
    }
    
    private fun getDownloadProgress(result: MethodChannel.Result) {
        scope.launch {
            try {
                val progress = torrentService?.getDownloadProgress() ?: 0
                
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to true,
                        "progress" to progress
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error getting progress", e)
                withContext(Dispatchers.Main) {
                    result.success(mapOf(
                        "success" to false,
                        "progress" to 0,
                        "message" to "Error getting progress: ${e.message}"
                    ))
                }
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        torrentService?.stopStreaming()
        scope.cancel()
    }
}

// Extension functions for easier coroutine handling
suspend fun <T> MethodChannel.Result.successAsync(value: T) = withContext(Dispatchers.Main) {
    success(value)
}

suspend fun MethodChannel.Result.errorAsync(errorCode: String, errorMessage: String?, errorDetails: Any?)
 = withContext(Dispatchers.Main) {
    error(errorCode, errorMessage, errorDetails)
}