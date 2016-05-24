$resource = "https://apps.novagroup.com.au/Search/api/"
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Schema%3A" -UseDefaultCredentials

$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=OptionsGroup%3A" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Extension%" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Extension%3Ashared" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Extension%3Asource" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Modified%3A" -UseDefaultCredentials

$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Scope%3A" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Scope%3Ashared" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Scope%3Asource" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Scope%3Aacronym" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Scope%3Aopenair" -UseDefaultCredentials
$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Scope%3Apeople" -UseDefaultCredentials

$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Aircraft%3A" -UseDefaultCredentials
foreach ($value in $result | Select -ExpandProperty PropertyValue){
    [string]$url = "$($resource)Options/?id=Aircraft" + [System.Web.HttpUtility]::UrlEncode(":$($value)")
    #$url
    $result2 = Invoke-RestMethod -Method Get -Uri $url -UseDefaultCredentials
}

$result = Invoke-RestMethod -Method Get -Uri "$($resource)Options/?id=Property%3A" -UseDefaultCredentials -TimeoutSec 120
foreach ($value in $result | Select -ExpandProperty PropertyValue){
    [string]$url = "$($resource)Options/?id=Property" + [System.Web.HttpUtility]::UrlEncode(":$($value)")
    #$url
    $result2 = Invoke-RestMethod -Method Get -Uri $url -UseDefaultCredentials -TimeoutSec 120
}

#$apiKey = "SomeKey"
#Invoke-RestMethod -Method Get -Uri $resource -Header @{ "X-ApiKey" = $apiKey }
#Invoke-RestSPO $Url Post $UserName $Password $listMetadata $contextInfo.GetContextWebInformation.FormDigestValue