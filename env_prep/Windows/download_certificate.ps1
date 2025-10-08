PS C:\Scripts> .\download_certificate.ps1
[2025-10-08 10:25:04.569] [INFO] ========================================
[2025-10-08 10:25:04.577] [INFO] Certificate Download Script - DEBUG MODE
[2025-10-08 10:25:04.579] [INFO] ========================================
[2025-10-08 10:25:04.593] [INFO] Script started with parameters:                                                        [2025-10-08 10:25:04.595] [INFO]   ProxyName: 10.0.0.7                                                                  [2025-10-08 10:25:04.600] [INFO]   MaxRetries: 30                                                                       [2025-10-08 10:25:04.602] [INFO]   RetryDelay: 10                                                                       [2025-10-08 10:25:04.604] [INFO]   Log file: C:\Scripts\download_certificate_debug.log
[2025-10-08 10:25:04.606] [INFO]   Current directory: C:\Scripts
[2025-10-08 10:25:04.608] [INFO]   Script path: C:\Scripts
[2025-10-08 10:25:04.610] [INFO] === Main Execution Phase ===
[2025-10-08 10:25:04.612] [INFO] Step 1: Resolving proxy address...
[2025-10-08 10:25:04.620] [DEBUG] === DNS Resolution Phase ===
[2025-10-08 10:25:04.622] [DEBUG] Input hostname: '10.0.0.7'
[2025-10-08 10:25:04.626] [SUCCESS] Input is already an IP address: 10.0.0.7
[2025-10-08 10:25:04.629] [SUCCESS] Resolved proxy address: 10.0.0.7
[2025-10-08 10:25:04.632] [INFO] Certificate URL: http://10.0.0.7:8080/squid-ca-cert.pem                                [2025-10-08 10:25:04.634] [INFO] Step 2: Testing proxy server connectivity...                                           [2025-10-08 10:25:04.638] [INFO] --- Attempt 1 of 30 ---                                                                [2025-10-08 10:25:04.640] [INFO] Testing connection to 10.0.0.7:8080...                                                 [2025-10-08 10:25:04.648] [DEBUG] === TCP Connection Test ===                                                           [2025-10-08 10:25:04.650] [DEBUG] Testing TCP connection to 10.0.0.7:8080                                               [2025-10-08 10:25:04.655] [DEBUG] TcpClient created successfully                                                        [2025-10-08 10:25:04.663] [DEBUG] Connection attempt initiated                                                          [2025-10-08 10:25:04.668] [DEBUG] Waiting for connection (timeout: 5000ms)
[2025-10-08 10:25:04.673] [SUCCESS] TCP connection to 10.0.0.7:8080 successful
[2025-10-08 10:25:04.675] [SUCCESS] TCP connection successful! Testing HTTP...
[2025-10-08 10:25:04.682] [DEBUG] === HTTP Response Test ===
[2025-10-08 10:25:04.684] [DEBUG] Testing HTTP response from: http://10.0.0.7:8080/squid-ca-cert.pem
[2025-10-08 10:25:04.685] [DEBUG] Sending HEAD request...
[2025-10-08 10:25:04.744] [DEBUG] HTTP response: 200 - Success: True
[2025-10-08 10:25:04.750] [DEBUG] Response headers count: 5
[2025-10-08 10:25:04.750] [SUCCESS] Web server is accessible and responding!
[2025-10-08 10:25:04.750] [INFO] === Certificate Download Phase ===
[2025-10-08 10:25:04.756] [SUCCESS] Proxy server is accessible, proceeding with certificate download...
[2025-10-08 10:25:04.756] [SUCCESS] Script completed successfully!
[2025-10-08 10:25:04.756] [INFO] Debug log saved to: C:\Scripts\download_certificate_debug.log
PS C:\Scripts> .\download_certificate.ps1
[2025-10-08 10:26:31.774] [INFO] ========================================
[2025-10-08 10:26:31.778] [INFO] Certificate Download & Install Script
[2025-10-08 10:26:31.779] [INFO] ========================================
[2025-10-08 10:26:31.780] [INFO] Script started with parameters:
[2025-10-08 10:26:31.780] [INFO]   ProxyName: 10.0.0.7
[2025-10-08 10:26:31.780] [INFO]   MaxRetries: 30
[2025-10-08 10:26:31.780] [INFO]   RetryDelay: 10
[2025-10-08 10:26:31.780] [INFO]   Log file: C:\Scripts\download_certificate_debug.log
[2025-10-08 10:26:31.780] [INFO] === STEP 1: Resolving Proxy Address ===
[2025-10-08 10:26:31.792] [DEBUG] === DNS Resolution Phase ===
[2025-10-08 10:26:31.794] [SUCCESS] Input is already an IP address: 10.0.0.7
[2025-10-08 10:26:31.794] [INFO] Certificate URL: http://10.0.0.7:8080/squid-ca-cert.pem
[2025-10-08 10:26:31.797] [INFO] === STEP 2: Testing Connectivity ===
[2025-10-08 10:26:31.799] [INFO] Attempt 1 of 30
[2025-10-08 10:26:31.828] [DEBUG] Testing TCP connection to 10.0.0.7:8080
[2025-10-08 10:26:31.831] [SUCCESS] TCP connection successful
[2025-10-08 10:26:31.838] [DEBUG] Testing HTTP response from: http://10.0.0.7:8080/squid-ca-cert.pem
[2025-10-08 10:26:31.853] [DEBUG] HTTP response: 200 - Success: True
[2025-10-08 10:26:31.855] [SUCCESS] Proxy server is accessible!
[2025-10-08 10:26:31.857] [INFO] === STEP 3: Downloading Certificate ===
[2025-10-08 10:26:31.862] [INFO] Downloading from: http://10.0.0.7:8080/squid-ca-cert.pem
[2025-10-08 10:26:31.893] [SUCCESS] Certificate downloaded! Size: 1992 bytes
[2025-10-08 10:26:31.901] [SUCCESS] Certificate format validation passed!
[2025-10-08 10:26:31.904] [INFO] === STEP 4: Renaming Certificate ===
[2025-10-08 10:26:31.911] [SUCCESS] Certificate renamed to: squid-ca-cert.crt
[2025-10-08 10:26:31.911] [INFO] === STEP 5: Installing Certificate ===
[2025-10-08 10:26:31.911] [INFO] Installing to Trusted Root Certification Authorities...
[2025-10-08 10:26:31.951] [SUCCESS] Certificate installed successfully!
[2025-10-08 10:26:31.951] [INFO] Certificate Subject: CN=Squid CA, OU=TS, O=TM, L=Cork, S=Cork, C=IE
[2025-10-08 10:26:31.957] [INFO] Certificate Thumbprint: C9D2F5BE43F6282B52D71A5E0BC24ADEB519760D
[2025-10-08 10:26:31.963] [INFO] Certificate Valid Until: 10/06/2035 10:01:12
[2025-10-08 10:26:31.966] [INFO] === STEP 6: Cleanup and Verification ===
[2025-10-08 10:26:31.967] [SUCCESS] Temporary certificate file cleaned up
[2025-10-08 10:26:31.983] [SUCCESS] Certificate verified in Windows certificate store!
[2025-10-08 10:26:31.985] [INFO] Found 1 Squid certificate(s)
[2025-10-08 10:26:31.987] [SUCCESS] ========================================
[2025-10-08 10:26:31.989] [SUCCESS] CERTIFICATE INSTALLATION COMPLETE!
[2025-10-08 10:26:31.993] [SUCCESS] ========================================
[2025-10-08 10:26:31.995] [INFO] Summary:
[2025-10-08 10:26:31.998] [INFO]   âœ… Server accessibility: VERIFIED
[2025-10-08 10:26:32.001] [INFO]   âœ… Certificate download: SUCCESS
[2025-10-08 10:26:32.003] [INFO]   âœ… Certificate installation: SUCCESS
[2025-10-08 10:26:32.005] [INFO]   âœ… Cleanup: COMPLETED
[2025-10-08 10:26:32.007] [SUCCESS] Certificate is ready for proxy usage!