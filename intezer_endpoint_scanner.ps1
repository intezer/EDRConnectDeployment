try {
    $JsonObject = ConvertFrom-Json $args[0] -ErrorAction Stop;
    $IsValidJson = $true;
} catch {
    $IsValidJson = $false;
}

if ($IsValidJson) {
    $ApiKey = $JsonObject | Select-Object -ExpandProperty 'api_key'
} else {
    $ApiKey = $args[0]
}

add-type -AssemblyName System.Net.Http

$Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$Headers.Add("Content-Type", "application/json")
$Body = "{`"api_key`":`"{$ApiKey}`"}"
try {
    $Response = Invoke-RestMethod 'https://analyze.intezer.com/api/v2-0/get-access-token' -Method 'POST' -Headers $Headers -Body $body
}
catch {
    Write-Error "Error authenticating to analyze.intezer.com, make sure it's accessible and you provided a valid api key. Error $PSItem"
    exit 1
}

$Headers.Add("Authorization", "Bearer $($Response.result)")

$TempFolder = ([io.path]::GetTempPath())
$ScannerFilePath = Join-Path $TempFolder "Scanner.exe"

try {
    Invoke-RestMethod -Uri "https://analyze.intezer.com/api/v2-0/endpoint-scanner/download" -Headers $Headers -OutFile $ScannerFilePath
}
catch {
    Write-Error "Error downloading the scanner. Error $PSItem"
    exit 1
}

Start-Process -FilePath $ScannerFilePath -Wait -NoNewWindow -ArgumentList "-k", $ApiKey

Remove-Item -Path $ScannerFilePath -Force
