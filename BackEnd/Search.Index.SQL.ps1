<#Unit tests: 
 cd C:\Search\Scripts

 1.test person table. Has some unicode fields which are not acepted by ES. Please read this: https://www.elastic.co/guide/en/elasticsearch/guide/master/unicode-normalization.html
   Do not index [AdditionalContactInfo],[Demographics],[rowguid] fields. XML should be converted to text first.
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -aliasName "adworks" -NewIndex `
        -SQL_DbName "AdventureWorks" -typeName "person" -keyFieldName "BusinessEntityID" -SQL_Query "SELECT [BusinessEntityID],[PersonType],[NameStyle],[Title],[FirstName],[MiddleName],[LastName],[Suffix],[EmailPromotion],[ModifiedDate] FROM [Person].[Person]"

   100 records rejected (some unicode symbols are not accepted by standard analyzer in First or Last name). That is accepteble now. Will investegate later
    
   The same test but with explicit mapping:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -aliasName "adworks" -NewIndex `
        -SQL_DbName "AdventureWorks" -typeName "person" -keyFieldName "BusinessEntityID" -SQL_Query "SELECT [BusinessEntityID],[PersonType],[NameStyle],[Title],[FirstName],[MiddleName],[LastName],[Suffix],[EmailPromotion],[ModifiedDate] FROM [Person].[Person]" `
        -typeMapping '{"adworks_v1":{"mappings":{"person":{"dynamic":"true","properties":{"BusinessEntityID":{"type":"integer"},"EmailPromotion":{"type":"integer"},"FirstName":{"type":"text"},"LastName":{"type":"text"},"MiddleName":{"type":"text"},"ModifiedDate":{"type":"date","format":"YYYY-MM-DD"},"NameStyle":{"type":"text"},"PersonType":{"type":"text"},"Suffix":{"type":"text"},"Title":{"type":"text"},}}}}}'

    &$cat

 2.test hierarchies. Check current index status
    &$cat
    &$get "adworks_v1/_settings"
    &$get "adworks_v1/_mapping"
   For SQL hierarchy we will use standard path_hierarchy tokenizer
        &$post "_analyze" '{"tokenizer": "path_hierarchy", "text": "/one/two/three"}'
   Check that our hierarchy_analyzer works
        &$post "/adworks_v1/_analyze" '{"analyzer": "hierarchy_analyzer", "text": "/one/two/three"}'
   Add new type to existing index. 
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "employee" -NewType `
        -SQL_DbName "AdventureWorks" -keyFieldName "BusinessEntityID" -SQL_Query "select * from [HumanResources].[Employee]"

    #2 of 290 records rejected with unicode issue in LoginID field. that is ok for now

    We can try extended unicode support https://www.elastic.co/guide/en/elasticsearch/plugins/master/analysis-icu.html
        cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install analysis-icu"
    Also, you can use query wihout rowguid and hierarchy like : -SQL_Query "SELECT [BusinessEntityID],[NationalIDNumber],[LoginID],[OrganizationLevel],[JobTitle],[BirthDate],[MaritalStatus],[Gender],[HireDate],[SalariedFlag],[VacationHours],[SickLeaveHours],[CurrentFlag],[ModifiedDate] FROM [HumanResources].[Employee]"

    &$cat

 3. Test documents with binary content. Not sure if that makes sense :)
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "pdocument" -NewType `
        -SQL_DbName "AdventureWorks" -keyFieldName "DocumentNode" -SQL_Query "select * from [Production].[Document]"

    #failed for OrganizationNode:  .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "employee" -SQL_DbName "AdventureWorks" -keyFieldName "BusinessEntityID" -SQL_Query "select * from [HumanResources].[Employee]"
    #failed for DocumentNode:  .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "pdocument" -SQL_DbName "AdventureWorks" -keyFieldName "DocumentNode" -SQL_Query "select * from [Production].[Document]"

    &$cat
 4.Test geography. Convert SqlGeography to GeoPoint for other shapes use poligons https://www.elastic.co/guide/en/elasticsearch/reference/master/geo-shape.html
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "address" -NewType `
        -SQL_DbName "AdventureWorks" -keyFieldName "AddressID" -SQL_Query "select * from [Person].[Address]"

    971 of 19614 records with unicode were rejected by analyzer: _type: address; _id: 552; error: mapper_parsing_exception; reason: failed to parse [AddressLine1]; status: 400
    &$cat

 5.test views. multi language test:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "candidate" -NewType `
        -SQL_DbName "AdventureWorks" -keyFieldName "JobCandidateID" -SQL_Query "SELECT  * FROM [HumanResources].[vJobCandidate]"

    3 of 13 records with unicode were rejected by analyzer: 
        _type: candidate; _id: 5; error: mapper_parsing_exception; reason: failed to parse [Skills]; status: 400
        _type: candidate; _id: 6; error: mapper_parsing_exception; reason: failed to parse [Skills]; status: 400
        _type: candidate; _id: 7; error: mapper_parsing_exception; reason: failed to parse [Skills]; status: 400


    &$cat
 5.test big tables:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -typeName "sales" -NewType `
        -SQL_DbName "AdventureWorks" -keyFieldName "SalesOrderDetailID" -SQL_Query "SELECT [SalesOrderID],[SalesOrderDetailID],[CarrierTrackingNumber],[OrderQty],[ProductID],[SpecialOfferID],[UnitPrice],[UnitPriceDiscount],[LineTotal],[ModifiedDate] FROM [Sales].[SalesOrderDetail]"
    &$cat

 6. Another database (index)
    .\Search.Index.SQL.ps1 -indexName "bms_v1" -NewIndex -aliasName "bms" `
        -SQL_ServerName ".\SQL2014" -SQL_DbName "Nova_Search" -typeName "acronym" -keyFieldName "Id" -SQL_Query "SELECT [Id],[Abbr],[Definition],[Context],[Reference],[AddDate] FROM [dbo].[Acronym] WHERE DeleteDate IS NULL"
    &$cat

    .\Search.Index.SQL.ps1 -indexName "bms_v1" -NewType `
        -SQL_DbName "Integrations_NOVA" -typeName "austender" -keyFieldName "Id" -SQL_Query "SELECT [Id],[Parent_CN_ID],[CN_ID],[Publish_Date],[Amendment_Date],[Status],[StartDate],[EndDate]
            ,[Value],[Description],[Agency_Ref_ID],[Category],[Procurement_Method],[ATM_ID],[SON_ID],[Confidentiality_Contract]
            ,[Confidentiality_Contract_Reasons],[Confidentiality_Outputs],[Confidentiality_Outputs_Reasons],[Consultancy],[Consultancy_Reasons],[Amendment_Reason]
            ,[Supplier_Name],[Supplier_Address],[Supplier_City],[Supplier_Postcode],[Supplier_Latitude],[Supplier_Longitude]
            ,[Supplier_Country],[Supplier_ABNExempt],[Supplier_ABN]
            ,[Agency],[Agency_Branch],[Agency_Divison],[Agency_Postcode],[Agency_State],[Agency_Latitude],[Agency_Longitude]
        FROM [dbo].[t_AusTenderContractNotice] ORDER BY [Id]"

 7.Just test API calls:
    $global:Debug = $false
    $global:Debug = $true #verbose tracing 
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force -Verbose

    &$cat
    &$get "/adworks_v1/_mapping"
    &$get "/adworks_v1/person/_mapping"
    &$get "/adworks_v1/employee/_mapping"
    &$get "/adworks_v1/address/_mapping"
    &$get "/adworks_v1/address"
    &$get "/adworks_v1/person/2"
    &$get "/adworks_v1/person/_query?q=*"
    &$delete "adworks_v1"
    &$createIndex "adworks_v1"

