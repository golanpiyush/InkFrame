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
import com.frostwire.jlibtorrent.swig.settings_pack
import fi.iki.elonen.NanoHTTPD
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class TorrentStreamingService(private val context: Context) {
    private val TAG = "TorrentStreamingService"
    private var sessionManager: SessionManager? = null
    private var httpServer: VideoStreamServer? = null
    private var isTorrentValid = false
    private val statusLock = Any()
    private var cachedStatus: TorrentStatus? = null
    private var currentTorrentHandle: TorrentHandle? = null

    @Synchronized get
    @Synchronized set
    private var downloadPath: String = ""

     // Thread-safe status holder
    data class SafeStatus(
        val progress: Float = 0f,
        val downloadRate: Int = 0,
        val uploadRate: Int = 0,
        val numSeeds: Int = 0,
        val numPeers: Int = 0,
        val state: TorrentStatus.State? = null,
        val hasMetadata: Boolean = false
    )
    private fun updateCachedStatus(status: TorrentStatus) {
        synchronized(statusLock) {
            cachedStatus = status
        }
    }

    private fun getSafeStatus(): SafeStatus {
        synchronized(statusLock) {
            return cachedStatus?.let {
                SafeStatus(
                    progress = it.progress(),
                    downloadRate = it.downloadRate(),
                    uploadRate = it.uploadRate(),
                    numSeeds = it.numSeeds(),
                    numPeers = it.numPeers(),
                    state = it.state(),
                    hasMetadata = it.hasMetadata()
                )
            } ?: SafeStatus()
        }
    }

    init {
        downloadPath = File(context.cacheDir, "torrents").absolutePath
        File(downloadPath).mkdirs()
        val sp = settings_pack()

        
        // Create optimized settings for jlibtorrent 1.2.19.0
        val settings = SettingsPack().apply {
            // Basic protocol support
            setBoolean(bool_types.enable_incoming_tcp.swigValue(), true)
            setBoolean(bool_types.enable_outgoing_tcp.swigValue(), true)
            setBoolean(bool_types.enable_incoming_utp.swigValue(), true)
            setBoolean(bool_types.enable_outgoing_utp.swigValue(), true)
            
            // DHT - CRITICAL for magnet links with updated bootstrap nodes
            setBoolean(bool_types.enable_dht.swigValue(), true)
            setString(string_types.dht_bootstrap_nodes.swigValue(), 
                "router.bittorrent.com:6881," +
                "router.utorrent.com:6881," +
                "dht.transmissionbt.com:6881," +
                "dht.aelitis.com:6881," +
                "dht.libtorrent.org:25401," +
                "bootstrap.ring.cx:4222," +
                "151.80.120.115:2710")
            
            // Local Service Discovery and UPnP
            setBoolean(bool_types.enable_lsd.swigValue(), true)
            setBoolean(bool_types.enable_upnp.swigValue(), true)
            setBoolean(bool_types.enable_natpmp.swigValue(), true)
            
            // Tracker settings - more aggressive
            setBoolean(bool_types.announce_to_all_trackers.swigValue(), true)
            setBoolean(bool_types.announce_to_all_tiers.swigValue(), true)
            setInteger(int_types.tracker_completion_timeout.swigValue(), 30)
            setInteger(int_types.tracker_receive_timeout.swigValue(), 15)
            setInteger(int_types.tracker_maximum_response_length.swigValue(), 1024 * 1024)
            
            // Connection settings
            setInteger(int_types.connections_limit.swigValue(), 200)
            // setInteger(int_types.connections_limit_global.swigValue(), 200)
            setBoolean(bool_types.allow_multiple_connections_per_ip.swigValue(), true)
            
            // Port configuration - try multiple ports
            setString(string_types.listen_interfaces.swigValue(), "0.0.0.0:6881")
            setInteger(int_types.listen_queue_size.swigValue(), 30)
            
            // Peer exchange and discovery
            setBoolean(bool_types.use_dht_as_fallback.swigValue(), true)
            setInteger(int_types.max_peerlist_size.swigValue(), 3000)
            setInteger(int_types.max_paused_peerlist_size.swigValue(), 1000)
            
            // User agent for better compatibility
            setString(string_types.user_agent.swigValue(), "libtorrent/1.2.19")
            setString(string_types.handshake_client_version.swigValue(), "LT 1.2.19")
            
            // Timeout settings - more aggressive
            setInteger(int_types.peer_connect_timeout.swigValue(), 10)
            setInteger(int_types.request_timeout.swigValue(), 30)
            setInteger(int_types.peer_timeout.swigValue(), 60)
            
            // Metadata settings
            setInteger(int_types.max_metadata_size.swigValue(), 3 * 1024 * 1024) // 3MB
            
            // DHT timing - faster announcements
            setInteger(int_types.dht_announce_interval.swigValue(), 5 * 60) // 5 minutes
            setInteger(int_types.min_announce_interval.swigValue(), 15) // 15 seconds
            
            // Additional optimizations
// sp.set_bool(settings_pack.bool_types.super_seeding.swigValue(), false)
            setBoolean(bool_types.rate_limit_ip_overhead.swigValue(), false)
            setInteger(int_types.choking_algorithm.swigValue(), 1) // fastest_upload
            setInteger(int_types.seed_choking_algorithm.swigValue(), 1) // fastest_upload
        }
        
        // Initialize SessionManager with proper configuration
        sessionManager = SessionManager().apply {
            applySettings(settings)
            start()
            
            // Wait for DHT and session initialization
            Thread.sleep(3000)
        }
        
        Log.d(TAG, "✅ TorrentStreamingService initialized with jlibtorrent 1.2.19.0")
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

    fun startTorrentStreaming(magnetLink: String): String? {
        try {
            stopStreaming()
            
            Log.d(TAG, "🚀 Starting torrent download")
            Log.d(TAG, "🧲 Magnet: ${magnetLink.take(100)}...")
            
            if (!checkNetworkConnectivity()) {
                Log.e(TAG, "❌ No network connection available")
                return null
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
                    when (alert.type()) {
                        AlertType.ADD_TORRENT -> {
                            val addTorrentAlert = alert as AddTorrentAlert
                            currentTorrentHandle = addTorrentAlert.handle()
                            Log.d(TAG, "✅ Torrent added to session")

                            currentTorrentHandle?.let { handle ->

                                updateCachedStatus(handle.status())

                                // Force immediate announce to all trackers
                                handle.forceReannounce()
                                // Set sequential download for streaming
                                handle.setFlags(TorrentFlags.SEQUENTIAL_DOWNLOAD)
                                // Resume if paused
                                handle.resume()
                            }
                        }

                        AlertType.STATE_CHANGED -> {
                            val stateAlert = alert as StateChangedAlert
                            if (isTorrentValid) {
                                try {
                                    val handle = stateAlert.handle()
                                    if (handle.isValid) {
                                        val status = handle.status()
                                        updateCachedStatus(status)
                                        Log.d(TAG, "🔄 State changed: ${stateAlert.prevState} -> ${stateAlert.state}")

                                        // Check if we've moved to downloading state
                                        if (stateAlert.state == TorrentStatus.State.DOWNLOADING &&
                                            metadataReceived && !torrentStarted) {
                                            torrentStarted = true
                                            Log.d(TAG, "🎉 Torrent started downloading!")
                                            latch.countDown()
                                        }
                                    } else {
                                        Log.w(TAG, "⚠️ Torrent handle is invalid.")
                                        isTorrentValid = false
                                    }
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error handling state change", e)
                                    isTorrentValid = false
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
                                torrentInfo = currentTorrentHandle?.torrentFile()
                                metadataReceived = true
                                
                                Log.d(TAG, "🎯 METADATA RECEIVED! Files: ${torrentInfo?.numFiles() ?: 0}")
                                torrentInfo?.let { info ->
                                    Log.d(TAG, "📊 Torrent name: ${info.name()}")
                                    Log.d(TAG, "📊 Total size: ${info.totalSize() / (1024 * 1024)} MB")
                                    
                                    // Find and prioritize video file immediately
                                    val videoFile = findLargestVideoFile(info)
                                    if (videoFile != null) {
                                        prioritizeVideoFile(videoFile.first)
                                        Log.d(TAG, "🎬 Video file prioritized: ${videoFile.second}")
                                    }
                                }
                                
                                // Force resume and reannounce after metadata
                                currentTorrentHandle?.let { handle ->
                                    handle.resume()
                                    handle.forceReannounce()
                                }
                                
                                // If we're already in a good state, signal completion
                                currentTorrentHandle?.status()?.let { status ->
                                    if (status.state() == TorrentStatus.State.DOWNLOADING || 
                                        status.state() == TorrentStatus.State.FINISHED) {
                                        torrentStarted = true
                                        latch.countDown()
                                    }
                                }
                            }
                        }

                        AlertType.TORRENT_CHECKED -> {
                            Log.d(TAG, "✅ Torrent checking completed")
                            currentTorrentHandle?.let { handle ->
                                handle.resume()
                                val status = handle.status()
                                if (metadataReceived && 
                                    (status.state() == TorrentStatus.State.DOWNLOADING || 
                                     status.state() == TorrentStatus.State.FINISHED) && 
                                    !torrentStarted) {
                                    torrentStarted = true
                                    latch.countDown()
                                }
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

                        else -> {
                            // Handle other alert types silently
                        }
                    }
                }
            }
            
            sessionManager?.addListener(tempListener)
            
            // Add magnet directly - don't use fetchMagnet first
            Log.d(TAG, "🔍 Adding magnet link directly to session...")
            try {
                sessionManager?.download(magnetLink, File(downloadPath))
            } catch (e: Exception) {
                Log.e(TAG, "Error adding magnet", e)
                sessionManager?.removeListener(tempListener)
                return null
            }
            
            // Wait for torrent to start with progress updates
            Log.d(TAG, "⏳ Waiting for torrent to start...")
            val startTime = System.currentTimeMillis()
            
            for (i in 1..48) { // 48 * 2.5 seconds = 120 seconds max
                if (latch.await(2500, TimeUnit.MILLISECONDS)) {
                    Log.d(TAG, "🎉 Torrent started successfully!")
                    break
                }
                
                val elapsed = (System.currentTimeMillis() - startTime) / 1000
                
                Log.d(TAG, "⏱️ ${elapsed}s - Peers: $peersFound, Trackers: $trackersResponded")
                
                // Check torrent status
                currentTorrentHandle?.let { handle ->
                    val status = handle.status()
                    Log.d(TAG, "📊 State: ${status.state()}, Seeds: ${status.numSeeds()}, Peers: ${status.numPeers()}")
                    Log.d(TAG, "📊 Progress: ${(status.progress() * 100).toInt()}%, Connections: ${status.numConnections()}")
                    Log.d(TAG, "📊 Has metadata: ${status.hasMetadata()}")
                    
                    // If we have metadata and we're downloading, consider it started
                    if (status.hasMetadata() && 
                        status.state() == TorrentStatus.State.DOWNLOADING && 
                        !torrentStarted) {
                        metadataReceived = true
                        torrentStarted = true
                        torrentInfo = handle.torrentFile()
                        Log.d(TAG, "🎉 Detected successful start via status check!")
                        
                    }
                    
                    // Force periodic announces and resume
                    if (elapsed % 15 == 0L && elapsed > 0) {
                        handle.forceReannounce()
                        handle.resume()
                        Log.d(TAG, "🔄 Forced announce and resume")
                    }
                }
                
                // Show session stats
                sessionManager?.let { session ->
                    val stats = session.stats()
                    Log.d(TAG, "🌐 DHT nodes: ${stats.dhtNodes()}")
                }
            }
            
            sessionManager?.removeListener(tempListener)
            
            if (torrentError != null) {
                Log.e(TAG, "❌ Torrent failed: $torrentError")
                return null
            }
            
            if (!metadataReceived || torrentInfo == null) {
                Log.e(TAG, "❌ TIMEOUT: Failed to start torrent in 120 seconds")
                Log.e(TAG, "📊 Final - Peers: $peersFound, Trackers: $trackersResponded")
                
                currentTorrentHandle?.let { handle ->
                    val status = handle.status()
                    Log.e(TAG, "📊 Final state: ${status.state()}")
                    Log.e(TAG, "📊 Has metadata: ${status.hasMetadata()}")
                }
                
                return null
            }
            
            // Find and prioritize video file
            val videoFile = findLargestVideoFile(torrentInfo)
            if (videoFile == null) {
                Log.e(TAG, "❌ No video file found in torrent")
                return null
            }
            
            Log.d(TAG, "🎬 Found video: ${videoFile.second}")
            prioritizeVideoFile(videoFile.first)
            
            // Start HTTP server
            httpServer = VideoStreamServer(0, File(downloadPath, videoFile.second))
            httpServer?.start()
            
            val port = httpServer?.listeningPort ?: 0
            if (port == 0) {
                Log.e(TAG, "❌ Failed to start HTTP server")
                return null
            }
            
            val streamUrl = "http://127.0.0.1:$port/video"
            Log.d(TAG, "🎉 SUCCESS! Stream URL: $streamUrl")
            
            return streamUrl
            
        } catch (e: Exception) {
            Log.e(TAG, "💥 Exception in torrent streaming", e)
            stopStreaming()
            return null
        }
    }
    
    private fun findLargestVideoFile(torrentInfo: TorrentInfo?): Pair<Int, String>? {
        if (torrentInfo == null) return null
        
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
        
        return if (largestFileIndex >= 0) {
            Log.d(TAG, "🎬 Selected: $largestFileName (${largestSize / (1024 * 1024)} MB)")
            Pair(largestFileIndex, largestFileName)
        } else {
            null
        }
    }
    
    private fun prioritizeVideoFile(fileIndex: Int) {
        currentTorrentHandle?.let { handle ->
            val torrentFile = handle.torrentFile()
            
            // Set file priority - only download the video file
            val filePriorities = Array(torrentFile.numFiles()) { Priority.IGNORE }
            filePriorities[fileIndex] = Priority.SEVEN
            handle.prioritizeFiles(filePriorities)
            
            // Prioritize first and last pieces for streaming
            val totalPieces = torrentFile.numPieces()
            val piecesToPrioritize = minOf(150, (totalPieces * 0.15).toInt().coerceAtLeast(30))
            val endPieces = minOf(50, (totalPieces * 0.05).toInt().coerceAtLeast(10))
            
            val piecePriorities = Array(totalPieces) { Priority.NORMAL }
            
            // High priority for first pieces (for quick start)
            for (i in 0 until piecesToPrioritize) {
                piecePriorities[i] = Priority.SEVEN
            }
            
            // High priority for last pieces (for proper streaming)
            for (i in (totalPieces - endPieces) until totalPieces) {
                piecePriorities[i] = Priority.SIX
            }
            
            handle.prioritizePieces(piecePriorities)
            
            Log.d(TAG, "🎯 Prioritized file $fileIndex, first $piecesToPrioritize pieces, and last $endPieces pieces")
        }
    }
    
    fun getDownloadProgress(): Int {
    synchronized(this) {
        return try {
            currentTorrentHandle?.status()?.progress()?.let { (it * 100).toInt() } ?: 0
        } catch (e: Exception) {
            Log.e(TAG, "Error getting download progress", e)
            0
        }
    }
}
    
    fun getConnectionStats(): String {
        return currentTorrentHandle?.status()?.let { status ->
            "Seeds: ${status.numSeeds()}, Peers: ${status.numPeers()}, " +
            "Progress: ${(status.progress() * 100).toInt()}%, " +
            "Down: ${status.downloadRate() / 1024} KB/s, " +
            "State: ${status.state()}"
        } ?: "No active torrent"
    }
    
    fun stopStreaming() {
    synchronized(this) {
        try {
            httpServer?.stop()
            currentTorrentHandle?.let {
                sessionManager?.remove(it)
                currentTorrentHandle = null  // Clear reference immediately
            }
            Log.d(TAG, "🛑 Streaming stopped")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping streaming", e)
        } finally {
            currentTorrentHandle = null
            httpServer = null
        }
    }
    fun destroy() {
    stopStreaming()
    sessionManager?.stop()
    sessionManager = null
}
}
    
    inner class VideoStreamServer(port: Int, private val videoFile: File) : NanoHTTPD(port) {
        
        override fun serve(session: IHTTPSession): Response {
            return when (session.uri) {
                "/video" -> serveVideoFile(session)
                else -> newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Not Found")
            }
        }
        
        private fun serveVideoFile(session: IHTTPSession): Response {
            try {
                // Wait for some data to be available
                var waitCount = 0
                while (!videoFile.exists() || videoFile.length() < 1024 * 1024) { // Wait for at least 1MB
                    if (waitCount++ > 30) { // 30 seconds max wait
                        return newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "Video not ready")
                    }
                    Thread.sleep(1000)
                }
                
                val fileSize = videoFile.length()
                val rangeHeader = session.headers["range"]
                
                return if (rangeHeader?.startsWith("bytes=") == true) {
                    handleRangeRequest(rangeHeader, fileSize)
                } else {
                    createFullResponse(fileSize)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error serving video", e)
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, MIME_PLAINTEXT, "Error: ${e.message}")
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
    }
}