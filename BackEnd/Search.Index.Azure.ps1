<#
Unit tests:
    \\svrsa1fs03\fs\bus\ ->	\\nova\fs\bus\ <-\\nova\nova-dfs\group\
    \\svrsa1fs03\library\ -> \\nova\nova-dfs\library\
    C:\Search\Nova.Search
    \\svrsa1fs03\library\EO eLibrary\AASTP- Done

Access denied test: \\nova\nova-dfs\group\training\3200 QUOTES
    \\nova\nova-dfs\library\Defence Publications\United States\US DOD\Defense Acquisition University\Software Intensive System Acquisition Management Course (DAU) 2008\5-Day SISAM\Supplemental DAU Material\LSN 06 - Architecture\SOA and DIB and SEI\GCSS Air Force
    \\nova\nova-dfs\library\Defence Publications\United States\US DOD\Defense Acquisition University\Software Intensive System Acquisition Management Course (DAU) 2008\5-Day SISAM\Supplemental DAU Material\LSN 06 - Architecture
Pasword protected files
    \\nova\fs\bus\nc\wg\c\0017\work\tender evaluation\assessment weightings where comments are required_jwv2.0.xls
    \\nova\nova-dfs\library\standards-specs-handbooks\pmi\pmi members access required\practice_standard_project_configuration_management.pdf

Index operations: https://msdn.microsoft.com/en-us/library/dn798918.aspx
#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
#param test script
Param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target root folders for search collection')]
    [String[]]
    $SharedFolders=@(), #"\\nova\nova-dfs\library\","\\nova\fs\Bus\"
    [String[]]
    [Parameter(HelpMessage = 'List of extensions inclusded in search')]
    [ValidateCount(1,100)]
    $FileExtensionsForFTS = @(".xls",".xlsx",".xlsm",".xlsb",".ppt",".pptx",".txt",".xml",".rtf",".doc",".docx",".docm",".pdf", ".csv"),
    [Parameter(HelpMessage = 'List of full path (partial name of folder or file) parts excluded from search')]
    $FilePathExceptions = @("*\_template*\*","*\_private\*","*\dfsrprivate\*","*\bin\*","*\tags\*","*obsolete\*","*\backup\*","*backup copy*","*\previous issues and bak-ups\*","*\log\*","*\old\*","*\recyclebin\*","*\AI_RecycleBin\*","*\conflictanddeleted\*","*\deleted\*","*\j940 - data\*","*\previous issues\*","*\temp\*","*\drafts\*","*\documents not used as re-worded\*","*_Draft Documents\*"), #,"*\archive\*"
    [Parameter(HelpMessage = 'List of file name excluded from search')]
    $FileNameExceptions = @("*.search.json","*.zip","*.config","*.db","*.bak","*.url","*.lnk","*.log","subsegmentlist_*.pdf","*._*.pdf","* draft *.","*_draft_*.*","temp *.*","*.bin","_permissions.txt","_readme.txt","*[?][?]*"),
    [Alias('Host')]
    #[ValidateSet('SVRADLDB02','SVRSA1DB04','.\SQL2014')]
    #[string]$SQL_ServerName = ".\SQL2014",
    [string]$SQL_ServerName = "SVRSA1DB04",

    [Alias('DBName')]
    [string]$SQL_SearchDbName = "Nova_Search",

    [string]$SearchFolderName = "_search",
    [bool]$SearchFileNameHashed = $true,

    #[string]$LogFilePath = "C:\Search\Nova.Search\Logs\Nova.Search.log",
    [string]$LogFilePath = "F:\NovaSearch\Logs\Nova.Search.log",

    [string]$EventLog = "Application",
    [string]$EventSource = "Nova.Search",
    [int]$MaxFileBiteSize = 20000000,  #<=20 Mb
    #[string]$NHunspellDllPath = "F:\NovaSearch\Binn\Hunspellx64.dll"

    [string]$SearchURL = "https://novasystems.search.windows.net",
    [string]$SearchPrimaryAdminKey = "1001EB543590B1E5A64751E0746EFF60",
    [string]$SearchQueryKey = "DFDBFE82FB10200DE6A8AA94B545872D",
    [string]$SubscriptionID = "32aaad0f-2570-49ef-81ca-2152a58718af",
    [string]$apiVersion = "2015-02-28"
)


