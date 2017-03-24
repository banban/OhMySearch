<#
1. Navigate to your working folder:
    cd C:\Search\Scripts 

2. Configure environment variables. Run this script as administrator (!!!) to set up environment variables permanently. Machine or User - up to you        
    .\Search.Environment.ps1

3. Set up dev
    .\Search.Setup.ps1 -ESVersion_Old = "5.1.2" -ESVersion "5.2.0" -ClusterName "OhMySearch-Dev"

4. Configure production cluster:
    cd E:\Search
    .\Search.Setup.ps1 -ESVersion_Old = "5.1.2" -ESVersion "5.2.0" -ClusterName "OhMySearch-Prod" -SetEnvironment `
        -DiscoveryHosts @("10.1.0.178","10.1.0.179") -AsService `
        -LicenceFilePath "E:\Search\company-license-<your code>.json"

5. Debug locally:
    cmd.exe /C "C:\Search\elasticsearch-5.2.0\bin\elasticsearch.bat"
    $ESVersion_Old = "5.1.2"
    $ESVersion = "5.2.0"
#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [Parameter(Mandatory=$false, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'current version of Elastic Search products is the same starting from 5.0')]
    [string]$ESVersion,
    [string]$ESVersion_Old,
    [string]$ClusterName,
    [string[]]$DiscoveryHosts = @(),
    [switch]$AsService,
    [switch]$UseSnapshot,
    [string]$LicenceFilePath,
    [switch]$SetEnvironment
)

