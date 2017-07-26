<# cd C:\Search\Scripts\

    .\Search.Index.Log.ps1 -indexName "logs_v1" -aliasName "logs" -typeName "log" -NewType -NewIndex -LogFilePath "\\Server\Logs"
#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] 
Param(
    #[Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target server')]
    [Parameter(HelpMessage = '# of days back from current Date')]
    [int]$LastDays = 60,
    [Parameter(HelpMessage = '# of file bottom lines to read')]
    [int]$LastLines = 5000,
    [string]$TimeStampFormat = "MM/dd/yyyy HH:mm:ss",
    $IgnoreErrorMasks = @("*emtpy file*","*The record already exists*"),
    [string]$LogFilePath = "$($env:LOG_DIR)",

    [string]$indexName,
    [string]$aliasName,
    [string]$typeName = "log",

    [Parameter(HelpMessage = '~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
    [int]$batchMaxSize = 1000,

    [switch]$newIndex,
    [switch]$newType
)

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

function Main(){
    try{Clear-Host}catch{} # avoid Exception setting "ForegroundColor": "Cannot convert null to type 
  
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose
    
    if ($newIndex.IsPresent){
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

    Add-Type -AssemblyName System.Web
    [DateTime]$StartDate = [DateTime]::Today.AddDays(-$LastDays)

    $files = Get-ChildItem $LogFilePath -File -Filter "*.log" -Force -ErrorAction SilentlyContinue | # -ErrorVariable err !do not use -ReadOnly
            Where-Object {$_.FullName.Length -le 255 -and $_.Name -notlike "*search*.log"} | 
            Where-Object {$_ -is [IO.FileInfo]} |
                % {"$($_.FullName.ToLower())"}

    $infoCache = @()
    [string]$BulkBody = ""
    $names = @()
    $types = @()
    $rows = 0
    $files | ForEach-Object {
        $fileInfo = [IO.FileInfo]$_
Echo "Read $($fileInfo.FullName)..."
        $lines = (Get-Content $($fileInfo.FullName))[-1 .. -$LastLines]
        $fileName = $fileInfo.Name
        [int]$rowcount = 0;
        foreach($line in $lines | Where {$_.Length -gt 20} ){
            $rows++
            if ($rows -eq 1){
                if ($newIndex.IsPresent) { #create new index
                    try{
                        &$delete $indexName 
                    }
                    catch{}

                    &$createIndex $indexName -obj @{
                        settings = @{
                            analysis = @{
                              filter = @{
                                brit_synonym_filter = @{
                                    type = "synonym"
                                    synonyms = @("british,english","queen,mo0narch")
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
                            log = @{
                                 dynamic = $true #will additional fields dynamically.
                                 date_detection = $false #avoid “malformed date” exception

                                 properties = @{
                                    #general properties
                                    LogDate = @{
                                        type = "date"
                                        format = $TimeStampFormat #"YYYY-MM-DD"  
                                    }
                                    LogName = @{
                                        type = "keyword"
                                    }
                                    LogEntry = @{
                                        type = "text"
                                        analyzer = "english"
                                    }
                                } #properties
                                } #file

                        } #mappings
                    } #obj
                }

                <#if ($newIndex.IsPresent -or $newType.IsPresent){ #add new type mapping to existing index with settings
                    #When another type is added to exsting index it could have the same field names as other types, but different data type. 
                    #ES generate exception. I think this is wrong. 
                    #As a workaround, we need to use parameter update_all_types to avoid missmatched field types exception
                    &$put "$($indexName)/_mapping/$($typeName)?update_all_types" -obj @{
                        #dynamic = $true #will create new fields dynamically
                        date_detection = $true #avoid “malformed date” exception
                        properties = $typeMapping
                    }
                }#>
            } #1st record

            try {
                $info = $line.Substring(20)
                #ignore known errors...
                if ($info -ne $null -and $info -ne "" ){
                    [DateTime]$timestamp = [datetime]::ParseExact($line.Substring(0,19),$TimeStampFormat,$null) 
                    if ( ($timestamp -gt $StartDate) `
                            -and ($info -like "*Error*") `
                            -and !$infoCache.Contains($info) `
                            -and ($IgnoreErrorMasks | where { $info -like "$_"}).Count -eq 0
                        ){
                        $infoCache +=$info

                        $entryProperties = @{
                            LogDate = $line.Substring(0,19) #$timestamp.ToString($TimeStampFormat)
                            LogName = $fileName
                            #LogPath = $fileInfo.FullName
                            LogEntry = CleanContent($info) #[System.Web.HttpUtility]::HtmlEncode($info)
                        }

                        $entry = '{"index": {"_type": "'+$typeName+'"}'+ "`n" +($entryProperties | ConvertTo-Json -Compress| Out-String) + "`n"
                #$entry
                        $BulkBody += $entry
                        $batchPercent = [decimal]::round(($BulkBody.Length / $batchMaxSize)*100)
                        if ($batchPercent -gt 100) {$batchPercent = 100}
                        Write-Progress -Activity "Loading $fileName" -status "Batching $batchPercent%" -percentcomplete $batchPercent;

                        if ($BulkBody.Length -ge $batchMaxSize){
                            $result = &$post "$indexName/_bulk" $BulkBody
                            #validate bulk errors
                            if ($result -ne $null){
                                $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
                                if ($errors -ne $null -and $errors.Count -gt 0){
                                    $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
                                }
                            }
                            $BulkBody = ""
                        }
                    }
                }
            }
            catch{}
        }
        Write-Progress -Completed -Activity "Loading $fileName"
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

    if ($NewIndex.IsPresent){
        if ($aliasName -ne $null -and $aliasName -ne ""){
            &$put "$indexName/_alias/$aliasName"
        }
    }
    #Start-Sleep 1
    #Write-Event "$(Get-Date) End session 'Search.Index.Log'."
}

Main
