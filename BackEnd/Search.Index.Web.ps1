<#
Unit tests:
    cd C:\Search\Scripts
    &$delete "web_v1"

    .\Search.Index.Web.ps1 -WebSite "https://www.tenders.gov.au/"-RootPath "C:\Search\Import\AusTender" -delimeter "	" -keyFieldName "CN ID" -indexName "web_v1" -aliasName "web" -typeName "austender" -NewIndex
        -fieldTypes "text,keyword,keyword,date,date,keyword,date,date,double,text,keyword,keyword,keyword,keyword,keyword,text,keyword,keyword,text,keyword,text,text,text,text,keyword,keyword,keyword,keyword,keyword,text,text,keyword"

    .\Search.Index.Web.ps1 -WebSite "https://www.tenders.gov.au/"-RootPath "C:\Search\Import\AusTender" -delimeter "	" -keyFieldName "CN ID" -indexName "web_v1" -aliasName "web" -typeName "austender" -NewIndex
        usign keyFieldName "CN ID" causes recursive ref issue:
         {
          "error": {
            "root_cause": [
              {
                "type": "circuit_breaking_exception",
                "reason": "[parent] Data too large, data for [<http_request>] would be larger than limit of [727213670/693.5mb]",
                "bytes_wanted": 727223400,
                "bytes_limit": 727213670
              }
            ],
            "type": "circuit_breaking_exception",
            "reason": "[parent] Data too large, data for [<http_request>] would be larger than limit of [727213670/693.5mb]",
            "bytes_wanted": 727223400,
            "bytes_limit": 727213670
          },
          "status": 503
        }

To test logstash in interactive mode use command: logstash.bat -e 'input { stdin { } } output { stdout {} }'
    logstash-plugin.bat list
    logstash-plugin.bat install logstash-filter-csv

    logstash -e 'input { stdin { } } output { elasticsearch { host => localhost } }'
    logstash -e 'input { stdin {} } output { stdout { codec => rubydebug } }'

Test your configuration use this command:
    logstash.bat -f "C:\Search\Import\AusTender\logstash-austender.conf" --configtest
Expected result: Configuration OK
Unexpected error: The signal HUP is in use by the JVM and will not work correctly on this platform
#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [string]$WebSite ,
    [string]$RootPath,
    [string]$delimeter,
    [string[]]$fieldTypes, #fields types for precise data conversion "int,keyword,text,date"
    [string]$keyFieldName,
    [string]$indexName,
    [string]$aliasName,
    [string]$typeName,
    [int]$MaxFileBiteSize = 1000000,  #~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.

    #[parameter(parametersetname="indexSwitches")]
    [switch]$NewIndex
)