Test unicode analizers https://www.elastic.co/guide/en/elasticsearch/plugins/master/analysis.html
    &$post "adworks_v1/_analyze" '{"keyword": "quotes_analyzer", "text": "You\'re my ‘favorite’ M‛Coy"}'
    
    &$post "/adworks_v1/_analyze" -obj @{
      analyzer = "autocomplete"
      text = "quick brown"
    }

    &$post "/adworks_v1/person/_search" -obj @{
        query = @{
            match = @{
                Job_Title = "Senio"
            }
        }
    }

    &$post "adworks_v1/_analyze" '{"tokenizer": "standard", "text": "Sánchez"}'
    &$post "adworks_v1/_analyze" '{"tokenizer": "icu_tokenizer", "text": "Sánchez"}'
    &$post "adworks_v1/_analyze" '{"tokenizer": "icu_tokenizer", "text": "Reátegui Alayo"}'
    &$post "adworks_v1/_analyze" '{"tokenizer": "icu_tokenizer", "text": "François"}'


    &$put "adworks_v1/_mapping/employee" -obj @{
        dynamic = $true #will create new fields dynamically.
        date_detection = $true #avoid “malformed date” exception
        properties = @{
            FirstName = @{
                type = "string"
            }
            LoginID = @{
            type = "keyword"
            }
        }
    }

    &$put "adworks_v1/_mapping/person?update_all_types" -obj @{
        dynamic = $true #will create new fields dynamically.
        date_detection = $true #avoid “malformed date” exception
        properties= @{
            FirstName = @{
                type = "string"
            }
        }
    }

    &$get "/adworks_v1/_mapping"

