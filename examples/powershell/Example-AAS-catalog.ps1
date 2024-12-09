function convertToBase64($string){
<#
this function converts a given string to a base64 string
TODO change the encoding to base64-url-safe
#>
Write-Verbose $string
$bytes = [System.Text.Encoding]::UTF8.GetBytes($string)
$base64 = [System.Convert]::ToBase64String($bytes)
Write-Verbose "String converted successfully"
Write-Verbose $base64
return $base64
}

function getSubscriptionKey{
<#
this function asks the user for his subscription key which is necessary to make the API-calls
#>

$key = ""
do{
    $key = Read-Host "Please enter your subscription key" 
    if ($key -eq ""){
        Write-Host "key cannot be null. Please enter a valid key"
        }
    }while($key -eq "")
return $key
}

function getAllAAS ($key){
<#
this function calls the getAllASS api with given key
#>
    try{
        $response = invoke-RestMethod -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/shells" -Headers @{"Ocp-Apim-Subscription-Key" = $key}
        Write-Verbose "called Restmethod succesfully"
        Write-Verbose $response
        return $response
    }
    catch{
        #catch HTML -Errors to give more information to the user
        $statusCode = $_.Exception.Response.StatusCode.Value__
        Write-Host "API call failed with status $statusCode and message: $($_.Exception.Message)"
        if ($statusCode -eq 401){
            Write-Host "invalid key, try again"
            return $null
        }
        if ($statusCode -eq 400){
            Write-Host "Server currently not available. Please try again later."
        }
        if ($statusCode -eq 404){
            Write-Host "Server address is not available. Please ask API-Manager"
            Exit
        }
        else{
            throw $_
        }
    }
}

function getAAS ($chosenAAS, $key){
<#
this function calls the getAAS API to give a specific AAS to the user
#>

$encodedId = convertToBase64 -string $chosenAAS
$response = Invoke-RestMethod -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/shells/$($encodedId)?context={context}" -Headers @{"Ocp-Apim-Subscription-Key" = $key}

return $response
}


function getSubmodel($chosenAAS, $chosenSubmodel, $key){
<#
this function calls the getSubmodelAAS API to show the details of a chosen Submodel
#>
Write-Verbose $chosenAAS
Write-Verbose $chosenSubmodel

$encodedId = convertToBase64 -string $chosenAAS
$encodedSubmodelId = convertToBase64 -string $chosenSubmodel
$response = Invoke-RestMethod -Uri "https://api.phoenixcontact.com/dt4i/asset-management/aas/v1/shells/$($encodedId)/submodels/$($encodedSubmodelId)?context={context}"  -Headers @{"Ocp-Apim-Subscription-Key" = $key}

return $response
}

#-----------main--------------

#get the subscription key from user and start first API-call, if key is wrong ask again
$key = getSubscriptionKey
Write-Host "Requesting all AAS. This might take some time. Please wait..." 
$AllAAS = getAllAAS -key $key


while ($AllAAS -eq $null){
    $key = getSubscriptionKey
    $AllAAS = getAllAAS -key $key
    
}


#show all AAS in a numbered list to choose the next
$idList = $AllAAS.result | ForEach-Object { $_.id }
Write-Verbose $idList.Count

$numberedIdList = $idList | ForEach-Object -Begin { $counter = 1 } -Process {
    "{0}: {1}" -f $counter++, $_
}

$numberedIdList | Format-Table -AutoSize


#user chooses a single AAS from the list given in the console
$userInput = Read-Host "Please enter the number of the AAS you would like to see"
while([int]$userInput -lt  1 -or [int]$userInput -gt $idList.Count -or $userInput -notmatch '^\d+$'){
    Write-Host "Invalid input. Please enter a number between 1 and $($idList.Count)."
    $userInput = Read-Host "Please enter the number of the AAS you would like to see"
}

$chosenAAS = $idList[$userInput-1]


#get the single AAS and show with all submodels
$singleAAS = getAAS -chosenAAS $chosenAAS -key $key

write-host -ForegroundColor Yellow  ($singleAAS | ConvertTo-Json -depth 100)

$submodelList = $singleAAS.submodels | ForEach-Object {$_.keys}
$numberedSubmodelList = $submodelList | ForEach-Object -Begin {$counter = 1} -Process{
    "{0}: {1}" -f $counter++, $_
}
$numberedSubmodelList | Format-Table -AutoSize


#read submodelID from values and get said Submodel as a Json in the Console
$submodelAAS = Read-Host "Please enter the Submodel you would like to view"
while([int]$submodelAAS -lt 1 -or [int]$submodelAAS -gt $submodelList.Count -or $submodelAAS -notmatch '^\d+$'){
    Write-Host "Invalid input. Please enter a number between 1 and $($submodelList.Count)."
    $submodelAAS = Read-Host "Please enter the submodel you would like to view"
}

$chosenSubmodel = $submodelList[$submodelAAS-1]
Write-Host $chosenSubmodel

$stringChosenSubmodel = $chosenSubmodel.value
Write-Host $stringChosenSubmodel

#get the submodel and show it as a Json in console
$singelSubmodel= getSubmodel -chosenAAS $chosenAAS -key $key -chosenSubmodel $stringChosenSubmodel
write-host -ForegroundColor Yellow  ($singelSubmodel | ConvertTo-Json -depth 100)

Read-Host "Press enter to terminate this script" 
