# =============================================================================
# CONFIGURATION
# =============================================================================
$server = "127.0.0.1"
$port = 32146
$messageType = 1
$filePath = "D:/tmp.nka"

# =============================================================================
# HELPER FUNCTION: HANDLES SENDING AND RECEIVING (ROBUST)
# =============================================================================
function Send-RpcRequest {
    param (
        [System.Net.Sockets.NetworkStream]$stream,
        [string]$jsonPayload,
        [int]$msgType,
        [switch]$MeasureTime
    )

    # --- 1. PREPARE PAYLOAD ---
    $enc = [System.Text.Encoding]::UTF8
    $payloadBytes = $enc.GetBytes($jsonPayload)

    # --- 2. PREPARE HEADER (4 Bytes Length + 1 Byte Type) ---
    $length = $payloadBytes.Length + 1
    $headerLenBytes = [BitConverter]::GetBytes([int]$length)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($headerLenBytes) }

    $fullPacket = $headerLenBytes + [byte]$msgType + $payloadBytes

    # --- 3. SEND ---
    $stream.Write($fullPacket, 0, $fullPacket.Length)
    
    $timer = $null
    if ($MeasureTime) { $timer = [System.Diagnostics.Stopwatch]::StartNew() }

    # --- 4. READ HEADER (4 Bytes) ---
    $headerBuffer = New-Object byte[] 4
    $bytesReadHeader = 0
    while ($bytesReadHeader -lt 4) {
        $read = $stream.Read($headerBuffer, $bytesReadHeader, 4 - $bytesReadHeader)
        if ($read -eq 0) { throw "Connection closed by server during header read." }
        $bytesReadHeader += $read
    }

    # --- 5. PARSE HEADER ---
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($headerBuffer) }
    $totalPayloadLength = [BitConverter]::ToInt32($headerBuffer, 0)

    # --- 6. READ PAYLOAD ---
    $payloadBuffer = New-Object byte[] $totalPayloadLength
    $totalBytesRead = 0
    while ($totalBytesRead -lt $totalPayloadLength) {
        $read = $stream.Read($payloadBuffer, $totalBytesRead, $totalPayloadLength - $totalBytesRead)
        if ($read -eq 0) { throw "Connection closed by server during payload read." }
        $totalBytesRead += $read
    }

    if ($MeasureTime) { $timer.Stop() }

    # --- 7. DECODE RESPONSE ---
    # Skip first byte (Message Type) and decode JSON
    $jsonBytes = $payloadBuffer[1..($payloadBuffer.Length - 1)]
    $responseString = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
    
    # Return a custom object with the string and the elapsed time (if measured)
    return [pscustomobject]@{
        Content = $responseString
        Elapsed = if ($MeasureTime) { $timer.Elapsed.TotalMilliseconds } else { 0 }
    }
}

# =============================================================================
# MAIN LOGIC
# =============================================================================
try {
    Write-Host "Connecting to $server on port $port..." -ForegroundColor Cyan
    $client = New-Object System.Net.Sockets.TcpClient($server, $port)
    $stream = $client.GetStream()
    Write-Host "Connected!" -ForegroundColor Green

    # -------------------------------------------------------------------------
    # STEP 1: OPEN AScan
    # -------------------------------------------------------------------------
    Write-Host "`n[STEP 1] Opening AScan file..." -ForegroundColor Yellow
    
    $jsonOpen = '{"packageName": "agi.ndtkit.api", "className": "NDTKitAScanInterface", "methodName": "openAScan", "parameters": [{"type": "java.lang.String", "value": "' + $filePath + '"}, {"type": "int", "value": "-1"}]}'
    
    $response1 = Send-RpcRequest -stream $stream -jsonPayload $jsonOpen -msgType $messageType
    
    # Parse JSON to extract UUID
    $jsonObj = $response1.Content | ConvertFrom-Json
    
    # ADJUST THIS PROPERTY NAME based on your actual server response structure
    # Common guesses: .id, .uuid, .returnValue, or the object itself if simple
    $extractedUUID = $jsonObj.id 
    
    if (-not $extractedUUID) {
        # Fallback: Try 'uuid' or just look at the object if specific field fails
        $extractedUUID = $jsonObj.uuid
    }
    
    if ($extractedUUID) {
        Write-Host "SUCCESS: AScan Object Created. UUID: $extractedUUID" -ForegroundColor Green
    } else {
        Write-Error "Could not find UUID in response. Response was: $($response1.Content)"
        # Stop script if we don't have a UUID
        exit 
    }

    # -------------------------------------------------------------------------
    # STEP 2: GET ROW DATA (Using Extracted UUID)
    # -------------------------------------------------------------------------
    Write-Host "`n[STEP 2] Fetching Row Data for UUID: $extractedUUID..." -ForegroundColor Yellow

    # Inject the variable $extractedUUID into the JSON string
    $jsonGetRow = '{"packageName":"agi.ndtkit.api.model.frame","className":"NICartographyFrameAScan","methodName":"getRowTofAmp","parameters":[{"type":"agi.ndtkit.api.model.frame.NICartographyFrameAScan","value":"' + $extractedUUID + '"},{"type":"int","value":"0"}]}'
    
    # Send with Time Measurement
    $response2 = Send-RpcRequest -stream $stream -jsonPayload $jsonGetRow -msgType $messageType -MeasureTime

    Write-Host "------------------------------------------------" -ForegroundColor Cyan
    Write-Host "SERVER RESPONSE:" -ForegroundColor White
    # Print the first 200 chars to avoid flooding console if data is huge
    if ($response2.Content.Length -gt 200) {
        Write-Host ($response2.Content.Substring(0, 200) + "... [truncated]") 
    } else {
        Write-Host $response2.Content
    }
    Write-Host "------------------------------------------------" -ForegroundColor Cyan
    
    Write-Host "Round-trip time: $($response2.Elapsed.ToString("N2")) ms" -ForegroundColor Magenta

    # Close Connection
    $client.Close()
}
catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    if ($client) { $client.Close() }
}