function Main(){
    Clear-Host

    [System.Net.ServicePointManager]::CheckCertificateRevocationList = $false;
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true; };

    Add-Type @"
  using System.Net;
  using System.Security.Cryptography.X509Certificates;
  public class TrustAllCertsPolicy : ICertificatePolicy {
     public bool CheckValidationResult(
      ServicePoint srvPoint, X509Certificate certificate,
      WebRequest request, int certificateProblem) {
      return true;
    }
  }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    $uri = "$($WebSite)?event=public.reports.listCNWeeklyExport"
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore test ssl certificate warning
    try{
        $HTML = Invoke-WebRequest -Uri "$uri" -Method Get -ContentType "text/html;charset=UTF-8" -UseDefaultCredentials

        #load new files
        foreach($link in $HTML.Links){
            if ($link.href.StartsWith("?event=public.reports.downloadCNWeeklyExport&amp;CNWeeklyExportUUID=")){
                $filePath = $fileDir.Trim('\') + "\"+ $link.innerText + ".csv"
                if (!(Test-Path $filePath)){
                    $uri = $WebSite + $link.href.Replace("&amp;","&")
                    Write-Output "Downloading file  $uri ..."
            
                    (New-Object Net.WebClient).DownloadFile($uri,$filePath);
                }
            }
        }
    }
    catch{}

    [bool]$firstRecord = $true
    #index all files
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}

    #index helper functions
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose
    #&$get
    #&$call "Get" "/_cluster/state"
    [int]$rowcount = 0
    [string]$BulkBody = ""
    Get-ChildItem $RootPath -Filter "*.csv" -File -Force -ErrorAction SilentlyContinue |
        Where-Object {$_ -is [IO.FileInfo]} |
        % {
            $filePath = $_.FullName.ToLower()
            $file = Get-Content $filePath
            $recordType = $file[0].Trim()
            $headers = $file[2] -split $delimeter
            $types = $fieldTypes -split ','
                                    

            if ($firstRecord -eq $true -and $NewIndex.IsPresent){
                try{
                    &$delete $indexName 
                }
                catch{}

                $dataTypes = New-Object PSObject
                for($i=0; $i -lt $headers.count;$i++){
                    if ($headers[$i] -ne ""){
                        $name = $headers[$i].TrimStart('=').Trim('"').Trim()
                        $name = $name -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                        $name = $name -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                        $name = $name -replace '[\,\.\\/''~?!*“"%&•â€¢©ø\[\]{}\(\)]', ' ' #special symbols and punctuation
                        $name = $name -replace '\s+', ' ' #remove extra spaces
                        $headers[$i] = $name
                        $type = "text"
                        if ($fieldTypes -ne $null -and $types.Count -ge $i -and $types[$i] -ne $null -and $types[$i] -ne ""){
                            $type = $types[$i]
                        }
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = $type
                        }
                    }
                }
                <#Some types of analysis are extremely unfriendly with regards to memory.
                There is a reason to avoid aggregating analyzed fields: high-cardinality fields consume a large amount of memory when loaded into fielddata. 
                The analysis process often (although not always) generates a large number of tokens, many of which are unique. 
                This increases the overall cardinality of the field and contributes to more memory pressure.
                 use index = "not_analyzed" for strings where possible#>
                &$createIndex "$indexName" -obj @{
                    settings = @{
                        analysis = @{
                          char_filter = @{ 
                            quotes = @{
                              type = "mapping"
                              mappings = @( "\\u0091=>\\u0027", "\\u0092=>\\u0027", "\\u2018=>\\u0027","\\u2019=>\\u0027","\\u201B=>\\u0027" )
                            }
                          }
                          analyzer = @{
                            quotes_analyzer= @{
                              tokenizer = "standard"
                              char_filter = @( "quotes" )
                            }
                          }#analyzer
                        } #analysis
                    } #| ConvertTo-Json -Depth 4

                    mappings = @{
                        "$typeName" = @{
                             dynamic = $true #will additional fields dynamically.
                             date_detection = $false #avoid “malformed date” exception
                             properties = $dataTypes
                        }
                    }
                }

                if ($aliasName -ne ""){
                    &$put "$indexName/_alias/$aliasName"
                }

                $firstRecord = $false
            }

            for($i=3; $i -lt $file.count;$i++){
	            $values = $file[$i] -split $delimeter
                #generate json record
                $entryObj = New-Object PSObject
                #$entryObj | add-member Noteproperty "RecordType" $recordType
                $id = ""
                for($j=0; $j -lt $values.count;$j++){
                    if ($headers[$j] -ne $null -and $headers[$j] -ne ""){
                        $name = $headers[$j]
                        $value = ""
                        if ($values[$j] -ne $null){
                            $value = $($values[$j].TrimStart('=').Trim('"').Trim())
                            $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                            $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                            $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                            $value = $value -replace '\s+', ' ' #remove extra spaces
                        }
                        if ($value -ne ""){ 
                            if ($name -eq $keyFieldName){ 
                                $id = ", ""_id"": ""$value""" 
                            }
                            else{ #if data has no id field it will be autogenerated
                                $entryObj | Add-Member Noteproperty $name $value
                            }
                        }
                    }
                }
                $entry = '{"index": {"_type": "'+$typeName+'"'+$id+'}'+ "`n" +($entryObj | ConvertTo-Json -Compress| Out-String)  + "`n"
                $rowcount++
#$entry
                $BulkBody += $entry
                $percent = [decimal]::round(($BulkBody.Length / $MaxFileBiteSize)*100)
                if ($percent -gt 100) {$percent = 100}
                Write-Progress -Activity "Batching in progress: $($_.Name) $rowcount rows" -status "$percent% complete" -percentcomplete $percent;
                if ($BulkBody.Length -ge $MaxFileBiteSize){
                    $result = &$post "$indexName/_bulk" $BulkBody

                    #validate bulk errors
                    $resultObj = ConvertFrom-Json $result 
                    $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
                    if ($errors -ne $null -and $errors.Count -gt 0){
                        $errors | %{ Write-Host "path: $($filePath); _type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
                    }

                    $BulkBody = ""
                }
            }
        }

    if ($BulkBody -ne ""){
        $result = &$post "$indexName/_bulk" $BulkBody
        $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
        if ($errors -ne $null -and $errors.Count -gt 0){
            $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
        }

        $BulkBody = ""
    }
}

Main