[string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
function Main(){
    Clear-Host

    if ($env:JAVA_HOME -eq $null) # since alpha 3 $env:JAVA_HOME is not the only option. It accepts java.exe path. Not implemented yet
    {
        Echo "Please install last version of Java and configure working catalog"
    }
    
    if ($UseSnapshot.IsPresent){#daily builds works for kibana only :(
        #DownLoadAndExtract -Url "http://download.elastic.co/elasticsearch/elasticsearch-snapshot/elasticsearch-5.0.0-snapshot.zip"
        #DownLoadAndExtract -Url "http://download.elastic.co/logstash/logstash-snapshot/logstash-5.0.0-snapshot.zip"
        #DownLoadAndExtract -Url "http://download.elastic.co/kibana/kibana-snapshot/kibana-5.0.0-snapshot-windows.zip"
        #DownLoadAndExtract -Url "http://download.elastic.co/beats/winlogbeat-snapshot/winlogbeat-5.0.0-snapshot-windows-64.zip"
    }
    else{ #Official release
        DownLoadAndExtract -Url "https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-$($ESVersion).zip"
        DownLoadAndExtract -Url "https://artifacts.elastic.co/downloads/logstash/logstash-$($ESVersion).zip"
        DownLoadAndExtract -Url "https://artifacts.elastic.co/downloads/kibana/kibana-$($ESVersion)-windows-x86.zip"
        DownLoadAndExtract -Url "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-$($ESVersion)-windows-x86_64.zip"
        DownLoadAndExtract -Url "https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-$($ESVersion)-windows-x86_64.zip"
    }
    
    #configure file processors: tesseract, image, etc. Install-Module described here: http://psget.net
    Install-Module -ModuleUrl "https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Image-module-caa4405a/file/62238/1/Image.zip" -Verbose

    #For server OS you need to activate Desktop-Experience to avoid this exception in Search.Json.ps1 : Retrieving the COM class factory for component with CLSID {00000000-0000-0000-0000-000000000000} failed due to the following error: 80040154 Class not registered (Exception from HRESULT: 0x80040154 (REGDB_E_CLASSNOTREG)).
    try{
        Add-WindowsFeature Desktop-Experience 
    }
    catch{}

    <#you can use 3.02, but I use 3.05 dev. First of all, get sources: https://github.com/tesseract-ocr/tesseract/archive/master.zip
    if you do not want to compile sources, get ready to use binaries from here: https://www.dropbox.com/s/8t54mz39i58qslh/tesseract-3.05.00dev-win32-vc19.zip?dl=1
    finally, fill tessdata subfolder with your languages training content: https://github.com/justin/tesseract-ocr/tree/master/tessdata
        for example, english training data could be found in file named "eng.traineddata"
    #>


    #DownLoadAndInstall -Url "http://www.imagemagick.org/download/binaries/ImageMagick-7.0.2-3-Q16-x64-dll.exe"
    #DownLoadAndInstall -Url "https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs919/gs919w64.exe"
    #DownLoadAndInstall -Url "https://inkscape.org/en/gallery/item/3956/inkscape-0.91-x64.msi" or https://inkscape.org/en/gallery/item/3938/Inkscape-0.91-1-win64.7z



    #configure elastice settings 
    #For settings that you do not wish to store in the configuration file, you can use the value ${prompt.text} or ${prompt.secret} 
    $config = Get-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\elasticsearch.yml" -Raw
    $config = $config.Replace("#cluster.name: my-application", " cluster.name: $ClusterName")
    #Environment variables referenced with the ${...} notation within the configuration file will be replaced with the value of the environment variable, for instance:
    #do not use host name in service mode to avoide Exception in thread "main" ception: Could not resolve placeholder 'HOSTNAME'
    $config = $config.Replace("#node.name: node-1", " node.name: $($env:COMPUTERNAME)") #`${HOSTNAME} or use ${COMPUTERNAME}
    $config = $config.Replace("#path.data: /path/to/data", " path.data: $env:SEARCH_HOME\Data")
    $config = $config.Replace("#path.logs: /path/to/logs", " path.logs: $env:LOG_DIR")

    #default is localhost:9200, otherwise use cluster
    #command line configuration
    #configure settings from command line:
    #cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch.bat" -Enode.name=node_1 -Ecluster.name=my_cluster 

    if($DiscoveryHosts.Length -gt 0){
        #The network.host setting also understands some special values such as _local_, _site_, _global_ and modifiers like :ip4 and :ip6, details of which can be found in the section called “Special values for network.hostedit”.
        $ipV4 = (Test-Connection -ComputerName (hostname) -Count 1  | Select IPV4Address).IPV4Address.IPAddressToString
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
    if (Test-Path "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\logging.yml")
    {
        $logging = Get-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\logging.yml" -Raw
        if ($logging -ne $null)
        {
            #$logging = $logging.Replace("es.logger.level: INFO", "es.logger.level: DEBUG")
            #For example, this will create a daily rolling deprecation log file in your log directory. Check this file regularly, especially when you intend to upgrade to a new major version.:
            $logging = $logging.Replace("deprecation: INFO, deprecation_log_file", "deprecation: DEBUG, deprecation_log_file")
            Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\logging.yml" $logging
        }
    }
    $env:JAVA_HOME
    <#The service installer requires that the thread stack size setting be configured in jvm.options before you install the service. 
        On 32-bit Windows, you should add -Xss320k to the jvm.options file, 
        and on 64-bit Windows you should add -Xss1m to the jvm.options file.
        
        While a JRE can be used for the Elasticsearch service, due to its use of a client VM 
        (as opposed to a server JVM which offers better performance for long-running applications) 
        its usage is discouraged and a warning will be issued.
    #>
    $jvmoptoins = Get-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" -Raw
    if ([Environment]::Is64BitProcess -eq $true -and $jvmoptoins.Contains("-Xss1m") -eq $false){
        $jvmoptoins += "`r`n-Xss1m"
        Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" $jvmoptoins
    }
    elseif (([Environment]::Is64BitProcess -eq $null -or [Environment]::Is64BitProcess -eq $false) -and $jvmoptoins.Contains("-Xss320k") -eq $false){
        $jvmoptoins += "`r`n-Xss320k"
        Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" $jvmoptoins
    }

    <#initial heap size [268435456] not equal to maximum heap size [2147483648]; this can cause resize pauses and prevents mlockall from locking the entire heap
        Min and max heap size must be equal to start ES 5.0.0-alpha2#>
    if (([Environment]::Is64BitProcess -eq $null -or [Environment]::Is64BitProcess -eq $false) -and $jvmoptoins.Contains("-Xms1g") -eq $false){
        $jvmoptoins += "`r`n-Xms1g"
        Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" $jvmoptoins
    }
    if (([Environment]::Is64BitProcess -eq $null -or [Environment]::Is64BitProcess -eq $false) -and $jvmoptoins.Contains("-Xmx1g") -eq $false){
        $jvmoptoins += "`r`n-Xmx1g"
        Set-Content "$env:SEARCH_HOME\elasticsearch-$ESVersion\config\jvm.options" $jvmoptoins
    }

    #check current versions
    cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch.bat" -V
    cmd.exe /C "$env:SEARCH_HOME\kibana-$ESVersion-windows-x86\bin\kibana.bat" -V
    java -version

    <#dotnet new
    dotnet restore
    dotnet run#>
    dotnet --version

    #configure windows services
    if ($AsService.IsPresent){
        #uninstall service
        try{
            cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion_Old\bin\elasticsearch-service.bat" stop Elastic-Search
            cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion_Old\bin\elasticsearch-service.bat" remove Elastic-Search
            #"Waiting 5 seconds to allow service to be uninstalled."
            Start-Sleep -s 5  
        }
        catch{
            sc.exe delete "Elastic-Search"
            sc.exe delete elasticsearch-service-x32 #default name
            sc.exe delete elasticsearch-service-x64 #default name
        }

        #install service
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-service.bat" install Elastic-Search
        #manager allowes to check current status of service and java options in UI
        #cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-service.bat" manager Elastic-Search
        #cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-service.bat" manager Elastic-Search
        #C:\Search\winlogbeat-5.2.2-windows-x86_64\scripts\import_dashboards.exe -es

        #let's start it...
        cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-service.bat" start Elastic-Search

        #or run it manually in command line deamon mode. To stop use Cntrl+C
        #cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\elasticsearch-service.bat" -d

        <#unfortunately kibana as a service is not available yet in v5
            cmd.exe /C "$env:SEARCH_HOME\elasticsearch-$ESVersion\bin\kibana.bat" install Kibana

            sc create "Kibana <version>" binPath= "{path to batch file}" depend= "elasticsearch-service-x64" 
            sc create "Kibana <version>" binPath= "{path to batch file}" depend= "elasticsearch-service-x64" 
            sc config "Kibana <version>" obj= LocalSystem password= "" 


        but we can simulate that service. run the following command in admin mode:
            cmd.exe /C sc create "ElasticSearch Kibana" binPath= "$env:SEARCH_HOME\kibana-$ESVersion-windows\bin\kibana.bat" depend= "Elastic-Search" 
            sc start "ElasticSearch Kibana"
        ignore messages that service is not accessible. it is already running, just check http://localhost:5601
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
    $fileName = split-path $Url.TrimEnd("?dl=1") -Leaf
    [IO.FileInfo]$archiveFileInfo = "$env:SEARCH_HOME\$fileName"
    if ((Test-Path $archiveFileInfo.FullName) -eq $false){
        Echo "Downloading archive  $Url ..."
        (New-Object Net.WebClient).DownloadFile($Url, $archiveFileInfo.FullName)
        Unblock-File -Path $archiveFileInfo.FullName
        if ($fileName -like "tesseract-*"){
            (new-object -com shell.application).namespace("$env:SEARCH_HOME\$($archiveFileInfo.BaseName)").CopyHere((new-object -com shell.application).namespace("$($archiveFileInfo.FullName)").Items(),16)
        }
        elseif ($fileName -like "*.zip"){
            (new-object -com shell.application).namespace($env:SEARCH_HOME).CopyHere((new-object -com shell.application).namespace("$($archiveFileInfo.FullName)").Items(),16)
        }
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