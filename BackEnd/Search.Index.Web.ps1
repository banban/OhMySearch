<#
Unit tests:
    cd C:\Search\Scripts
    
    Test 1. Do not download new files, just process existings:
    .\Search.Index.Web.ps1 -rootPath "C:\Search\Import\Test" -delimeter "	" -keyFieldName "CN ID" -indexName "tender_v1" -aliasName "tender" -typeName "austender" -NewIndex

    Test 2. Adjust type mapping:
    .\Search.Index.Web.ps1 -rootPath "C:\Search\Import\Test" -delimeter "	" -keyFieldName "CN ID" -indexName "tender_v1" -aliasName "tender" -typeName "austender" -NewIndex `
       -typeMapping '{"tender_v1":{"mappings":{"austender":{"dynamic":"true","properties":{"ATM_ID":{"type":"keyword"},"Agency":{"type":"text"},"Agency_Branch":{"type":"text"},
"Agency_Divison":{"type":"text"},"Agency_Postcode":{"type":"keyword"},"Agency_Ref_ID":{"type":"keyword"},"Amendment_Publish_Date":{"type":"date"},
"Amendment_Reason":{"type":"text","fields":{"keyword":{"type":"keyword","ignore_above":256}}},"CN_ID":{"type":"keyword"},"Category":{"type":"text"},
"Confidentiality_Contract":{"type":"text"},"Confidentiality_Contract_Reason_s":{"type":"text"},"Confidentiality_Outputs":{"type":"text"},"Confidentiality_Outputs_Reason_s":{"type":"text"},
"Consultancy":{"type":"text"},"Consultancy_Reason_s":{"type":"text"},"Description":{"type":"text"},"EndDate":{"type":"date"},"Parent_CN_ID":{"type":"text"},
"Procurement_Method":{"type":"text"},"Publish_Date":{"type":"date"},"StartDate":{"type":"date"},"Status":{"type":"text"},"Supplier_ABN":{"type":"keyword"},
"Supplier_ABNExempt":{"type":"text"},"Supplier_Address":{"type":"text"},"Supplier_City":{"type":"text"},"Supplier_Country":{"type":"text"},"Supplier_Name":{"type":"text"},
"Supplier_Postcode":{"type":"keyword"},"Value":{"type":"double"}}}}}}'

    Test 3. Full load test with type mapping:
    .\Search.Index.Web.ps1 -webSite "https://www.tenders.gov.au/"-rootPath "C:\Search\Import\AusTender" -delimeter "	" -keyFieldName "CN ID" -indexName "tender_v1" -aliasName "tender" -typeName "austender" -NewIndex `
       -typeMapping '{"tender_v1":{"mappings":{"austender":{"dynamic":"true","properties":{"ATM_ID":{"type":"keyword"},"Agency":{"type":"text"},"Agency_Branch":{"type":"text"},
