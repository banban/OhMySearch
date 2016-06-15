<#
This script uses the .NET FileSystemWatcher class to monitor file events in folder(s). 
The advantage of this method over using WMI eventing is that this can monitor sub-folders. 
The -Action parameter can contain any valid Powershell commands.  I have just included two for example. 
The script can be set to a wildcard filter, and IncludeSubdirectories can be changed to $true. 
You need not subscribe to all three types of event.  All three are shown for example. 

Unit Tests:
    cd C:\Search\Scripts
    .\Search.Index.Files.Events.ps1 -listenFolder "C:\temp" -indexName "shared"
    .\Search.Index.Files.Events.ps1 -listenFolder "\\shares\fs" -indexName "dfs"
    .\Search.Index.Files.Events.ps1 -listenFolder "\\shares\library" -indexName "library"

    \\shares\fs
    "$([Environment]::getfolderpath("mypictures"))"
    "$([Environment]::getfolderpath("mydocuments"))"

    $id = (ConvertFrom-Json(&$search -index "shared" -type "photo" -obj @{
        fields = @("_id")
        query = @{ match_phrase = @{ Path = "c:/users/yourname/pictures/geotags/20150819_144945.jpg" }}})).hits.hits[0]._id


    &$search "$indexName" "photo,file" -obj @{
        query = @{
            match = @{
                Path = "$path"
            }
        }
    }

    &$search $indexName "photo,file" '{
        "query": {
            "match_phrase": {
                "Path": "$path"
            }
        }
    }'
#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "EventSet")] #SupportShouldProcess=$true, 
Param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target root folders to monitor')]
    [string]$listenFolder = "",
    [int]$waitSeconds = 600,
    [string]$filter = '*.*',  # You can enter a wildcard filter here. 
    [string]$SearchFolderName = "_search",
    [string]$SearchFileMask = "*.search.json",
    [bool]$SearchFileNameHashed = $true,
    [string]$indexName = ""
)

function RefreshIndex(){
    [CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "RefreshSet")]
    Param(
        [Parameter(Mandatory=$false, Position = 0)]
        [IO.FileInfo]$file,
        [Parameter(Mandatory=$false, Position = 1)]
        [IO.DirectoryInfo]$directory
    )
    #recreate json file 
    &"$scripLocation\Search.Index.Json.ps1" -SharedFolders "$($file.FullName)"

    #add/replace index document in Elastic
    if ($SearchFileNameHashed) {
        [string]$searchFilePath = "$($file.DirectoryName)\$($SearchFolderName)\$($file.Name.ToLower().GetHashCode()).search.json".ToLower() #$($SearchFileMask.Replace("*",""))
    }
    else {
        [string]$searchFilePath = "$($file.DirectoryName)\$($SearchFolderName)\$($file.Name).search.json".ToLower()
    }
    &"$scripLocation\Search.Index.Files.ps1" -SharedFolders "$searchFilePath" -indexName "$indexName" -BulkDocuments $false

}

function Main(){
    Clear-Host
    if ($listenFolder -eq "" -or $indexName -eq ""){
        Echo "Please specify listenFolder and indexName parameter value"
        break;
    }
    
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}

    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose

    <#try{
        Unregister-Event FileDeleted 
        Unregister-Event FileCreated 
        Unregister-Event FileChanged
        Unregister-Event FileRenamed
    }
    catch{
    }#>

    #$listenFolder = "C:\temp\"
    # In the following line, you can change 'IncludeSubdirectories to $true if required.                           
    $fsw = New-Object IO.FileSystemWatcher $listenFolder, $filter -Property @{IncludeSubdirectories = $true;NotifyFilter = [IO.NotifyFilters]'DirectoryName, FileName, LastWrite'} 

    # Here, all three events are registerd.  You need only subscribe to events that you need: 