function Write-Event {
    [CmdletBinding()]   
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Message,
 
        [Parameter(Position=1, Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [System.Int32]
        $EventId = 1,
 
         [Switch]
        $Information,
 
        [Switch]
        $Warning,
 
        [Switch]
        $Error
    )
    #Specifies the entry type of the event. Valid values are Error, Warning, Information, SuccessAudit, and FailureAudit. The default value is Information.
    If ($Error.IsPresent) {
        Write-Warning $Message

        try { Add-Content $LogFilePath $Message }
        catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to log file $($_.LogFilePath)." }

        try { Write-EventLog –LogName $EventLog –Source $EventSource –EntryType Error –EventID $EventId –Message $Message | Out-Null }
        catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to event logs." }
    }
    ElseIf ($Warning.IsPresent){
        Write-Warning $Message

        try { Add-Content $LogFilePath $Message }
        catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to log file $($_.LogFilePath)." }

        try { Write-EventLog –LogName $EventLog –Source $EventSource –EntryType Warning –EventID $EventId –Message $Message | Out-Null }
        catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to event logs." }
    }
    ElseIf ($Information.IsPresent) {
        Write-Output $Message
        try { Add-Content $LogFilePath $Message }
        catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to log file $($_.LogFilePath)." }

        try { Write-EventLog –LogName $EventLog –Source $EventSource –EntryType Information –EventID $EventId –Message $Message | Out-Null }
        catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to event logs." }
    }
    Else {
        Write-Output $Message
        Add-Content $LogFilePath $Message
    }
}

function Main(){
    Clear-Host
    #Get-Module -list Azure
    #get indexes
    [string]$url = "$SearchURL/indexes?api-version=$apiVersion&api-key=$SearchQueryKey"
    /indexes?api-version=2015-02-28
    [string]$url = "$SearchURL/indexes/hotels/docs?search=*&$orderby=lastRenovationDate desc&api-version=$apiVersion&api-key=$SearchQueryKey"
    (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore test ssl certificate warning
$Headers = @{
	'Content-Type' = 'application/json; charset=utf-8'
	'api-key' = $SearchPrimaryAdminKey # Provide Your API key
}


$IndexDefinition = @{
	'name' = 'vacancies'
	'fields' = @(
		@{
			'name' = 'VacancyId'
			'type' = 'Edm.String'
			'searchable' = $False
			'filterable' = $False
			'sortable' = $False
			'facetable' = $False
			'key' = $True
			'retrievable' = $True
		},
		@{
			'name' = 'Position'
			'type' = 'Edm.String'
			'searchable' = $True
			'filterable' = $True
			'sortable' = $True
			'facetable' = $True
			'key' = $False
			'retrievable' = $True
            #'analyzer' = 'ru.lucene' # <--- Here is tricky part
            'analyzer' = 'ru.microsoft' # <--- Microsoft NLP can stemm russian words
		}
	)
    'suggesters' = @(
		@{
			'name' = 'sg'
			'searchMode' = 'analyzingInfixMatching'
			'sourceFields' = @('Position')
		}
	)

}
[string]$url = "$SearchURL/indexes?api-version=$apiVersion"
Invoke-RestMethod -Method Post -Uri $url -Headers $Headers -Body ($IndexDefinition | ConvertTo-Json -Depth 10)


#delete index vacancies
[string]$url = "$SearchURL/indexes/vacancies?api-version=$apiVersion"
Invoke-RestMethod -Method Delete -Uri $url -Headers $Headers

#http://mac-blog.org.ua/azure-search-cyrillic/
#Insert some data
$Documents = @{
	'value' = @(
		@{
			'VacancyId' = '1'
			'Position' = 'Менеджер по продажам в Киеве' # Translation: Sales manager in Kiev
		},
		@{
			'VacancyId' = '2'
			'Position' = '1-С Программист Киев' # Translation: 1-C programmer Kiev
		},
		@{
			'VacancyId' = '3'
			'Position' = '1-С Программист во Львове' # Translation: 1-C programmer Lviv
		},
		@{
			'VacancyId' = '4'
			'Position' = 'Acme ищет менеджера по продажам' # Translation: Acme search sales manager
		}
	)
}
[string]$url = "$SearchURL/indexes/vacancies/docs/index?api-version=$apiVersion"
Invoke-RestMethod -Method Post -Uri $url -Headers $Headers -Body ([System.Text.Encoding]::UTf8.GetBytes(($Documents | ConvertTo-Json -Depth 10)))

#get data
[string]$url = "$SearchURL/indexes/vacancies/docs/index?api-version=$apiVersion&search=киеве"
Invoke-RestMethod -Method Get -Uri $url -Headers $Headers | select -ExpandProperty value

    #Alternatively, you can use PUT and specify the index name on the URI. If the index does not exist, it will be created.



    $json = "api-key:$SearchPrimaryAdminKey"


    $json = @{"api-key:$SearchPrimaryAdminKey"} #convert request to POST body format, please use empty name ""= instead of "value"=

    #PUT https://[servicename].search.windows.net/indexes/[index name]?api-version=[api-version]
    $response = Invoke-RestMethod -Uri $url -Body $json -Method POST -UseDefaultCredentials -ContentType "application/json"
    $response | Format-Table


    #if ($pscmdlet.ShouldProcess($SharedFolders)){
    #    Write-output "Going to index the following folders $($SharedFolders)"
    #    break
    #    exit
    #}
    [System.Reflection.Assembly]::LoadWithPartialName(“System.Web.Extensions”) | Out-Null

    # Create log file if it doesn't already exist
    if(-not (Test-Path -LiteralPath $LogFilePath)) {
        New-Item $LogFilePath -type file | Out-Null
    }
    Write-Event "$(Get-Date) Start session."

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_SearchDbName;Integrated Security=True;Application Name=Search.SharedFolderReader;MultipleActiveResultSets=True;"
    $SqlConnection.Open()

    #Write-output 'Add known extensions (document types) from database... '
    $sqlDocTypes = New-Object System.Data.SqlClient.SqlCommand
    $sqlDocTypes.Connection = $SqlConnection
    $sqlDocTypes.CommandType = [System.Data.CommandType]::Text;
    $sqlDocTypes.CommandText = "SELECT DISTINCT LOWER(document_type) as document_type FROM sys.fulltext_document_types where LEN(document_type)<8 UNION SELECT '.jpg' ORDER BY 1" #we can ignore too long extensions as irrelevant ...and document_type='.pdf' 
    $reader1 = $sqlDocTypes.ExecuteReader()
    while ($reader1.Read())
    {
        [string]$ext = [string]$reader1["document_type"]
        if (!$FileExtensionsForFTS.Contains($ext)){
            $FileExtensionsForFTS = $FileExtensionsForFTS + $ext
        }
    }
    $reader1.Close()

    $sqlCmdGetFiles = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdGetFiles.Connection = $SqlConnection
    $sqlCmdGetFiles.CommandTimeout = 600;
    $sqlCmdGetFiles.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdGetFiles.CommandText = "[dbo].[GetFiles]"
    $sqlCmdGetFiles.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdGetFiles.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FilePath",[Data.SQLDBType]::NVarChar, 512))) | Out-Null
    $sqlCmdGetFiles.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileExtension",[Data.SQLDBType]::NVarChar, 8))) | Out-Null

    $sqlCmdAddFile = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddFile.Connection = $SqlConnection
    $sqlCmdAddFile.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdAddFile.CommandText = "[dbo].[AddFile]"
    $sqlCmdAddFile.CommandTimeout = 120;
    $sqlCmdAddFile.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileName",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FilePath",[Data.SQLDBType]::NVarChar, 512))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileContent",[Data.SQLDBType]::VarBinary, -1))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileExtension",[Data.SQLDBType]::NVarChar, 8))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileModifiedDateUTC",[Data.SQLDBType]::DatewTime))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileModifiedLength",[Data.SQLDBType]::BigInt))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@SameFileId",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileId",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddFile.Parameters["@FileId"].Direction = [system.Data.ParameterDirection]::Output

    $sqlCmdAddFileProperty = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddFileProperty.Connection = $SqlConnection
    $sqlCmdAddFileProperty.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdAddFileProperty.CommandText = "[dbo].[AddFileProperty]"
    $sqlCmdAddFileProperty.CommandTimeout = 30;
    $sqlCmdAddFileProperty.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdAddFileProperty.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileId",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddFileProperty.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@PropertyName",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
    $sqlCmdAddFileProperty.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@PropertyValue",[Data.SQLDBType]::NVarChar, 255))) | Out-Null

    $sqlCmdAddFileEntity = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddFileEntity.Connection = $SqlConnection
    $sqlCmdAddFileEntity.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdAddFileEntity.CommandText = "[dbo].[AddFileEntity]"
    $sqlCmdAddFileEntity.CommandTimeout = 30;
    $sqlCmdAddFileEntity.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdAddFileEntity.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileId",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddFileEntity.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Type",[Data.SQLDBType]::NVarChar, 3))) | Out-Null
    $sqlCmdAddFileEntity.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Mention",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
    $sqlCmdAddFileEntity.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Count",[Data.SQLDBType]::Int))) | Out-Null

    $filesDBDict = New-Object 'System.Collections.Generic.Dictionary[[string],[DateTime]]'
    $samefilesDBDict = New-Object 'System.Collections.Generic.Dictionary[[string],[int]]'
    foreach ($sharedFolder in $SharedFolders){
        Write-Event "$(Get-Date) Start crawling folder: $sharedFolder ..."
        #$pattern = "[{0}]" -f ([Regex]::Escape( [System.IO.Path]::GetInvalidFileNameChars() -join '' ))

        $filesDBDict.Clear()
        $samefilesDBDict.Clear()
        foreach($fileExtension in $FileExtensionsForFTS){
            $sqlCmdGetFiles.Parameters["@FilePath"].Value = $sharedFolder
            $sqlCmdGetFiles.Parameters["@FileExtension"].Value = $fileExtension
            $reader2 = $sqlCmdGetFiles.ExecuteReader()
            while ($reader2.Read())
            {
                $fileFullPath = [string]$reader2["FileFullPath"]
                $fileModifiedDateUTC = $reader2["FileModifiedDateUTC"]
                $sameFileId = $reader2["SameFileId"]
                $key = $fileFullPath.ToLower()
                if ($fileModifiedDateUTC -eq [System.DBNull]::Value){
                    $fileModifiedDateUTC = [System.DateTime]::MinValue;
                }
                if ($filesDBDict.ContainsKey($key) -eq $False) {
                    $filesDBDict.Add($key, [System.DateTime]$fileModifiedDateUTC);
                }
                if ($sameFileId -ne [System.DBNull]::Value -and $samefilesDBDict.ContainsKey($key) -eq $False) {
                    $samefilesDBDict.Add($key, [int]$sameFileId)
                }
            }
            $reader2.Close()
        }
Write-Host "Indexed files: $($filesDBDict.Count), Similar files: $($samefilesDBDict.Count)"
        LoadFolder -RootPath $sharedFolder -Level 0
        #DeleteOrphanRecords($sharedFolder)
    }

    $sqlCmdCleanData = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdCleanData.Connection = $SqlConnection
    $sqlCmdCleanData.CommandType = [System.Data.CommandType]::StoredProcedure
    $sqlCmdCleanData.CommandText = "[dbo].[CleanImportedData]"
    $sqlCmdCleanData.CommandTimeout = 1000;
    $sqlCmdCleanData.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdCleanData.ExecuteNonQuery() | Out-Null
    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }
    Write-Event "$(Get-Date) End session."
}


