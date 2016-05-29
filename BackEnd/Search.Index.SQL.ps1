<#Unit tests: 
 cd C:\Search\Scripts
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -aliasName "adworks" -NewIndex `
        -SQL_DbName "AdventureWorks" -typeName "person" -keyFieldName "BusinessEntityID" -SQL_Query "SELECT * FROM [Person].[Person]"
        #this command has some unicode fields which are not acepted by ES. Please read this: https://www.elastic.co/guide/en/elasticsearch/guide/master/unicode-normalization.html
        

    &$cat
    &$get "/adworks/_mapping"
    &$get "/adworks/person/2"
    &$get "/adworks/person/_query?q=*"

 hierarchies:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -NewType `
        -SQL_DbName "AdventureWorks" -typeName "employee" -keyFieldName "BusinessEntityID" -SQL_Query "select * from [HumanResources].[Employee]"
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -NewType `
        -SQL_DbName "AdventureWorks" -typeName "pdocument" -keyFieldName "DocumentNode" -SQL_Query "select * from [Production].[Document]"

    #failed for OrganizationNode:  .\Search.Index.SQL.ps1 -indexName "adworks_v1" -SQL_DbName "AdventureWorks" -typeName "employee" -keyFieldName "BusinessEntityID" -SQL_Query "select * from [HumanResources].[Employee]"
    #failed for DocumentNode:  .\Search.Index.SQL.ps1 -indexName "adworks_v1" -SQL_DbName "AdventureWorks" -typeName "pdocument" -keyFieldName "DocumentNode" -SQL_Query "select * from [Production].[Document]"

 geography:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -NewType `
        -SQL_DbName "AdventureWorks" -typeName "address" -keyFieldName "AddressID" -SQL_Query "select * from [Person].[Address]"

views:
    multi language test:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -NewType `
        -SQL_DbName "AdventureWorks" -typeName "candidate" -keyFieldName "JobCandidateID" -SQL_Query "SELECT * FROM [HumanResources].[vJobCandidate]"

big tables:
    .\Search.Index.SQL.ps1 -indexName "adworks_v1" -NewType `
        -SQL_DbName "AdventureWorks" -typeName "sales" -keyFieldName "SalesOrderDetailID" -SQL_Query "SELECT [SalesOrderID],[SalesOrderDetailID],[CarrierTrackingNumber],[OrderQty],[ProductID],[SpecialOfferID],[UnitPrice],[UnitPriceDiscount],[LineTotal],[ModifiedDate] FROM [Sales].[SalesOrderDetail]"

    .\Search.Index.SQL.ps1 -indexName "bms_v1" -NewIndex -aliasName "bms" `
        -SQL_ServerName ".\SQL2014" -SQL_DbName "Nova_Search" -typeName "acronym" -keyFieldName "Id" -SQL_Query "SELECT [Id],[Abbr],[Definition],[Context],[Reference],[AddDate] FROM [dbo].[Acronym] WHERE DeleteDate IS NULL"

    .\Search.Index.SQL.ps1 -indexName "bms_v1" -NewType `
        -SQL_DbName "Integration" -typeName "austender" -keyFieldName "Id" -SQL_Query "SELECT [Id],[Parent_CN_ID],[CN_ID],[Publish_Date],[Amendment_Date],[Status],[StartDate],[EndDate]
            ,[Value],[Description],[Agency_Ref_ID],[Category],[Procurement_Method],[ATM_ID],[SON_ID],[Confidentiality_Contract]
            ,[Confidentiality_Contract_Reasons],[Confidentiality_Outputs],[Confidentiality_Outputs_Reasons],[Consultancy],[Consultancy_Reasons],[Amendment_Reason]
            ,[Supplier_Name],[Supplier_Address],[Supplier_City],[Supplier_Postcode],[Supplier_Latitude],[Supplier_Longitude]
            ,[Supplier_Country],[Supplier_ABNExempt],[Supplier_ABN]
            ,[Agency],[Agency_Branch],[Agency_Divison],[Agency_Postcode],[Agency_State],[Agency_Latitude],[Agency_Longitude]
        FROM [dbo].[t_AusTenderContractNotice] ORDER BY [Id]"