Fields in the same index with the same name in two different types must have the same mapping, as they are backed by the same field internally. 
Trying to update a mapping parameter for a field which exists in more than one type will throw an exception, unless you specify the update_all_types parameter, 
in which case it will update that parameter across all fields with the same name in the same index.
    &$put "adworks_v1/_mapping/employee?update_all_types" -obj @{
      properties = @{
        FirstName = @{
            type = "string"
        }
        LoginID = @{
          type = "keyword"
        }
      }
    }

    &$put "adworks_v1/_mapping/employee" -body '{"properties":{"BusinessEntityID":{"type":"integer"},"NationalIDNumber":{"type":"text"},"LoginID":{"type":"text"},"OrganizationNode":{"fields":{"tree":{"type":"string","analyzer":"hierarchy_analyzer"}},"type":"text","index":"not_analyzed"},"OrganizationLevel":{"type":"short"},"JobTitle":{"type":"text"},"BirthDate":{"type":"date","format":"YYYY-MM-DD"},"MaritalStatus":{"type":"text"},"Gender":{"type":"text"},"HireDate":{"type":"date","format":"YYYY-MM-DD"},"SalariedFlag":{"type":"text"},"VacationHours":{"type":"short"},"SickLeaveHours":{"type":"short"},"CurrentFlag":{"type":"text"},"ModifiedDate":{"type":"date","format":"YYYY-MM-DD"}}}'

    &$get "/adworks_v1/_mapping"
    &$get "/adworks_v1/_settings"
    &$get "/adworks_v1/_mapping/person"
    &$get "/adworks_v1/_mapping/employee"
    &$cat

