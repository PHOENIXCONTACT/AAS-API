Import-Module .\base64url.psm1

### Semantic IDs (IEC CDD / IDTA Digital Nameplate)
$serialNumberSemanticId = '0173-1#02-AAM556#002' # SerialNumber property
$nameplateV1SemanticId  = '0173-1#01-AHZ713#001' # Digital Nameplate submodel, V1.0

function getSubscriptionKey{
<#
this function asks the user for his subscription key which is necessary to make the API-calls
#>

$subscription = ""
do{
    $subscription = Read-Host "Please enter your subscription key"
    if ($subscription -eq ""){
        Write-Host "key cannot be null. Please enter a valid key"
        }
    }while($subscription -eq "")
return $subscription
}

function getIdentificationLink{
<#
this function asks the user for the identification link (IEC 61406) of the asset, which is printed
on the product as a QR code, e.g. https://i4d.de/a99fd6ef0b73b11d0a6cfde7c1ee76e8
#>

$identificationLink = ""
do{
    $identificationLink = Read-Host "Please enter the identification link, e.g. https://i4d.de/a99fd6ef0b73b11d0a6cfde7c1ee76e8"
    if ($identificationLink -eq ""){
        Write-Host "identification link cannot be null. Please enter a valid link"
        }
    }while($identificationLink -eq "")
return $identificationLink
}

function hasSemanticId($element, $semanticId){
<#
this function checks whether a submodel element or submodel reference carries the given semantic ID
#>
return ($element.semanticId.keys.value -contains $semanticId)
}

function readValue($element){
<#
this function reads the value of a submodel element as text; a MultiLanguageProperty carries one
text per language, so the English one is preferred
#>
if ($element.modelType -eq 'MultiLanguageProperty'){
    $texts = @($element.value)
    $preferred = $texts | Where-Object {$_.language -like 'en*'} | Select-Object -First 1
    if (-not $preferred){
        $preferred = $texts | Select-Object -First 1
    }
    return $preferred.text
}
return $element.value
}

function findSerialNumber($elements){
<#
this function searches the SerialNumber in a list of submodel elements and descends into
collections, so that a nested serial number is found as well
#>
foreach ($element in $elements){
    if ($element.modelType -eq 'Property' -or $element.modelType -eq 'MultiLanguageProperty'){
        if ((hasSemanticId $element $serialNumberSemanticId) -or $element.idShort -eq 'SerialNumber'){
            $value = readValue $element
            if ($value){
                return $value
            }
        }
        continue
    }
    $nested = findSerialNumber $element.value
    if ($nested){
        return $nested
    }
}
return $null
}

$subscription = getSubscriptionKey
$identificationLink = getIdentificationLink

$headers = @{
'Ocp-Apim-Subscription-Key' = $subscription
'Content-Type' = 'application/json'
}

### Lookup Asset and get AasId
# There is no dedicated endpoint for identification links: an IEC 61406 link is resolved by
# passing it as an asset identifier to /lookup/shells.
Write-Host "Lookup Asset with identification link $identificationLink and get AasId"

$identificationLinkEncoded = ConvertTo-Base64Url $identificationLink
$assetLookupResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/lookup/shells?assetIds=$identificationLinkEncoded"
# $assetLookupResponse | ConvertTo-Json -Depth 100
$aasId = $assetLookupResponse.result[0]

if (-not $aasId){
    Write-Host "No AAS found for this identification link."
    return
}

Write-Host "Got AasId $aasId"
$aasIdEncoded = ConvertTo-Base64Url $aasId

### Get AAS by AasId
$shellsAasResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/shells/$aasIdEncoded"
# $shellsAasResponse | ConvertTo-Json -Depth 100

#### Search SubmodelId of the Digital Nameplate
# The API is not consistent about which form of semantic ID it returns - V2.0 uses an
# admin-shell.io URL containing "nameplate", V1.0 the IRDI above - so both are matched, with the
# submodel ID naming convention of this API (".../submodel/Nameplate") as a last fallback.
$nameplateRefs = $shellsAasResponse.submodels | Where-Object {($_.referredSemanticId.keys.value -like '*nameplate*') -or ($_.referredSemanticId.keys.value -contains $nameplateV1SemanticId)}
if (-not $nameplateRefs){
    $nameplateRefs = $shellsAasResponse.submodels | Where-Object {$_.keys.value -like '*/submodel/Nameplate'}
}

if (-not $nameplateRefs){
    Write-Host "The AAS $aasId has no Nameplate submodel, so no serial number is available."
    return
}

$nameplateId = @($nameplateRefs)[0].keys.value
Write-Host "Got Nameplate submodel $nameplateId"
$nameplateIdEncoded = ConvertTo-Base64Url $nameplateId

### Get the serial number out of the Nameplate
$subModelResponse = Invoke-RestMethod -Method Get -Headers $headers -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/submodels/$nameplateIdEncoded"
# $subModelResponse | ConvertTo-Json -Depth 100

$serialNumber = findSerialNumber $subModelResponse.submodelElements

if ($serialNumber){
    Write-Host "Serial number: $serialNumber"
} else {
    Write-Host "The Nameplate carries no serial number - the identification link may refer to a product type rather than a single instance."
}
 