#LoadFolder -RootPath "\\nova\fs\bus\ba\" -FileExtension ".pdf" -ParentHasDFSFolder $false -Level 0
#LoadFolder -RootPath $sharedFolder -DfsFolders $null -Level 0
#[string]$RootPath = "\\nova\fs\bus\nc\ra\c\0106\work\80_reference docs\relevant human factors standards and docs\human factors hf-std-001 (click on index.htm)\word files"
# (Get-ChildItem -Path "$RootPath" -Directory -ErrorAction SilentlyContinue -ErrorVariable err) | %{$_.FullName}
function LoadFolder(){
    Param(
        [string]$RootPath,
        #[string[]]$DfsFolders,
        [int]$Level
    )
    $RootPath = $RootPath.Trim().TrimEnd('\').TrimEnd('.').ToLower();
    if (($FilePathExceptions | where { $RootPath+'\' -like "$_"}).Count -gt 0 ) {return}
    #[bool]$ChildHasDFSFolder = (($DfsFolders | Where { $searchFolder -like "$RootPath*"}).Count -gt 0)
Write-Output "Load Folder: $($RootPath); Level: $($Level)"

    $Level++

    #take files on current level only
    $files = Get-ChildItem $RootPath -File -Force -ErrorAction SilentlyContinue | # -ErrorVariable err !do not use -ReadOnly
        Where-Object {$_.FullName.Length -le 255} | 
        Where-Object {$_ -is [IO.FileInfo]} |
        #Where-Object {$_.lastwritetime -gt (get-date).addDays(-100)} | 
        #Sort $_.CreationTime |
        % {"$($_.FullName.ToLower())"}
    $files | ForEach-Object {
        $fileInfo = [IO.FileInfo]$_
        if ($FileExtensionsForFTS.Contains($fileInfo.Extension.ToLower()) -eq $True) { #do not mix .xls and xlsx
Write-Output "Load File: $($fileInfo.FullName)"
                LoadFile -fileInfo $fileInfo #-longPath = $null
        }
    }

    (Get-ChildItem -Path "$RootPath" -Directory -ErrorAction SilentlyContinue -ErrorVariable err)| % {
        #if ($DfsFolders.Contains($RootPath)){ #current folder is DFS link
        #    if ($ParentHasDFSFolder -eq $true) { #this folder is not a target and can cause circular refs
        #        break;
        #    }
        #    else {
        #        $ParentHasDFSFolder = $true
        #    }
        #}

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


#$sharedFolder = "\\nova\fs\Bus"
function DeleteOrphanRecords([string]$sharedFolder){
    #soft deleting obsolete records
    #[System.Data.SqlClient.SqlConnection]$SqlConnection = Get-Variable -Name SqlConnection -Valueonly  -Erroraction SilentlyContinue -Scope 1
    if ($SqlConnection.State -ne 'Open')
    {
        $SqlConnection.Open()
    }
    [string]$queryString = "SELECT [FileId], [FullName] as FileFullPath, [FilePath], [FileName] FROM [shared].[File] WHERE FilePath LIKE '" + $sharedFolder.Replace("'", "''") + "%' AND [DeleteDate] IS NULL"
    $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($queryString, $SqlConnection)
    $filesDataSet = New-Object System.Data.DataSet
    [void]$sqlAdapter.Fill($filesDataSet, "Files")

    $updateCommand = New-Object System.Data.SqlClient.SqlCommand("UPDATE [shared].[File] SET DeleteDate = GETDATE() WHERE FileID = @FileID AND DeleteDate IS NULL", $SqlConnection)
    $parameter = $updateCommand.Parameters.Add("@FileID", [Data.SQLDBType]::Int, 4, "FileID")
    $parameter.SourceVersion = [System.Data.DataRowVersion]::Original
    $sqlAdapter.UpdateCommand = $updateCommand
    $sqlAdapter.UpdateCommand.CommandTimeout = 24000

    $rows = $filesDataSet.Tables["Files"].Rows

    foreach ($row in $rows)
    {
        [string]$fullPath = $row["FileFullPath"]
        [string]$folderPath = $row["FilePath"]
        
        #if ($searchFolders.Contains($folderPath) -eq $false){
        #    delete it...
        #}

        try {
            if (($FilePathExceptions | where { $folderPath+'\' -like "$_"}).Count -gt 0 ) {
                    Write-Event "soft deleting1 $fullPath"
                    $row.SetModified() | Out-Null
            }
            elseif (($FileNameExceptions | where { $fullPath -like "$_"}).Count -gt 0 ) {
                    Write-Event "soft deleting2 $fullPath"
                    $row.SetModified() | Out-Null
            }
            elseif ($folderPath.Lenght -lt 248 -and $fullPath.Lenght -le 255) {
                #$fullPath = "\\nova\fs\Bus\AA\EA\APR\2718\02718.0061 - Weight and Balance Record Updates\02719.0061.0062 - FCOM Removal\Engineering\Approval Package\VH-EBK\1 - 02718.0061.0062\VH-EBK Issue 9 (2014-08-26).xls"
                #(Test-Path -LiteralPath "\\nova\nova-dfs\library\Defence Publications\United States\US DOD\Defense Acquisition University\Software Intensive System Acquisition Management Course (DAU) 2008\5-Day SISAM\Supplemental DAU Material\LSN 06 - Architecture\SOA and DIB and SEI\DIB Success Story.pdf")
                if ((Test-Path -LiteralPath $fullPath) -eq $False){
                    Write-Event "soft deleting3 $fullPath"
                    $row.SetModified() | Out-Null
                }
            }
        }
        catch {
            Write-Event $_.Exception.Message -Error
        }
    }
    $dtChanges = $filesDataSet.Tables["Files"].GetChanges([System.Data.DataRowState]::Modified)
    if ($dtChanges -ne $null) {
        try {
            $sqlAdapter.Update($dtChanges) | Out-Null
        }
        catch {
            #ignore exception: calling "Update" with "1" argument(s): "Concurrency violation: the UpdateCommand
        }
    }
}

#[IO.FileInfo]$fileInfo = [IO.FileInfo]"\\nova\nova-dfs\group\Legacy\auspacefs01\AGI\Marketing\Laptop Blown away\Auspace\NavyDemo\NavyDemo\Antenna\Modified_pattern.txt"
#[IO.FileInfo]$fileInfo = [IO.FileInfo]"\\nova\fs\bus\aa\ea\apr\2572\02572.0094 - compressor wash valve modification\photos\2014-12-11\20141211_134503.jpg"
#[IO.FileInfo]$fileInfo = [IO.FileInfo]"\\svrsa1fs03\library\defence publications\australia\dmo\test and evaluation master plan\old dmo policy from website\dmo temp procedure.pdf"
#[IO.FileInfo]$fileInfo = [IO.FileInfo]"C:\Search\Nova.Search\AIAA-2007-1609-221.pdf"
#[IO.FileInfo]$fileInfo = [IO.FileInfo]"\\nova\fs\bus\nc\ra\c\0106\work\80_reference docs\relevant human factors standards and docs\human factors hf-std-001 (click on index.htm)\word files\master table of contents.doc"
#LoadFile -fileInfo $fileInfo
function LoadFile () {
    Param(
        [IO.FileInfo]$fileInfo
    )
    #the fully qualified file name must be less than 260 characters
    if ($fileInfo.FullName.Length -gt 255 -or $fileInfo.Name.StartsWith("~")) {return}
    #skip files bigger than 20 MB
    if ($fileInfo.Length -gt $MaxFileBiteSize) {return}
    #exclude irrelevant folders and files
    if (($FilePathExceptions | where { $fileInfo.DirectoryName.ToLower() -like "$_"}).Count -gt 0 ) {return}
    if (($FileNameExceptions | where { $fileInfo.Name.ToLower() -like "$_"}).Count -gt 0 ) {return}
    #[System.Collections.Generic.Dictionary[[string],[DateTime]]]$filesDBDict = Get-Variable -Name filesDBDict -Valueonly  -Erroraction SilentlyContinue -Scope 1
    #[System.Collections.Generic.Dictionary[[string],[int]]]$samefilesDBDict = Get-Variable -Name samefilesDBDict -Valueonly  -Erroraction SilentlyContinue -Scope 1

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

    if ($filesDBDict.ContainsKey($key)) {
        #[Sistem.DateTime] $fileDBModifiedDateUTC = $filesDBDict.Item($fullPath)
        if ([System.DateTime]$filesDBDict[$key] -ge $fileInfo.LastWriteTimeUtc.AddSeconds(-3) ) {
            #Write-output 'File is up to date... ' $fullPath
            return
        }
        $filesDBDict[$key] = [System.DateTime]$fileInfo.LastWriteTimeUtc
        Write-Event "Updating existing file... $key"
    }
    else{
        $filesDBDict.Add($key, [System.DateTime]$fileInfo.LastWriteTimeUtc);
        Write-Event "Adding new file... $key"
    }

    [int]$sameFileID = $null
    #if file has newer LastWriteTimeUtc, load content even if the same file exists
    if ($samefilesDBDict.ContainsKey($key)) 
    {
        $sameFileID = [int]$samefilesDBDict[$key]
    }

    [string]$fileExtensionForSearch = ".txt"
    [string]$fileText = $null
    [byte[]]$fileContent = $null
#$extension
    switch ($extension) {
        #".zip" {
            #Write-output "extract files to temp folder and read content" 
            #Get-ChildItem $fullPath | % {<insert your favorite zip utility here>; Move-Item $_ C:\tmp\unzipped}
            #LoadFile -fileInfo [IO.FileInfo]$fileInfo2
        #}

        {$_ -in ".pdf",".jpg",".doc",".xls",".ppt",".docx",".docm",".xlsx",".xlsm",".pptx",".pptm"} {
            if ($SearchFileNameHashed) {
                [string]$searchFilePath = "$($fileInfo.DirectoryName)\$($SearchFolderName)\$($fileInfo.Name.ToLower().GetHashCode()).search.json"
            }
            else {
                [string]$searchFilePath = "$($fileInfo.DirectoryName)\$($SearchFolderName)\$($fileInfo.Name).search.json"
            }
            if(Test-Path -LiteralPath $searchFilePath) {
                Write-output "    |___Extracting content from json file: $searchFilePath ..."

                <#ConvertFrom-JSON would work but only for a JSON object < 2MB in size. For higher you can use JavaScriptSerializer class
                    $fileObj = Get-Content $searchFilePath -Raw | ConvertFrom-Json 
                        |_____ConvertFrom-Json : Error during serialization or deserialization using the JSON

                    [string]$searchFilePath = "\\svrsa1fs03\library\EO eLibrary\AASTP- Done\_search\901560180.search.json"
                #>
                $json = Get-Content $searchFilePath -Raw 
                $jsser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                $jsser.MaxJsonLength = $jsser.MaxJsonLength * 10
                $jsser.RecursionLimit = 10
                $fileObj = $jsser.DeserializeObject($json)

                $fileText = $fileObj.Content
                
                if ($fileObj.Properties -ne $null){
                    $fileProperties = $fileObj.Properties
                }
                if ($fileObj.Entities -ne $null){
                    $fileEntities = $fileObj.Entities
                }

                #$fileName = $fileObj.Name + $fileObj.Extension
                #$fileLastWriteTimeUtc = $fileInfo.LastWriteTimeUtc
                #$fileLength = $fileInfo.Length
            }
        }

        {$_ -in ".htm",".html",".csv",".txt",".xml",".rtf"} {
            #Write-output "Processing text content"
            #$fileText = [System.IO.File]::ReadAllText($fullPath)
            #PS 3.0 has new command: 
            $fileText = Get-Content $fullPath -Raw
        }

        #binary content
        Default {
        }
    } 
    if($fileContent.Length -eq 0 -and $fileText.Length -gt 0) {
        #Write-output "Converting text content to binary"
        $fileContent = [System.Text.Encoding]::UTF8.GetBytes($fileText) #Unicode is not sutable for FTS functions
    }


    #if not able to retreave text, use binary content (without file properties) which SQL FTS can index directly
    if($fileContent.Length -eq 0) {
        Write-output "Loading binary content directly from file"
        try {
            $fileContent = [System.IO.File]::ReadAllBytes($fullPath);
            #PS 3.0 has new command: 
            #$fileContent = Get-Content $fullPath -Raw

            $fileExtensionForSearch = $fileInfo.Extension
        }
        catch {
            #Write-output "Access Denied!"
            Write-Event $error[0].Exception.Message -Error
        }
    }

    #commented block: allow broken files to be collected for reporting
    #if($fileContent.Length -ne 0) { 
        if ($sqlCmdAddFile.Connection.State -ne 'Open')
        {
            $sqlCmdAddFile.Connection.Open()
        }
        $sqlCmdAddFile.Parameters["@FileName"].Value = $fileName

        if (($fullPath -ne $null) -and ($fullPath -ne "")){

            $sqlCmdAddFile.Parameters["@FilePath"].Value = $directoryName
            $sqlCmdAddFile.Parameters["@FileExtension"].Value = $fileExtensionForSearch
            $sqlCmdAddFile.Parameters["@FileModifiedDateUTC"].Value = $fileLastWriteTimeUtc
            $sqlCmdAddFile.Parameters["@FileModifiedLength"].Value = $fileLength
            $sqlCmdAddFile.Parameters["@SameFileId"].Value = [System.DBNull]::Value
            $sqlCmdAddFile.Parameters["@FileContent"].Value = [System.DBNull]::Value

            if ($sameFileID -and $sameFileID -gt 0) {
                $sqlCmdAddFile.Parameters["@SameFileID"].Value = $sameFileID
            }
            if ($fileContent){
                $sqlCmdAddFile.Parameters["@FileContent"].Value = $fileContent
            }

            #Write-output "Loading binary content to database"
            $sqlCmdAddFile.ExecuteNonQuery() | Out-Null
            [int]$fileId = $sqlCmdAddFile.Parameters["@FileId"].Value

            if ($fileId -gt 0) {
                if ($fileProperties){
                    $fileProperties.GetEnumerator() | %{
                        $sqlCmdAddFileProperty.Parameters["@FileId"].Value = $fileId
                        $sqlCmdAddFileProperty.Parameters["@PropertyName"].Value = $_.Key
                        $sqlCmdAddFileProperty.Parameters["@PropertyValue"].Value = $_.Value
                        $sqlCmdAddFileProperty.ExecuteNonQuery() | Out-Null
                    }
                }

                if ($fileEntities){
                    foreach ($ent in $fileEntities){
                        $sqlCmdAddFileEntity.Parameters["@FileId"].Value = $fileId
                        $sqlCmdAddFileEntity.Parameters["@Type"].Value = $ent.Type
                        $sqlCmdAddFileEntity.Parameters["@Mention"].Value = $ent.Mention
                        $sqlCmdAddFileEntity.Parameters["@Count"].Value = $ent.Count
                        $sqlCmdAddFileEntity.ExecuteNonQuery() | Out-Null
                    }
                }
            }
        }
    #}
}

#TestFileLock ("F:\NovaSearch\Temp\OfficeFileConverter\Input\FDIST05.XLS")
function TestFileLock {
    ## Attempts to open a file and trap the resulting error if the file is already open/locked
    param ([string]$filePath )
    $filelocked = $false
    $fileInfo = New-Object System.IO.FileInfo $filePath
    trap {
        Set-Variable -name Filelocked -value $true -scope 1
        continue
    }
    $fileStream = $fileInfo.Open( [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None )
    if ($fileStream) {
        $fileStream.Close()
    }
    $filelocked
}


Main
Echo Finish