#$fsw 
    Register-ObjectEvent $fsw Created -SourceIdentifier FileCreated -Action { 
        $fullPath = $Event.SourceEventArgs.FullPath.ToLower()
        $searchPath = $fullPath.Replace("\","/").TrimEnd("/") 
        $changeType = $Event.SourceEventArgs.ChangeType 
        $timeStamp = $Event.TimeGenerated 

        if (Test-Path $sharedFolder -PathType Container){
            Write-Host "$timeStamp The folder '$fullPath' was $changeType" -fore green 
            #[IO.DirectoryInfo]$di = $fullPath 
            #check if $di has files 
            #RefreshIndex -directory $di
        }
        elseif (Test-Path $sharedFolder -PathType Leaf){
            if ($fi.Length -gt 0){
                Write-Host "$timeStamp The file '$fullPath' was $changeType" -fore green 
                #[IO.FileInfo]$fi = $fullPath
                #RefreshIndex -file $fi
            }
        }
    } 
 
    Register-ObjectEvent $fsw Deleted -SourceIdentifier FileDeleted -Action { 
        $fullPath = $Event.SourceEventArgs.FullPath.ToLower()
        $searchPath = $fullPath.Replace("\","/").TrimEnd("/") 
        $changeType = $Event.SourceEventArgs.ChangeType 
        $timeStamp = $Event.TimeGenerated 
        Write-Host "$timeStamp The file '$fullPath' was $changeType" -fore red 
        $id = (ConvertFrom-Json(&$search "$indexName" "photo,file" -obj @{
          fields = @("_id")
          query = @{ match_phrase = @{ Path = $searchPath }}})).hits.hits[0]._id

        if ($id -ne ""){
            &$delete "/$indexName/file,photo/$id"
        }
    } 
 
    Register-ObjectEvent $fsw Changed -SourceIdentifier FileChanged -Action { 
        $fullPath = $Event.SourceEventArgs.FullPath.ToLower()
        $changeType = $Event.SourceEventArgs.ChangeType 
        $timeStamp = $Event.TimeGenerated 

        if (Test-Path $sharedFolder -PathType Container){
            Write-Host "$timeStamp The folder '$fullPath' was $changeType" -fore yellow 
            #[IO.DirectoryInfo]$di = $fullPath
            #RefreshIndex -directory $di
        }
        elseif (Test-Path $sharedFolder -PathType Leaf){
            if ($fi.Length -gt 0){
                Write-Host "$timeStamp The file '$fullPath' was $changeType" -fore yellow 
                #[IO.FileInfo]$fi = $fullPath
                #RefreshIndex -file $fi
            }
        }
    } 


    Register-ObjectEvent $fsw Renamed -SourceIdentifier FileRenamed -Action { 
        $fullPath = $Event.SourceEventArgs.FullPath.ToLower()
        $oldName = $Event.SourceEventArgs.OldFullPath
        $searchPath = $oldName.Replace("\","/").TrimEnd("/") 
        $changeType = $Event.SourceEventArgs.ChangeType 
        $timeStamp = $Event.TimeGenerated

        if (Test-Path $sharedFolder -PathType Container){
            Write-Host "$timeStamp The folder '$fullPath' was $changeType. Old name: $oldName" -fore yellow 
            #TBD delete or update?

            #[IO.DirectoryInfo]$di = $fullPath
            #RefreshIndex -directory $di
        }
        elseif (Test-Path $sharedFolder -PathType Leaf){
            if ($fi.Length -gt 0){
                Write-Host "$timeStamp The file '$fullPath' was $changeType. Old name: $oldName" -fore yellow 
                #delete old indexed record
                $id = (ConvertFrom-Json(&$search "$indexName" "photo,file" -obj @{
                  fields = @("_id")
                  query = @{ match_phrase = @{ Path = $searchPath }}})).hits.hits[0]._id

                if ($id -ne ""){
                    &$delete "/$indexName/file,photo/$id"
                }

                #[IO.FileInfo]$fi = $fullPath
                #RefreshIndex -file $fi
            }
        }
    } 
    
    <#Start-Sleep -Seconds $waitSeconds
    # To stop the monitoring, run the following commands: 
    Unregister-Event FileDeleted 
    Unregister-Event FileCreated 
    Unregister-Event FileChanged
    Unregister-Event FileRenamed#>
}

Main