<#
Preperation check list could be found here https://github.com/banban/OhMySearch/wiki/Preperations
Later this script will cover all preperations to avoid manual processing

Unit tests:
    cd C:\Search\Scripts

    .\Search.Json.ps1 -SharedFolders "$([Environment]::getfolderpath("mypictures"))\NGC2015" -FileExtensionsForSearch ".jpg"
    .\Search.Json.ps1 -SharedFolders "$([Environment]::getfolderpath("mydocuments"))" -FileExtensionsForSearch ".pdf"
    .\Search.Json.ps1 -SharedFolders "C:\Search\_artefacts"
    .\Search.Json.ps1 -SharedFolders "\\shares\library\"
    .\Search.Json.ps1 -SharedFolders "\\shares\files\"

Test OCR
1.pdf to png
    &"$($env:MAGICK_HOME)\magick.exe" -monochrome -limit memory 10GB -limit area 10GB -limit disk 15GB -limit map 10GB -density 200 "C:\Search\_artefacts\AMM 25 Part 1.pdf" "C:\Search\_temp\MAGICK_TMPDIR\ocr-%04d.png" | Out-Null
2.png to txt
    &"$env:TESSDATA_PREFIX\tesseract.exe" "$($env:MAGICK_TMPDIR)\ocr-0000.png" "$($env:MAGICK_TMPDIR)\ocr-0000" -psm 1 | Out-Null # -l eng

#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    #filters
    [Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target root folders for search collection')]
    [String[]]
    $SharedFolders=@(), #"\\shares\library","\\shares\fs\"
    [Parameter(HelpMessage = 'List of extensions inclusded in search')]
    [ValidateCount(1,100)]
    $FileExtensionsForSearch = @(".xls",".xlsx",".xlsm",".xlsb",".ppt",".pps",".pptx",".doc",".docx",".docm",".pdf",".jpg",".msg"), #
    [Parameter(HelpMessage = 'List of full path (partial name of folder or file) parts excluded from search')]
    $FilePathExceptions = @("*\_template*\*","*\_private\*","*\dfsrprivate\*","*\bin\*","*\tags\*","*obsolete\*","*\backup\*","*backup copy*","*\previous issues and bak-ups\*","*\log\*","*\old\*","*\recyclebin\*","*\AI_RecycleBin\*","*\conflictanddeleted\*","*\deleted\*","*\previous issues\*","*\temp\*","*\drafts\*","*\documents not used as re-worded\*","*_Draft Documents\*","*\99_Old Versions\*","*\.svn\*","*\.git\*","*\jre\*"),
    [Parameter(HelpMessage = 'List of file name excluded from search')]
    $FileNameExceptions = @("*.search.json","*.zip","*.config","*.db","*.bak","*.url","*.lnk","*.log","subsegmentlist_*.pdf","*._*.pdf","* draft *.","*_draft_*.*","temp *.*","*.bin","_permissions.txt","_readme.txt","*[?][?]*","_*~*.pdf"),
    [Parameter(HelpMessage = 'werfault process is message box described here http://smallbusiness.chron.com/stop-werfaultexe-56154.html')]
    $ProcessNameExceptions = @("werfault","excelcnv","ofc","excelcnv","wordcnv", "powerpnt", "doc2x","ppt2x","xls2x"), #"WINWORD","EXCEL","POWERPNT"

    #tools
    [string]$TesseractExecPath = "$($env:TESSERACT_HOME)\tesseract.exe",
    [string]$ImageMagickPath = $env:MAGICK_HOME, #"$($ImageMagickPath)\magick.exe"
    [string]$ImageMagickTempFiles = "$([environment]::getfolderpath(“mydocuments”))".Trim("Documents") + "magick-*",
    [string]$ImageMagickTempPath = $env:MAGICK_TMPDIR,
    [string]$OfficeFileConverterExecPath = "$($env:SEARCH_HOME)\_artefacts\Binn\OfficeFileConverter\Tools\ofc.exe",
    [string]$OfficeFileConverterTempPath = "$($env:SEARCH_HOME)\_temp\OfficeFileConverter\", #!!!create Input and Output folders here
    [string]$b2xtranslatorExecPath = "$($env:SEARCH_HOME)\_artefacts\Binn\b2xtranslator\", 
    [string]$GHostScriptDllPath = "$($env:GHOSTSCRIPT_HOME)\bin\gsdll64.dll",
    [string]$iTextSharpDllPath = "$($env:SEARCH_HOME)\_artefacts\Binn\itextsharp.dll",
    [string]$DocFormatOpenXmlDllPath = "$($env:SEARCH_HOME)\_artefacts\Binn\DocumentFormat.OpenXml.dll",

    #General settings
    [int]$MaxFileBiteSize = 20000000,  #<=20 Mb
    [int]$MaxFolderNestedLevel = 20,
    [int]$MaxFilesInFolder = 20,
    [string]$SearchFolderName = "_search",
    [string]$LogFilePath = "$($env:LOG_DIR)\Search.Index.Json.log",
    [string]$EventSource = "Search",
    #Azure tools settings
    [string]$EntityRecognizerURI = $env:EntityRecognizerURI,
    [string]$EntityRecognizerApiKey = $env:EntityRecognizerApiKey,

    #[parameter(parametersetname="SearchSwitches")]
    [switch]$SearchFileNameHashed = $true
)


