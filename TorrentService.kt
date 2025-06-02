package com.example.inkframe

import android.content.Context
import android.util.Log
import com.frostwire.jlibtorrent.*
import com.frostwire.jlibtorrent.AlertListener
import com.frostwire.jlibtorrent.alerts.*
import com.frostwire.jlibtorrent.SettingsPack
import com.frostwire.jlibtorrent.swig.settings_pack.bool_types
import com.frostwire.jlibtorrent.swig.settings_pack.int_types
import com.frostwire.jlibtorrent.swig.settings_pack.string_types
import fi.iki.elonen.NanoHTTPD
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

class TorrentStreamingService(private val context: Context) {
    private val TAG = "TorrentStreamingService"
    private val serviceLock = ReentrantLock()
    
    // Session components
    private var sessionManager: SessionManager? = null
    private var httpServer: VideoStreamServer? = null
    private var currentTorrentHandle: TorrentHandle? = null
    
    // State tracking
    private val isTorrentActive = AtomicBoolean(false)
    private val isHandleValid = AtomicBoolean(false)
    private var lastKnownProgress = 0f
    private var lastStatusUpdateTime = 0L
    private var downloadPath: String = ""
    
    // Thread-safe status cache
    private data class StatusCache(
        val progress: Float = 0f,
        val downloadRate: Int = 0,
        val uploadRate: Int = 0,
        val numSeeds: Int = 0,
        val numPeers: Int = 0
    )
    private var statusCache = StatusCache()

    init {
        initializeSession()
    }

    private fun initializeSession() {
        serviceLock.withLock {
            downloadPath = File(context.cacheDir, "torrents").absolutePath
            File(downloadPath).mkdirs()
            
            val settings = SettingsPack().apply {
                // DHT configuration
                setBoolean(bool_types.enable_dht.swigValue(), true)
                setString(string_types.dht_bootstrap_nodes.swigValue(), 
                    "router.bittorrent.com:6881," +
                    "router.utorrent.com:6881," +
                    "dht.transmissionbt.com:6881," +
                    "dht.aelitis.com:6881," +
                    "dht.libtorrent.org:25401")
                
                // Local discovery
                setBoolean(bool_types.enable_lsd.swigValue(), true)
                setBoolean(bool_types.enable_upnp.swigValue(), false) // Disable for stability
                setBoolean(bool_types.enable_natpmp.swigValue(), false) // Disable for stability
                
                // Tracker settings
                setBoolean(bool_types.announce_to_all_trackers.swigValue(), true)
                setBoolean(bool_types.announce_to_all_tiers.swigValue(), true)
                setInteger(int_types.tracker_completion_timeout.swigValue(), 30)
                setInteger(int_types.tracker_receive_timeout.swigValue(), 15)
                
                // Connection management - reduced for stability
                setInteger(int_types.connections_limit.swigValue(), 50)
                setBoolean(bool_types.allow_multiple_connections_per_ip.swigValue(), true)
                setString(string_types.listen_interfaces.swigValue(), "0.0.0.0:6881")
                
                // Peer discovery - reduced limits
                setBoolean(bool_types.use_dht_as_fallback.swigValue(), true)
                setInteger(int_types.max_peerlist_size.swigValue(), 500)
                
                // Identification
                setString(string_types.user_agent.swigValue(), "libtorrent/1.2.19")
                setString(string_types.handshake_client_version.swigValue(), "LT 1.2.19")
                
                // Timeouts - increased for stability
                setInteger(int_types.peer_connect_timeout.swigValue(), 15)
                setInteger(int_types.request_timeout.swigValue(), 45)
                setInteger(int_types.peer_timeout.swigValue(), 120)
                
                // Metadata handling - reduced size
                setInteger(int_types.max_metadata_size.swigValue(), 1 * 1024 * 1024)
                setInteger(int_types.dht_announce_interval.swigValue(), 10 * 60)
                setInteger(int_types.min_announce_interval.swigValue(), 30)
                
                // Performance optimizations
                setBoolean(bool_types.rate_limit_ip_overhead.swigValue(), true)
                setInteger(int_types.choking_algorithm.swigValue(), 1) // fastest_upload
                setInteger(int_types.seed_choking_algorithm.swigValue(), 1) // fastest_upload
            }
            
            sessionManager = SessionManager().apply {
                applySettings(settings)
                start()
                // Allow time for session initialization
                Thread.sleep(3000)
            }
            
            Log.d(TAG, "✅ TorrentStreamingService initialized with jlibtorrent 1.2.19.0")
        }
    }

