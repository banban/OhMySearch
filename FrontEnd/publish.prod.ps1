<#
    This script demonstrates how to deploy the solution to production environment
#>
$source = "C:\GitHub\banban\OhMySearch\FrontEnd\Search.Core.Windows"
cd $source
$remoteServer = "localhost"
$remoteAppPool = "Apps.Core"
$destination = "\\$remoteServer\c$\inetpub\Apps\Search"
#stop remote application pool
Invoke-Command -ComputerName "$remoteServer" -ScriptBlock { Stop-WebAppPool -Name $args[0] } -ArgumentList($remoteAppPool)

#npm install -g bower
#npm install -g gulp #if exception dotnet : No executable found matching command "gulp"
#dotnet build -c release
dotnet publish -c release -o $destination
#msbuild SlnFolders.sln /t:NotInSolutionfolder:Rebuild;NewFolder\InSolutionFolder:Clean

#merge settings from staging file to default one 
$settings = Get-Content "$destination\appsettings.json" -Raw | ConvertFrom-Json 
$settings_prod = Get-Content "$source\appsettings.Production.json" -Raw | ConvertFrom-Json 
$settings.AppSettings = $settings_prod.AppSettings
$settings.Data = $settings_prod.Data
$settings | ConvertTo-Json -Depth 10 | Out-File "$destination\appsettings.json" -Force

#remove irrelevent app settings files
try{Remove-Item "$destination\appsettings.Test.json"} catch{}
try{Remove-Item "$destination\appsettings.Staging.json"} catch{}
try{Remove-Item "$destination\appsettings.Production.json"} catch{}

#start remote application pool
Invoke-Command -ComputerName "$remoteServer" -ScriptBlock { Start-WebAppPool -Name $args[0] } -ArgumentList($remoteAppPool)