#recursive function with 
function LoadFolder(){
    Param(
        [string]$RootPath,
        [int]$Level
    )

    $RootPath = $RootPath.Trim().TrimEnd('\').TrimEnd('.').ToLower();
    if (($FilePathExceptions | where { $RootPath+'\' -like "$_"}).Count -gt 0 ) {return}

    $Level++
#Echo "--- $($RootPath); Level: $($Level) ---"

    #take files at the current level only
    $files = Get-ChildItem $RootPath -File -Force -ErrorAction SilentlyContinue | # -ErrorVariable err !do not use -ReadOnly
        Where-Object {$_.FullName.Length -le 255} | 
        Where-Object {$_ -is [IO.FileInfo]} |
        Where-Object {$FileExtensionsForSearch.Contains($_.Extension.ToLower()) -eq $True} |
        Sort-Object -Property LastWriteTime -Descending | Sort-Object -Property Length -Descending |
        % {"$($_.FullName.ToLower())"}

    if($files.Count -gt 0){
        if ($files.Count -gt $MaxFilesInFolder){
            $files = $files | Select-Object -First $MaxFilesInFolder
        }

        $searchFiles = $null
        $searchFolder = Get-Item "$($RootPath)\$($SearchFolderName)\" -Force -ErrorAction SilentlyContinue 
        if ($searchFolder -ne $null){
            $searchFiles = Get-ChildItem $searchFolder -File -Force -ErrorAction SilentlyContinue | # -ErrorVariable err !do not use -ReadOnly
                Where-Object {$_.FullName.Length -le 255} | 
                Where-Object {$_ -is [IO.FileInfo]} |
                % {"$($_.FullName.ToLower())"}
        }

        if ($SearchFileNameHashed.IsPresent) {
            $fileNames = $files | %{ (split-path $_ -Leaf).ToLower().GetHashCode().ToString()}
        }
        else {
            $fileNames = $files | %{ (split-path $_ -Leaf)}
        }

        if ($searchFiles -ne $null){
            #delete orphan search files
            $searchFiles | %{ 
                if (!$fileNames.Contains((split-path $_ -Leaf).TrimEnd(".json").TrimEnd("search").TrimEnd("."))){
                    try{
                        $fileInfo = [IO.FileInfo]$_
                        $fileInfo.Attributes = 'Normal' #can't delete hidden file until unhide it
                        $fileInfo.Delete(); #orphan search file
                    }
                    catch{}
                }
            }
        }

        #index existing files
        $files | ForEach-Object{
            $fileInfo = [IO.FileInfo]$_

            #skip pdf version of word document: "test.pdf" <== "test.docx" | "test.doc"
            if ($fileInfo.Name.ToLower() -like "*.pdf"){
                if (!$files.Contains($fileInfo.Name.ToLower().TrimEnd(".pdf")+".docx") -and !$files.Contains($fileInfo.Name.ToLower().TrimEnd(".pdf")+".doc")) {
                    LoadFile -fileInfo $fileInfo #-longPath = $null
                }
            }
            elseif ($FileExtensionsForSearch.Contains($fileInfo.Extension.ToLower()) -eq $True) { #do not mix .xls and xlsx
                LoadFile -fileInfo $fileInfo
            }
        }

        $searchFolder = Get-Item "$($RootPath)\$($SearchFolderName)\" -Force -ErrorAction SilentlyContinue 
        if ($searchFolder -ne $null){
            #clean up empty folders
            try{
                $searchFiles = Get-ChildItem $searchFolder -Filter "*.search.json" -File -Force -ErrorAction SilentlyContinue
                if ($searchFiles.Count -eq 0){
                    Remove-Item "$($RootPath)\$($SearchFolderName)\" -Force -Recurse | Out-Null
                    #$searchFolder = Get-Item "$($RootPath)\$($SearchFolderName)\" -Force -ErrorAction SilentlyContinue 
                    #$searchFolder.Attributes = 'Normal'
                    #$searchFolder.Delete()| Out-Null 
                }
            }
            catch{}
        }
    }

    #proceed with sub folders with except of $SearchFolderName
    (Get-ChildItem -Path "$RootPath" -Directory -ErrorAction SilentlyContinue -ErrorVariable err) | 
        ? {$_.Name -ne $SearchFolderName} |
        % {
            if (($FilePathExceptions | where { $_.FullName+'\' -like "$_"}).Count -eq 0 ) {
                #traverse deep down until max allowed level
                if (($Level -lt $MaxFolderNestedLevel) -and ($RootPath.ToLower() -ne $_.FullName.ToLower()) ){ 
                    LoadFolder -RootPath $_.FullName -Level $Level
                }
            }
        }

    foreach ($errorRecord in $err) {
        if ($errorRecord.Exception -is [System.ArgumentException]) {
            Echo "Warning: Illegal characters in path: $($errorRecord.TargetObject)"
        }
        elseif ($errorRecord.Exception -is [System.IO.PathTooLongException]) {
            Echo "Warning: Path too long: $($errorRecord.TargetObject)"
        }
        else {
            Echo "Error: $($errorRecord.TargetObject)"
        }
    }
}

function LoadFile () {
    Param(
        [IO.FileInfo]$fileInfo
    )

    [string]$fullPath = $fileInfo.FullName.ToLower()
    [string]$extension = $fileInfo.Extension.ToLower()
    if(($extension -eq "")) {
        return
    }

    #the full file name must be less than 260 characters. PowerShell restriction
    if ($fullPath.Length -gt 255 -or $fileInfo.Name.StartsWith("~")) {return}
    #skip files bigger than max size (empiric rule)

    if ($fileInfo.Length -gt $MaxFileBiteSize) {return}

    #exclude irrelevant folders and files
    if (($FilePathExceptions | where { $fileInfo.DirectoryName.ToLower() -like "$_"}).Count -gt 0 ) {return}
    if (($FileNameExceptions | where { $fileInfo.Name.ToLower() -like "$_"}).Count -gt 0 ) {return}

    $searchFolder = Get-Item "$($fileInfo.DirectoryName)\$($SearchFolderName)\" -Force -ErrorAction SilentlyContinue 
    if ($searchFolder -eq $null){
        $searchFolder = New-Item -ItemType directory -Path "$($fileInfo.DirectoryName)\$($SearchFolderName)\" -ErrorAction SilentlyContinue 
        $searchFolder.Attributes = 'Hidden' #, NotContentIndexed, Compressed is ignored
    }

    if ($SearchFileNameHashed) {
        [string]$searchFilePath = "$($fileInfo.DirectoryName)\$($SearchFolderName)\$($fileInfo.Name.ToLower().GetHashCode()).search.json"
    }
    else {
        [string]$searchFilePath = "$($fileInfo.DirectoryName)\$($SearchFolderName)\$($fileInfo.Name).search.json"
    }

    if (Test-Path -LiteralPath $searchFilePath){ #check if .search.jason file exists and has higher LastModified date
        try{
            $fileJson = Get-Item -Force $searchFilePath # [IO.FileInfo]$searchFilePath
            if ($extension -eq ".pdf" -and $fileInfo.Length -gt 1024 -and $fileJson.Length -lt 512){
                $fileObj = Get-Content $searchFilePath -Raw | ConvertFrom-Json 
                if ($fileObj.Content -ne ""){
                    return
                }
                #Echo "Warning: No content in search file: $($searchFilePath)"
            }
            elseif ($fileJson -ne $null -and $fileJson.LastWriteTimeUtc.AddSeconds(-3) -ge $fileInfo.LastWriteTimeUtc.AddSeconds(-3) ){
#Echo "$searchFilePath is up to date"
                return
            }
            #update .search.json file ...
            $fileJson.Attributes = 'Normal' # unlock attributes before overwriting

        }
        catch{}
    }
Echo $fullPath
#    Echo "      |___Extracting data to search file: $($searchFilePath) ..."
    #[string]$fileExtensionForSearch = ".txt"
    [string]$fileText = $null
    [byte[]]$fileContent = $null
    $fileProperties = @{}
    [bool]$cleanContent = $true
#$extension
    switch ($extension) {
        #".zip" {
            #Echo "extract files to temp folder and read content" 
            #Get-ChildItem $fullPath | % {<insert your favorite zip utility here>; Move-Item $_ C:\tmp\unzipped}
            #LoadFile -fileInfo [IO.FileInfo]$fileInfo2
        #}
        ".pdf" {
            ParsePdfText ($fullPath)
        }
        ".msg" {
            ParseMsgText ($fullPath)
        }
        ".jpg" {
            ParseJpgText ($fullPath)
            $cleanContent = $false
            #$fileExtensionForSearch = ".svg"
        }
        {$_ -in ".doc",".xls",".ppt",".pps"} {
            #Echo "        |___Converting old office document to XML format... $($fileInfo.FullName)"
            #there are 2 tools. 1st is ofc - accurate but heavy. 2nd is b2xtranslator, lightweight, but do not convert properties
            #clean temp files hanged and processes
            try {
                KillConverterProcesses(100);
                Remove-Item $OfficeFileConverterTempPath\Input\* -recurse -Force #delete hidden files as well
                Remove-Item $OfficeFileConverterTempPath\Output\* -recurse -Force #delete hidden files as well
            }
            catch {
                 #Echo $_.Exception.Message
                 #Add-Content $LogFilePath "$(Get-Date) Error: " $_.Exception.Message
            }

            #1st tool approach with custom fields :)
            [string]$filePathIni = $OfficeFileConverterExecPath.Replace(".exe",".ini")
            [string]$filePathCopy =$OfficeFileConverterTempPath+"Input\"+$fileInfo.Name.ToLower()
            [string]$filePathOut = $OfficeFileConverterTempPath+"Output\"+$fileInfo.Name.ToLower()+"x"
            Copy-Item $fileInfo.FullName "$filePathCopy"
            Set-ItemProperty $filePathCopy -name IsReadOnly -value $false
            Unblock-File -Path $filePathCopy
            
            #1st tool - direct call stops other processes caused by protected files modal dialog
            #&$OfficeFileConverterExecPath $filePathIni | Out-Null 
            $process = $(Start-Process $OfficeFileConverterExecPath -ArgumentList "$filePathIni" -WindowStyle Hidden -PassThru) #| Wait-Process # do not wait here!!!
            Start-Sleep -Milliseconds 5000
            if((Test-Path -LiteralPath $filePathOut) -eq $false) { 
                Start-Sleep -Milliseconds 2000
            }
            #if 1st approach fails, use 2nd
            if((Test-Path -LiteralPath $filePathOut) -eq $false) { 
                KillConverterProcesses(5000);
                #2nd tool - without custom fields :(
                [string]$executable = $b2xtranslatorExecPath + $extension.replace(".","")+"2x.exe"

                $arguments = '"{0}" -o "{1}" -v 0' -f $filePathCopy, $filePathOut
                Start-Process $executable -ArgumentList $arguments -WindowStyle Hidden -PassThru | Wait-Process #wait here!
            }
   
            if(Test-Path -LiteralPath $filePathOut) {
                #Echo "        |___Extracting content from XML file: $filePathOut ..."
                switch ($extension) {
                    ".doc" {
                        #Echo "Processing docx content"
                        ParseWordXml($filePathOut)
                    }
                    ".xls"{
                        #Echo "Processing xlsx content"
                        ParseExcelXml ($filePathOut)
                    }
                    ".ppt" {
                        #Echo "Processing pptx content"
                        ParsePowerPointXml ($filePathOut)
                    }
                    ".pps" {
                        #Echo "Processing pptx content"
                        ParsePowerPointXml ($filePathOut)
                    }
                }
            }
        }

        {$_ -in ".htm",".html",".csv",".txt",".xml",".rtf"} {
            #Echo "Processing text content"
            #$fileText = [System.IO.File]::ReadAllText($fullPath)
            #PS 3.0 has new command: 
            $fileText = Get-Content $fullPath -Raw
        }

        {$_ -in ".docx",".docm"} {
            #Echo "Processing docx content"
            ParseWordXml ($fullPath)
        }
        {$_ -in ".xlsx",".xlsm"} {
            #Echo "Processing xlsx content"
            ParseExcelXml ($fullPath)
        }
        {$_ -in ".pptx",".pptm"} {
            #Echo "Processing pptx content"
            ParsePowerPointXml ($fullPath)
        }
        #binary content
        Default {
        }
    } 

    <#if($fileContent.Length -eq 0 -and $fileText.Length -gt 0) {
        #Echo "Converting text content to binary"
        $fileContent = [System.Text.Encoding]::UTF8.GetBytes($fileText) #Unicode is not sutable for FTS functions. But may be ok for Azure Search ???
    }#>


    <#if not able to retreave text, use binary content (without file properties) which SQL FTS can index directly
    if($fileContent.Length -eq 0) {
        Echo "Loading binary content directly from file"
        try {
            $fileContent = [System.IO.File]::ReadAllBytes($fullPath);
            #PS 3.0 has new command: 
            #$fileContent = Get-Content $fullPath -Raw

            $fileExtensionForSearch = $fileInfo.Extension
        }
        catch {
            #Echo "Access Denied!"
            Echo $error[0].Exception.Message -Error
        }
    }#>


    #allow broken files without content to be indexed
    #clean text by removing repetition of the same symbol more than 3 times
    if ($cleanContent){
        $fileText = CleanContent($fileText)
    }

    if ($fileText -eq ""){
        $fileText = " " #empty file indicator
    }

    $fileObj = new-object psobject -Property @{            
        Name = $fileInfo.BaseName
        Extension = $extension
        LastModified = $fileInfo.LastWriteTimeUtc
        Length = $fileInfo.Length
        Content=$fileText
    }

    if ($fileProperties -ne $null -and $fileProperties.Count -gt 0){
        $fileObj | add-member Noteproperty "Properties" $fileProperties
    }

    if ($extension -ne ".jpg"){
        $fileEntities = GetEntities($fileText)
        if ($fileEntities -ne $null -and $fileEntities.Count -gt 0){
            $fileObj | add-member Noteproperty "Entities" $fileEntities
        }
    }
    
    if ($fileLocation -ne $null){
        $fileObj | add-member Noteproperty "Location" $fileLocation
    }

    try{
        #$searchFilePath = "$($env:SEARCH_HOME)\_artefacts\Temp\test.search.json"
        #not sure what is returned by Out-File
        $fileObj | ConvertTo-Json -Compress| Out-File -Force $searchFilePath # -ErrorAction Continue
        $fileJson = Get-Item -Force $searchFilePath
        $fileJson.Attributes = 'Hidden, NotContentIndexed' #, NotContentIndexed, Compressed - is not supported
        #The attribute cannot be set because attributes are not supported. Only the following attributes can be set: Archive, Hidden, Normal, ReadOnly, or System.
        #$compressAttr=[io.fileattributes]::Compressed

        #Set-ItemProperty -Path $fullPath -Name attributes -Value ((Get-ItemProperty $fullPath).attributes -BXOR $compressAttr)
        #Invoke-WmiMethod -Path "Win32_Directory.Name='$($fullPath)'" -Name compress
        #$file = Get-WmiObject -Query "SELECT * FROM CIM_DataFile WHERE Name='$($env:SEARCH_HOME)\_artefacts\Temp\approval letter.docx'"
        #$file.Compress()
        #$computer = "svrsa1fs03"
        #$compressedPath = "C:\Library\mchardie.pps.search.json"
        #([wmi]"\\$computer\root\cimv2:win32_DataFile.name='$($env:SEARCH_HOME)\_artefacts\Temp\approval letter.docx'").compress()
        #([wmi]"\\$computer\root\cimv2:win32_Directory.name='$($env:SEARCH_HOME)\\_artefacts\\Temp\\potrace-1.12.win64'").compress()

        #$file = Get-WmiObject -Query "SELECT * FROM CIM_DataFile WHERE Name='$($env:SEARCH_HOME)\\_artefacts\\Temp\\approval letter.docx'"
        #$file = Get-WmiObject -Query "SELECT * FROM CIM_DataFile WHERE Name='\\\\shares\\library\\stein.pps.search.json'"
        #$file.Compress()
    }
    catch{}
}


function KillConverterProcesses([int]$Milliseconds){
    #http://smallbusiness.chron.com/stop-werfaultexe-56154.html
    $ProcessNames = Get-Process | Select Name
        #where { ($_.path -like "*ofc.exe" -or $_.path -like "*excelcnv.exe" -or $_.path -like "*wordcnv.exe" -or $_.path -like "*powerpnt.exe" -or $_.path -like "*doc2x.exe" -or $_.path -like "*ppt2x.exe" -or $_.path -like "*xls2x.exe") }

    foreach($ProcessName in $ProcessNames){
        $name = $ProcessName.Name.ToLower()
        if (($ProcessNameExceptions | where { $name -like "$_"}).Count -gt 0 ) {
Echo "Killing process $name ..."
            Start-Sleep -Milliseconds $Milliseconds #wait before killing processes
            Stop-Process -Name $name -Force -ErrorAction SilentlyContinue | Out-Null
        }
    }
}

function ParseWordXml([string]$filePath) {
    #if(!(Test-Path -LiteralPath $filePath)) {return}
    try
    {
        $wpdoc = [DocumentFormat.OpenXml.Packaging.WordprocessingDocument]::Open($filePath, $false)
        try {
            $xml = [xml]$wpdoc.MainDocumentPart.Document.OuterXml
            if ($xml -ne $null) {
                $ns = @{w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
                $textBuilder = New-Object -TypeName "System.Text.StringBuilder"
                Select-Xml -Xml $xml -XPath '//w:p//w:t' -Namespace $ns | Select -First 10000 | Foreach {
                    $text = $_.Node.InnerText.Trim()
                    if ($text) {
                        $textBuilder.AppendLine($text) | Out-Null
                    }
                } | Out-Null
                $fileText = $textBuilder.ToString()
                #change parent variables
                Set-Variable -Scope 1 -Name fileText -Value $fileText | Out-Null
                UpdateOfficeFileProperties($wpdoc) | Out-Null
            }
        }
        catch{
            Echo $error[0].Exception.Message
        }
        finally{
            $wpdoc.Close()
        }
    }
    catch {
        #Echo "Access Denied"
        Echo $error[0].Exception.Message
    }
}

function ParseExcelXml([string]$filePath) {
    #if(!(Test-Path -LiteralPath $filePath)) {return}
    try
    {
        $ns = @{x="http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
        $wpxls = [DocumentFormat.OpenXml.Packaging.SpreadsheetDocument]::Open($filePath, $false)
        try{
            $textBuilder = New-Object -TypeName "System.Text.StringBuilder"
            $xml = [xml]$wpxls.WorkbookPart.SharedStringTablePart.SharedStringTable.OuterXml
            if ($xml -ne $null -and $xml.sst -ne $null) {
                Select-Xml -Xml $xml -XPath '//x:sst//x:t' -Namespace $ns | Select -First 10000 | Foreach {
                    $text = $_.Node.InnerText.Trim()
                    if ($text) {
                        $textBuilder.AppendLine($text) | Out-Null
                    }
                }  | Out-Null
                $fileText = $textBuilder.ToString()
                #change parent variables
                Set-Variable -Scope 1 -Name fileText -Value $textBuilder.ToString() | Out-Null
                UpdateOfficeFileProperties($wpxls) | Out-Null
            }
        }
        catch{
            Echo $error[0].Exception.Message
        }
        finally{
            $wpxls.Close()
        }
    }
    catch {
        #Echo "Access Denied"
        Echo $error[0].Exception.Message #-Error
    }
}

function ParsePowerPointXml([string]$filePath) {
    #if(!(Test-Path -LiteralPath $filePath)) {return}
    try
    {
        $ns = @{p="http://schemas.openxmlformats.org/presentationml/2006/main"; a="http://schemas.openxmlformats.org/drawingml/2006/main"}
        $wpppt = [DocumentFormat.OpenXml.Packaging.PresentationDocument]::Open($filePath, $false)
        try {
            $textBuilder = New-Object -TypeName "System.Text.StringBuilder"
            $wpppt.PresentationPart.SlideParts | Foreach { $_.Slide | Foreach { 
                $xml = [xml]$_.OuterXml
                if ($xml -ne $null) {
                    Select-Xml -Xml $xml -XPath '//p:cSld//a:t' -Namespace $ns | Select -First 10000 | Foreach {
                        $text = $_.Node.InnerText.Trim()
                        if ($text) {
                            $textBuilder.AppendLine($text) | Out-Null
                        }
                    } 
                }
            }} | Out-Null
            #change parent variables
            Set-Variable -Scope 1 -Name fileText -Value $textBuilder.ToString() | Out-Null
            UpdateOfficeFileProperties($wpppt)| Out-Null
        }
        catch{
            Echo $error[0].Exception.Message #-Error
        }
        finally{
            $wpppt.Close()
        }
    }
    catch {
        #Echo "Access Denied"
        Echo $error[0].Exception.Message #-Error
    }

}

function ParseMsgText ([string]$filePath) {
    #get variable from parent level, do not use ref argument
    [string]$fileText = Get-Variable -Name fileText -Valueonly  -Erroraction SilentlyContinue -Scope 1
    $fileProperties = Get-Variable -Name fileProperties -Valueonly  -Erroraction SilentlyContinue -Scope 1


    #$enca = [System.Text.Encoding]::ASCII
    #$encu = [System.Text.Encoding]::Unicode

    $textBuilder = New-Object -TypeName "System.Text.StringBuilder"
    $outlook = New-Object -ComObject Outlook.Application
    if ($outlook -ne $null) {
        $msg = $outlook.CreateItemFromTemplate($filePath)
        if ($msg -ne $null -and $msg.Body -ne ""){
            $textBuilder.AppendLine($msg.Body) | Out-Null
        }

        <#$msg.Attachments | % {
                # Work out attachment file name
                $attFn = $msgFn -replace '\.msg$', " - Attachment - $($_.FileName)"
                # Do not try to overwrite existing files
                if (Test-Path -literalPath $attFn) {
                    Write-Verbose "Skipping $($_.FileName) (file already exists)..."
                    return
                }
                $textBuilder.AppendLine($_.Body) | Out-Null
                # Save attachment
                Write-Verbose "Saving $($_.FileName)..."
                $_.SaveAsFile($attFn)

                # Output to pipeline
                Get-ChildItem -LiteralPath $attFn
            }#>
        $fileText  = $textBuilder.ToString()
    }
    $outlook = $null
    #change grand parent variables
    Set-Variable -Scope 1 -Name fileText -Value $fileText | Out-Null
    Set-Variable -Scope 1 -Name fileProperties -Value $fileProperties | Out-Null
}

function ParsePdfText ([string]$filePath) {
    #get variable from parent level, do not use ref argument
    [string]$fileText = Get-Variable -Name fileText -Valueonly  -Erroraction SilentlyContinue -Scope 1
    $fileProperties = Get-Variable -Name fileProperties -Valueonly  -Erroraction SilentlyContinue -Scope 1

    #$xAttribute1 = $fileProperties.CreateAttribute("NumberOfPages")
    #$xAttribute2 = $fileProperties.CreateAttribute("TextSource")

    #$enca = [System.Text.Encoding]::ASCII
    #$encu = [System.Text.Encoding]::Unicode

    $textBuilder = New-Object -TypeName "System.Text.StringBuilder"
    $pdfReader = New-Object iTextSharp.text.pdf.pdfreader -ArgumentList $filePath
    if ($pdfReader -ne $null) {
        #$pdfReader.RemoveUnusedObjects() | Out-Null
        for ([int]$page = 1; $page -le $pdfReader.NumberOfPages; $page++)
        {
#Write-Debug "."
            #[iTextSharp.text.pdf.parser.ITextExtractionStrategy] $strategy = New-Object -TypeName [iTextSharp.text.pdf.parser.ITextExtractionStrategy]
            [iTextSharp.text.pdf.parser.ITextExtractionStrategy]$strategy = New-Object iTextSharp.text.pdf.parser.SimpleTextExtractionStrategy
#Echo "             load page $($page)..."
            [string] $currentText = [iTextSharp.text.pdf.parser.PdfTextExtractor]::GetTextFromPage($pdfReader, $page, $strategy)
            #$currentText = $encu.GetString($enca.Convert([System.Text.Encoding]::Default, $encu, [System.Text.Encoding]::Default.GetBytes($currentText))).Trim()
            #$bytes = [System.Text.Encoding]::UTF8.GetBytes($currentText) #Unicode
            #$textBuilder.Append([System.Text.Encoding]::UTF8.GetString($bytes)) | Out-Null
            $textBuilder.Append($currentText) | Out-Null
        }
        if (!$fileProperties.Contains("NumberOfPages")){
            $fileProperties.Add("NumberOfPages",$pdfReader.NumberOfPages)| Out-Null
        }
        $pdfReader.Close() | Out-Null

        [string]$s = $pdfReader.Info["Author"];
        if ($s -ne $null -and $s -ne "" -and !$fileProperties.Contains("Author")){
            $fileProperties.Add("Author", $s)| Out-Null
        }
    }
    $fileText  = $textBuilder.ToString()
    if (!$fileProperties.Contains("PDFParser")){
        $fileProperties.Add("PDFParser","iTextSharp")| Out-Null
    }

    if (!$fileText -or $fileText -eq "") {
        if (!$fileProperties.Contains("PDFParser")){
            $fileProperties.Add("PDFParser","Tesseract OCR")| Out-Null
        }
        else{
            $fileProperties["PDFParser"]="Tesseract OCR"
        }

        [int]$numberOfPages = 0
        try {
            Remove-Item $ImageMagickTempPath\* -recurse
            Remove-Item $OfficeFileConverterTempPath\Input\* -recurse -Force #delete hidden files as well
            Remove-Item $ImageMagickTempFiles
        }
        catch {
                #Echo $_.Exception.Message
                #Add-Content $LogFilePath "$(Get-Date) Error: " $_.Exception.Message
        }

        #copy file locally to avoid permission issues
        [string]$filePathCopy =$OfficeFileConverterTempPath+"Input\"+$fileInfo.Name.ToLower().Replace(",","")
        Copy-Item $fileInfo.FullName "$filePathCopy"
        Set-ItemProperty $filePathCopy -name IsReadOnly -value $false
        Unblock-File -Path $filePathCopy

        &"$($ImageMagickPath)\magick.exe" -monochrome -limit memory 10GB -limit area 10GB -limit disk 15GB -limit map 10GB -density 200 "$($filePathCopy)" "$($ImageMagickTempPath)\ocr-%04d.png" | Out-Null
        start-sleep -Milliseconds 1000 #small delay after conversion

        Get-ChildItem $ImageMagickTempPath -Filter "*ocr-*.png" -ErrorAction SilentlyContinue -ErrorVariable err | 
            Where-Object {$_.FullName.Length -le 255} | 
            Where-Object {$_ -is [IO.FileInfo]} | 
            #Where-Object {$_.lastwritetime -gt (get-date).addDays(-100)} | 
            Sort $_.CreationTime |
                ForEach-Object{
                    $numberOfPages++
                    [string]$fullName = ([IO.FileInfo]$_).FullName
                    [string]$outputBase = $fullName.Replace(".png", "")
                    &"$($TesseractExecPath)" "$($fullName)" "$($outputBase)" -psm 1 | Out-Null # -l eng
                    try{
                        [string]$currentText = [System.IO.File]::ReadAllText($fullName.Replace(".png", ".txt"))
                        #$bytes = [System.Text.Encoding]::UTF8.GetBytes($currentText) #Unicode
                        #$currentText = $encu.GetString($enca.Convert([System.Text.Encoding]::Default, $encu, [System.Text.Encoding]::Default.GetBytes($currentText))).Trim()
                        #$textBuilder.Append([System.Text.Encoding]::UTF8.GetString($bytes)) | Out-Null
                        $textBuilder.Append($currentText) | Out-Null
                    }
                    catch{}
                }

        $fileText  = $textBuilder.ToString()

        if (!$fileProperties.Contains("NumberOfPages")){
            $fileProperties.Add("NumberOfPages",$numberOfPages)| Out-Null
        }
    }
   
    #change grand parent variables
    Set-Variable -Scope 1 -Name fileText -Value $fileText | Out-Null
    Set-Variable -Scope 1 -Name fileProperties -Value $fileProperties | Out-Null
}

function ParseJpgText ([string]$filePath) {
    #get variable from parent level, do not use ref argument
    [string]$fileText = Get-Variable -Name fileText -Valueonly  -Erroraction SilentlyContinue -Scope 1
    $fileProperties = Get-Variable -Name fileProperties -Valueonly  -Erroraction SilentlyContinue -Scope 1

#Write-Host "$filePath loading file..."
    if ($fileText -eq $null -or $fileText -eq "") { #
        #$xAttribute2.Value = "ImageMagick OCR"
        [string]$temp = "$($ImageMagickTempPath.TrimEnd("\"))\temp.svg"
        try {
            Remove-Item $ImageMagickTempPath\* -recurse
            Remove-Item $ImageMagickTempFiles
        }
        catch {
                #Echo $_.Exception.Message
                #Add-Content $LogFilePath "$(Get-Date) Error: " $_.Exception.Message
        }
#Write-Host "converting image..."
        &"$($ImageMagickPath)\magick.exe" "$($filePath)" -charcoal 2 -strip -trim -level 50% -threshold 50% -density 200 "$($temp)" | Out-Null
        if ((Test-Path -LiteralPath $temp) -eq $True) {
#Write-Host "Get-Content..."
            $fileText = Get-Content $temp
        }
#Write-Host "loading image..."
        $image  = New-Object -ComObject Wia.ImageFile #don't forget to activate the feature on your server: Add-WindowsFeature Desktop-Experience  
#Write-Host "loading exif..."
        $image.LoadFile($filePath)
        $exif = Get-Exif($image)
        $names = $exif | Get-Member -membertype properties | % {$_.Name}
        foreach ($name in $names){
            try{
                $value = $exif | Select -ExpandProperty "$name"
                if ($value -and $value -ne "") { 
                    #Write-Host $name ":" $value
                    if (!$fileProperties.Contains($name)){
                        $fileProperties.Add($name, $value)| Out-Null
                    }
                }
            }
            catch{}
        }
    }
    Remove-Item $ImageMagickTempPath\* -recurse
   
    #change grand parent variables
    Set-Variable -Scope 1 -Name fileText -Value $fileText | Out-Null
    Set-Variable -Scope 1 -Name fileProperties -Value $fileProperties | Out-Null
}

function UpdateOfficeFileProperties($officeDoc){
    #get variable from  grand parent level, do not use ref argument
    $fileProperties = Get-Variable -Name fileProperties -Valueonly  -Erroraction SilentlyContinue -Scope 2
    $names = $officeDoc.PackageProperties | Get-Member -membertype properties | % {$_.Name}
    foreach ($name in $names){
        try{
            $value = $officeDoc.PackageProperties | Select -ExpandProperty "$name"
            if ($value -and $value -ne "") { 
                #Write-Host $name ":" $value
                if (!$fileProperties.Contains($name)){
                    $fileProperties.Add($name, $value)| Out-Null
                }
            }
        }
        catch{}
    }

    $extProps = $officeDoc.ExtendedFilePropertiesPart.Properties | Select LocalName, InnerText | %{$_}
    foreach ($extProp in $extProps){
        $name = $extProp.LocalName
        $value = $extProp.InnerText
        #Write-Host $extProp.LocalName ":" $extProp.InnerText
        if ($value -and $value -ne "") { 
            #Write-Host $name ":" $value
            if (!$fileProperties.Contains($name)){
                $fileProperties.Add($name, $value)| Out-Null
            }
        }
    }

    $cProps = $officeDoc.ExtendedFilePropertiesPart.Properties | Select LocalName, InnerText | %{$_}
    foreach ($cProp in $cProps){
        $name = $cProp.LocalName
        $value = $cProp.InnerText
        if ($value -and $value -ne "") { 
            #Write-Host $name ":" $value
            if (!$fileProperties.Contains($name)){
                $fileProperties.Add($name, $value)| Out-Null
            }
        }
    }
    #change grand parent variable
    Set-Variable -Scope 2 -Name fileProperties -Value $fileProperties | Out-Null
}

function CleanOFCTempFolder(){
    #clean C:\Users\UserName\AppData\Local\Microsoft\Windows\INetCache\Content.MSO
    [string]$temp = (get-item $env:TEMP ).parent.parent.FullName
    if ((Test-Path -LiteralPath $temp) -eq $true) {
        [string]$temp2 = (Get-ChildItem $temp -Force  -Recurse -filter "INetCache" -ErrorAction SilentlyContinue | where { $_.Attributes -match "Hidden"}).FullName
        if ($temp2 -ne $null -and $temp2 -ne "" -and (Test-Path -LiteralPath $temp2) -eq $true) {
            [string]$temp3 = (Get-ChildItem -LiteralPath $temp2 -Force  -Recurse -filter "Content.MSO" -ErrorAction SilentlyContinue | where { $_.Attributes -match "Hidden"}).FullName
            if ($temp3 -ne $null -and $temp3 -ne "" -and (Test-Path -LiteralPath $temp3) -eq $true) {
                Remove-Item $temp3\*.* -recurse
            }
        }
    }
}

<#
$content = "123                                                                                                                                                             SERIES 200      #$     #               ( ) (            ) TASK No. FSL 17(3)"
$r = CleanContent -Content $content
#>
function CleanContent(){
    Param(
        [string]$Content
    )
    if ($Content -eq ""){
        return $Content
    }
    $b=[system.text.encoding]::UTF8.GetBytes($Content) | Where {$_ -ne 0x00} #exclude nulls: http://stackoverflow.com/questions/9863455/how-to-remove-null-char-0x00-from-object-within-powershell/9870457#9870457
    if ($b -eq $null){
        return $Content
    }
    $c=[system.text.encoding]::convert([text.encoding]::UTF8,[text.encoding]::ASCII,$b)
    $Content = -join [system.text.encoding]::ASCII.GetChars($c)
   
    $Content = $Content  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
    $Content = $Content -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c' \u0000
    $Content = $Content -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}\-]', ' ' #special symbols and punctuation
    $Content = $Content -replace '\x00|`0', ' ' #nulls
    $Content = $Content -replace '\s+', ' ' #remove extra spaces
    $Content = $Content -replace '(\w)\1{3,}', '$1' #replace repeating symbols more than 3 times with 1: "aaaassssssssssseeeee111112222223334" -replace '(\w)\1{3,}', '$1'
    
    #now filter out repeating records
    $tb = New-Object -TypeName "System.Text.StringBuilder"
    $uniqueRows = @{}
    [int]$rowNo = 1
    $crLf = "`r`n"
    $Content.Split("`n") | % { 
        if ($_ -ne $crLf -and !$uniqueRows.Contains($_ )) { 
            $uniqueRows.Add($_, $rowNo)
            $tb.AppendLine($_)
        }
        $rowNo++
    } | out-null
    #$uniqueRows.GetEnumerator() | sort -Property name
    $Content = $tb.ToString().Trim()

    #Watch the size of the data you are posting to API! They allow up to 4 MB in the RRS request.
    if ($Content.Length -gt 4194304 ){
        $Content = $Content.Substring(0,4194303)
    }

    return $Content
}

function GetEntities(){
    Param(
        [string]$Content
    )

    if ($Content.Length -eq 0){
        return $null
    }
    #Watch the size of the data you are posting to API! They allow up to 4 MB in the RRS request.
    if ($Content.Length -gt 4194304 ){
        $Content = $Content.Substring(0,4194303)
    }
    [string]$id = "1" #id is not relevant if you send only 1 item

    [string]$request = '{
      "Inputs": {
        "input1": {
          "ColumnNames": [
            "Col1",
            "Col2"
          ],
          "Values": [
            [
              "'+$id+'",
              "'+$Content+'"
            ]
          ]
        }
      },
      "GlobalParameters": {}
    }'

    $webRequest=Invoke-WebRequest -Method Post -Uri $EntityRecognizerURI -Header @{ Authorization = "BEARER "+$EntityRecognizerApiKey} -ContentType "application/json" -Body $request		
    $response = $webRequest.Content

    #Convert and parse response
    $responseObject = ConvertFrom-Json $response
    $results = New-Object System.Collections.Generic.List[System.Object]

    #$request | ConvertTo-Json -Depth 6 
	for ($i=0;$i -lt $responseObject.Results.output1.value.Values.Count;$i++){
    	$output = New-Object PSObject
		for ($j=0;$j -lt $responseObject.Results.output1.value.ColumnNames.Count;$j++)
		{
			$a=$responseObject.Results.output1.value.ColumnNames[$j]
			$b=$responseObject.Results.output1.value.ColumnTypes[$j]
			$c=$responseObject.Results.output1.value.Values[$i][$j]
			switch ($b) 
			{ 
				"double"	{$output | add-member Noteproperty $a ([double]$c)}
				"int"		{$output | add-member Noteproperty $a ([int]$c)}
				"long"		{$output | add-member Noteproperty $a ([long]$c)}
				"datetime"	{$output | add-member Noteproperty $a ([datetime]$c)}
				"Boolean"	{$output | add-member Noteproperty $a ([boolean]$c)}
				"Int16"		{$output | add-member Noteproperty $a ([int16]$c)}
				"Int32"		{$output | add-member Noteproperty $a ([int32]$c)}
				"Int64"		{$output | add-member Noteproperty $a ([int64]$c)}
				"Single"	{$output | add-member Noteproperty $a ([single]$c)}
				"Byte"		{$output | add-member Noteproperty $a ([byte]$c)}
				"String"	{$output | add-member Noteproperty $a ([string]$c)}
				default		{$output | add-member Noteproperty $a ($c)}
			}
		}
        $results.Add($output)
    }
    $fileEntities = $results | 
        ? { ` #remove some noise
            ($_.Type.Trim() -eq "PER" -and $_.Mention.Replace(" ","").Trim().Length -gt 6) `
            -or ($_.Type.Trim() -eq "LOC" -and $_.Mention.Replace(" ","").Trim().Length -gt 3) `
            -or ($_.Type.Trim() -eq "ORG" -and $_.Mention.Replace(" ","").Trim().Length -gt 3) `
        } |
        group-object -property Type, Mention -noelement |
            where {$_.Count -gt 1} | # it looks like noise
            sort-object -property count –descending | % {
                New-Object psobject -Property @{
                    "Type" = $_.Name.Substring(0,3).Trim()
                    "Mention" = $_.Name.Substring(4).Trim()
                    "Count" = $_.Count 
                }
            }

    return $fileEntities;
}


function Main(){
    try{Clear-Host}catch{} # avoid Exception setting "ForegroundColor": "Cannot convert null to type 
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
    #configure logging
    Import-Module -Name "$scripLocation\Log.Helper.psm1" -Force #-Verbose
    $global:EventLogSource = $EventLogSource
    $global:LogFilePath = $LogFilePath

    [System.Reflection.Assembly]::LoadWithPartialName(“WindowsBase”) | Out-Null
    [System.Reflection.Assembly]::LoadWithPartialName(“System.Xml.Linq”) | Out-Null
    [System.Reflection.Assembly]::LoadFrom("$DocFormatOpenXmlDllPath") | Out-Null
    Add-Type -Path $iTextSharpDllPath | Out-Null
    Import-Module Image

    # Create log file if it doesn't already exist
    if(-not (Test-Path -LiteralPath $LogFilePath)) {
        New-Item $LogFilePath -type file | Out-Null
    }

    [bool]$foldersSession = $false
    foreach ($sharedFolder in $SharedFolders){
        if (Test-Path $sharedFolder -PathType Container){

            Echo "$(Get-Date) Start crawling folder: $sharedFolder" #Write-Event
            LoadFolder -RootPath $sharedFolder -Level 0
            Echo "$(Get-Date) End crawling folder: $sharedFolder" #Write-Event

            CleanOFCTempFolder
        }
        elseif (Test-Path $sharedFolder -PathType Leaf){
            LoadFile -fileInfo $sharedFolder
        }
    }
}

Main