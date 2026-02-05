# 1. Configuration
$server = "127.0.0.1"
$port = 32146
$messageType = 1

# 2. Define the JSON Payload
$json = '{"packageName": "agi.ndtkit.api", "className": "NDTKitCScanInterface", "methodName": "openCScan", "parameters": [{"type": "java.lang.String", "value": "D:/tmp.nkc"}]}'

# 3. Create the Connection
try {
    $client = New-Object System.Net.Sockets.TcpClient($server, $port)
    $stream = $client.GetStream()

    # 4. Prepare the Bytes
    $enc = [System.Text.Encoding]::UTF8
    $payloadBytes = $enc.GetBytes($json)

    # 5. Create the Big-Endian Header (4 Bytes Length + 1 Byte Type)
    $length = $payloadBytes.Length + 1
    $headerLenBytes = [BitConverter]::GetBytes([int]$length)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($headerLenBytes) }

    # 6. Combine all parts into one packet for display and sending
    #    (Header + Type + Payload)
    $fullPacket = $headerLenBytes + [byte]$messageType + $payloadBytes

    # --- PRINT THE FULL BINARY CODE (HEX) ---
    $hexString = [BitConverter]::ToString($fullPacket).Replace("-", "")
    Write-Host "------------------------------------------------" -ForegroundColor Cyan
    Write-Host "SENDING BINARY DATA (HEX):" -ForegroundColor Yellow
    Write-Host $hexString -ForegroundColor White
    Write-Host "------------------------------------------------" -ForegroundColor Cyan

    # 7. Send the full packet
    $stream.Write($fullPacket, 0, $fullPacket.Length)

    Write-Host "Message sent successfully!" -ForegroundColor Green
    
	# --- WAIT FOR RESPONSE ---
    # Wait until at least 5 bytes (Header) are available
    $maxWait = 50 
    while ($client.Available -lt 5 -and $maxWait -gt 0) {
        Start-Sleep -Milliseconds 100
        $maxWait--
    }

	# 8. Read and Parse Response (Matching Python Logic)
    if ($client.Available -ge 5) {
        
        # A. READ LENGTH (First 4 Bytes)
        $lenBytes = New-Object byte[] 4
        $bytesRead = $stream.Read($lenBytes, 0, 4)
        
        # Convert Big-Endian bytes to Int
        if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($lenBytes) }
        $totalLen = [BitConverter]::ToInt32($lenBytes, 0)

        # B. READ TYPE (Next 1 Byte)
        $typeByte = $stream.ReadByte()

        # C. READ PAYLOAD
        # Calculate JSON length (Total - 1 byte for Type)
        $jsonLen = $totalLen - 1
        
        # Read the exact number of bytes for the JSON
        $jsonBytes = New-Object byte[] $jsonLen
        $bytesRead = 0
        while ($bytesRead -lt $jsonLen) {
            $n = $stream.Read($jsonBytes, $bytesRead, $jsonLen - $bytesRead)
            if ($n -eq 0) { break }
            $bytesRead += $n
        }
        
        # Decode ONLY the JSON bytes
        $responseStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
        
        Write-Host "------------------------------------------------" -ForegroundColor Cyan
        Write-Host "SERVER RESPONSE (JSON ONLY):" -ForegroundColor Yellow
        Write-Host $responseStr
        Write-Host "------------------------------------------------" -ForegroundColor Cyan
    }
    else {
        Write-Host "No response received (Timeout or Incomplete Data)." -ForegroundColor DarkGray
    }
    
    $client.Close()
}
catch {
    Write-Error "Connection failed. Is the server running on port $port?"
}