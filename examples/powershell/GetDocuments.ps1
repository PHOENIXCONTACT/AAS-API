param(
    [string]$SubscriptionKey = "",
    [string]$IdentificationLink = "",
    [string]$OutputDirectory = ""
)

Import-Module .\base64url.psm1
. .\config.ps1

# Authenticate against the corporate web proxy with the current Windows account (Kerberos/NTLM).
# Windows PowerShell 5.1 does not do this on its own, so the proxy would block the downloads.
if ($null -ne [System.Net.WebRequest]::DefaultWebProxy) {
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
}

if ($SubscriptionKey -ne "")    { $subscription       = $SubscriptionKey }
elseif ($DefaultSubscriptionKey -ne "") { $subscription = $DefaultSubscriptionKey }
else                            { $subscription       = getSubscriptionKey }

if ($IdentificationLink -ne "") { $identificationLink = $IdentificationLink }
else                            { $identificationLink = getIdentificationLink }

if ($OutputDirectory -ne "")    { $outputDir = $OutputDirectory }
else                            { $outputDir = $DefaultOutputDirectory }

$headers = @{
    'Ocp-Apim-Subscription-Key' = $subscription
    'Content-Type'              = 'application/json'
}

### Lookup Asset and get AasId
Write-Host "Lookup Asset with identification link $identificationLink and get AasId"
$identificationLinkEncoded = ConvertTo-Base64Url $identificationLink
$assetLookupResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/lookup/shells?assetIds=$identificationLinkEncoded"
$aasId = $assetLookupResponse.result[0]

if (-not $aasId) {
    Write-Host "No AAS found for this identification link."
    return
}

Write-Host "Got AasId $aasId"
$aasIdEncoded = ConvertTo-Base64Url $aasId

### Get AAS by AasId
$shellsAasResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/shells/$aasIdEncoded"
# $shellsAasResponse | ConvertTo-Json -Depth 100

#### Search SubmodelId of Handover Documentation
$handoverDocumentIds = $shellsAasResponse.submodels | Where-Object { $_.referredSemanticId.keys.value -EQ '0173-1#01-AHF578#001' }
$handoverDocumentationId = $handoverDocumentIds[0].keys.value

if (-not $handoverDocumentationId) {
    Write-Host "The AAS $aasId has no Handover Documentation submodel."
    return
}

$handoverDocumentationIdEncoded = ConvertTo-Base64Url $handoverDocumentationId

### Get links to Documents
$subModelResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/submodels/$handoverDocumentationIdEncoded"
# $subModelResponse | ConvertTo-Json -Depth 100

$files = $subModelResponse.submodelElements.value.value | Where-Object { $_.idShort -like 'DigitalFile*' } | Select-Object -Property value

if (-not $files) {
    Write-Host "No documents found in the Handover Documentation submodel."
    return
}

### Download documents
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
Write-Host "Saving $(@($files).Count) document(s) to: $outputDir"

$files | ForEach-Object {
    $filename = Split-Path $_.value -Leaf
    $outPath  = Join-Path $outputDir $filename
    # No $headers here: the subscription key is only for api.phoenixcontact.com, not for the file host
    Invoke-WebRequest -Uri $_.value -OutFile $outPath
    Write-Host "  Saved: $outPath"
}
