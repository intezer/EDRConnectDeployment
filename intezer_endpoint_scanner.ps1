param(
    [string]$ApiKey,
    [string]$EndpointAnalysisId,
    [string]$LogFolder,
    [string]$Url = "https://analyze.intezer.com",
    [switch]$Help
)

function Show-Help {
    "Usage: .\YourScriptName.ps1 [-ApiKey <api_key>] [-EndpointAnalysisId <endpoint_analysis_id>] [-Url <url>] [-Help]"
    "       .\YourScriptName.ps1 '<json_object>'"
    "       .\YourScriptName.ps1 <api_key> [<endpoint_analysis_id>]"
    "  -ApiKey              Specifies the API key for authentication."
    "  -EndpointAnalysisId  Optional. Specifies the Endpoint Analysis ID."
    "  -LogFolder           Optional. Specifies the log file's folder."
    "  -Url                 Optional. Specifies the Intezer base URL. Default: https://analyze.intezer.com"
    "  -Help                Displays this help message."
    "  <json_object>        Specifies a JSON object with 'api_key' and optionally 'endpoint_analysis_id', 'log_folder' and 'url'."
    "  <api_key>            Specifies the API key as a positional argument."
    "  <endpoint_analysis_id> Optional. Specifies the Endpoint Analysis ID as a second positional argument."
    exit
}

if ($Help) {
    Show-Help
}

if (-not $PSBoundParameters.ContainsKey('ApiKey')) {
    if ($args.Count -gt 0) {
        try {
            $JsonObject = $args[0] | ConvertFrom-Json -ErrorAction Stop
            $IsValidJson = $true
        }
        catch {
            $IsValidJson = $false
        }

        if ($IsValidJson) {
            $ApiKey = $JsonObject.api_key
            $EndpointAnalysisId = $JsonObject.endpoint_analysis_id
            $LogFolder = $JsonObject.log_folder
            if ($JsonObject.url) {
                $Url = $JsonObject.url
            }
        }
        else {
            $ApiKey = $args[0]
            if ($args.Count -gt 1) {
                $EndpointAnalysisId = $args[1]
            }
        }
    }
}

if (-not $ApiKey) {
    Write-Error "ApiKey is required. Use -Help for more information."
    exit 1
}

add-type -AssemblyName System.Net.Http

$Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$Headers.Add("Content-Type", "application/json")
$Body = "{`"api_key`":`"{$ApiKey}`"}"
try {
    $Response = Invoke-RestMethod "$Url/api/v2-0/get-access-token" -Method 'POST' -Headers $Headers -Body $body
}
catch {
    Write-Error "Error authenticating to $Url, make sure it's accessible and you provided a valid api key. Error $PSItem"
    exit 1
}

$Headers.Add("Authorization", "Bearer $($Response.result)")

$TempFolder = ([io.path]::GetTempPath())
$ScannerFilePath = Join-Path $TempFolder "IntezerScanner.exe"

try {
    Invoke-RestMethod -Uri "$Url/api/v2-0/endpoint-scanner/download" -Headers $Headers -OutFile $ScannerFilePath
}
catch {
    Write-Error "Error downloading the scanner. Error $PSItem"
    exit 1
}
if ([string]::IsNullOrEmpty($LogFolder)){
    $LogFolder = Join-Path $TempFolder "IntezerLogs"
}

$ArgumentList = @("-k", $ApiKey, "-l", $LogFolder, "-n", "-u", $Url)

if (![string]::IsNullOrEmpty($EndpointAnalysisId)) {
    $ArgumentList += @("-i", $EndpointAnalysisId)
}

$process = Start-Process -FilePath $ScannerFilePath -NoNewWindow -ArgumentList $ArgumentList -PassThru

if ($null -eq $process) {
    Write-Error "Failed to initiate process: $ScannerFilePath"
    Remove-Item -Path $ScannerFilePath -Force
    exit 2
}

$process.WaitForExit()
Remove-Item -Path $ScannerFilePath -Force
exit $process.ExitCode
