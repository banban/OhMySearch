#http://svn.novagroup.com.au:8008/svn/SSIS/Nova.Integration/
#http://svn.novagroup.com.au:8008/svn/SSRS/trunk/NovaReporting/
#http://svn.novagroup.com.au:8008/svn/SQL/trunk/Schemas/
#http://svn.novagroup.com.au:8008/svn/Apps/trunk/
#exec [ssis].[RefreshPackages] 
#http://svn.novagroup.com.au:8008/svn/SSIS/Nova.Integration/http://svn.novagroup.com.au:8008/svn/SSAS/trunk/

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")]
#param test script
Param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true, HelpMessage = 'Target root folders for search collection')]
    [String[]]
    $SourceRepositories= @(), #"http://svn.novagroup.com.au:8008/svn/SSRS/trunk/NovaReporting/","http://svn.novagroup.com.au:8008/svn/SQL/trunk/Schemas/","http://svn.novagroup.com.au:8008/svn/SSIS/Nova.Integration/","http://svn.novagroup.com.au:8008/svn/Apps/trunk/","http://svn.novagroup.com.au:8008/svn/SSAS/trunk/", "http://svn.novagroup.com.au:8008/svn/Auspace/"
    [String[]]
    [Parameter(HelpMessage = 'List of extensions included in search')]
    [ValidateCount(1,100)]
    $FileExtensions = @(".ascx",".asm",".asp",".aspx",".bat",".bim",".cs",".cmd",".config",".cpp",".cube",".def",".dim",".dtsx",".h",".hhc",".hpp",".htm",".html",".htw",".htx",".inc",".inf",".ini",".inx",".js",".mht",".odc",".pl",".ps1",".py",".rc",".rdl",".reg",".rsd",".sql",".rtf",".txt",".vbs",".wtx",".xsl",".xlt",".xml"), #, ".zip"

    [Parameter(HelpMessage = 'List of full path (partial name of folder or file) parts excluded from search')]
    $FilePathExceptions = @("/_private/","/dfsrprivate/","/bin/","/obj/","/Debug/","/Release/","/Published/","/packages/","/tags/","/obsolete/","/backup/","/backup copy/","/log/","/old/","/archive/","/recyclebin/"),
    [Parameter(HelpMessage = 'List of file name excluded from search')]
    $FileNameExceptions = @(".config"),
    [Alias('Host')]
    #[ValidateSet('SVRADLDB02','SVRSA1DB04')]
    [string]$SQL_ServerName = "SVRSA1DB04",
    [Alias('DBName')]
    [string]$SQL_SearchDbName = "Nova_Search",

    [string]$LogFilePath = "F:\NovaSearch\Logs\Nova.Search.Source.log", #"C:\Temp\Nova.Search.Source.log",
    [string]$EventLog = "Application",
    [string]$EventSource = "Nova.Search",

    [string]$SvnClientExePath = "C:\Program Files\CollabNet\Subversion Client\svn.exe"

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
    # Create log file if it doesn't already exist
    if(-not (Test-Path -LiteralPath $LogFilePath)) {
        New-Item $LogFilePath -type file | Out-Null
    }
    Write-Event "$(Get-Date) Start session."
   
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_SearchDbName;Integrated Security=True;Application Name=Search.SourceRepositoryReader"
    $SqlConnection.Open()

    $sqlCmdGetFiles = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdGetFiles.Connection = $SqlConnection
    $sqlCmdGetFiles.CommandTimeout = 600;
    $sqlCmdGetFiles.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdGetFiles.CommandText = "[dbo].[GetFiles]"
    $sqlCmdGetFiles.Parameters.AddWithValue("@SchemaName", "source") | Out-Null
    $sqlCmdGetFiles.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FilePath",[Data.SQLDBType]::NVarChar, 512))) | Out-Null
    $sqlCmdGetFiles.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileExtension",[Data.SQLDBType]::NVarChar, 8))) | Out-Null

    $sqlCmdAddFile = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddFile.Connection = $SqlConnection
    $sqlCmdAddFile.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdAddFile.CommandText = "[dbo].[AddFile]"
    $sqlCmdAddFile.CommandTimeout = 600;
    $sqlCmdAddFile.Parameters.AddWithValue("@SchemaName", "source") | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileName",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FilePath",[Data.SQLDBType]::NVarChar, 512))) | Out-Null
    #$sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileText",[Data.SQLDBType]::NVarChar, -1))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileContent",[Data.SQLDBType]::VarBinary, -1))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileExtension",[Data.SQLDBType]::NVarChar, 8))) | Out-Null
    #$sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileProperties",[Data.SQLDBType]::NVarChar, -1))) | Out-Null
    #$sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileModifiedDateUTC",[Data.SQLDBType]::DatewTime))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileModifiedLength",[Data.SQLDBType]::BigInt))) | Out-Null
    #$sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@SameFileID",[Data.SQLDBType]::Int))) | Out-Null

    $sqlCmdCleanData = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdCleanData.Connection = $SqlConnection
    $sqlCmdCleanData.CommandType = [System.Data.CommandType]::StoredProcedure
    $sqlCmdCleanData.CommandText = "[dbo].[CleanImportedData]"
    $sqlCmdCleanData.Parameters.AddWithValue("@SchemaName", "source") | Out-Null
    $sqlCmdCleanData.CommandTimeout = 600;

