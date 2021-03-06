﻿<#
Unit tests:
    command line call examples:
        cd C:\Search\Scripts\
        powershell -ExecutionPolicy ByPass -command "C:\Search\Scripts\Search.Index.Files.ps1" -SharedFolders "\\shares\files\" -indexName "shared_v1" -aliasName "shared" -NewIndex
        powershell -executionPolicy bypass -noexit -file "C:\Search\Scripts\Search.Index.Files.ps1" -SharedFolders "\\shares\files\" -indexName "shared_v1" -aliasName "shared" -NewIndex
    PS environment call examples:

        .\Search.Index.Files.ps1 -SharedFolders "\\shares\files\" -indexName "files_v1" -aliasName "files" -NewIndex
        .\Search.Index.Files.ps1 -SharedFolders "\\shares\library\" -indexName "library_v1" -aliasName "library" -NewIndex

    Add specific mapping
        $indexName = "shared_v1"

        $typeMapping = '{"shared_v1":{"mappings":{
            "file":{"dynamic":"true","properties":{
                "Author":{"type":"text","fielddata":true},
                "LastModifiedBy":{"type":"text","fielddata":true},
                "Manager":{"type":"text","fielddata":true},
                "Company":{"type":"text","fielddata":true},
                "LastPrinted":{"type":"date"},
                "NumberOfPages":{"type":"integer"}
            }},
            "photo":{"dynamic":"true","properties":{
                "Saturation":{"type":"keyword"},
                "Flash":{"type":"keyword"},
                "WhiteBalance":{"type":"keyword"},
                "CaptureMode":{"type":"keyword"},
                "ExposureMode":{"type":"keyword"},
                "MeteringMode":{"type":"keyword"},
                "Manufacturer":{"type":"keyword"},
                "Sharpness":{"type":"keyword"},
                "Contrast":{"type":"keyword"},
                "LightSource":{"type":"keyword"},

                "DigitalZoomRatio":{"type":"text","fielddata":true},
                "Software":{"type":"text","fielddata":true},
                "ExposureProgram":{"type":"text","fielddata":true},
                "Model":{"type":"text","fielddata":true},
                "Copyright":{"type":"text","fielddata":true},

                "DateTaken":{"type":"date"},
                "LastPrinted":{"type":"date"},

                "ISO":{"type":"integer"},
                "Height":{"type":"integer"},
                "Width":{"type":"integer"},
                "MaxApperture":{"type":"integer"},
                "FocalLength":{"type":"integer"},
                "FocalLength35":{"type":"integer"},
                "FNumber":{"type":"float"}
            }}
         }}}'


        .\Search.Index.Files.ps1 -SharedFolders "$([Environment]::getfolderpath("mypictures"))\GeoTags" -indexName "shared_v1" `
            -aliasName "shared" -NewIndex -typeMapping $typeMapping
        .\Search.Index.Files.ps1 -SharedFolders "\\$(hostname)\C$\Search\_search" -indexName "shared_v1"

    C:\Search\logstash-5.0.0\bin\logstash.bat -f "C:\Search\Import\AusTender\logstash-austender.conf"

    ES helper function call examples:
        Import-Module -Name ".\ElasticSearch.Helper.psm1" -Force -Verbose
        &$cat
        #test file update/add 
        &$get "/_mapping"
        &$get "/shared_v1/_mapping"
        &$get "/shared/file,photo/_search"
        &$get "/shared/photo/AVQZ9Boa2V9OaD-z4_3i"
        &$delete "files"
        &$get "/files,library/_mapping"

#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] 
Param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target root folders for search collection')]
    [String[]]
    $SharedFolders=@(),
    [Parameter(HelpMessage = 'List of full path (partial name of folder or file) parts excluded from search')]
    $FilePathExceptions = @("*\_template*\*","*\_private\*","*\dfsrprivate\*","*\bin\*","*\tags\*","*obsolete\*","*\backup\*","*backup copy*","*\previous issues and bak-ups\*","*\log\*","*\old\*","*\recyclebin\*","*\AI_RecycleBin\*","*\conflictanddeleted\*","*\deleted\*","*\previous issues\*","*\temp\*","*\drafts\*","*\documents not used as re-worded\*","*Draft Documents\*","*\*Old Versions\*","*\.svn\*","*\.git\*","*\jre\*"), #,"*\archive\*"
    [string]$SearchFolderName = "_search",
    [string]$SearchFileMask = "*.search.json",
    [bool]$SearchFileNameHashed = $true,

    [string]$EventLogSource = "Search",
    [string]$LogFilePath = "$($env:LOG_DIR)\Search.Index.Files.log",

    [string]$indexName = "",
    [string]$aliasName = "",
    [Parameter(HelpMessage = 'Represents manual mapping - most accurate approach')]
    [string]$typeMapping,
    [Parameter(HelpMessage = '~20 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
    [int]$batchMaxSize = 20000000,

    #[parameter(parametersetname="indexSwitches")]
    [switch]$NewIndex,
    [switch]$BulkDocuments = $true
)


function Main(){
    try{Clear-Host}catch{} # avoid Exception setting "ForegroundColor": "Cannot convert null to type 
    <#if ($pscmdlet.ShouldProcess($SharedFolders)){
        Write-output "Going to index the following folders $($SharedFolders)"
        break
        exit
    }#>
    [System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions") | Out-Null
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}

    #configure logging functions
    Import-Module -Name "$scripLocation\Log.Helper.psm1" -Force #-Verbose
    $global:EventLogSource = $EventLogSource
    $global:LogFilePath = $LogFilePath
    #Write-Event -Message "test"
    #Write-Event -Error "Error test"

    #index helper functions
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose
    #&$cat
    #&$call "Get" "/_cluster/state"

    if ($typeMapping -ne $null -and $typeMapping -ne ""){
        $meatadata = ConvertFrom-Json $typeMapping
    }
    else{
        #read existing index mapping metadata
        try{
            $meatadata = ConvertFrom-Json (&$get "$indexName/_mapping")
        }
        catch{}
    }
    
    $fileTypeMapping = @{} #cached mapping between field name and data type
    $photoTypeMapping = @{} #cached mapping between field name and data type

    if ($meatadata -ne $null){
        $index_mt = $meatadata.psobject.properties | Where {$_.Name -eq "$indexName"} 
        if ($index_mt -ne $null){
            $type_mt = $index_mt.Value.mappings.psobject.properties | Where {$_.Name -eq "file"}
            if ($type_mt -ne $null){
                $type_mt.Value.properties.psobject.properties | %{
                    $fileTypeMapping.Set_Item($_.Name, $_.Value.type)
                }
            }

            $type_mt = $index_mt.Value.mappings.psobject.properties | Where {$_.Name -eq "photo"}
            if ($type_mt -ne $null){
                $type_mt.Value.properties.psobject.properties | %{
                    $photoTypeMapping.Set_Item($_.Name, $_.Value.type)
                }
            }
        }
    }

    #get storage status summary before index
    #ConvertFrom-Json (&$cat) | ft
    #(ConvertFrom-Json (&$cat)) | Where-Object {$_.index -EQ $indexName} | select health, status, docs.count, store.size |  fl


    # Create log file if it doesn't already exist
    if(-not (Test-Path -LiteralPath $LogFilePath)) {
        New-Item $LogFilePath -type file | Out-Null
    }
    Write-Host "$(Get-Date) Start session."

    #$filesDBDict = New-Object 'System.Collections.Generic.Dictionary[[string],[DateTime]]'
    #TBD: populate disct with existing documents/files...

    if ($NewIndex.IsPresent){
        try{
            &$delete $indexName 
        }
        catch{}


        <#Some types of analysis are extremely unfriendly with regards to memory.
        There is a reason to avoid aggregating analyzed fields: high-cardinality fields consume a large amount of memory when loaded into fielddata. 
        The analysis process often (although not always) generates a large number of tokens, many of which are unique. 
        This increases the overall cardinality of the field and contributes to more memory pressure.
        The string field datatype has been replaced by the text field for full text analyzed content, and the keyword field for not-analyzed exact string values. For backwards compatibility purposes, during the 5.x series:
        #>


        $fileProperties = @{
            #general properties
            Path = @{
                type = "keyword"
                fields = @{
                    Tree = @{ # Path.Tree field will contain the path hierarchy.
                        type = "string"
                        analyzer = "hierarchy_analyzer"
                    }
                }
            }
            Extension = @{
                type = "keyword"
            }
            Content = @{
                type = "text"
                analyzer = "english"
            }
            LastModified = @{
                type = "date"
                format = "YYYY-MM-DD"  
            }
        
            #the rest fields would be added dynamically

            <#Azure ML output based on Content
            Entities = @{
                type = "nested"
                properties = @{
                    Count = @{
                        type = "integer"
                        index = "not_analyzed"
                    }
                    Mention = @{
                        type = "string"
                    }
                    Type = @{
                        type = "string"
                    }
                }
            }#>

        }#general properties
        #additional properties mapping 
        $fileTypeMapping.GetEnumerator() | %{
            [bool]$isNewProp = $false
            try{
                if ($fileProperties.psobject.properties.Item($_.Key) -eq $null){
                    $isNewProp = $true
                }
            }
            catch{
                $isNewProp = $true
            }
            if ($isNewProp){ #add new field mapping
                if ($_.Value -eq "text"){
                    $fileProperties.Add(@{
                                    type = "$($_.Key, $_.Value)"
                                    fielddata = $true
                                })

                    #$fileProperties | Add-Member Noteproperty $_.Key @{
                    #    type = "$($_.Value)"
                    #    fielddata = $true
                    #}
                }
                else{
                    $fileProperties.Add($_.Key, @{
                                    type = "$($_.Value)"
                                })
                    #$fileProperties | Add-Member Noteproperty $_.Key @{
                    #    type = "$($_.Value)"
                    #}
                }
            }
        }

        $photoProperties = @{
            #general properties
            Path = @{
                type = "keyword"
        		#key = $True #obsolete notation, not supported in ES 2.0
                #index = "not_analyzed"
                fields = @{
                    Tree = @{ # Path.Tree field will contain the path hierarchy.
                        type = "string"
                        analyzer = "hierarchy_analyzer"
                    }
                }
            }
            Extension = @{
                type = "keyword"
                index = "not_analyzed" #To be able to group on the whole extension
            }

            #Exif data. This field should be typed in mapping explicitly
            GPS = @{
                type = "geo_point"
                geohash_prefix = "true" #tells Elasticsearch to index all geohash prefixes, up to the specified precision.
                precision = "1km" #The precision can be specified as an absolute number, representing the length of the geohash, or as a distance. A precision of 1km corresponds to a geohash of length 7.
            }

        }#general properties
        #additional properties mapping 
        $photoTypeMapping.GetEnumerator() | %{
            [bool]$isNewProp = $false
            try{
                if ($photoProperties.psobject.properties.Item($_.Key) -eq $null){
                    $isNewProp = $true
                }
            }
            catch{
                $isNewProp = $true
            }

            if ($isNewProp){ #add new field mapping
                if ($_.Value -eq "text"){
                    $photoProperties | Add-Member Noteproperty $_.Key @{
                        type = "$($_.Value)"
                        fielddata = $true
                    }
                }
                else{
                    $photoProperties | Add-Member Noteproperty $_.Key @{
                        type = "$($_.Value)"
                    }
                }
            }
        }

        &$createIndex $indexName -obj @{
            settings = @{
                analysis = @{
                  filter = @{
                    brit_synonym_filter = @{
                        type = "synonym"
                        synonyms = @("british,english","queen,monarch")
                    }
                  }
                  char_filter = @{ 
                    <##We define a custom char_filter called quotes that maps all apostrophe variants to a simple apostrophe.
                    #For clarity, we have used the JSON Unicode escape syntax for each character, but we could just have used the characters themselves: "‘=>'".
                    #We use our custom quotes character filter to create a new analyzer called quotes_analyzer.
                    #As always, we test the analyzer after creating it: 
                    #GET /my_index/_analyze?analyzer=quotes_analyzer
                    #You're my ‘favorite’ M‛Coy#>
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
                    synonyms_analyzer = @{
                        tokenizer = "standard"
                        filter = @( "lowercase","brit_synonym_filter" )
                    }
                  }#analyzer
                } #analysis
            } #| ConvertTo-Json -Depth 4

            mappings = @{
                file = @{
                     dynamic = $true #will additional fields dynamically.
                     date_detection = $false #avoid “malformed date” exception
                     properties = $fileProperties
                } #file

                photo = @{
                    dynamic = $true #will additional fields dynamically.
                    date_detection = $false #avoid “malformed date” exception
                    properties = $photoProperties
                } #photo
            } #mappings
        } #obj
    }

    <#if ($DeleteAllDocuments.IsPresent){
        &$delete "$indexName/file,photo/_query?q=*"
    }#>

    [string]$global:BulkBody = ""
    #Set-Variable -Name BulkBody -Option AllScope #make this variable available in functions 

    foreach ($sharedFolder in $SharedFolders){
        #$sharedFolder = "C:\Temp"
        if (Test-Path $sharedFolder -PathType Container){
            Echo "$(Get-Date) Start crawling folder: $sharedFolder ..." #Write-Event 
            #$filesDBDict.Clear()
            LoadFolder -RootPath $sharedFolder -Level 0
        }
        elseif (Test-Path $sharedFolder -PathType Leaf){
            LoadFile -fileInfo $sharedFolder
        }
    }
    if ($global:BulkBody -ne ""){
        $result = &$post "$indexName/_bulk" $global:BulkBody
        #validate bulk errors
        if ($result -ne $null){
            $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
            if ($errors -ne $null -and $errors.Count -gt 0){
                $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
            }
        }

        $global:BulkBody = ""
    }

    if ($NewIndex.IsPresent){
        if ($aliasName -ne ""){
            &$put "$indexName/_alias/$aliasName"
        }
    }
    Echo "$(Get-Date) End session." #Write-Host
}


#LoadFolder -RootPath "\\shares\fs\" -FileExtension ".pdf" -ParentHasDFSFolder $false -Level 0
#LoadFolder -RootPath $sharedFolder -DfsFolders $null -Level 0
function LoadFolder(){
    Param(
        [string]$RootPath,
        #[string[]]$DfsFolders,
        [int]$Level
    )
    $RootPath = $RootPath.Trim().TrimEnd('\').TrimEnd('.').ToLower();
    if (($FilePathExceptions | where { $RootPath+'\' -like "$_"}).Count -gt 0 ) {return}
    #[bool]$ChildHasDFSFolder = (($DfsFolders | Where { $searchFolder -like "$RootPath*"}).Count -gt 0)
#Write-Output "Load Folder: $($RootPath); Level: $($Level)"
    $Level++

    #take files on current level only
    $files = Get-ChildItem $RootPath -File -Force -ErrorAction SilentlyContinue | # -ErrorVariable err !do not use -ReadOnly
        Where-Object {$_.FullName.Length -le 255} | 
        Where-Object {$_ -is [IO.FileInfo]} |
            % {"$($_.FullName.ToLower())"}
    $files | ForEach-Object {
        $fileInfo = [IO.FileInfo]$_
        if ($fileInfo.Name.ToLower() -like $SearchFileMask) {
#Echo "Load Search File: $($fileInfo.FullName)"
                LoadFile -fileInfo $fileInfo #-longPath = $null
        }
    }
    (Get-ChildItem -Path "$RootPath" -Directory -Force -ErrorAction SilentlyContinue -ErrorVariable err)| % {
        if (($FilePathExceptions | where { $_.FullName+'\' -like "$_"}).Count -eq 0 ) {
            #proceed recursion up to level 20, to avoid deep recursion
            if (($Level -lt 20) -and ($RootPath.ToLower() -ne $_.FullName.ToLower()) ){ 
                LoadFolder -RootPath $_.FullName -Level $Level
            }
        }
    }
    foreach ($errorRecord in $err) {
        if ($errorRecord.Exception -is [System.ArgumentException]) {
            Write-Event "Illegal characters in path: $($errorRecord.TargetObject)" -Warning
        }
        elseif ($errorRecord.Exception -is [System.IO.PathTooLongException]) {
            Write-Event "Path too long: $($errorRecord.TargetObject)" -Warning
        }
        else {
            Write-Event "Error: $($errorRecord.TargetObject)" -Error
        }
    }
}


#[IO.FileInfo]$fileInfo = "C:\Search\_search\-18110677.search.json"
#[IO.FileInfo]$fileInfo = "C:\Search\_search\-32778784.search.json"
#LoadFile -fileInfo $fileInfo
function LoadFile() {
    Param(
        [IO.FileInfo]$fileInfo
    )

    #the fully qualified file name must be less than 260 characters
    if ($fileInfo.FullName.Length -gt 255 -or $fileInfo.Name.StartsWith("~")) {return}
    #skip files bigger than 20 MB
    if ($fileInfo.Length -gt $batchMaxSize) {return}
    #exclude irrelevant folders
    if (($FilePathExceptions | where { $fileInfo.DirectoryName.ToLower() -like "$_"}).Count -gt 0 ) {return}

    [string]$extension = $fileInfo.Extension.ToLower()
    if(($extension -eq "")) {
        return
    }
    [string]$fullPath = $fileInfo.FullName
    [string]$key = $fullPath.ToLower()

    [string]$directoryName = $fileInfo.DirectoryName
    [DateTime]$fileLastWriteTimeUtc = $fileInfo.LastWriteTimeUtc
    [int]$fileLength = $fileInfo.Length
    [string]$fileName = $fileInfo.Name

    <#if ($filesDBDict.ContainsKey($key)) {
        $filesDBDict[$key] = [System.DateTime]$fileInfo.LastWriteTimeUtc
        Write-Event "Updating existing file... $key"
    }
    else{
        $filesDBDict.Add($key, [System.DateTime]$fileInfo.LastWriteTimeUtc);
        Write-Event "Adding new file... $key"
    }#>
    #$fullPath = "C:\Users\andrew.butenko\Pictures\GeoTags\_search\-1607404516.search.json"
    #$fileJson = Get-Item -Force $fullPath #this method works with file size <4Mb
    $json = Get-Content $fullPath -Raw #-Encoding UTF8
    $jsser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $jsser.MaxJsonLength = $jsser.MaxJsonLength * 10
    $jsser.RecursionLimit = 10
    $fileObj = $jsser.DeserializeObject($json)
    [string]$searchPath = ($fileInfo.Directory.Parent.FullName.Replace("\","/").TrimEnd("/") + "/"+$fileObj.Name + $fileObj.Extension).ToLower() #).TrimStart("//")
#Write-Output "   |___Original Path: $searchPath"
    $indexObj = New-Object PSObject
    #Add General properties
    $indexObj | Add-Member Noteproperty "Path" $searchPath
    $indexObj | Add-Member Noteproperty "Extension" $fileObj.Extension.TrimStart('.')
    $indexObj | Add-Member Noteproperty "LastModified" $fileObj.LastModified.ToString("yyyy-MM-dd")
    #convert Properties collection
    if($fileObj.Properties -ne $null){
        foreach ($prop in $fileObj.Properties.GetEnumerator()| Where-Object {$_.Key.ToLower()-notin "path","extension","lastmodified","pdfparser"}){
            if ($prop.Key -eq "GPS"){
                if ($prop.Value -match "([0-9]+)°([0-9]+)'([0-9]+[\.[0-9]+]?)\""(S|N)\s+([0-9]+)°([0-9]+)'([0-9]+[\.[0-9]+]?)\""(E|W)"){
                    $lat = [math]::round([math]::abs([int]$matches[1]) + ([decimal]$matches[2])/60.0 + ([decimal]$matches[3])/3600.0,6)
                    if($matches[4] -eq "S"){ $lat = $lat * (-1) }

                    $lng = [math]::round([math]::abs([int]$matches[5]) + ([decimal]$matches[6])/60.0 + ([decimal]$matches[7])/3600.0,6)
                    if($matches[8] -eq "W"){ $lng = $lng * (-1) }
                    #if $lat < -90 OR $lat > 90 # System.FormatException: 24201: Latitude values must be between -90 and 90 degrees.

                    #It was decided early on to switch the order for arrays @(lat, lng) in order to conform with GeoJSON.
                    #The result is a bear trap that captures all unsuspecting users on their journey to full geolocation nirvana.
                    $indexObj | Add-Member Noteproperty $prop.Key @{
                            "lat" = $lat
                            "lon" = $lng
                         } 
                }
            }
            else{
                $indexObj | Add-Member Noteproperty $prop.Key "$(CleanContent($prop.Value))"
            }
        }
    }
    [string]$typeName = "file"
    #add file to index and read _id ???
    if ($fileObj.Extension.ToLower() -eq ".jpg"){
        $typeName = "photo"
        #no need to load Content here
        #$indexObj | Remove-Member Noteproperty "Content"

        #&$add -index $indexName -type 'photo' -obj $indexObj
        if ($BulkDocuments.IsPresent){
            $global:BulkBody += '{"index": {"_type": "photo"}'+ "`n" +($indexObj | ConvertTo-Json -Depth 2 -Compress| Out-String)  + "`n"
        }
    }
    elseif($fileObj.Content.Trim() -ne ""){ #other types have content
        <#if ($fileObj.Entities -ne $null){
            #foreach ($ent in $fileObj.Entities){
            #    $entityObj = New-Object PSObject
            #    #$entityObj | Add-Member Noteproperty "FileId" $fileId
            #    $entityObj | Add-Member Noteproperty "Path" $searchPath
            #    $entityObj | Add-Member Noteproperty "Count" $ent.Count
            #    $entityObj | Add-Member Noteproperty "Mention" $ent.Mention
            #    $entityObj | Add-Member Noteproperty "Type" $ent.Type
            #    &$add -index $indexName -type 'entity' -obj $entityObj
            #}
            $indexObj | Add-Member Noteproperty "Entities" $fileObj.Entities
        }#>
        $indexObj | Add-Member Noteproperty "Content" "$(CleanContent($fileObj.Content))"
        
        #&$add -index $indexName -type 'file' -obj $indexObj
        if ($BulkDocuments.IsPresent){
            $global:BulkBody += '{"index": {"_type": "file"}'+ "`n" +($indexObj | ConvertTo-Json -Compress| Out-String)  + "`n"
        }
    }

    if ($BulkDocuments.IsPresent){
        $percent = [decimal]::round(($global:BulkBody.Length / $batchMaxSize)*100)
        if ($percent -gt 100) {$percent = 100}
        Write-Progress -Activity "Batching in progress: $fullPath" -status "$percent% complete" -percentcomplete $percent;
        if ($global:BulkBody.Length -ge $batchMaxSize){
            $result = &$post "$indexName/_bulk" $global:BulkBody
            #validate bulk errors
            if ($result -ne $null)
            {
                $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
                if ($errors -ne $null -and $errors.Count -gt 0){
                    $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status); path: $($searchPath)" -f Red }
                }
            }
            $global:BulkBody = ""
        }
    }
    else{
        $id = (ConvertFrom-Json(&$search -index "$indexName" -type "$typeName" -obj @{
          fields = @("_id")
          query = @{ match_phrase = @{ Path = $searchPath }}})).hits.hits[0]._id
        if ($id -ne  ""){
#Echo "Update file id: $id"
            &$replace -index $indexName -type $typeName -id $id -obj $indexObj
        }
        else{
#Echo "Add file: $filePath"
            &$add -index "$indexName" -type "$typeName" -obj $indexObj
        }
    }
}
# CleanContent("jan_joubert\u0027s_gat_bridge")
function CleanContent(){
    Param(
        [string]$Content
    )
    #$b=[system.text.encoding]::UTF8.GetBytes($Content)
    #$c=[system.text.encoding]::convert([text.encoding]::UTF8,[text.encoding]::ASCII,$b) 
    #$Content = -join [system.text.encoding]::ASCII.GetChars($c)

    $Content = $Content  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
    $Content = $Content -replace '\\u\d{3}[0-9a-zA-Z]', ' ' # remove encodded special symbols like '\u0026' '\u003c'
    $Content = $Content -replace '[`''~!*“"•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
    $Content = $Content -replace '\s+', ' ' #remove extra spaces
    $Content = $Content -replace '(\w)\1{3,}', '$1' #replace repeating symbols more than 3 times with 1: "aaaassssssssssseeeee111112222223334" -replace '(\w)\1{3,}', '$1'
    $Content = $Content.Trim() 
    return $Content
}


