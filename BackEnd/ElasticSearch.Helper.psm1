<#
[Environment]::SetEnvironmentVariable("ElasticUri", "http://localhost:9200", "User")
$env:ElasticUri = "http://localhost:9200"

Indices API declarations
Index operations: 
https://msdn.microsoft.com/en-us/library/dn798918.aspx
https://netfxharmonics.com/2015/11/learningelasticps
#>
$CURL="Invoke-RestMethod"
if (!(Get-Command $CURL -errorAction SilentlyContinue))
{
  Write-Error "$CURL cmdlet was not found. You may need to upgrade your PowerShell version."
  exit 1
}


if ($global:ElasticUri -eq $null -or $global:ElasticUri -eq ""){
    $global:ElasticUri = $env:ElasticUri
    if ($global:ElasticUri -eq $null -or $global:ElasticUri -eq ""){
        $env:ElasticUri = "http://$($env:computername):9200"
        $global:ElasticUri = $env:ElasticUri
    }
}

$call = {
    param($verb, $params, $body)

    $basicAuthValue = 'Basic fVmBDcxgYWpndYXJj3RpY3NlkZzY3awcmxhcN2Rj'
    #if x-pack is installed, use user:password pair
    if ($env:ElasticUser -ne $null -and $env:ElasticPassword -ne $null) {
        $pair = $env:ElasticUser+":"+$env:ElasticPassword
        $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $basicAuthValue = "Basic $encodedCreds"
    }
    $headers = @{ 
        'Authorization' = $basicAuthValue
    }

    $params = $params.Replace("//","/").Trim('/')

    if ($global:Debug -eq $true){
        Write-Host "`nCalling [$global:ElasticUri/$params]" -f Green
        if($body) {
            if($body) {
                Write-Host "BODY`n--------------------------------------------`n$body`n--------------------------------------------`n" -f Green
            }
        }
    }

    $response = Invoke-WebRequest -Uri "$global:ElasticUri/$params" -method $verb -Headers $headers -ContentType 'application/json' -Body $body
    $response.Content #  | Select StatusCode, StatusDescription, Headers, Content | Write-Output #
}

$get = {
    param($params)
    &$call "Get" $params
}
#&$get
#ConvertFrom-Json (&$get) | ft
$delete = {
    param($params)
    &$call "Delete" $params
}
#&$delete /shared_v1/file,photo/_query?q=* #https://www.elastic.co/guide/en/elasticsearch/plugins/2.0/delete-by-query-usage.html

$put = {
        param($params, $body, $obj)
        if($obj) {
            $body = ConvertTo-Json -Depth 10 $obj
        }
        &$call "Put" $params $body
    }

$post = {
    param($params,  $body, $obj)
    if($obj) {
        $body = ConvertTo-Json -Depth 10 $obj
    }
    &$call "Post" $params $body
}

$add = {
    param($index, $type, $body, $obj)
    if($obj) {
        $body = ConvertTo-Json -Depth 10 $obj -Compress
    }
    &$put "$index/$type" $body
}

$search = {
    param($index, $body, $obj)
    if($obj) {
        &$post "$index/_search" -obj $obj
    }
    elseif ($body) {
        &$get "$index/_search?pretty&source=$body"
    }
}

#The update action allows to directly update a specific document based on a script. https://github.com/elastic/elasticsearch/issues/1583
$update = {
    param($index, $type, $id, $body, $obj)
    if($obj) {
        $body = ConvertTo-Json -Depth 10 $obj -Compress
    }
    &$put "$index/$type/$id/_update" $body
}

#But I preffer replace instead of update
$replace = {
    param($index, $type, $id, $body, $obj)
    if($obj) {
        $body = ConvertTo-Json -Depth 10 $obj -Compress
    }
    &$put "$index/$type/$id" $body
}

$createIndex = {
    param($index, $body, $obj)
    if($obj) {
        $body = ConvertTo-Json -Depth 10 $obj -Compress
    }
    &$put $index $body
}

$mapping = {
    param($index)
    &$get "$index/_mapping?pretty"
}
#&$mapping $indexName

$search = {
    param($index, $type, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj -Compress
    }
    &$get "$index/$type/_search?pretty&source=$json"
}

$cat = {
    &$get "_cat/indices?format=json&pretty"
}
#get storage status summary before index
#ConvertFrom-Json (&$cat) | out-datatable
#Convert-TextToObject (&$cat)
#(ConvertFrom-Json (&$cat)) | select index, docs.count, store.size |  ft
    #| where { $_.index -match '!files' }  `

#Invoke-Elasticsearch -Uri "$global:ElasticUri/$indexName/_cat/indices?v&pretty" # -Method Default -Body
function Invoke-Elasticsearch {
    [CmdletBinding()]
    Param(
        [Uri]$global:ElasticUri,
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = 'Get',
        $Body = $null,
        [PSCredential]$Credential
    )

    $headers = @{}
    if ($Credential -ne $null) {
        $temp = "{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().Password
        $userinfo = "Basic {0}" -f [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($temp))
        $headers.Add("Authorization", $userinfo)
    } elseif ($global:ElasticUri.UserInfo -ne "") {
        $userinfo = "Basic {0}" -f [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($global:ElasticUri.UserInfo))
        $headers.Add("Authorization", $userinfo)
    }

    $response = try { 
        Invoke-WebRequest -Method $Method -Uri $global:ElasticUri -Body $Body -Headers $headers
    } catch {
        if ($_.Exception.Response -eq $null) {
            Write-Error $_.Exception
        }

        $webResponse = New-Object Microsoft.PowerShell.Commands.WebResponseObject($_.Exception.Response, $_.Exception.Response.GetResponseStream())
        $content = [System.Text.Encoding]::UTF8.GetString($webResponse.Content)

        $webResponse | Select StatusCode, StatusDescription, Headers, @{Name="Content"; Expr={$content}}
    } 

    Write-Verbose ("{0} {1}" -f $response.StatusCode, $response.StatusDescription)

    $response | Select StatusCode, StatusDescription, Headers, Content | Write-Output
}

#make all members available for host scope
Export-ModuleMember -Variable * #-function * 
