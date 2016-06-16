<#
1. Configure you environment variables
2. Run this scrip as administrator to set up environment variables permanently. Machine or User - up to you

   Another approach is to use session variables configuration: 
        $env:SEARCH_HOME = "C:\Search"
        $env:LOG_DIR = "C:\Logs"
        $env:ElasticUri = "http://localhost:9200"
        $env:SEARCH_HOME
        $env:MAGICK_HOME
        $env:MAGICK_TMPDIR

   But it is sutable just for debugging. Do not use it for persistent environment. It will be cleared next time when you open new PowerShell session.
   Use SetEnvironmentVariable which overrite session $env objects. 
   All scripts and apps read data from environment variables.
#>

function Test-IsAdmin { 
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 
} 
if (!(Test-IsAdmin)){ 
    throw "Please run this script with admin priviliges" 
}

#persistent for current user profile
[Environment]::SetEnvironmentVariable("ElasticUri", "http://localhost:9200", "User")
#when x-pack is installed use this credencials
#[Environment]::SetEnvironmentVariable("ElasticUser", "elastic", "User")
#[Environment]::SetEnvironmentVariable("ElasticPassword", "changeme", "User")

#3rd party apps
[Environment]::SetEnvironmentVariable("TESSERACT_HOME", "C:\Program Files (x86)\Tesseract-OCR", "User") 

[Environment]::SetEnvironmentVariable("MAGICK_HOME", "C:\Program Files\ImageMagick-7.0.1-Q16", "User")
[Environment]::SetEnvironmentVariable("MAGICK_TMPDIR", "C:\Temp\MAGICK_TMPDIR", "User") #use non system drive with enough free space

[Environment]::SetEnvironmentVariable("SEARCH_HOME", "C:\Search", "User")
[Environment]::SetEnvironmentVariable("LOG_DIR", "C:\Logs", "User")
[Environment]::SetEnvironmentVariable("GHOSTSCRIPT_HOME", "C:\Program Files\gs\gs9.18", "User")

#https://console.developers.google.com/apis/credentials
[Environment]::SetEnvironmentVariable("Google_MapApiKey", "<your value>", "User") 

#https://www.bingmapsportal.com/Application#
[Environment]::SetEnvironmentVariable("Bing_MapApiKey", "<your value>", "User")

#https://foursquare.com/developers/apps
[Environment]::SetEnvironmentVariable("Foursquare_ClientId", "<your value>", "User") 
[Environment]::SetEnvironmentVariable("Foursquare_ClientSecret", "<your value>", "User") 

#https://www.flickr.com/services/api/
[Environment]::SetEnvironmentVariable("Flickr_ApiKey", "<your value>", "User") 
[Environment]::SetEnvironmentVariable("Flickr_ApiSecret", "<your value>", "User")

#your Azure subscription settings
[Environment]::SetEnvironmentVariable("EntityRecognizerURI", "https://<your area>.services.azureml.net/workspaces/<your guid>/services/<your guid>/execute?api-version=2.0&details=true", "User")
[Environment]::SetEnvironmentVariable("EntityRecognizerApiKey", "<your value>", "User")

#read environment variables
Get-ChildItem Env: | ft
