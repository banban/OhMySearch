<#
Unit tests:
    cd C:\Search\Scripts
    &$delete "web_v2"
    
    Test. Do not download new files, just process existings:
    .\Search.Index.Web.ps1 -rootPath "C:\Search\Import\Test" -delimeter "	" -keyFieldName "CN ID" -indexName "web_v1" -aliasName "web" -typeName "austender" -NewIndex `
        -fieldTypes "text,keyword,keyword,date,date,keyword,date,date,double,text,keyword,keyword,keyword,keyword,keyword,text,keyword,keyword,text,keyword,text,text,text,text,keyword,keyword,keyword,keyword,keyword,text,text,keyword"

    prod
    .\Search.Index.Web.ps1 -webSite "https://www.tenders.gov.au/"-rootPath "C:\Search\Import\AusTender" -delimeter "	" -keyFieldName "CN ID" -indexName "web_v1" -aliasName "web" -typeName "austender" -NewIndex `
        -fieldTypes "text,keyword,keyword,date,date,keyword,date,date,double,text,keyword,keyword,keyword,keyword,keyword,text,keyword,keyword,text,keyword,text,text,text,text,keyword,keyword,keyword,keyword,keyword,text,text,keyword"

    using "CN ID" as PK generates circuit_breaking_exception. You can use internal _id by ignoring the fueild
    .\Search.Index.Web.ps1 -webSite "https://www.tenders.gov.au/"-rootPath "C:\Search\Import\AusTender" -delimeter "	" -indexName "web_v1" -aliasName "web" -typeName "austender" -NewIndex


    Alternative approach is logstash. To test logstash in interactive mode use command: 
        logstash.bat -e 'input { stdin { } } output { stdout {} }'
    Check existing plugins
        logstash-plugin.bat list
        logstash-plugin.bat install logstash-filter-csv

        logstash -e 'input { stdin { } } output { elasticsearch { host => localhost } }'
        logstash -e 'input { stdin {} } output { stdout { codec => rubydebug } }'

    Test your configuration use this command:
        C:\Search\logstash-5.0.0-alpha2\bin\logstash.bat -f "C:\Search\Import\AusTender\logstash-austender.conf" --configtest
    Expected result: Configuration OK
    Unexpected error: The signal HUP is in use by the JVM and will not work correctly on this platform
    Wich means - kill existing jruby process conflicting with your request :(
#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [string]$webSite ,
    [string]$rootPath,
    [string]$delimeter,
    [Parameter(HelpMessage = 'fields types for precise data conversion "int,keyword,text,date"')]
    [string]$fieldTypes,
    [string]$keyFieldName,
    [string]$indexName,
    [string]$aliasName,
    [string]$typeName,
    [Parameter(HelpMessage = '~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
    [int]$batchMaxSize = 1000000,
    [int]$rowMinLength = 25,
    #[parameter(parametersetname="indexSwitches")]
    [switch]$NewIndex
)

function Main(){
    Clear-Host

    if ($webSite -ne $null -and $webSite -ne ""){
        #ignore test ssl certificate warning, do not use for external resources
        #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} 

        $uri = "$($webSite)?event=public.reports.listCNWeeklyExport"
        $HTML = Invoke-WebRequest -Uri "$uri" -Method Get -ContentType "text/html;charset=UTF-8" #-UseDefaultCredentials

        #load new files
        foreach($link in $HTML.Links){
            if ($link.href.StartsWith("?event=public.reports.downloadCNWeeklyExport&amp;CNWeeklyExportUUID=")){
                $filePath = $rootPath.Trim('\') + "\"+ $link.innerText + ".csv"
                if (!(Test-Path $filePath)){
                    $uri = $webSite + $link.href.Replace("&amp;","&")
                    Write-Output "Downloading file  $uri ..."
                    (New-Object Net.WebClient).DownloadFile($uri,$filePath);
                }
            }
        }
    }

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
    Get-ChildItem $rootPath -Filter "*.csv" -File -Force -ErrorAction SilentlyContinue |
        Where-Object {$_ -is [IO.FileInfo]} |
        % {
            $filePath = $_.FullName.ToLower()
            if ($firstRecord -eq $true -and $NewIndex.IsPresent){
                try{
                    &$delete $indexName 
                }
                catch{}

                #remove "empty" rows
                (Get-Content $filePath | Select-Object | Where-Object {$_.Length -gt $rowMinLength}) | Set-Content $filePath -Force

                #load file content
                #$filePath  = "C:\Search\Import\Test\01-Mar-15 to 07-Mar-15.csv"
                $content = Import-Csv -LiteralPath $filePath -Delimiter "	" 
                $fields = $content | Get-Member -MemberType NoteProperty -force | %{$_.Name}
                $headers = @{} #cached mapping between original and clean names
                $types = @{} #cached mapping between original name and data type
                $elasticTypes = $fieldTypes -split ','
                $dataTypes = New-Object PSObject
                #remove some symbols from field names, put it into $headers array. Fill dataTypes array
                for($i=0; $i -lt $fields.Count;$i++){
                    $name = $fields[$i].TrimStart('=').Trim('"').Trim()
                    $name = $name -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                    $name = $name -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                    $name = $name -replace '[\-\,\.\\/''~?!*“"%&•â€¢©ø\[\]{}\(\)]', ' ' #special symbols and punctuation
                    $name = $name.Trim() -replace '\s+', '_' #remove extra spaces and raplace with _
                    $headers.Set_Item($fields[$i], $name)
                    $types.Set_Item($fields[$i], "text")
                    if ($fieldTypes -ne $null -and $elasticTypes.Count -ge $i -and $elasticTypes[$i] -ne $null -and $elasticTypes[$i] -ne ""){
                        $types.Set_Item($fields[$i], $elasticTypes[$i])
                    }
                    $dataTypes | Add-Member Noteproperty $name @{
                        type = $types.Get_Item($fields[$i])
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
                             #date_detection = $true #avoid “malformed date” exception
                             properties = $dataTypes
                        }
                    }
                }

                if ($aliasName -ne ""){
                    &$put "$indexName/_alias/$aliasName"
                }

                $firstRecord = $false
            }

            #mutate data

            for($i=0; $i -lt $content.count;$i++){
                #generate json record
                $entryObj = New-Object PSObject
                $id = ""
                $content[$i].psobject.properties | % {
                    $name = $headers.Get_Item($_.Name)
                    $value = $_.Value
                    $type = $types.Get_Item($_.Name)
                    if ($value -ne $null){
                        $value = $($value.TrimStart('=').Trim('"').Trim())
                        $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                        $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                        $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                        $value = $value -replace '\s+', ' ' #remove extra spaces
                    }
                    else{
                        $value  = ""
                    }
                    if ($value -ne ""){ 
                        if ($type -eq "date"){ # reformat date
                            try{
                                if (($value -as [DateTime]) -ne $null){ #check value is a date
                                    $value =  Get-Date -Date $value -Format "yyyy-MM-dd"
                                }
                            }
                            catch{
                                Write-Host "can't convert date value in row $i"  -f Red 
                            }
                        }
                        if ($name -eq $keyFieldName){ 
                            $id = ", ""_id"": ""$value""" 
                        }
                        else{ #if data has no id field it will be autogenerated
                            $entryObj | Add-Member Noteproperty $name $value
                        }
                    }
                }

                $entry = '{"index": {"_type": "'+$typeName+'"'+$id+'}'+ "`n" +($entryObj | ConvertTo-Json -Compress| Out-String)  + "`n"
                $rowcount++
$entry
                $BulkBody += $entry
                $percent = [decimal]::round(($BulkBody.Length / $batchMaxSize)*100)
                if ($percent -gt 100) {$percent = 100}
                Write-Progress -Activity "Batching in progress: $($_.Name) $rowcount rows" -status "$percent% complete" -percentcomplete $percent;
                if ($BulkBody.Length -ge $batchMaxSize){
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