<#
It was decided early on to switch the order for arrays @(lat, lng) in order to conform with GeoJSON.
The result is a bear trap that captures all unsuspecting users on their journey to full geolocation nirvana.

$gps = "32°3'29.8""S  115°48'16.88""E, 42.0758377425044M above Sea Level"
$gps = "17°57'1.2112""S  122°14'20.8062""E, 3.799M below Sea Level"
$gps = "32°5'35.29""S  115°52'48.1""E, 12.7743229689067M below Sea Level"
$gps = "17°57'1.3829""S  122°14'20.8337""E, 0M above Sea Level"
$gps = "17°56'56.3635""S  122°14'17.3181""E, 92M above Sea Level"
$gps = "17°57'1.3829""S  122°14'20.8337""E, 0M above Sea Level"
$gps = "32°3'29.3752""S  115°48'13.1129""E, 0M above Sea Level" 
$gps = "31°55'30.54""S  115°57'37.62""E, 32.0554493307839M above Sea Level"
$gps = "31°55'32.21""S  115°57'40.12""E, 22M above Sea Level"
$gps = "31°55'32.21""S  115°57'40.12""E" #data wihout altitude
$gps = "131°55'32.21""  115°57'40.12""" #incorrect data

if ($gps -match "([0-9]+)°([0-9]+)'([0-9]+[\.[0-9]+]?)\""(S|N)\s+([0-9]+)°([0-9]+)'([0-9]+[\.[0-9]+]?)\""(E|W)"){
    $latitudeDD = [math]::round([math]::abs([int]$matches[1]) + ([decimal]$matches[2])/60.0 + ([decimal]$matches[3])/3600.0,6)
    if($matches[4] -eq "S"){ $latitudeDD = $latitudeDD * (-1) }

    $longitudeDD = [math]::round([math]::abs([int]$matches[5]) + ([decimal]$matches[6])/60.0 + ([decimal]$matches[7])/3600.0,6)
    if($matches[8] -eq "W"){ $longitudeDD = $longitudeDD * (-1) }

    @($latitudeDD, $longitudeDD)
}
#>

Main
Echo Finish
