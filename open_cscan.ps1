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
    $maxWait = 20 
    while ($client.Available -eq 0 -and $maxWait -gt 0) {
        Start-Sleep -Milliseconds 100
        $maxWait--
    }

    # 8. Read Response
    if ($client.Available -gt 0) {
        # Create a buffer to hold the incoming data
        $buffer = New-Object byte[] $client.Available
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        
        # Convert bytes to string (UTF-8)
        # Note: Since the server sends a binary header (Length+Type) before the JSON,
        # you might see 5 weird characters/symbols at the start of the string.
        $responseStr = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
        
        Write-Host "------------------------------------------------" -ForegroundColor Cyan
        Write-Host "SERVER RESPONSE:" -ForegroundColor Yellow
        Write-Host $responseStr
        Write-Host "------------------------------------------------" -ForegroundColor Cyan
    }
    else {
        Write-Host "No response received (Timeout)." -ForegroundColor DarkGray
    }
    
    $client.Close()
}
catch {
    Write-Error "Connection failed. Is the server running on port $port?"
}