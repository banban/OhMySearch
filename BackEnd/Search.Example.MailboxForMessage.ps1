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
	[Parameter(Position=0,Mandatory=$True,HelpMessage="Specifies the mailbox to be accessed")]
	[ValidateNotNullOrEmpty()]
	[string]$Mailbox,
	
	[Parameter(Position=1,Mandatory=$True,HelpMessage="Specifies the message class of the items being searched")]
	[ValidateNotNullOrEmpty()]
	[string]$MessageClass,
	
	[Parameter(Mandatory=$False,HelpMessage="If this switch is specified, items will be searched for in the archive mailbox (otherwise, the main mailbox is searched)")]
	[switch]$SearchArchive,

	[Parameter(Mandatory=$False,HelpMessage="If this switch is specified, items will be deleted")]
	[switch]$DeleteItems,
	
	[Parameter(Mandatory=$False,HelpMessage="Username used to authenticate with EWS")]
	[string]$AuthUsername,
	
	[Parameter(Mandatory=$False,HelpMessage="Password used to authenticate with EWS")]
	[string]$AuthPassword,
	
	[Parameter(Mandatory=$False,HelpMessage="Domain used to authenticate with EWS")]
	[string]$AuthDomain,
	
	[Parameter(Mandatory=$False,HelpMessage="Whether we are using impersonation to access the mailbox")]
	[switch]$Impersonate,
	
	[Parameter(Mandatory=$False,HelpMessage="EWS Url (if omitted, then autodiscover is used)")]	
	[string]$EwsUrl,
	
	[Parameter(Mandatory=$False,HelpMessage="Path to managed API (if omitted, a search of standard paths is performed)")]	
	[string]$EWSManagedApiPath = "C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll",
	
	[Parameter(Mandatory=$False,HelpMessage="Whether to ignore any SSL errors (e.g. invalid certificate)")]	
	[switch]$IgnoreSSLCertificate,
	
	[Parameter(Mandatory=$False,HelpMessage="Log file - activity is logged to this file if specified")]	
	[string]$LogFile = ""
	
	
)


# Define our functions

Function Log([string]$Details)
{
	Write-Host $Details -ForegroundColor White
	if ( $LogFile -eq "" ) { return	}
	$Details | Out-File $LogFile -Append
}

Function LoadEWSManagedAPI()
{
	# Find and load the managed API
	
	if ( ![string]::IsNullOrEmpty($EWSManagedApiPath) )
	{
		if ( { Test-Path $EWSManagedApiPath } )
		{
			Add-Type -Path $EWSManagedApiPath
			return $true
		}
		Write-Host ( [string]::Format("Managed API not found at specified location: {0}", $EWSManagedApiPath) ) -ForegroundColor Yellow
	}
	
	$a = Get-ChildItem -Recurse "C:\Program Files (x86)\Microsoft\Exchange\Web Services" -ErrorAction SilentlyContinue | Where-Object { ($_.PSIsContainer -eq $false) -and ( $_.Name -eq "Microsoft.Exchange.WebServices.dll" ) }
	if (!$a)
	{
		$a = Get-ChildItem -Recurse "C:\Program Files\Microsoft\Exchange\Web Services" -ErrorAction SilentlyContinue | Where-Object { ($_.PSIsContainer -eq $false) -and ( $_.Name -eq "Microsoft.Exchange.WebServices.dll" ) }
	}
	
	if ($a)	
	{
		# Load EWS Managed API
		Write-Host ([string]::Format("Using managed API {0} found at: {1}", $a.VersionInfo.FileVersion, $a.VersionInfo.FileName)) -ForegroundColor Gray
		Add-Type -Path $a.VersionInfo.FileName
		return $true
	}
	return $false
}

Function ProcessItem( $item )
{
	# We have found an item, so this function handles any processing
	# In this case, we are simply going to log a few details
	if ($DeleteItems)
	{
		Log([string]::Format("Deleting item (Subject = {0})", $item.Subject))
		$item.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::SoftDelete)
	}
	else
	{
		Log([string]::Format("{0}", $item.Subject, $item.DateTimeCreated))
	}
}

Function SearchMailbox()
{
	
	Log "Mailbox = $Mailbox"

	# Set EWS URL if specified, or use autodiscover if no URL specified.
    $rootFolder = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot
    if ($SearchArchive)
    {
        $rootFolder = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::ArchiveMsgFolderRoot
    }

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
		$FolderId = $rootFolder
	}
	else
	{
		# If we're not impersonating, we will specify the mailbox in case we are accessing a mailbox that is not the authenticating account's
		$mbx = New-Object Microsoft.Exchange.WebServices.Data.Mailbox( $Mailbox )
		$FolderId = New-Object Microsoft.Exchange.WebServices.Data.FolderId( $rootFolder, $mbx )
	}
	
	Set-Variable -Name FolderPath -Value "" -Scope script
	SearchFolder $FolderId
	Log ""
}

Function SearchFolder( $FolderId, $ParentPath )
{
	# Bind to the folder and show which one we are processing
	$folder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$FolderId)
    $folderPath = [string]::Format("{0}\{1}", $ParentPath, $folder.DisplayName)
	Log "Processing folder: $folderPath" 

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
		SearchFolder $subFolder.Id $folderPath
	}
}


Function TrustAllCerts() {
    <#
    .SYNOPSIS
    Set certificate trust policy to trust self-signed certificates (for test servers).
    #>

    ## Code From http://poshcode.org/624
    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") | Out-Null

    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy {
        public class TrustAll : System.Net.ICertificatePolicy {
            public TrustAll()
            { 
            }
            public bool CheckValidationResult(System.Net.ServicePoint sp,
                                                System.Security.Cryptography.X509Certificates.X509Certificate cert, 
                                                System.Net.WebRequest req, int problem)
            {
                return true;
            }
        }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll
}

# The following is the main script


# Check if we need to ignore any certificate errors
# This needs to be done *before* the managed API is loaded, otherwise it doesn't work consistently (i.e. usually doesn't!)
if ($IgnoreSSLCertificate)
{
	Write-Host "WARNING: Ignoring any SSL certificate errors" -foregroundColor Yellow
    TrustAllCerts
}

# Load EWS Managed API
if (!(LoadEWSManagedAPI))
{
	Write-Host "Failed to locate EWS Managed API, cannot continue" -ForegroundColor Red
	Exit
}
  
# Create Service Object - archives need a minimum of Exchange 2010 SP1
If ($SearchArchive)
{
    $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2010_SP1)
}
else
{
    $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2007_SP1)
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
 


Write-Host ""

# Check whether we have a CSV file as input...
$FileExists = Test-Path $Mailbox
If ( $FileExists )
{
	# We have a CSV to process
	$csv = Import-CSV $Mailbox
	foreach ($entry in $csv)
	{
		$Mailbox = $entry.PrimarySmtpAddress
		if ( [string]::IsNullOrEmpty($Mailbox) -eq $False )
		{
			SearchMailbox
		}
	}
}
Else
{
	# Process as single mailbox
	SearchMailbox
}