#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] 
Param(
    #[Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target server')]
    [string]$SQL_ServerName = ".\SQL2014",
    [string]$SQL_DbName,
    [string]$SQL_Query,

    [string]$indexName,
    [string]$aliasName,
    [string]$typeName,
    [Parameter(HelpMessage = 'Represents manual mapping - most accurate approach')]
    [string]$typeMapping,
    [string]$keyFieldName,

    [Parameter(HelpMessage = '~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
    [int]$batchMaxSize = 1000000,
    [Parameter(HelpMessage = '~4MB should be enough. They allow up to 4 MB in the RRS request.')]
    [int]$searchMaxBiteSize = 4194304,

    [switch]$NewIndex,
    [switch]$NewType

    #[string]$EventLogSource = "Search",
    #[string]$LogFilePath = "$($env:LOG_DIR)\Search.Index.SQL.log"
)

function Main(){
    Clear-Host
    if ($SQL_DbName -eq "" -or $SQL_Query -eq ""){
        Echo "Please specify SQL_DbName and SQL_Query parameter value"
        break;
    }
    
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
    <#
    #configure logging
    Import-Module -Name "$scripLocation\Log.Helper.psm1" -Force #-Verbose
    $global:EventLogSource = $EventLogSource
    $global:LogFilePath = $LogFilePath
    #Write-Event -Message "test"
    #Write-Event -Error "Error test"
    #>
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose
    
    $fieldTypeMapping = @{} #cached mapping between field name and data type
    if ($typeMapping -ne $null -and $typeMapping -ne ""){
        $meatadata = ConvertFrom-Json $typeMapping
    }
    else{
        #read existing index mapping metadata
        try{
            #$indexName = "web_v1"; $typeName = "austender"; 
            $meatadata = ConvertFrom-Json (&$get "$indexName/_mapping")
        }
        catch{}
    }
    
    $typeMapping = New-Object PSObject
    if ($meatadata -ne $null){
        $index_mt = $meatadata.psobject.properties | Where {$_.Name -eq "$indexName"} 
        if ($index_mt -ne $null){
            $type_mt = $index_mt.Value.mappings.psobject.properties | Where {$_.Name -eq "$typeName"}
            if ($type_mt -ne $null){
                $typeMapping = $type_mt.Value.properties
                $typeMapping.psobject.properties | %{
                    $fieldTypeMapping.Set_Item($_.Name, $_.Value.type)
                }
            }
        }
    }

   if ($NewIndex.IsPresent){
        try{
            &$delete $indexName 
        }
        catch{}
    }

    <#if ($DeleteAllDocuments -eq $true){
        try{
            &$delete "$indexName/$typeName/_query?q=*"
        }
        catch{}
    }#>
    #&$get
    #&$call "Get" "/_cluster/state"
    #&$cat

    #get storage status summary before index
    #ConvertFrom-Json (&$cat) | ft

    #Write-Event "$(Get-Date) Start session 'Search.Index.SQL'."
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=True"
    $SqlConnection.Open()

    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $SqlConnection
    $sqlCmd.CommandTimeout = 600
    $sqlCmd.CommandType = [System.Data.CommandType]::Text
    $sqlCmd.CommandText = $SQL_Query

    #very slow and RAM consuming approach
    #$dt1 = new-object system.data.datatable
    #$dt1.Load($reader1) 

    #let's use reader instead with minimal impact on memory and CPU
    $reader1 = $sqlCmd.ExecuteReader()

    [string]$BulkBody = ""
    $names = @()
    $types = @()
    $rows = 0
    $cols = $reader1.FieldCount
    while ($reader1.Read()){
        $rows++
        if ($rows -eq 1){ #first record foud, let's map data types
            for ($i=0; $i -lt $cols; $i++){
                $fieldType = $reader1.GetFieldType($i).Name
                $name = $reader1.GetName($i)
                #clean name. ES field naming convention is pretty restrictive
                $name = $name.TrimStart('=').Trim('"').Trim()
                $name = $name -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                $name = $name -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                $name = $name -replace '[\-\,\.\\/''~?!*“"%&•â€¢©ø\[\]{}\(\)]', ' ' #special symbols and punctuation
                $name = $name.Trim() -replace '\s+', '_' #remove extra spaces and raplace with _

                #existing mapping has a priority - user can change which is more accurate than dynamic mapping
                if ( ($NewIndex.IsPresent -or $NewType.IsPresent) -and ($typeMapping.psobject.properties.Item($name) -eq $null) ){
                    $typeMapping | Add-Member Noteproperty $name (Get-ElasticMappingByDataType -DataTypeName $fieldType)
                }
                #cache names and types to use it in bulk process
                $names += $name
                $types += $fieldType
            }

            if ($NewIndex.IsPresent) { #create new index
                try{
                    &$delete $indexName 
                }
                catch{}

                &$createIndex $indexName -obj @{
                    settings = @{
                        analysis = @{
                            char_filter = @{ 
                                quotes = @{
                                    type = "mapping"
                                    mappings = @( "\\u0091=>\\u0027", "\\u0092=>\\u0027", "\\u2018=>\\u0027","\\u2019=>\\u0027","\\u201B=>\\u0027" )
                                }
                            }
                            filter = @{
                                <#nfc_normalizer = @{
                                  type = "icu_normalizer"
                                  name = "nfc"
                                }#>
                                autocomplete_filter = @{ 
                                    type = "edge_ngram"
                                    min_gram = 1
                                    max_gram = 20
                                }
                                postcode_filter = @{
                                    type = "edge_ngram"
                                    min_gram = 1
                                    max_gram = 8
                                }
                            }
                            analyzer = @{
                                hierarchy_analyzer = @{ 
                                    tokenizer = "hierarchy_tokenizer"
                                }
                                postcode_index = @{ # The postcode_index analyzer would use the postcode_filter to turn postcodes into edge n-grams.
                                    tokenizer = "keyword"
                                    filter = @("postcode_filter")
                                }
                                postcode_search = @{ #The postcode_search analyzer would treat search terms as if they were not_analyzed.
                                    tokenizer = "keyword"
                                }
                                <# #When using the standard tokenizer or icu_tokenizer, this doesn’t really matter. 
                                #These tokenizers know how to deal with all forms of Unicode correctly.
                                nfkc_cf_normalized = @{ 
                                    tokenizer = "icu_tokenizer"
                                    filter = @("icu_normalizer")
                                }
                                nfc_normalized = @{ 
                                    tokenizer = "icu_tokenizer"
                                    filter = @("nfc_normalizer")
                                }#>
                                autocomplete = @{
                                    type = "custom"
                                    tokenizer = "standard"
                                    filter = @("lowercase","autocomplete_filter")
                                }
                            }
                            tokenizer = @{
                                hierarchy_tokenizer = @{
                                    type = "path_hierarchy"
                                    delimiter = "/"
                                }
                            }
                        }
                    }
                } #| ConvertTo-Json -Depth 
            }

            if ($NewIndex.IsPresent -or $NewType.IsPresent){ #add new type mapping to existing index with settings
                #When another type is added to exsting index it could have the same field names as other types, but different data type. 
                #ES generate exception. I think this is wrong. 
                #As a workaround, we need to use parameter update_all_types to avoid missmatched field types exception
                &$put "$($indexName)/_mapping/$($typeName)?update_all_types" -obj @{
                    dynamic = $true #will create new fields dynamically.
                    date_detection = $true #avoid “malformed date” exception
                    properties = $typeMapping
                }
            }

            if ($aliasName -ne $null -and $aliasName -ne ""){
                &$put "$indexName/_alias/$aliasName"
            }
        } #1st record

        #&$get "_cluster/health?wait_for_status=yellow"
        $entryProperties = @{}
        for ($i=0; $i -lt $cols; $i++){
            $fieldType = $types[$i]
            if ($reader1[$i] -ne [DBNull]::Value -and $reader1[$i] -ne $null -and $reader1[$i] -ne ""){

                if ($fieldType -eq "DateTime"){ $val = $reader1[$i].ToString("yyyy-MM-dd")}
                elseif ($fieldType -in "Int16", "UInt16"){
                    $val = [Int16]$reader1[$i]
                }
                elseif ($fieldType -in "Int32", "UInt32"){
                    $val = [int]$reader1[$i]
                }
                elseif ($fieldType -in "Int64", "UInt64"){
                    $val = [long]$reader1[$i]
                }
                elseif ($fieldType -eq "SqlHierarchyId"){ #trim values: /1/2/3/4/ => /1/2/3/4
                    $val = $reader1[$i].ToString()
                    if ($val -ne "/"){ $val = $val.TrimEnd('/') } #remove ending / with except of root
                }#
                elseif ($fieldType -eq "SqlGeography" -and $reader1[$i].Lat -ne [DBNull]::Value -and $reader1[$i].Long -ne [DBNull]::Value){ 
                    <#$val = @{ #GeoJSON Geo-point as an object
                        lat = $($reader1[$i].Lat.Value) 
                        lon = $($reader1[$i].Long.Value)
                    }#>
                    $val = "$($reader1[$i].Lat.Value),$($reader1[$i].Long.Value)"#GeoJSON Geo-point as a string
                    #$val = "drm3btev3e86" Geo-point as a geohash 
                    #$val = @($($reader1[$i].Lat.Value),$($reader1[$i].Long.Value))#Geo-point as an array
                }
                elseif ($fieldType -eq "Guid"){
                    $val = $reader1[$i].ToString().TrimStart('{').TrimEnd('}') #json_parse_exception: Unexpected character ('}' (code 125))
                }
                elseif ($fieldType -eq "Decimal"){
                    $val = [decimal]$reader1[$i]
                }
                elseif ($fieldType -eq "Double"){
                    $val = [double]$reader1[$i]
                }
                elseif ($fieldType -in "Float", "Single" ){
                    $val = [float]$reader1[$i]
                }
                elseif ( $names[$i] -ne $keyFieldName -and $fieldType -in "Guid","Byte[]","SqlHierarchyId","SqlGeometry","SqlGeography" ){ #skip this values
                    $val = $null
                }
                elseif ($fieldType -eq "String"){
                    $val = $reader1[$i]
                    $val = $val -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                    $val = $val -replace '`r`n', '; ' #JSON cannot include embedded newline characters. Newline characters in the script should either be escaped as \n or replaced with semicolons.
                    $val = $val -replace '[\\''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                    $val = $val -replace '\s+', ' ' #remove extra spaces
                    #$val = $val -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                    #$val = $val -replace '(\w)\1{3,}', '$1' #replace repeating symbols more than 3 times with 1: "aaaassssssssssseeeee111112222223334" -replace '(\w)\1{3,}', '$1'
                    $val = $val.Trim()
                    #Watch the size of the data you are posting to API!
                    if ($val.Length -gt $searchMaxBiteSize ){
                        $val = $val.Substring(0,$searchMaxBiteSize)
                    }
                }
                else { $val = $reader1[$i].ToString() }

                if ($val -ne $null -and $val -ne ""){
                    if ($names[$i] -eq $keyFieldName){ 
                        if ($fieldType -in "Int","Int32","Int64", "UInt16", "UInt32", "UInt64","Float", "Single", "Double", "Decimal"){
                            $id = ", ""_id"": $val" 
                        }
                        else{
                            $id = ", ""_id"": ""$val""" 
                        }

                    }
                    else{ $entryProperties += @{"$($names[$i])" = $val} }
                }
            }
        }

        $entry = '{"index": {"_type": "'+$typeName+'"'+$id+'}'+ "`n" +($entryProperties | ConvertTo-Json -Compress| Out-String) + "`n"
#$entry
        $BulkBody += $entry
        $batchPercent = [decimal]::round(($BulkBody.Length / $batchMaxSize)*100)
        if ($batchPercent -gt 100) {$batchPercent = 100}
        Write-Progress -Activity "Loading $typeName $rows rows" -status "Batching $batchPercent%" -percentcomplete $batchPercent;

        if ($BulkBody.Length -ge $batchMaxSize){
            $result = &$post "$indexName/_bulk" $BulkBody
            #validate bulk errors
            $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
            if ($errors -ne $null -and $errors.Count -gt 0){
                $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
            }
            $BulkBody = ""
        }
    }
    $reader1.Close()
    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }

    if ($BulkBody -ne ""){
        $result = &$post "$indexName/_bulk" $BulkBody
        #validate bulk errors
        $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
        if ($errors -ne $null -and $errors.Count -gt 0){
            $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
        }
        $BulkBody = ""
    }

    Start-Sleep 1
    #Write-Event "$(Get-Date) End session 'Search.Index.SQL'."
}

