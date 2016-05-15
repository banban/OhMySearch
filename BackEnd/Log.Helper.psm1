[string]$global:EventLog = "Application";
[string]$global:EventLogSource = "Search"

#try to resolve global settings
if($env:LOG_DIR  -eq $null -or $env:LOG_DIR  -eq ""){
    $env:LOG_DIR = "C:\Logs"
}
[string]$global:LogFilePath = "$env:LOG_DIR\Search.log"

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
        if ($global:LogFilePath -ne ""){
            try { Add-Content $global:LogFilePath $Message }
            catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to log file $($_.LogFilePath)." }
        }

        if ($global:EventLog -ne "" -and $global:EventLogSource -ne ""){
            if ([system.diagnostics.eventlog]::SourceExists($global:EventLogSource) -eq $false) {
                [system.diagnostics.EventLog]::CreateEventSource($global:EventLogSource, $global:EventLog)
            }

            try { Write-EventLog –LogName $global:EventLog –Source $global:EventLogSource –EntryType Error –EventID $EventId –Message $Message | Out-Null }
            catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to event logs." }
        }
    }
    ElseIf ($Warning.IsPresent){
        Write-Warning $Message

        if ($global:LogFilePath -ne ""){
            try { Add-Content $global:LogFilePath $Message }
            catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to log file $($_.LogFilePath)." }
        }

        <#if ($global:EventLog -ne "" -and $global:EventLogSource -ne ""){
            try { Write-EventLog –LogName $global:EventLog –Source $global:EventLogSource –EntryType Warning –EventID $EventId –Message $Message | Out-Null }
            catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to event logs." }
        }#>
    }
    ElseIf ($Information.IsPresent) {
        Write-Output $Message

        if ($global:LogFilePath -ne ""){
            try { Add-Content $global:LogFilePath $Message }
            catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to log file $($_.LogFilePath)." }
        }

        <#if ($global:EventLog -ne "" -and $global:EventLogSource -ne ""){
            try { Write-EventLog –LogName $global:EventLog –Source $global:EventLogSource –EntryType Information –EventID $EventId –Message $Message | Out-Null }
            catch [System.Security.SecurityException] { Write-Error "Error:  Run as elevated user.  Unable to write or read to event logs." }
        }#>
    }
    Else {
        Write-Output $Message
        if ($global:LogFilePath -ne ""){
            try{
                Add-Content $global:LogFilePath $Message
            }
            catch{
                #sometimes file is locked by another process. try again in 100 msecon
                Start-Sleep -Milliseconds 100
                Add-Content $global:LogFilePath $Message
            }
        }        
    }
}