#
# Search-MailboxForMessageClass.ps1
#
# By David Barrett, Microsoft Ltd. 2013. Use at your own risk.  No warranties are given.
#
#  DISCLAIMER:
# THIS CODE IS SAMPLE CODE. THESE SAMPLES ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND.
# MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR
# A PARTICULAR PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLES REMAINS WITH YOU. IN NO EVENT SHALL
# MICROSOFT OR ITS SUPPLIERS BE LIABLE FOR ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS PROFITS,
# BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS) ARISING OUT OF THE USE OF OR INABILITY TO USE THE
# SAMPLES, EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES. BECAUSE SOME STATES DO NOT ALLOW THE EXCLUSION OR LIMITATION
# OF LIABILITY FOR CONSEQUENTIAL OR INCIDENTAL DAMAGES, THE ABOVE LIMITATION MAY NOT APPLY TO YOU.

param (
	[Parameter(Position=0,Mandatory=$True,HelpMessage="Specifies the mailbox to be used to obtain autodiscover information")]
	[ValidateNotNullOrEmpty()]
	[string]$Mailbox,
	
	[Parameter(Position=1,Mandatory=$True,HelpMessage="Specifies the message class of the items being searched")]
	[ValidateNotNullOrEmpty()]
	[string]$MessageClass,
	
	[Parameter(Position=2,Mandatory=$False,HelpMessage="Username used to authenticate with EWS")]
	[string]$AuthUsername,
	
	[Parameter(Position=3,Mandatory=$False,HelpMessage="Password used to authenticate with EWS")]
	[string]$AuthPassword,
	
	[Parameter(Position=4,Mandatory=$False,HelpMessage="Domain used to authenticate with EWS")]
	[string]$AuthDomain,
	
	[Parameter(Position=5,Mandatory=$False,HelpMessage="Whether we are using impersonation to access the mailbox")]
	[bool]$Impersonate = $True,
	
	[Parameter(Position=6,Mandatory=$False,HelpMessage="EWS Url (if omitted, then autodiscover is used)")]	
	[string]$EwsUrl,
	
	[Parameter(Position=7,Mandatory=$False,HelpMessage="Path to managed API (if omitted, a search of standard paths is performed)")]	
	[string]$EWSManagedApiPath = "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll",
	
	[Parameter(Position=8,Mandatory=$False,HelpMessage="Whether to ignore any SSL errors (e.g. invalid certificate)")]	
	[bool]$IgnoreSSLCertificate = $False,
	
	[Parameter(Position=9,Mandatory=$False,HelpMessage="Log file - activity is logged to this file if specified")]	
	[string]$LogFile = ""
)


# Define our functions

Function Log([string]$Details)
{
	Write-Host $Details -ForegroundColor White
	if ( $LogFile -eq "" ) { return	}
	$Details | Out-File $LogFile -Append
}

Function SearchPublicFolders()
{
	# Set EWS URL if specified, or use autodiscover if no URL specified.
	if ($EwsUrl)
	{
		$service.URL = New-Object Uri($EwsUrl)
	}
	else
	{
		Write-Host "Performing autodiscover for $Mailbox" -ForegroundColor Gray
		$service.AutodiscoverUrl($Mailbox)
		Write-Host "EWS Url found: ", $service.Url -ForegroundColor Gray
	}
	 
	# Set impersonation if specified
	if ($Impersonate)
	{
		Write-Host "Impersonating $Mailbox" -ForegroundColor Gray
		$service.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $Mailbox)
	}
	
	$FolderId = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::PublicFoldersRoot
	SearchFolder $FolderId
	Log ""
}

Function ProcessItem( $item )
{
	# We have found an item, so this function handles any processing
	# In this case, we are simply going to log a few details
	Log "Item created = ", $item.DateTimeCreated, " Item Subject =", $item.Subject
}

Function SearchFolder( $FolderId )
{
	# Bind to the folder and show which one we are processing
	$folder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$FolderId)
	Write-Host "Processing folder:" $folder.DisplayName -ForegroundColor Gray

	# Search the folder for any matching items
	$pageSize = 500 # We will get details for up to 500 items at a time
	$offset = 0
	$moreItems = $true
	
	# Perform the search and display the results
	while ($moreItems)
	{
		$searchFilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.ItemSchema]::ItemClass, $MessageClass)
		
		$view = New-Object Microsoft.Exchange.WebServices.Data.ItemView($pageSize, $offset, [Microsoft.Exchange.WebServices.Data.OffsetBasePoint]::Beginning)
		$view.PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::IdOnly, [Microsoft.Exchange.WebServices.Data.ItemSchema]::ItemClass, [Microsoft.Exchange.WebServices.Data.ItemSchema]::Subject, [Microsoft.Exchange.WebServices.Data.ItemSchema]::DateTimeCreated)
		$view.Traversal = [Microsoft.Exchange.WebServices.Data.ItemTraversal]::Shallow
		
		$results = $service.FindItems( $FolderId, $searchFilter, $view )
		
		ForEach ($item in $results.Items)
		{
			ProcessItem $item
		}
		
		$moreItems = $results.MoreAvailable
		$offset += $pageSize
	}
	
	# Now search subfolders
	$view = New-Object Microsoft.Exchange.WebServices.Data.FolderView(500)
	ForEach ($subFolder in $folder.FindFolders($view))
	{
		SearchFolder $subFolder.Id
	}
}


# The following is the main script


 
# Check EWS Managed API available
if ( !(Get-Item -Path $EWSManagedApiPath -ErrorAction SilentlyContinue) )
{
    $EWSManagedApiPath = "C:\Program Files\Microsoft\Exchange\Web Services\2.0\Microsoft.Exchange.WebServices.dll"
	if ( !(Get-Item -Path $EWSManagedApiPath -ErrorAction SilentlyContinue) )
	{
		$EWSManagedApiPath = "C:\Program Files\Microsoft\Exchange\Web Services\1.1\Microsoft.Exchange.WebServices.dll"
		if ( !(Get-Item -Path $EWSManagedApiPath -ErrorAction SilentlyContinue) )
		{
			throw "EWS Managed API could not be found at $($EWSManagedApiPath)."
		}
	}
}
Write-Host "Using managed API found at:" $EWSManagedApiPath -ForegroundColor Gray
 
# Load EWS Managed API
Add-Type -Path $EWSManagedApiPath
 
# Create Service Object.  We use Exchange 2007 schema.
$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2007_SP1)

# If we are ignoring any SSL errors, set up a callback
if ($IgnoreSSLCertificate)
{
	Write-Host "WARNING: Ignoring any SSL certificate errors" -ForegroundColor Yellow
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
}


# Set credentials if specified, or use logged on user.
 if ($AuthUsername -and $AuthPassword)
 {
	Write-Host "Applying given credentials for", $AuthUsername -ForegroundColor Gray
	if ($AuthDomain)
	{
		$service.Credentials = New-Object  Microsoft.Exchange.WebServices.Data.WebCredentials($AuthUsername,$AuthPassword,$AuthDomain)
	} else {
		$service.Credentials = New-Object  Microsoft.Exchange.WebServices.Data.WebCredentials($AuthUsername,$AuthPassword)
	}

} else {
	Write-Host "Using default credentials" -ForegroundColor Gray
    $service.UseDefaultCredentials = $true
 }

# Now search for items
Write-Host ""
SearchPublicFolders