#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] 
Param(
    #[Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target server')]
    [string]$SQL_ServerName = ".\SQL2014",
    [string]$SQL_DbName = "",
    [string]$SQL_Query = "",
    [string]$typeName = "",
    [string]$keyFieldName = "",

    [string]$indexName = "",
    [string]$aliasName = "",
    [Parameter(HelpMessage = '~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
    [int]$batchMaxSize = 1000000,  #
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
        if ($rows -eq 1){ #let's map fields' data types
            for ($i=0; $i -lt $cols; $i++){
                $type = $reader1.GetFieldType($i).Name
                $name = $reader1.GetName($i)
#$names
#$types
                if ($NewIndex.IsPresent -or $NewType.IsPresent){
                    $dataTypes = New-Object PSObject
                    if ($type -eq "SqlGeography"){ #This field should be typed in mapping explicitly
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "geo_point"
                            #geohash_prefix = "true" #tells Elasticsearch to index all geohash prefixes, up to the specified precision.
                            #geohash_precision = "1km" #The precision can be specified as an absolute number, representing the length of the geohash, or as a distance. A precision of 1km corresponds to a geohash of length 7.
                        }
                    }

                    elseif ($type -eq "SqlHierarchyId"){ #This field should be typed in mapping explicitly
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "text"
                            index = "not_analyzed"
                            fields = @{
                                tree = @{
                                    type = "string"
                                    analyzer = "hierarchy_analyzer"
                                }
                            }
                        }
                    }
                    elseif ($type -in "Decimal"){
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "double"
                        }
                    }
                    elseif ($type -in "Float", "Single", "Double"){
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "float"
                        }
                    }
                    elseif ($type -in "Int64", "UInt64"){
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "long"
                        }
                    }
                    elseif ($type -in "Int32", "UInt32"){
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "integer"
                        }
                    }
                    elseif ($type -eq "Int16", "UInt16","Byte"){
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "short"
                        }
                    }
                    <#elseif ($type -in "Byte[]","Object"){ #? not sure if we need it
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "binary"
                        }
                    }#>
                    elseif ($type -eq "DateTime"){ # "DateTimeOffset","TimeSpan" ?
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "date"
                            format = "YYYY-MM-DD"  
                        }
                    }
                    else{ #$type -in "String","Guid","Char[]","Xml"
                        $dataTypes | Add-Member Noteproperty $name @{
                            type = "text"
                        }
                    }
                }
                $names += $name
                $types += $type
            }
                
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
                        analyzer = @{
                            hierarchy_analyzer = @{ 
                                tokenizer= "path_hierarchy"
                            }
                            quotes_analyzer= @{
                                tokenizer = "standard"
                                char_filter = @( "quotes" )
                            }

                            <#When using the standard tokenizer or icu_tokenizer, this doesn’t really matter. 
                              These tokenizers know how to deal with all forms of Unicode correctly.#>
                            nfkc_cf_normalized = @{ 
                                tokenizer = "icu_tokenizer"
                                filter = @("icu_normalizer")
                            }
                            nfc_normalized = @{ 
                                tokenizer = "icu_tokenizer"
                                filter = @("nfc_normalizer")
                            }
                        }

                        filter = @{
                            nfkc_normalizer = @{ #Normalize all tokens into the nfkc normalization form
                                <#The icu_tokenizer uses the same Unicode Text Segmentation algorithm as the standard tokenizer, 
                                  but adds better support for some Asian languages by using a dictionary-based approach to identify words in Thai, Lao, Chinese, Japanese, and Korean, 
                                  and using custom rules to break Myanmar and Khmer text into syllables.#>
                                type = "icu_normalizer"
                                name = "nfkc"
                            }
                        }
                    }
                } #| ConvertTo-Json -Depth 
                mappings = @{
                    "$typeName"  = @{
                            dynamic = $true #will not create new fields dynamically.
                            date_detection = $true #avoid “malformed date” exception
                            properties = $dataTypes
                    } #type
                } #mappings
            }#obj

            if ($aliasName -ne ""){
                &$put "$indexName/_alias/$aliasName"
            }
        } #1st record

        $properties = @{}
        for ($i=0; $i -lt $cols; $i++){
         if ($reader1[$i] -ne [DBNull]::Value -and $reader1[$i] -ne $null -and $reader1[$i] -ne ""){

            if ($types[$i] -eq "DateTime"){ $val = $reader1[$i].ToString("yyyy-MM-dd")}
            elseif ($types[$i] -in "Int16", "UInt16"){
                $val = [Int16]$reader1[$i]
            }
            elseif ($types[$i] -in "Int32", "UInt32"){
                $val = [int]$reader1[$i]
            }
            elseif ($types[$i] -in "Int64", "UInt64"){
                $val = [long]$reader1[$i]
            }
            elseif ($types[$i] -eq "SqlHierarchyId"){ #trim values: /1/2/3/4/ => /1/2/3/4
                $val = $reader1[$i].ToString()
                if ($val -ne "/"){ $val = $val.TrimEnd('/') } #remove ending / with except of root
            }#
            elseif ($types[$i] -eq "SqlGeography"){ #$names[$i] -eq "Location" -and 
                $val = "[""lat"" = $($reader1[$i].Lat) ""lon"" = $($reader1[$i].Long)]"#GeoJSON format
            }
            elseif ($types[$i] -eq "Guid"){
                $val = $reader1[$i].ToString().TrimStart('{').TrimEnd('}') #json_parse_exception: Unexpected character ('}' (code 125))
            }
            elseif ($types[$i] -eq "Decimal"){
                $val = [decimal]$reader1[$i]
            }
            elseif ($types[$i] -eq "Double"){
                $val = [double]$reader1[$i]
            }
            elseif ($types[$i] -in "Float", "Single" ){
                $val = [float]$reader1[$i]
            }
            elseif ( $names[$i] -ne $keyFieldName -and $types[$i] -in "Guid","Byte[]","SqlHierarchyId","SqlGeometry","SqlGeography" ){ #skip this values
                $val = $null
            }
            elseif ($types[$i] -eq "String"){
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
                    if ($types[$i] -in "Int","Int32","Int64", "UInt16", "UInt32", "UInt64","Float", "Single", "Double", "Decimal"){
                        $id = ", ""_id"": $val" 
                    }
                    else{
                        $id = ", ""_id"": ""$val""" 
                    }

                }
                else{ $properties += @{"$($names[$i])" = $val} }
            }
         }

        }

        $entry = '{"index": {"_type": "'+$typeName+'"'+$id+'}'+ "`n" +($properties | ConvertTo-Json -Compress| Out-String)  + "`n"
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

