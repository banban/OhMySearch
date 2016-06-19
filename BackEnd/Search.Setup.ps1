<#
1. Navigate to your working folder:
    cd C:\Search 

2. Configure environment variables. Run this script as administrator (!!!) to set up environment variables permanently. Machine or User - up to you        
    .\Search.Environment.ps1

3. Set up dev (with daily snapshot ??)
    .\Search.Setup.ps1 -ESVersion "5.0.0-alpha3" -ClusterName "OhMySearch-Dev"

4. Configure production cluster:
    cd E:\Search
    .\Search.Setup.ps1 -ESVersion "5.0.0-alpha3" -ClusterName "OhMySearch-Prod" -SetEnvironment `
        -DiscoveryHosts @("10.1.0.178","10.1.0.179") -AsService `
        -LicenceFilePath "E:\Search\company-license-<your code>.json"

5. Debug locally:
    cmd.exe /C "C:\Search\elasticsearch-5.0.0-alpha3\bin\elasticsearch.bat"
    $ESVersion = "5.0.0-alpha3"

#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'current version of Elastic Search products is the same starting from 5.0')]
    [string]$ESVersion,
    [string]$ClusterName,
    [string[]]$DiscoveryHosts = @(),
    [switch]$AsService,
    [switch]$UseSnapshot,
    [string]$LicenceFilePath,
    [switch]$SetEnvironment
)

