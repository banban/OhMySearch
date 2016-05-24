<#
    cd C:\GitHub\banban\OhMySearch\BackEnd
    #dev test
    .\Setup.ps1 -ESVersion "5.0.0-alpha2" -ClusterName "Search-Dev" -SearchFolder "C:\Search" -LogFolder "C:\Logs"

    local executable test:
    cmd.exe /C "C:\Search\elasticsearch-5.0.0-alpha2\bin\elasticsearch.bat"


    #prod cluster
    .\setup.ps1 -ESVersion "5.0.0-alpha2" -ClusterName "Nova-Search" -SearchFolder "E:\Search" -LogFolder "F:\Logs" `
        -DiscoveryHosts @("10.1.0.178","10.1.0.179") -SetWinService $false `
        -LicenceFilePath "C:\Search\andrew-butenko-287161d3-a6db-4e47-a8b3-5e62df55586f.json"

    Exception in thread "main" java.lang.RuntimeException: bootstrap checks failed initial heap size [268435456] not equal to maximum heap size [1073741824]; 
    this can cause resize pauses and prevents mlockall from locking the entire heap 
    please set [discovery.zen.minimum_master_nodes] to a majority of the number of master eligible nodes in your cluster
#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'current version of Elastic Search products is the same starting from 5.0')]
    [string]$ESVersion,
    [string]$ClusterName,
    [string]$SearchFolder,
    [string]$LogFolder,
    [string[]]$DiscoveryHosts = @(),
    [switch]$SetWinService = $false,
    [string]$LicenceFilePath
)

function DownLoadAndExtract(){
    Param(
        [string]$Url
    )
    $fileName = split-path $Url -Leaf
    [IO.FileInfo]$archiveFileInfo = "$SearchFolder\$fileName"
    if ((Test-Path $archiveFileInfo.FullName) -eq $false){
        Echo "Downloading archive  $Url ..."
        (New-Object Net.WebClient).DownloadFile($Url,$archiveFileInfo.FullName);
        Unblock-File -Path $archiveFileInfo.FullName
        (new-object -com shell.application).namespace($SearchFolder).CopyHere((new-object -com shell.application).namespace("$($archiveFileInfo.FullName)").Items(),16)
        #Remove-Item $archiveFileInfo.FullName -Confirm:$false
    }
}

function Main(){
    Clear-Host

    DownLoadAndExtract -Url "https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/zip/elasticsearch/5.0.0-alpha2/elasticsearch-$ESVersion.zip"
    DownLoadAndExtract -Url "https://download.elastic.co/logstash/logstash/logstash-$ESVersion.zip"
    DownLoadAndExtract -Url "https://download.elastic.co/kibana/kibana/kibana-$ESVersion-windows.zip" #http://download.elastic.co/kibana/kibana-snapshot/kibana-5.0.0-snapshot-windows.zip
    DownLoadAndExtract -Url "https://download.elastic.co/beats/winlogbeat/winlogbeat-$ESVersion-windows-64.zip"

    #configure search parameters 
    $config = Get-Content "$SearchFolder\elasticsearch-$ESVersion\config\elasticsearch.yml" -Raw
    $config = $config.Replace("# cluster.name: my-application", " cluster.name: $ClusterName")
    $config = $config.Replace("# node.name: node-1", " node.name: $env:COMPUTERNAME")
    $config = $config.Replace("# path.data: /path/to/data", " path.data: $SearchFolder\Data")
    $config = $config.Replace("# path.logs: /path/to/logs", " path.logs: $LogFolder")
    <#if ($config.Contains("repositories.url.allowed_urls") -eq $false){
    $config += "
 repositories.url.allowed_urls: [""http://download.elastic.co/*""]"
    }#>

    #default is localhost:9200, otherwise use cluster
    if($DiscoveryHosts.Length -gt 0){
        $ipV4 = (Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address).IPV4Address.IPAddressToString
        #$config = $config.Replace("# network.host: 192.168.0.1", " network.host: $ipV4")
        $otherhosts = ''
        for ([int]$i = 0; $i -lt $DiscoveryHosts.Length; $i++){
            if ($DiscoveryHosts[$i] -notin $ipV4, $env:COMPUTERNAME){
                $otherhosts += ',"'+$DiscoveryHosts[$i]+'"'
            }
        }
        $otherhosts = $otherhosts.Trim(',')
        if ($otherhosts -ne ""){
            $config = $config.Replace("# discovery.zen.ping.unicast.hosts: [""host1"", ""host2""]", " discovery.zen.ping.unicast.hosts: [$otherhosts]")
        }
    }
    
    Set-Content "$SearchFolder\elasticsearch-$ESVersion\config\elasticsearch.yml" $config

    #configure environment variables
    if ($env:ElasticUri -eq $null){
        $env:ElasticUri = "http://$ipV4:9200"
    }
    if ($env:SEARCH_HOME -eq $null){
        $env:SEARCH_HOME = $SearchFolder
    }
    if ($env:LOG_DIR -eq $null){
        $env:LOG_DIR = $LogFolder
    }
    if ($env:JAVA_HOME -eq $null)
    {
        Echo "Please install last version of Java" and configure working catalog
    }

    if ($SetWinService -eq $true){
        #uninstall service
        try{
            cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\service.bat" stop Elastic-Search
            cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\service.bat" remove Elastic-Search
        }
        catch{}

        #install service
        cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\service.bat" install Elastic-Search
        cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\service.bat" start Elastic-Search
    }
    else{
        Echo "To run elastic service use this command in separate window: cmd.exe /C '$SearchFolder\elasticsearch-$ESVersion\bin\elasticsearch.bat'"
    }

    #plugins
    #cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat list"
    #cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install x-pack"
    #cmd.exe /C "$SearchFolder\kibana-$ESVersion\bin\kibana-plugin.bat install x-pack"
        #https://download.elastic.co/kibana/x-pack/x-pack-5.0.0-alpha2.zip

    <#
    #Managing your licence https://www.elastic.co/guide/en/marvel/current/license-management.html#listing-licenses
    #Marvel trial licence:
    cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install license"
    cmd.exe /C "$SearchFolder\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install marvel-agent"

    #&$get '_license'
    #install licence from file
    if (Test-Path $LicenceFilePath){
        [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
        if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
        Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose

        $license = Get-Content -Raw -Path $LicenceFilePath #| ConvertFrom-Json
        Echo "Installing licence from file $LicenceFilePath"
        &$put "_license?acknowledge=true" $license
     }
     #>
}

Main