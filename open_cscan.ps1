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
    
    # Optional: Read response (simple check)
    if ($client.Available -gt 0) {
        $reader = New-Object System.IO.StreamReader($stream)
        Write-Host "Response: " $reader.ReadToEnd()
    }
    
    $client.Close()
}
catch {
    Write-Error "Connection failed. Is the server running on port $port?"
}