    fun checkNetworkConnectivity(): Boolean {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager
            val activeNetwork = connectivityManager.activeNetworkInfo
            val isConnected = activeNetwork?.isConnectedOrConnecting == true
            Log.d(TAG, "Network connected: $isConnected")
            isConnected
        } catch (e: Exception) {
            Log.e(TAG, "Error checking network connectivity", e)
            false
        }
    }

    // Safe method to check if handle is valid
    private fun safeIsValid(handle: TorrentHandle?): Boolean {
        return try {
            handle?.let { 
                if (isHandleValid.get()) {
                    it.isValid
                } else {
                    false
                }
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking handle validity", e)
            isHandleValid.set(false)
            false
        }
    }

    // Safe method to get torrent status
    private fun safeGetStatus(handle: TorrentHandle?): TorrentStatus? {
        return try {
            if (safeIsValid(handle)) {
                handle?.status()
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting torrent status", e)
            isHandleValid.set(false)
            null
        }
    }

    fun startTorrentStreaming(magnetLink: String): String? {
        return serviceLock.withLock {
            try {
                stopStreaming()
                isTorrentActive.set(true)
                isHandleValid.set(false)
                lastKnownProgress = 0f
                statusCache = StatusCache()
                
                Log.d(TAG, "🚀 Starting torrent download")
                Log.d(TAG, "🧲 Magnet: ${magnetLink.take(100)}...")
                
                if (!checkNetworkConnectivity()) {
                    Log.e(TAG, "❌ No network connection available")
                    return@withLock null
                }
                // Verify download directory
            val downloadDir = File(downloadPath)
            if (!downloadDir.exists() && !downloadDir.mkdirs()) {
                Log.e(TAG, "❌ Failed to create download directory: $downloadPath")
                return@withLock null
            }
            if (!downloadDir.canWrite()) {
                Log.e(TAG, "❌ Download directory not writable: $downloadPath")
                return@withLock null
            }
                
                val latch = CountDownLatch(1)
                var torrentInfo: TorrentInfo? = null
                var torrentError: String? = null
                var metadataReceived = false
                var torrentStarted = false
                var peersFound = 0
                var trackersResponded = 0
                
                val tempListener = object : AlertListener {
                    override fun types(): IntArray = intArrayOf(
                        AlertType.ADD_TORRENT.swig(),
                        AlertType.TORRENT_ERROR.swig(),
                        AlertType.METADATA_RECEIVED.swig(),
                        AlertType.TORRENT_CHECKED.swig(),
                        AlertType.TRACKER_ANNOUNCE.swig(),
                        AlertType.TRACKER_ERROR.swig(),
                        AlertType.TRACKER_REPLY.swig(),
                        AlertType.DHT_REPLY.swig(),
                        AlertType.PEER_CONNECT.swig(),
                        AlertType.PEER_DISCONNECTED.swig(),
                        AlertType.METADATA_FAILED.swig(),
                        AlertType.LISTEN_SUCCEEDED.swig(),
                        AlertType.LISTEN_FAILED.swig(),
                        AlertType.DHT_BOOTSTRAP.swig(),
                        AlertType.STATE_CHANGED.swig()
                    )
                    
                    override fun alert(alert: Alert<*>) {
                        try {
                            when (alert.type()) {
                                AlertType.ADD_TORRENT -> {
                                    val addTorrentAlert = alert as AddTorrentAlert
                                    currentTorrentHandle = addTorrentAlert.handle()
                                    isHandleValid.set(true)
                                    Log.d(TAG, "✅ Torrent added to session")

                                    safeGetStatus(currentTorrentHandle)?.let { status ->
                                        updateStatusCache(status)
                                    }
                                    
                                    try {
                                        currentTorrentHandle?.let { handle ->
                                            if (safeIsValid(handle)) {
                                                handle.forceReannounce()
                                                handle.setFlags(TorrentFlags.SEQUENTIAL_DOWNLOAD)
                                                handle.resume()
                                            }
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error configuring torrent handle", e)
                                    }
                                }

                                AlertType.STATE_CHANGED -> {
                                    val stateAlert = alert as StateChangedAlert
                                    if (isTorrentActive.get()) {
                                        val handle = stateAlert.handle()
                                        safeGetStatus(handle)?.let { status ->
                                            updateStatusCache(status)
                                            
                                            Log.d(TAG, "🔄 State changed: ${stateAlert.prevState} -> ${stateAlert.state}")
                                            
                                            if (stateAlert.state == TorrentStatus.State.DOWNLOADING &&
                                                metadataReceived && !torrentStarted) {
                                                torrentStarted = true
                                                Log.d(TAG, "🎉 Torrent started downloading!")
                                                latch.countDown()
                                            }
                                        }
                                    }
                                }

                                AlertType.LISTEN_SUCCEEDED -> {
                                    val listenAlert = alert as ListenSucceededAlert
                                    Log.d(TAG, "🎧 Listening on: ${listenAlert.address()}:${listenAlert.port()}")
                                }

                                AlertType.LISTEN_FAILED -> {
                                    val listenAlert = alert as ListenFailedAlert
                                    Log.w(TAG, "⚠️ Listen failed on: ${listenAlert.address()}:${listenAlert.port()}")
                                }

                                AlertType.DHT_BOOTSTRAP -> {
                                    Log.d(TAG, "🌐 DHT bootstrap completed")
                                }

                                AlertType.METADATA_RECEIVED -> {
                                    if (!metadataReceived) {
                                        val metadataAlert = alert as MetadataReceivedAlert
                                        currentTorrentHandle = metadataAlert.handle()
                                        isHandleValid.set(true)
                                        
                                        try {
                                            torrentInfo = currentTorrentHandle?.torrentFile()
                                            metadataReceived = true
                                            
                                            Log.d(TAG, "🎯 METADATA RECEIVED! Files: ${torrentInfo?.numFiles() ?: 0}")
                                            torrentInfo?.let { info ->
                                                Log.d(TAG, "📊 Torrent name: ${info.name()}")
                                                Log.d(TAG, "📊 Total size: ${info.totalSize() / (1024 * 1024)} MB")
                                                
                                                val videoFile = findLargestVideoFile(info)
                                                if (videoFile != null) {
                                                    prioritizeVideoFile(videoFile.first)
                                                    Log.d(TAG, "🎬 Video file prioritized: ${videoFile.second}")
                                                }
                                            }
                                            
                                            currentTorrentHandle?.let { handle ->
                                                if (safeIsValid(handle)) {
                                                    handle.resume()
                                                    handle.forceReannounce()
                                                }
                                            }
                                            
                                            safeGetStatus(currentTorrentHandle)?.let { status ->
                                                if (status.state() == TorrentStatus.State.DOWNLOADING || 
                                                    status.state() == TorrentStatus.State.FINISHED) {
                                                    torrentStarted = true
                                                    latch.countDown()
                                                }
                                            }
                                        } catch (e: Exception) {
                                            Log.e(TAG, "Error processing metadata", e)
                                            torrentError = "Metadata processing error: ${e.message}"
                                            latch.countDown()
                                        }
                                    }
                                }

                                AlertType.TORRENT_CHECKED -> {
                                    Log.d(TAG, "✅ Torrent checking completed")
                                    try {
                                        currentTorrentHandle?.let { handle ->
                                            if (safeIsValid(handle)) {
                                                handle.resume()
                                                safeGetStatus(handle)?.let { status ->
                                                    if (metadataReceived && 
                                                        (status.state() == TorrentStatus.State.DOWNLOADING || 
                                                        status.state() == TorrentStatus.State.FINISHED) && 
                                                        !torrentStarted) {
                                                        torrentStarted = true
                                                        latch.countDown()
                                                    }
                                                }
                                            }
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error in torrent checked handler", e)
                                    }
                                }

                                AlertType.TRACKER_ANNOUNCE -> {
                                    val trackerAlert = alert as TrackerAnnounceAlert
                                    Log.d(TAG, "📡 Tracker announce to: ${trackerAlert.trackerUrl()}")
                                }

                                AlertType.TRACKER_REPLY -> {
                                    trackersResponded++
                                    val trackerReply = alert as TrackerReplyAlert
                                    Log.d(TAG, "✅ Tracker responded #$trackersResponded - Peers: ${trackerReply.numPeers()}")
                                }

                                AlertType.TRACKER_ERROR -> {
                                    val trackerAlert = alert as TrackerErrorAlert
                                    Log.w(TAG, "⚠️ Tracker failed: ${trackerAlert.trackerUrl()} - ${trackerAlert.errorMessage()}")
                                }

                                AlertType.DHT_REPLY -> {
                                    Log.d(TAG, "🔍 DHT reply received")
                                }

                                AlertType.PEER_CONNECT -> {
                                    peersFound++
                                    val peerAlert = alert as PeerConnectAlert
                                    Log.d(TAG, "🤝 Peer connected #$peersFound - ${peerAlert.endpoint()}")
                                }

                                AlertType.PEER_DISCONNECTED -> {
                                    Log.d(TAG, "👋 Peer disconnected")
                                }

                                AlertType.METADATA_FAILED -> {
                                    val metadataFailed = alert as MetadataFailedAlert
                                    torrentError = "Metadata failed: ${metadataFailed.error}"
                                    Log.e(TAG, "❌ $torrentError")
                                    latch.countDown()
                                }

                                AlertType.TORRENT_ERROR -> {
                                    val errorAlert = alert as TorrentErrorAlert
                                    torrentError = errorAlert.error().message()
                                    Log.e(TAG, "💥 Fatal torrent error: $torrentError")
                                    latch.countDown()
                                }

                                else -> {}
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error processing alert", e)
                        }
                    }
                }
                
                sessionManager?.addListener(tempListener)
                
                Log.d(TAG, "🔍 Adding magnet link directly to session...")
                try {
                    sessionManager?.download(magnetLink, File(downloadPath))
                } catch (e: Exception) {
                    Log.e(TAG, "Error adding magnet", e)
                    sessionManager?.removeListener(tempListener)
                    return@withLock null
                }
                
                Log.d(TAG, "⏳ Waiting for torrent to start...")
                val startTime = System.currentTimeMillis()
                
                for (i in 1..48) {
                    if (latch.await(2500, TimeUnit.MILLISECONDS)) {
                        Log.d(TAG, "🎉 Torrent started successfully!")
                        break
                    }
                    
                    val elapsed = (System.currentTimeMillis() - startTime) / 1000
                    Log.d(TAG, "⏱️ ${elapsed}s - Peers: $peersFound, Trackers: $trackersResponded")
                    
                    try {
                        safeGetStatus(currentTorrentHandle)?.let { status ->
                            Log.d(TAG, "📊 State: ${status.state()}, Seeds: ${status.numSeeds()}, Peers: ${status.numPeers()}")
                            Log.d(TAG, "📊 Progress: ${(status.progress() * 100).toInt()}%, Connections: ${status.numConnections()}")
                            Log.d(TAG, "📊 Has metadata: ${status.hasMetadata()}")
                            
                            if (status.hasMetadata() && 
                                status.state() == TorrentStatus.State.DOWNLOADING && 
                                !torrentStarted) {
                                metadataReceived = true
                                torrentStarted = true
                                torrentInfo = currentTorrentHandle?.torrentFile()
                                Log.d(TAG, "🎉 Detected successful start via status check!")
                            }
                            
                            if (elapsed % 15 == 0L && elapsed > 0) {
                                currentTorrentHandle?.let { handle ->
                                    if (safeIsValid(handle)) {
                                        handle.forceReannounce()
                                        handle.resume()
                                        Log.d(TAG, "🔄 Forced announce and resume")
                                    }
                                }
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in status check loop", e)
                    }
                    
                    sessionManager?.let { session ->
                        try {
                            val stats = session.stats()
                            Log.d(TAG, "🌐 DHT nodes: ${stats.dhtNodes()}")
                        } catch (e: Exception) {
                            Log.e(TAG, "Error getting session stats", e)
                        }
                    }
                }
                
                sessionManager?.removeListener(tempListener)
                
                if (torrentError != null) {
                    Log.e(TAG, "❌ Torrent failed: $torrentError")
                    return@withLock null
                }
                
                if (!metadataReceived || torrentInfo == null) {
                    Log.e(TAG, "❌ TIMEOUT: Failed to start torrent in 120 seconds")
                    Log.e(TAG, "📊 Final - Peers: $peersFound, Trackers: $trackersResponded")
                    
                    try {
                        safeGetStatus(currentTorrentHandle)?.let { status ->
                            Log.e(TAG, "📊 Final state: ${status.state()}")
                            Log.e(TAG, "📊 Has metadata: ${status.hasMetadata()}")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting final status", e)
                    }
                    
                    return@withLock null
                }
                
                val videoFile = findLargestVideoFile(torrentInfo)
    if (videoFile == null) {
        Log.e(TAG, "❌ No video file found in torrent")
        return@withLock null
    }
                
                Log.d(TAG, "🎬 Found video: ${videoFile.second}")
                val videoFilePath = File(downloadPath, videoFile.second)
            
            // Log file existence and size
            Log.d(TAG, "📁 File exists: ${videoFilePath.exists()}, Size: ${if (videoFilePath.exists()) videoFilePath.length() else 0} bytes")
            
            prioritizeVideoFile(videoFile.first)
            
            httpServer = VideoStreamServer(0, videoFilePath)
                httpServer?.start()
                
                val port = httpServer?.listeningPort ?: 0
                if (port == 0) {
                    Log.e(TAG, "❌ Failed to start HTTP server")
                    return@withLock null
                }
                
                val streamUrl = "http://127.0.0.1:$port/video"
                Log.d(TAG, "🎉 SUCCESS! Stream URL: $streamUrl")
                
                return@withLock streamUrl
                
            } catch (e: Exception) {
                Log.e(TAG, "💥 Exception in torrent streaming", e)
                stopStreaming()
                return@withLock null
            }
        }
    }
    
    private fun updateStatusCache(status: TorrentStatus) {
        try {
            lastKnownProgress = status.progress()
            statusCache = StatusCache(
                progress = status.progress(),
                downloadRate = status.downloadRate(),
                uploadRate = status.uploadRate(),
                numSeeds = status.numSeeds(),
                numPeers = status.numPeers()
            )
            lastStatusUpdateTime = System.currentTimeMillis()
        } catch (e: Exception) {
            Log.e(TAG, "Error updating status cache", e)
        }
    }
    
    private fun findLargestVideoFile(torrentInfo: TorrentInfo?): Pair<Int, String>? {
        if (torrentInfo == null) return null
        
        return try {
            val videoExtensions = listOf(
                ".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm",
                ".mpg", ".mpeg", ".m4v", ".3gp", ".ts", ".m2ts", ".vob"
            )
            
            Log.d(TAG, "📁 Files in torrent (${torrentInfo.numFiles()} total):")
            var largestSize = 0L
            var largestFileIndex = -1
            var largestFileName = ""
            
            val fileStorage = torrentInfo.files()
            for (i in 0 until torrentInfo.numFiles()) {
                val fileName = fileStorage.fileName(i)
                val fileSize = fileStorage.fileSize(i)
                
                Log.d(TAG, "   $i: $fileName (${fileSize / (1024 * 1024)} MB)")
                
                val isVideo = videoExtensions.any { ext ->
                    fileName.lowercase().endsWith(ext)
                }
                
                val isLikelyVideo = isVideo || 
                    (fileSize > 50_000_000 && 
                     !fileName.lowercase().contains("sample") &&
                     !fileName.lowercase().contains("trailer"))
                
                if (isLikelyVideo && fileSize > largestSize) {
                    largestSize = fileSize
                    largestFileIndex = i
                    largestFileName = fileName
                }
            }
            
            if (largestFileIndex >= 0) {
                Log.d(TAG, "🎬 Selected: $largestFileName (${largestSize / (1024 * 1024)} MB)")
                Pair(largestFileIndex, largestFileName)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error finding video file", e)
            null
        }
    }
    
    private fun prioritizeVideoFile(fileIndex: Int) {
        try {
            currentTorrentHandle?.let { handle ->
                if (!safeIsValid(handle)) return
                
                val torrentFile = handle.torrentFile()
                val filePriorities = Array(torrentFile.numFiles()) { Priority.IGNORE }
                filePriorities[fileIndex] = Priority.SEVEN
                handle.prioritizeFiles(filePriorities)
                
                val totalPieces = torrentFile.numPieces()
                val piecesToPrioritize = minOf(150, (totalPieces * 0.15).toInt().coerceAtLeast(30))
                val endPieces = minOf(50, (totalPieces * 0.05).toInt().coerceAtLeast(10))
                
                val piecePriorities = Array(totalPieces) { Priority.NORMAL }
                
                for (i in 0 until piecesToPrioritize) {
                    piecePriorities[i] = Priority.SEVEN
                }
                
                for (i in (totalPieces - endPieces) until totalPieces) {
                    piecePriorities[i] = Priority.SIX
                }
                
                handle.prioritizePieces(piecePriorities)
                
                Log.d(TAG, "🎯 Prioritized file $fileIndex, first $piecesToPrioritize pieces, and last $endPieces pieces")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error prioritizing video file", e)
        }
    }
    
    fun getDownloadProgress(): Int {
        return serviceLock.withLock {
            try {
                // Return cached progress without accessing native objects
                (lastKnownProgress * 100).toInt().coerceIn(0, 100)
            } catch (e: Exception) {
                Log.e(TAG, "Error getting download progress", e)
                0
            }
        }
    }
    
    fun getConnectionStats(): String {
        return serviceLock.withLock {
            "Progress: ${(lastKnownProgress * 100).toInt()}%, " +
            "Seeds: ${statusCache.numSeeds}, Peers: ${statusCache.numPeers}, " +
            "Down: ${statusCache.downloadRate / 1024} KB/s"
        }
    }
    
    fun stopStreaming() {
        serviceLock.withLock {
            try {
                isTorrentActive.set(false)
                isHandleValid.set(false)
                
                httpServer?.stop()
                httpServer = null
                
                currentTorrentHandle?.let { handle ->
                    try {
                        // Don't check isValid here, just try to remove
                        sessionManager?.remove(handle)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error removing torrent from session", e)
                    }
                }
                currentTorrentHandle = null
                
                // Clean up downloaded files
                try {
                    File(downloadPath).listFiles()?.forEach { file ->
                        if (file.isFile) {
                            file.delete()
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error cleaning up files", e)
                }
                
                Log.d(TAG, "🛑 Streaming stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping streaming", e)
            }
        }
    }
    
    fun destroy() {
        serviceLock.withLock {
            try {
                stopStreaming()
                
                sessionManager?.let { session ->
                    try {
                        session.stop()
                    } catch (e: Exception) {
                        Log.e(TAG, "Error stopping session manager", e)
                    }
                }
                sessionManager = null
                
                // Clean up download directory
                try {
                    File(downloadPath).deleteRecursively()
                } catch (e: Exception) {
                    Log.e(TAG, "Error cleaning download directory", e)
                }
                
                Log.d(TAG, "🔌 Service destroyed")
            } catch (e: Exception) {
                Log.e(TAG, "Error in destroy", e)
            }
        }
    }
    
    inner class VideoStreamServer(port: Int, private val videoFile: File) : NanoHTTPD(port) {
    private var isReady = false
    private var fileMonitorThread: Thread? = null
    
    init {
        startFileMonitor()
    }
    
    private fun startFileMonitor() {
        fileMonitorThread = Thread {
            try {
                Log.d(TAG, "🔍 Starting file monitor for ${videoFile.absolutePath}")
                var lastSize = 0L
                var sameSizeCount = 0
                var notFoundCount = 0
                val startTime = System.currentTimeMillis()
                val maxWaitTime = 120000L // 120 seconds
                
                while (!isReady && System.currentTimeMillis() - startTime < maxWaitTime) {
                    if (videoFile.exists()) {
                        val currentSize = videoFile.length()
                        
                        // File is considered ready if:
                        // 1. It has at least 1MB of data, AND
                        // 2. Either:
                        //    a. The size is increasing, OR
                        //    b. The size has been stable for 5 seconds
                        if (currentSize > 1024 * 1024) {
                            if (currentSize > lastSize) {
                                Log.d(TAG, "✅ File ready: ${currentSize / (1024 * 1024)} MB")
                                isReady = true
                            } else if (currentSize == lastSize) {
                                sameSizeCount++
                                if (sameSizeCount >= 5) {
                                    Log.d(TAG, "✅ File ready (stable size): ${currentSize / (1024 * 1024)} MB")
                                    isReady = true
                                }
                            }
                        }
                        lastSize = currentSize
                        notFoundCount = 0
                    } else {
                        notFoundCount++
                        if (notFoundCount % 10 == 0) {
                            Log.d(TAG, "📁 File still not found (attempt $notFoundCount)")
                        }
                    }
                    
                    Thread.sleep(1000)
                }
                
                if (!isReady) {
                    if (videoFile.exists()) {
                        Log.e(TAG, "❌ File never reached ready state: ${videoFile.length()} bytes")
                    } else {
                        Log.e(TAG, "❌ File never appeared at ${videoFile.absolutePath}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "File monitor error", e)
            } finally {
                Log.d(TAG, "🔍 File monitor stopped")
            }
        }.apply { start() }
    }
    
    override fun serve(session: IHTTPSession): Response {
        return when (session.uri) {
            "/video" -> serveVideoFile(session)
            else -> newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not Found")
        }
    }
    
    private fun serveVideoFile(session: IHTTPSession): Response {
        try {
            if (!isReady) {
                Log.d(TAG, "⏳ Video not ready yet, returning 503")
                return newFixedLengthResponse(
                    Response.Status.SERVICE_UNAVAILABLE,
                    MIME_PLAINTEXT,
                    "Video not ready yet"
                ).apply {
                    addHeader("Retry-After", "2")
                }
            }
            
            val fileSize = videoFile.length()
            val rangeHeader = session.headers["range"]
            
            return if (rangeHeader?.startsWith("bytes=") == true) {
                handleRangeRequest(rangeHeader, fileSize)
            } else {
                createFullResponse(fileSize)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error serving video", e)
            return newFixedLengthResponse(
                Response.Status.INTERNAL_ERROR, 
                MIME_PLAINTEXT, 
                "Error: ${e.message}"
            )
        }
    }
    
    private fun handleRangeRequest(rangeHeader: String, fileSize: Long): Response {
        val ranges = rangeHeader.substring(6).split("-")
        val start = ranges[0].toLongOrNull() ?: 0
        val end = ranges.getOrNull(1)?.toLongOrNull() ?: (fileSize - 1)
        
        val actualEnd = minOf(end, fileSize - 1)
        val contentLength = actualEnd - start + 1
        
        val fis = FileInputStream(videoFile).apply { skip(start) }
        
        return newFixedLengthResponse(
            Response.Status.PARTIAL_CONTENT,
            getMimeType(videoFile.name),
            fis,
            contentLength
        ).apply {
            addHeader("Accept-Ranges", "bytes")
            addHeader("Content-Range", "bytes $start-$actualEnd/$fileSize")
            addHeader("Content-Length", contentLength.toString())
            addHeader("Cache-Control", "no-cache")
        }
    }
    
    private fun createFullResponse(fileSize: Long): Response {
        return newChunkedResponse(
            Response.Status.OK,
            getMimeType(videoFile.name),
            FileInputStream(videoFile)
        ).apply {
            addHeader("Accept-Ranges", "bytes")
            addHeader("Content-Length", fileSize.toString())
            addHeader("Cache-Control", "no-cache")
        }
    }
    
    private fun getMimeType(fileName: String): String {
        return when (fileName.substringAfterLast(".").lowercase()) {
            "mp4" -> "video/mp4"
            "avi" -> "video/x-msvideo"
            "mkv" -> "video/x-matroska"
            "mov" -> "video/quicktime"
            "wmv" -> "video/x-ms-wmv"
            "flv" -> "video/x-flv"
            "webm" -> "video/webm"
            "mpg", "mpeg" -> "video/mpeg"
            else -> "video/mp4"
        }
    }
    
    override fun stop() {
        fileMonitorThread?.interrupt()
        super.stop()
    }
}}