##this is not relevant for sources. We preffer to use predefined list of extensions for sources
#    Write-output 'Add known extensions (document types) from database... '
#    $sqlDocTypes = New-Object System.Data.SqlClient.SqlCommand
#    $sqlDocTypes.Connection = $SqlConnection
#    $sqlDocTypes.CommandType = [System.Data.CommandType]::Text;
#    $sqlDocTypes.CommandText = "SELECT document_type FROM sys.fulltext_document_types ORDER BY 1"
#    $reader1 = $sqlDocTypes.ExecuteReader()
#    while ($reader1.Read())
#    {
#        [string]$ext = [string]$reader1["document_type"]
#        if (!$FileExtensions.Contains($ext) -and $ext.ToLower() -ne ".zip"){
#            $FileExtensions = $FileExtensions + $ext
#        }
#    }
#    $reader1.Close()

    foreach ($SourceRepository in $SourceRepositories){
        #DeleteOrphanRecords($SourceRepository)
        #$SourceRepository = "http://svn.novagroup.com.au:8008/svn/SQL/trunk/Schemas/"
        #$r=Invoke-WebRequest "http://svn.novagroup.com.au:8008/svn/SQL/trunk/Schemas/SVRSA1DB04/Nova_Search/shared/Tables/File.sql" -UseDefaultCredential
        Write-Event "$(Get-Date) Start crawling folder: $SourceRepository"
        & $SvnClientExePath list --recursive $SourceRepository| %{ 
            [string]$url = $SourceRepository +$_
            $exceptions = $FilePathExceptions | Where {$url -like "*"+$_+"*"}| measure
            if ($exceptions.Count -eq 0 -and $FileExtensions.Contains("."+$_.split('\.')[-1])) {
                #[string]$url = "http://svn.novagroup.com.au:8008/svn/old/SQL/trunk/Schemas/SVRADLDB02/Nova_Datamart/lightswitch/Views/vw_DDR_Projects.sql"
                $url
                $response = (Invoke-WebRequest $url -UseDefaultCredential -UseBasicParsing)
                if ($response.StatusDescription -eq "OK"){
                    $fileName = $url.split('\/')[-1]
                    if ($fileName.StartsWith("~")  -eq $False -and ($FileNameExceptions | where { $fileName.ToLower() -like "*$_*"}).Count -eq 0 ) {
                        $filePath = $url.Replace($fileName,"")
                        [string]$fileText = $response.Content
                        if ($fileText -ne $null -and $fileText -ne ""){
                            $fileText = $fileText.Trim().TrimStart("ï»¿")
                        }
                        $fileContent = [System.Text.Encoding]::UTF8.GetBytes($fileText) #Unicode is not sutable for FTS functions

                        $sqlCmdAddFile.Parameters["@FilePath"].Value = $filePath
                        $sqlCmdAddFile.Parameters["@FileName"].Value = $fileName
                        #$sqlCmdAddFile.Parameters["@FileText"].Value = $fileText
                        $sqlCmdAddFile.Parameters["@FileContent"].Value = $fileContent
                        #$sqlCmdAddFile.Parameters["@FileModifiedDateUTC"].Value = $fileInfo.LastWriteTimeUtc
                        $sqlCmdAddFile.Parameters["@FileModifiedLength"].Value = $fileText.Length
                        $sqlCmdAddFile.Parameters["@FileExtension"].Value = "."+$fileName.split('\.')[-1]
                    
                        #$sqlCmdAddFile.Parameters["@FileProperties"].Value = [System.DBNull]::Value
                        [void]$sqlCmdAddFile.ExecuteNonQuery()
                    }
                }

            }
        }

        #& $SvnClientExePath info -–xml $SourceRepository
        #([xml]($SvnClientExePath info $SourceRepository -–xml)).info.entry.revision
    }

    [void]$sqlCmdCleanData.ExecuteNonQuery()
    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }
    Write-Event "$(Get-Date) End session."
}

function DeleteOrphanRecords([string]$SourceRepository){
    #soft deleting obsolete records
    #[System.Data.SqlClient.SqlConnection]$SqlConnection = Get-Variable -Name SqlConnection -Valueonly  -Erroraction SilentlyContinue -Scope 1
    if ($SqlConnection.State -ne 'Open')
    {
        $SqlConnection.Open()
    }
    [string]$queryString = "SELECT [FileId], REPLACE([FilePath] +'\'+ [FileName],'\\'+ [FileName],'\'+ [FileName]) as FileFullPath, [FilePath], [FileName] FROM [source].[File] WHERE FilePath LIKE '" + $SourceRepository.Replace("'", "''") + "%' AND [DeleteDate] IS NULL"
    $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($queryString, $SqlConnection)
    $filesDataSet = New-Object System.Data.DataSet
    $sqlAdapter.Fill($filesDataSet, "Files") | Out-Null

    $updateCommand = New-Object System.Data.SqlClient.SqlCommand("UPDATE [source].[File] SET DeleteDate = GETDATE() WHERE FileID = @FileID AND DeleteDate IS NULL", $SqlConnection)
    $parameter = $updateCommand.Parameters.Add("@FileID", [Data.SQLDBType]::Int, 4, "FileID")
    $parameter.SourceVersion = [System.Data.DataRowVersion]::Original
    $sqlAdapter.UpdateCommand = $updateCommand
    $sqlAdapter.UpdateCommand.CommandTimeout = 6000

    foreach ($row in $filesDataSet.Tables["Files"].Rows)
    {
        [string]$fullPath = $row[1]
        [string]$folderPath = $row[2]
        try {
            if ($folderPath.Lenght -lt 248 -and $fullPath.Lenght -le 255) {
                if ((Test-Path -LiteralPath $fullPath) -eq $False){
                    Write-output 'soft deleting1 ' $fullPath
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


Main
Echo Finish