function Main(){
    Clear-Host

    if ($env:JAVA_HOME -eq $null) # since alpha 3 $env:JAVA_HOME is not the only option. It accepts java.exe path. Not implemented yet
    {
        Echo "Please install last version of Java and configure working catalog"
    }
    
    if ($UseSnapshot.IsPresent){#daily builds works for kibana only :(
        #DownLoadAndExtract -Url "http://download.elastic.co/elasticsearch/elasticsearch-snapshot/elasticsearch-5.0.0-snapshot.zip"
        #DownLoadAndExtract -Url "http://download.elastic.co/logstash/logstash-snapshot/logstash-5.0.0-snapshot.zip"
        DownLoadAndExtract -Url "http://download.elastic.co/kibana/kibana-snapshot/kibana-5.0.0-snapshot-windows.zip"
        #DownLoadAndExtract -Url "http://download.elastic.co/beats/winlogbeat-snapshot/winlogbeat-5.0.0-snapshot-windows-64.zip"
    }
    else{ #Official release
        DownLoadAndExtract -Url "https://download.elasticsearch.org/elasticsearch/release/org/elasticsearch/distribution/zip/elasticsearch/$($ESVersion)/elasticsearch-$($ESVersion).zip"
        DownLoadAndExtract -Url "https://download.elastic.co/logstash/logstash/logstash-$($ESVersion).zip"
        DownLoadAndExtract -Url "https://download.elastic.co/kibana/kibana/kibana-$($ESVersion)-windows.zip"
        DownLoadAndExtract -Url "https://download.elastic.co/beats/winlogbeat/winlogbeat-$($ESVersion)-windows-x64.zip"
    }

    #configure elastice settings 
    #For settings that you do not wish to store in the configuration file, you can use the value ${prompt.text} or ${prompt.secret} 
    $config = Get-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\elasticsearch.yml" -Raw
    $config = $config.Replace("# cluster.name: my-application", " cluster.name: $ClusterName")
    #Environment variables referenced with the ${...} notation within the configuration file will be replaced with the value of the environment variable, for instance:
    $config = $config.Replace("# node.name: node-1", " node.name: `${HOSTNAME}") #$env:COMPUTERNAME
    $config = $config.Replace("# path.data: /path/to/data", " path.data: $env:SEARCH_HOME\Data")
    $config = $config.Replace("# path.logs: /path/to/logs", " path.logs: $env:LOG_DIR")

    #default is localhost:9200, otherwise use cluster
    #command line configuration
    #configure settings from command line:
    #cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch.bat" -Enode.name=node_1 -Ecluster.name=my_cluster 

    if($DiscoveryHosts.Length -gt 0){
        #The network.host setting also understands some special values such as _local_, _site_, _global_ and modifiers like :ip4 and :ip6, details of which can be found in the section called “Special values for network.hostedit”.
        #$ipV4 = (Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address).IPV4Address.IPAddressToString
        $config = $config.Replace("# network.host: 192.168.0.1", " network.host: $ipV4") # `${ES_NETWORK_HOST}

        $otherhosts = ''
        for ([int]$i = 0; $i -lt $DiscoveryHosts.Length; $i++){
            if ($DiscoveryHosts[$i] -notin $ipV4, $env:COMPUTERNAME){
                $otherhosts += ',"'+$DiscoveryHosts[$i]+'"'
            }
        }
        $otherhosts = $otherhosts.Trim(',')
        if ($otherhosts -ne ""){
            $config = $config.Replace("# discovery.zen.ping.unicast.hosts: [""host1"", ""host2""]", " discovery.zen.ping.unicast.hosts: [$otherhosts]")
            #If discovery.zen.minimum_master_nodes is not set when Elasticsearch is running in production mode, an exception will be thrown which will prevent the node from starting.
            $config = $config.Replace("# discovery.zen.minimum_master_nodes: 3", " discovery.zen.minimum_master_nodes: $($DiscoveryHosts.Length / 2 + 1)") #quorum of master-eligible nodes
        }
    }

    #It is, however, possible to start more than one node on the same server by mistake and to be completely unaware that this problem exists. 
    #To prevent more than one node from sharing the same data directory, it is advisable to add the following setting:
    $config = $config.Replace("# node.max_local_storage_nodes: 1", " node.max_local_storage_nodes: 1")

    #add some trusted sources of data:
    if ($config.Contains("repositories.url.allowed_urls") -eq $false){
        $config += "`r`n repositories.url.allowed_urls: [""http://download.elastic.co/*""]"
    }

    Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\elasticsearch.yml" $config

    #configure logging setting. 
    $logging = Get-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\logging.yml" -Raw
    #$logging = $logging.Replace("es.logger.level: INFO", "es.logger.level: DEBUG")
    #For example, this will create a daily rolling deprecation log file in your log directory. Check this file regularly, especially when you intend to upgrade to a new major version.:
    $logging = $logging.Replace("deprecation: INFO, deprecation_log_file", "deprecation: DEBUG, deprecation_log_file")
    Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\logging.yml" $logging

    <#The service installer requires that the thread stack size setting be configured in jvm.options before you install the service. 
        On 32-bit Windows, you should add -Xss320k to the jvm.options file, 
        and on 64-bit Windows you should add -Xss1m to the jvm.options file.#>
    $jvmoptoins = Get-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" -Raw
    if ([Environment]::Is64BitProcess -eq $true -and $jvmoptoins.Contains("-Xss1m") -eq $false){
        $jvmoptoins += "`r`n-Xss1m"
        Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" $jvmoptoins
    }
    elseif (([Environment]::Is64BitProcess -eq $null -or [Environment]::Is64BitProcess -eq $false) -and $jvmoptoins.Contains("-Xss320k") -eq $false){
        $jvmoptoins += "`r`n-Xss320k"
        Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" $jvmoptoins
    }

    #check current versions
    cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch.bat" -V
    cmd.exe /C "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana.bat" -V

    #configure windows services
    if ($AsService.IsPresent){
        #uninstall service
        try{
            cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\service.bat" stop Elastic-Search
            cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\service.bat" remove Elastic-Search
            #"Waiting 5 seconds to allow service to be uninstalled."
            Start-Sleep -s 5  
        }
        catch{}

        #install service
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\service.bat" install #Elastic-Search
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\service.bat" start #Elastic-Search
        #or run it manually in command line deamon mode. To stop use Cntrl+C
        #cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\service.bat" -d

        <#unfortunately kibana as a service is not available yet in v5
            cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\kibana.bat" install Kibana

        but we can simulate that service. run the following command in admin mode:
            cmd.exe /C sc create "ElasticSearch Kibana" binPath= "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana.bat" depend= "Elastic-Search" 
            sc start "ElasticSearch Kibana"
        ignore messages that service is not accesable. it is already running, just check http://localhost:5601
        to uninstall run:
            sc stop "ElasticSearch Kibana"
            sc delete "ElasticSearch Kibana"
        Or use our script function provided below:
            Setup-Service -serviceName "ElasticSearch Kibana" -exePath "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana.bat" -uninstall -install -start #-cred $cred
        #>
    }
    else{
        Echo "To run elastic service use this command in separate window: cmd.exe /C '$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch.bat'"
    }

    <#configure plugins. 
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat list"
        cmd.exe /C "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana-plugin.bat list"

    #extended unicode support https://www.elastic.co/guide/en/elasticsearch/plugins/master/analysis-icu.html
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install analysis-icu"
    #TimeLion
        cmd.exe /C "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana-plugin.bat install timelion"

    #https://www.elastic.co/guide/en/x-pack/current/security-getting-started.html
    Install X-Pack. Run as admin
        $ESVersion = "5.0.0-alpha3"
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install x-pack"
        cmd.exe /C "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana-plugin.bat install x-pack"
        #[Environment]::SetEnvironmentVariable("ElasticUser", "elastic", "User")
        #[Environment]::SetEnvironmentVariable("ElasticPassword", "changeme", "User")


    Uninstall X-Pack. Run as admin         
        $ESVersion = "5.0.0-alpha3"
        cmd.exe /C "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana-plugin.bat remove x-pack"
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat remove x-pack"
        Remove-Item Env:\ElasticUser
        Remove-Item Env:\ElasticPassword


    Do not use examples below in v5!!!
    Many v2 plugings are moved or depricated in v5. For example, v2 marvel. 
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install license"
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-plugin.bat install marvel-agent"
        #check the license from our scripts
            &$get '_license'

        install license from file:
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

function DownLoadAndExtract(){
    Param(
        [string]$Url
    )
    $fileName = split-path $Url -Leaf
    [IO.FileInfo]$archiveFileInfo = "$env:SEARCH_HOME\$fileName"
    if ((Test-Path $archiveFileInfo.FullName) -eq $false){
        Echo "Downloading archive  $Url ..."
        (New-Object Net.WebClient).DownloadFile($Url,$archiveFileInfo.FullName);
        Unblock-File -Path $archiveFileInfo.FullName
        (new-object -com shell.application).namespace($env:SEARCH_HOME).CopyHere((new-object -com shell.application).namespace("$($archiveFileInfo.FullName)").Items(),16)
        #Remove-Item $archiveFileInfo.FullName -Confirm:$false
    }
}

function Setup-Service(){
    [CmdletBinding(PositionalBinding=$false)] 
    Param(
        [string]$serviceName,
        [string]$dependsOn,
        [string]$exePath,
        [switch]$install,
        [switch]$uninstall,
        [switch]$start,
        [switch]$stop,
        $cred
        #$username,
        #$password = convertto-securestring -String "somePassword" -AsPlainText -Force  
        #$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
    )

    $existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"

    if (($install.IsPresent -or $uninstall.IsPresent -or $stop.IsPresent) -and $existingService) {
      "'$serviceName' exists already. Stopping..."
      Stop-Service $serviceName
      "Waiting 3 seconds to allow existing service to stop."
      Start-Sleep -s 3
    }

    if (($uninstall.IsPresent -or $install.IsPresent) -and $existingService) {
      $existingService.Delete()
      "Waiting 5 seconds to allow service to be uninstalled."
      Start-Sleep -s 5  
    }

    if ($install.IsPresent) {
        "Installing the service: $serviceName"
        New-Service -BinaryPathName $exePath -Name $serviceName -Credential $cred -DisplayName $serviceName -StartupType Automatic -DependsOn $dependsOn
        "Installed the service."
    }

    $existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
    if ($start.IsPresent -and $existingService) {
        "Starting the service: $serviceName"
        Start-Service $serviceName
    }
    "Completed."
}

Main