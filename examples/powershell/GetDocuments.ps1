Import-Module .\base64url.psm1
$headers = @{
'Ocp-Apim-Subscription-Key' = $subscription
'Content-Type' = 'application/json'
}

### Loopup Asset and get AasId
$assetId = 'https://i4d.de/T/2924016' # MACX MCR-EX-SL-RPSSI-I-SP
$assetIdEncoded = ConvertTo-Base64Url $assetId
$assetLookupResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/lookup/shells?assetIds=$assetIdEncoded" 
# $assetLookupResponse | ConvertTo-Json -Depth 100
$aasId = $assetLookupResponse.result[0]
$aasIdEncoded = ConvertTo-Base64Url $aasId 

### Get AAS by AasId
$shellsAasResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/shells/$aasIdEncoded" 
# $shellsAasResponse | ConvertTo-Json -Depth 100

#### Search SubmodelId of Handover Documentation 
$handoverDocumentIds = $shellsAasResponse.submodels | Where-Object {$_.referredSemanticId.keys.value -EQ '0173-1#01-AHF578#001'}
$handoverDocumentationId = $handoverDocumentIds[0].keys.value
$handoverDocumentationIdEncoded = ConvertTo-Base64Url $handoverDocumentationId

### Get links to Documents
$subModelResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/submodels/$handoverDocumentationIdEncoded" 
# $subModelResponse | ConvertTo-Json -Depth 100

$files = $subModelResponse.submodelElements.value.value | Where-Object {$_.idShort -like 'DigitalFile*'} | select-object -Property value
$files # $files | ForEach-Object {Invoke-WebRequest -Uri  $_.value -OutFile "c:\temp\downloadFiles" -Headers $headers}