Main

<#function Get-SqlType 
{ 
    param([string]$TypeName) 
 
    switch ($TypeName)  
    { 
        'Boolean' {[Data.SqlDbType]::Bit} 
        'Byte[]' {[Data.SqlDbType]::VarBinary} 
        'Byte'  {[Data.SQLDbType]::VarBinary} 
        'Datetime'  {[Data.SQLDbType]::DateTime} 
        'Decimal' {[Data.SqlDbType]::Decimal} 
        'Double' {[Data.SqlDbType]::Float} 
        'Guid' {[Data.SqlDbType]::UniqueIdentifier} 
        'Int16'  {[Data.SQLDbType]::SmallInt} 
        'Int32'  {[Data.SQLDbType]::Int} 
        'Int64' {[Data.SqlDbType]::BigInt} 
        'UInt16'  {[Data.SQLDbType]::SmallInt} 
        'UInt32'  {[Data.SQLDbType]::Int} 
        'UInt64' {[Data.SqlDbType]::BigInt} 
        'Single' {[Data.SqlDbType]::Decimal}
        default {[Data.SqlDbType]::VarChar} 
    } 
     
} #Get-SqlType


function Get-ElasticType
{ 
    param([string]$TypeName) 
 
    switch ($TypeName)  
    { 
        'SqlGeography' {"geo_point"} 
        #'SqlHierarchyId' {hierarchy_analyzer} 
        'Byte[]' {"binary"} 
        'Byte'  {"short"} 
        'Datetime'  {"date"} 
        'Decimal' {"double"} 
        'Int16'  {"short"} 
        'Int32'  {"integer"} 
        'Int64' {"long"} 
        'UInt16'  {"short"} 
        'UInt32'  {"integer"} 
        'UInt64' {"long"} 
        'Double' {"float"} 
        'Float' {"float"}
        'Single' {"float"}
        #'Guid' {[Data.SqlDbType]::UniqueIdentifier} 
        default {"text"} 
    } 
     
} #Get-ElasticType
#>