#Get-ElasticMappingByDataType -DataTypeName "DateTime"
function Get-ElasticMappingByDataType
{ 
    param([string]$DataTypeName) 
    switch ($DataTypeName.ToLower())  
    { 
        'sqlgeography' {@{
                type = "geo_point"
                #geohash_prefix = "true" #tells Elasticsearch to index all geohash prefixes, up to the specified precision.
                #geohash_precision = "1km" #The precision can be specified as an absolute number, representing the length of the geohash, or as a distance. A precision of 1km corresponds to a geohash of length 7.
            }}
        { @("date", "datetime") -contains $_ } {@{
                type = "date"
                format = "YYYY-MM-DD"  
            }} 
        'sqlhierarchyId' {@{
                type = "string"
                index = "not_analyzed"
                fields = @{
                    tree = @{
                        type = "string"
                        analyzer = "hierarchy_analyzer"
                    }
                }
            }} 
        { @("float", "single", "double") -contains $_ } {@{ type = "float" }}
        { @("int", "int32", "uInt32") -contains $_ } {@{ type = "integer" }}
        { @("byte", "int16", "uint32") -contains $_ }  {@{ type = "short" }}
        { @("int64", "uint64") -contains $_ }  {@{ type = "long" }}
        'byte[]' {@{ type = "binary" }} 
        'decimal' {@{ type = "double" }} 
        'guid' {@{ type = "keyword" }} 
        default {@{ type = "text" }} #"String","Guid","Char[]","Xml"
    } 
}

