<#

Unit Tests:
    cd C:\Search\Scripts
    .\Search.Index.SQL.Events.ps1 -SQL_DbName... -indexName ...
#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    #[Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target server')]
    [string]$SQL_ServerName = ".\SQL2014",
    [string]$SQL_DbName = "",
    [string]$SQL_Query = "",
    [string]$typeName = "",
    [string]$keyFieldName = "",

    [string]$indexName = "",
    [string]$EventLogSource = "Search",
    [string]$LogFilePath = "$($env:LOG_DIR)\Search.Index.SQL.log"
)
Main

function Main(){
    Clear-Host
    if ($SQL_DbName -eq "" -or $SQL_Query -eq ""){
        Echo "Please specify SQL_DbName and SQL_Query parameter value"
        break;
    }
    
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
    <#
    #configure logging
    Import-Module -Name "$scripLocation\Log.Helper.psm1" -Force #-Verbose
    $global:EventLogSource = $EventLogSource
    $global:LogFilePath = $LogFilePath
    #Write-Event -Message "test"
    #Write-Event -Error "Error test"
    #>
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose


    SqlDependency.Start("Server=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=True"); #, queueName
    AddNotification();
    Thread.Sleep(new TimeSpan(6, 0, 0)); //stop current thread to listen events
    SqlDependency.Stop(cmd.ConnectionString); #, queueName

function AddNotification() {

    if (null != this.trackingDependency)
    {
        this.trackingDependency.OnChange -= null;
    } 

    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=True"
    $SqlConnection.Open()

    $sqlCmd = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmd.Connection = $SqlConnection
    $sqlCmd.CommandTimeout = 600
    $sqlCmd.CommandType = [System.Data.CommandType]::Text
    $sqlCmd.CommandText = $SQL_Query

    #Create a dependency and associate it with the SqlCommand.
    this.trackingDependency = new SqlDependency(command);
    #Maintain the refence in a class member.

    #Subscribe to the SqlDependency event.
    this.trackingDependency.OnChange += new OnChangeEventHandler(OnDependencyChange);

    #Execute the command.
    SqlDataReader $reader = $sqlCmd.ExecuteReader()
    #Process the DataReader

    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }
}

# Handler method
function OnDependencyChange(object sender, SqlNotificationEventArgs eventArgs) {
    if (eventArgs.Info == SqlNotificationInfo.Invalid) {
        Dts.Events.FireError(0, "(S) OnDependencyChange", "The above notification query is not valid.", string.Empty, 0);
    }
    else {
        bool fireAgain = true;
        #Dts.Events.FireInformation(0, "(S) OnDependencyChange", "Notification Info: " + eventArgs.Info, string.Empty, 0, ref fireAgain);
        #Dts.Events.FireInformation(0, "(S) OnDependencyChange", "Notification source: " + eventArgs.Source, string.Empty, 0, ref fireAgain);
        #Dts.Events.FireInformation(0, "(S) OnDependencyChange", "Notification type: " + eventArgs.Type, string.Empty, 0, ref fireAgain);
   
        #Create connection.
        using (SqlConnection trackingConnection = new SqlConnection("Server=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=True"))
        using (SqlCommand trackingCommand = new SqlCommand())
        {
            trackingCommand.Connection = trackingConnection;
            // Create command.
            //SqlCommand trackingCommand = new SqlCommand { Connection = trackingConnection };
            trackingCommand.CommandType = CommandType.Text;
            trackingCommand.CommandText = "print @@VERSION";
            trackingCommand.Notification = null;

            trackingConnection.Open();
            trackingCommand.ExecuteNonQuery();
            trackingConnection.Close();
        }

        AddNotification();
    }
}