"Agency_Divison":{"type":"text"},"Agency_Postcode":{"type":"keyword"},"Agency_Ref_ID":{"type":"keyword"},"Amendment_Publish_Date":{"type":"date"},
"Amendment_Reason":{"type":"text","fields":{"keyword":{"type":"keyword","ignore_above":256}}},"CN_ID":{"type":"keyword"},"Category":{"type":"text"},
"Confidentiality_Contract":{"type":"text"},"Confidentiality_Contract_Reason_s":{"type":"text"},"Confidentiality_Outputs":{"type":"text"},"Confidentiality_Outputs_Reason_s":{"type":"text"},
"Consultancy":{"type":"text"},"Consultancy_Reason_s":{"type":"text"},"Description":{"type":"text"},"EndDate":{"type":"date"},"Parent_CN_ID":{"type":"text"},
"Procurement_Method":{"type":"text"},"Publish_Date":{"type":"date"},"StartDate":{"type":"date"},"Status":{"type":"text"},"Supplier_ABN":{"type":"keyword"},
"Supplier_ABNExempt":{"type":"text"},"Supplier_Address":{"type":"text"},"Supplier_City":{"type":"text"},"Supplier_Country":{"type":"text"},"Supplier_Name":{"type":"text"},
"Supplier_Postcode":{"type":"keyword"},"Value":{"type":"double"}}}}}}'

 2 records were rejected: 
    path: c:\search\import\austender\08-nov-15 to 14-nov-15.csv; _type: austender; _id: AVUer-1TRN9q28PbTZhH; error: mapper_parsing_exception; reason: failed to parse [Description]; status: 400
    path: c:\search\import\austender\08-nov-15 to 14-nov-15.csv; _type: austender; _id: AVUer-1TRN9q28PbTZif; error: mapper_parsing_exception; reason: failed to parse [Supplier_Name]; status: 400


    prod
    .\Search.Index.Web.ps1 -webSite "https://www.tenders.gov.au/"-rootPath "C:\Search\Import\AusTender" -delimeter "	" -keyFieldName "CN ID" -indexName "tender_v1" -aliasName "tender" -typeName "austender" -NewIndex

    using "CN ID" as PK generates circuit_breaking_exception. You can use internal _id by ignoring the fueild
    .\Search.Index.Web.ps1 -webSite "https://www.tenders.gov.au/"-rootPath "C:\Search\Import\AusTender" -delimeter "	" -indexName "tender_v1" -aliasName "tender" -typeName "austender" -NewIndex


    Alternative approach is logstash. To test logstash in interactive mode use command: 
        logstash.bat -e 'input { stdin { } } output { stdout {} }'
    Check existing plugins
        logstash-plugin.bat list
        logstash-plugin.bat install logstash-filter-csv

        logstash -e 'input { stdin { } } output { elasticsearch { host => localhost } }'
        logstash -e 'input { stdin {} } output { stdout { codec => rubydebug } }'

    Test your configuration use this command:
        C:\Search\logstash-5.0.0-alpha3\bin\logstash.bat -f "C:\Search\Import\logstash-austender.conf" --config.test_and_exit
    Expected result: Configuration OK
    Unexpected error: The signal HUP is in use by the JVM and will not work correctly on this platform
    Which means - kill existing jruby process conflicting with your request :(

 test API:
    $global:Debug = $true
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force -Verbose
    &$cat
    &$get "tender_v1/_mapping"
    &$get "tender_v1/austender"
    &$get "tender_v1/austender/_query?q=*"
    &$get "tender_v1"
    &$get "tender_v1/austender/AVUQ7SGd4sw0coEpumpQ"

    &$post "tender_v1/austender/_search" -obj @{
        size = 0
        aggs = @{
            Agencies = @{
                terms = @{
                    field = "Agency"
                }
            }
        }
    }

    &$delete "tender_v1" 

    check foursquare search in Search.Index.Files.Test.ps1
#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [string]$webSite ,
    [string]$rootPath,
    [string]$delimeter,
    [string]$keyFieldName,
    [string]$indexName,
    [string]$aliasName,
    [string]$typeName,
    [Parameter(HelpMessage = 'Represents manual mapping - most accurate approach')]
    [string]$typeMapping,

    #[Parameter(HelpMessage = '~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
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
    #&$call "Get" "/_cluster/state"
    [int]$rowcount = 0
    [string]$BulkBody = ""
    $headers = @{} #cached mapping between original and clean names
    $fieldTypeMapping = @{} #cached mapping between field name and data type
    
    if ($typeMapping -ne $null -and $typeMapping -ne ""){
        $meatadata = ConvertFrom-Json $typeMapping
    }
    else{
        #read existing index mapping metadata
        try{
            #$indexName = "tender_v1"; $typeName = "austender"; 
            $meatadata = ConvertFrom-Json (&$get "$indexName/_mapping")
        }
        catch{}
    }
    $mappingProperties = New-Object PSObject
    if ($meatadata -ne $null){
        $index_mt = $meatadata.psobject.properties | Where {$_.Name -eq "$indexName"} 
        if ($index_mt -ne $null){
            $type_mt = $index_mt.Value.mappings.psobject.properties | Where {$_.Name -eq "$typeName"}
            if ($type_mt -ne $null){
                $mappingProperties = $type_mt.Value.properties
                $mappingProperties.psobject.properties | %{
                    $fieldTypeMapping.Set_Item($_.Name, $_.Value.type)
                }
            }
        }
    }

    Get-ChildItem $rootPath -Filter "*.csv" -File -Force -ErrorAction SilentlyContinue |
        Where-Object {$_ -is [IO.FileInfo]} |
        % {
            $filePath = $_.FullName.ToLower()
            #remove empty and useless short rows
            (Get-Content $filePath | Select-Object | Where-Object {$_.Length -gt $rowMinLength}) | Set-Content $filePath -Force
            #load file content
            $content = Import-Csv -LiteralPath $filePath -Delimiter $delimeter

            if ($firstRecord -eq $true -and $content.Count -gt 0){
                if ($newIndex.IsPresent){
                    try{
                        &$delete $indexName 
                    }
                    catch{}

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
                    }
                }
                if ($newIndex.IsPresent -or $newType.IsPresent){
                    $fields = $content | Get-Member -MemberType NoteProperty -force | %{$_.Name}

                    #clean field names
                    for($i=0; $i -lt $fields.Count;$i++){
                        $name = $fields[$i].TrimStart('=').Trim('"').Trim()
                        $name = $name -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                        $name = $name -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                        $name = $name -replace '[\-\,\.\\/''~?!*“"%&•â€¢©ø\[\]{}\(\)]', ' ' #special symbols and punctuation
                        $name = $name.Trim() -replace '\s+', '_' #remove extra spaces and raplace with _
                        $headers.Set_Item("$($fields[$i])", "$name")
                    }

                    #let's try to guess missed data type based on first 1 (or more, some fields in 1st row might be empty!) record(s)
                    $content[0].psobject.properties | % {
                        $name = $headers.Get_Item($_.Name)
                        if ($_.Value -ne $null -and $_.Value -ne "" -and $fieldTypeMapping.Get_Item($name) -eq $null){
                            $value = $_.Value
                            $value = $($value.TrimStart('=').Trim('"').Trim())
                            $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                            $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                            $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                            $value = $value -replace '\s+', ' ' #remove extra spaces
                            if (($value -as [DateTime]) -ne $null){ #check value is a date
                                $fieldTypeMapping.Set_Item("$name", "date")
                            }
                            else{
                                $fieldTypeMapping.Set_Item("$name", "text")
                                # if you do not need to aggregate by this field - do not set doc_values = true
                                $fieldTypeMapping.Set_Item("$doc_values", $true) 
                            }
                        }
                    }

                    $fieldTypeMapping.GetEnumerator() | %{
                        [bool]$isNewProp = $false
                        try{
                            if ($mappingProperties.psobject.properties.Item($_.Key) -eq $null){
                                $isNewProp = $true
                            }
                        }
                        catch{
                            $isNewProp = $true
                        }

                        if ($isNewProp){ #add new field mapping
                            if ($_.Value -eq "text"){
                                $mappingProperties | Add-Member Noteproperty $_.Key @{
                                    type = "$($_.Value)"
                                    fielddata = $true
                                }
                            }
                            else{
                                $mappingProperties | Add-Member Noteproperty $_.Key @{
                                    type = "$($_.Value)"
                                }
                            }
                        }
                    }

                    &$put "$($indexName)/_mapping/$($typeName)?update_all_types" -obj @{
                        dynamic = $true #will create new fields dynamically.
                        date_detection = $true #avoid “malformed date” exception
                        properties = $mappingProperties
                    }
                }

                if ($aliasName -ne ""){
                    &$put "$indexName/_alias/$aliasName"
                }

                $firstRecord = $false
            }

            #mutate data
            for($i=0; $i -lt $content.count;$i++){
                $entryProperties = @{}
                $id = ""
                $content[$i].psobject.properties | % {
                    $name = $headers.Get_Item($_.Name)
                    if ($_.Value -eq $null -or $_.Value -eq ""){
                        $value = $null
                    }

                    if ($fieldTypeMapping.Get_Item($name) -ne $null){
                        $type = $fieldTypeMapping.Get_Item($name)
                    }
                    else{
                        $type = "keyword"
                    }

                    if ($type -in "string","text","keyword"){
                        $value = $_.Value
                        if ($value -ne $null){
                            $value = $($value.TrimStart('=').Trim('"').Trim())
                            $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                            $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                            $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                            $value = $value -replace '\s+', ' ' #remove extra spaces
                        }
                        else{
                            $value = ""
                        }
                    }
                    elseif ($type -eq "date"){ # reformat date
                        try{
                            if (($_.Value -as [DateTime]) -ne $null){ #check value is a date
                                $value =  Get-Date -Date $_.Value -Format "yyyy-MM-dd"
                            }
                        }
                        catch{
                            Write-Host "can't convert date value in row $i"  -f Red 
                        }
                    }
                    elseif ($type -in "short","integer","long", "double", "decimal", "float", "number"){
                        $value = 0
                        if ($type -in "double", "number"){
                            try{
                                if (($_.Value -as [double]) -ne $null){
                                    $value =  [double]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "float"){
                            try{
                                if (($_.Value -as [float]) -ne $null){
                                    $value =  [float]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "decimal"){
                            try{
                                if (($_.Value -as [decimal]) -ne $null){
                                    $value =  [decimal]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "long"){
                            try{
                                if (($_.Value -as [long]) -ne $null){
                                    $value =  [long]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "integer"){
                            try{
                                if (($_.Value -as [integer]) -ne $null){
                                    $value =  [integer]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "short"){
                            try{
                                if (($_.Value -as [short]) -ne $null){
                                    $value =  [short]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                    }
                    if ($value -ne $null){ 
                        if ($name -eq $keyFieldName){ 
                            $id = ", ""_id"": ""$value""" 
                        }
                        else{
                           $entryProperties += @{"$name" = $value}
                        }
                    }
                }

                $entry = '{"index": {"_type": "'+$typeName+'"'+$id+'}'+ "`n" +($entryProperties | ConvertTo-Json -Compress| Out-String)  + "`n"
                $rowcount++
#$entry
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