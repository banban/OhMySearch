[string]$SQL_ServerName = ".\SQL2014"
[string]$SQL_DbName = "AdventureWorks"
[string]$TempFolder = "C:\Search\Import\PostCodes"

<#This function process data in the following manner: 
    - picks up unprocessed addresses from database; 
    - sends it to Google API without API key
        Users of the free API can send 2,500 requests per 24 hour period; 5 requests per second. https://developers.google.com/maps/documentation/timezone/#Limits
    - writes processed address in XML format back to database
#>
function FormatAddresses(){
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=True;MultipleActiveResultSets=True"
    $SqlConnection.Open()

    $sqlCmdGetAddresses = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdGetAddresses.Connection = $SqlConnection
    $sqlCmdGetAddresses.CommandTimeout = 600
    $sqlCmdGetAddresses.CommandType = [System.Data.CommandType]::StoredProcedure
    $sqlCmdGetAddresses.CommandText = "[dbo].[getUnformattedAddresses]"

    $sqlCmdAddAddress = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddAddress.Connection = $SqlConnection
    $sqlCmdAddAddress.CommandType = [System.Data.CommandType]::StoredProcedure
    $sqlCmdAddAddress.CommandText = "[dbo].[AddAddress]"
    $sqlCmdAddAddress.CommandTimeout = 600
    $sqlCmdAddAddress.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Unformatted",[Data.SQLDBType]::NVarChar, 255))) | Out-Null
    $sqlCmdAddAddress.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Content",[Data.SQLDBType]::NVarChar, -1))) | Out-Null

    $tempfile = $TempFolder.TrimEnd('\') + "\tmp.xml"
    $reader1 = $sqlCmdGetAddresses.ExecuteReader()
    while ($reader1.Read())
    {
        if($reader1["Unformatted"] -ne $null){
            $address = [string]$reader1["Unformatted"]
$address
            $url = "http://maps.googleapis.com/maps/api/geocode/json?address=${address}&sensor=true"
            $response = (Invoke-RestMethod $url)
            if ($response.status -eq "OK"){
                $response.results[0] | Export-Clixml -Path $tempfile -Force
                [string]$xml = ""
                Get-Content $tempfile | % {
                    $xml = $xml + $_.ToString().Trim()
                }
                $sqlCmdAddAddress.Parameters["@Unformatted"].Value = $address
                $sqlCmdAddAddress.Parameters["@Content"].Value = $xml
                $sqlCmdAddAddress.ExecuteNonQuery() | Out-Null
            }
        }
    }
    $reader1.Close()
    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }
}

<#This function brings timezone history for specific locations
It takes into account daylight savings.
Data is collected by day with except of day lightingh shift where data collected by hour

Users of the free API:2,500 requests per 24 hour period.5 requests per second.
    https://developers.google.com/maps/documentation/timezone/#Limits
 #>
function CollectTimezoneHistory(){
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=True;MultipleActiveResultSets=True"
    $SqlConnection.Open()

    $sqlCmdGetTimeOffsets = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdGetTimeOffsets.Connection = $SqlConnection
    $sqlCmdGetTimeOffsets.CommandTimeout = 100
    $sqlCmdGetTimeOffsets.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdGetTimeOffsets.CommandText = "[staging].[TimeZoneOffsets_GoogleToDM_001]"

    $sqlCmdAddTimeOffset = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddTimeOffset.Connection = $SqlConnection
    $sqlCmdAddTimeOffset.CommandType = [System.Data.CommandType]::Text
    $sqlCmdAddTimeOffset.CommandText = "INSERT INTO [dbo].[TimeZone_LocationHistory]([LocationId], [AsOfDate], [DstOffset], [RawOffset], [TimeZoneName])
SELECT @LocationId, DATEADD(SECOND, @TimeStamp, '19700101'), @DstOffset, @RawOffset, @TimeZoneName"
    $sqlCmdAddTimeOffset.CommandTimeout = 100
    $sqlCmdAddTimeOffset.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@LocationId",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddTimeOffset.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@TimeStamp",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddTimeOffset.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@DstOffset",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddTimeOffset.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@RawOffset",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddTimeOffset.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@TimeZoneName",[Data.SQLDBType]::NVarChar, 128))) | Out-Null

    $reader1 = $sqlCmdGetTimeOffsets.ExecuteReader()
    while ($reader1.Read())
    {
        $url = "https://maps.googleapis.com/maps/api/timezone/json?location="+[string]$reader1["Latitude"]+","+[string]$reader1["Longitude"]+"&timestamp="+[string]$reader1["TimeStamp"]
        $response = (Invoke-RestMethod $url -Method Get)
$response.status
        if ($response.status -eq "OK"){
#Write-Output $response | Format-Table -property timeZoneId, timeZoneName, dstOffset, rawOffset
            [int]$offset = $response.rawOffset*(-1)
            $sqlCmdAddTimeOffset.Parameters["@LocationId"].Value = [int]$reader1["LocationId"]
            $sqlCmdAddTimeOffset.Parameters["@TimeStamp"].Value = [int]$reader1["TimeStamp"]
            $sqlCmdAddTimeOffset.Parameters["@DstOffset"].Value = [int]$response.dstOffset
            $sqlCmdAddTimeOffset.Parameters["@RawOffset"].Value = [int]$response.rawOffset
            $sqlCmdAddTimeOffset.Parameters["@TimeZoneName"].Value = [string]$response.timeZoneName
            $sqlCmdAddTimeOffset.ExecuteNonQuery() | Out-Null
        }
    }
    $reader1.Close()

    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }
}

