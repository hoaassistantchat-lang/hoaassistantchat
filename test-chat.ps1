# HOA Assistant - PowerShell Test Script

# Test 1: Health Check
Write-Host "=== Testing Health Endpoint ===" -ForegroundColor Green
$healthResponse = Invoke-WebRequest -Uri "http://localhost:8080/api/chat/health" -Method GET
Write-Host "Health Status: $($healthResponse.Content)" -ForegroundColor Green
Write-Host ""

# Test 2: Chat Request
Write-Host "=== Testing Chat Endpoint ===" -ForegroundColor Green

$chatBody = @{
    message = "What are the pool hours?"
    communityId = 1
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
}

try {
    $chatResponse = Invoke-WebRequest -Uri "http://localhost:8080/api/chat" `
        -Method POST `
        -Headers $headers `
        -Body $chatBody

    Write-Host "Response Status: $($chatResponse.StatusCode)" -ForegroundColor Green
    Write-Host "Response Content:" -ForegroundColor Green
    $chatResponse.Content | ConvertFrom-Json | ConvertTo-Json | Write-Host
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        Write-Host "Response: $($_.Exception.Response.Content)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Green