#Get-ElasticTypeByDataType -DataTypeName "int"
function Get-ElasticTypeByDataType
{ 
    param([string]$DataTypeName) 
    switch ($DataTypeName.ToLower())  
    { 
        'sqlgeography' {"geo_point"} 
        'byte[]' {"binary"} 
        'decimal' {"double"} 
        'guid' {"keyword"} 
        #'sqlhierarchyId' {hierarchy_analyzer} 
        { @("date", "datetime") -contains $_ } {"date"} 
        { @("int", "int32", "uInt32") -contains $_ }  {"integer"}
        { @("byte", "int16", "uint32") -contains $_ }  {"short"}
        { @("int64", "uint64") -contains $_ }  {"long"}
        { @("float", "single", "double") -contains $_ } {"float"}
        default {"text"} 
    } 
}

#Get-ElasticMappingByDataType -DataTypeName "Byte"
function Get-SqlTypeByDataType 
{ 
    param([string]$TypeName) 
 
    switch ($TypeName.ToLower())  
    { 
        'boolean' {[Data.SqlDbType]::Bit} 
        'byte[]' {[Data.SqlDbType]::VarBinary} 
        'byte'  {[Data.SQLDbType]::VarBinary} 
        'datetime'  {[Data.SQLDbType]::DateTime} 
        'decimal' {[Data.SqlDbType]::Decimal} 
        'double' {[Data.SqlDbType]::Float} 
        'guid' {[Data.SqlDbType]::UniqueIdentifier} 
        'int16'  {[Data.SQLDbType]::SmallInt} 
        'int32'  {[Data.SQLDbType]::Int} 
        'int64' {[Data.SqlDbType]::BigInt} 
        'uint16'  {[Data.SQLDbType]::SmallInt} 
        'uint32'  {[Data.SQLDbType]::Int} 
        'uint64' {[Data.SqlDbType]::BigInt} 
        'single' {[Data.SqlDbType]::Decimal}
        default {[Data.SqlDbType]::VarChar} 
    } 
}


Main