<#
country code      : iso country code, 2 characters
postal code       : varchar(20)
place name        : varchar(180)
admin name1       : 1. order subdivision (state) varchar(100)
admin code1       : 1. order subdivision (state) varchar(20)
admin name2       : 2. order subdivision (county/province) varchar(100)
admin code2       : 2. order subdivision (county/province) varchar(20)
admin name3       : 3. order subdivision (community) varchar(100)
admin code3       : 3. order subdivision (community) varchar(20)
latitude          : estimated latitude (wgs84)
longitude         : estimated longitude (wgs84)
accuracy          : accuracy of lat/lng from 1=estimated to 6=centroid
Usage:
    Main -CountryCode 'AU' -TruncateTable $true
    Main -CountryCode 'GB' -TruncateTable $false
    Main -CountryCode 'NO' -TruncateTable $false
    Main -CountryCode 'NZ' -TruncateTable $false
    #Main -CountryCode 'SG' -TruncateTable $false# SG has nopostal codes :)
#>
function CollectPostCodes{
    Param(
        [string]$CountryCode,
        [bool]$TruncateTable = $false
    )
    #download and extract from archive
    [string]$url = "http://download.geonames.org/export/zip/$CountryCode.zip"
    Write-Output "Downloading archive  $url ..."
    (New-Object Net.WebClient).DownloadFile($url,"$TempFolder\$CountryCode.zip");
    (new-object -com shell.application).namespace($TempFolder).CopyHere((new-object -com shell.application).namespace("$TempFolder\$CountryCode.zip").Items(),16)
    Remove-Item "$TempFolder\$CountryCode.zip" -Confirm:$false

    $headers = "CountryCode	PostCode	PlaceName	AdminName1	AdminCode1	AdminName2	AdminCode2	AdminName3	AdminCode3	Latitude	Longitude	Accuracy"
    $columns = $headers.Split('	')
    #$ImportFile = "$TempFolder$CountryCode_2.txt"
    #$headers | Out-File -FilePath $ImportFile
    #$content = Get-Content "$TempFolder\$CountryCode.txt"
    #Add-Content $ImportFile $content
    $content = Import-Csv "$TempFolder\$CountryCode.txt" -Delimiter '	' -Header $columns

    if ($content.Count -lt 100) {return} #avoid incomplete source data

    $dt1 = new-object system.data.datatable
    $cn = new-object System.Data.SqlClient.SqlConnection("Data Source=$SQL_ServerName;Database=$SQL_DbName;Integrated Security=SSPI;");
    $cn.Open()
    $bulkCopy = New-Object Data.SqlClient.SqlBulkCopy($cn)
    $bulkCopy.DestinationTableName = "[staging].[t_Postcodes]"
    $bulkCopy.BatchSize = 1000

    $columns | %{
        $type = [string]
        if ("$_" -in ("Latitude","Longitude")){ $type = [decimal] }
        elseif("$_" -in ("Accuracy")){ $type = [single] }

        $col = New-Object system.Data.DataColumn "$_", $type
        [Void]$dt1.Columns.Add($col)

        [Void]$bulkCopy.ColumnMappings.Add("$_", "$_")
    }

    for($i=1; $i -le $content.Length; $i++){
        $Row = $dt1.NewRow()
        $Row["CountryCode"] =  $content[$i].CountryCode
        $Row["PostCode"] =  $content[$i].PostCode
        $Row["PlaceName"] =  $content[$i].PlaceName
        $Row["AdminName1"] =  $content[$i].AdminName1
        $Row["AdminName2"] =  $content[$i].AdminName2
        $Row["AdminName3"] =  $content[$i].AdminName3
        $Row["Latitude"] =  [decimal]$content[$i].Latitude
        $Row["Longitude"] =  [decimal]$content[$i].Longitude
        $Row["Accuracy"] =  [single]$content[$i].Accuracy
        $dt1.Rows.Add($Row)  | Out-Null
    }
    
    if ($TruncateTable -eq $true){
        $sqlDocTypes = New-Object System.Data.SqlClient.SqlCommand
        $sqlDocTypes.Connection = $cn
        $sqlDocTypes.CommandType = [System.Data.CommandType]::Text;
        $sqlDocTypes.CommandText = "truncate table staging.t_Postcodes"
        $sqlDocTypes.ExecuteNonQuery() | Out-Null
    }

    Write-Output "Loading $CountryCode $($dt1.Rows.Count) rows ..."
    $bulkCopy.WriteToServer($dt1)

    $cn.Close()
}

Export-ModuleMember -Variable * #-function * 
