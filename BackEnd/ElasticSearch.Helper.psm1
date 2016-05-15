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


if ($global:ElasticUri -eq $null){
    $global:ElasticUri = $env:ElasticUri
    if ($global:ElasticUri -eq ""){
        $env:ElasticUri = "http://localhost:9200"
        $global:ElasticUri = $env:ElasticUri
    }
}

$call = {
        param($verb, $params, $body)
        $headers = @{ 
            'Authorization' = 'Basic fVmBDcxgYWpndYXJj3RpY3NlkZzY3awcmxhcN2Rj'
        }

        if ($global:Debug -eq $true){
            Write-Host "`nCalling [$global:ElasticUri/$params]" -f Green
            if($body) {
                if($body) {
                    Write-Host "BODY`n--------------------------------------------`n$body`n--------------------------------------------`n" -f Green
                }
            }
        }

        $response = wget -Uri "$global:ElasticUri/$params" -method $verb -Headers $headers -ContentType 'application/json' -Body $body
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
        param($params, $body)
        &$call "Put" $params $body
    }

$post = {
    param($params,  $body)
    &$call "Post" $params $body
}

$add = {
    param($index, $type, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type" $json
}

#The update action allows to directly update a specific document based on a script. https://github.com/elastic/elasticsearch/issues/1583
$update = {
    param($index, $type, $id, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type/$id/_update" $json
}

#But I preffer replace instead of update
$replace = {
    param($index, $type, $id, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }
    &$post "$index/$type/$id" $json
}

$createIndex = {
        param($index, $json, $obj)
        if($obj) {
            $json = ConvertTo-Json -Depth 10 $obj
        }
        &$post $index $json
    }

$mapping = {
    param($index)
    &$get "$index/_mapping?pretty"
}
#&$mapping $indexName

$search = {
    param($index, $type, $json, $obj)
    if($obj) {
        $json = ConvertTo-Json -Depth 10 $obj
    }

    &$get "$index/$type/_search?pretty&source=$json"
}

$cat = {
    &$get "_cat/indices?v&pretty"
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
