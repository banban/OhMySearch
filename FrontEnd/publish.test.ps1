<#
    This script demonstrates how to deploy the solution to, let's say, test environment
#>
cd C:\GitHub\banban\OhMySearch\FrontEnd\Search.Core.Windows
$remoteServer = "MyServerName"
$remoteAppPool = "MyAppPoolName"
$destination = "\\$remoteServer\c$\inetpub\Search"
#stop remote application pool
Invoke-Command -ComputerName "$remoteServer" -ScriptBlock { Stop-WebAppPool -Name $args[0] } -ArgumentList($remoteAppPool)

#npm install -g bower #if bower is not installed yet 
#npm install -g gulp #if gulp is not installed yet: exception dotnet : No executable found matching command "gulp"
#dotnet build -c release #no need to run it before publish
dotnet publish -c release -o $destination

#merge settings from staging file to default one 
$settings = Get-Content "$destination\appsettings.json" -Raw | ConvertFrom-Json 
$settings_prod = Get-Content "$destination\appsettings.Test.json" -Raw | ConvertFrom-Json 
$settings.AppSettings = $settings_prod.AppSettings
$settings.Data = $settings_prod.Data
$settings | ConvertTo-Json -Depth 10 | Out-File "$destination\appsettings.json" -Force

#remove irrelevent app settings files
try{Remove-Item "$destination\appsettings.Test.json"} catch{}
try{Remove-Item "$destination\appsettings.Staging.json"} catch{}
try{Remove-Item "$destination\appsettings.Production.json"} catch{}

#start remote application pool
Invoke-Command -ComputerName "$remoteServer" -ScriptBlock { Start-WebAppPool -Name $args[0] } -ArgumentList($remoteAppPool)
