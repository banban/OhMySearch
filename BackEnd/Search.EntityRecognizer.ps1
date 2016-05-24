<#

#>
[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
#param test script
Param(
    [Parameter(Mandatory=$true, Position = 0, ValueFromRemainingArguments=$true , HelpMessage = 'Target root folders for search collection')]
    [String[]]
    $SharedFolders=@(),
    [Alias('Host')]
    #[ValidateSet('.\SQL2014','SVRSA1DB04')]
    [string]$SQL_ServerName = "SVRSA1DB04",
    [Alias('DBName')]
    [string]$SQL_SearchDbName = "Nova_Search",
    [string]$AzureMLURI = "https://ussouthcentral.services.azureml.net/workspaces/yourguid/services/yourguid/execute?api-version=2.0&details=true",
    [string]$apiKey = "your key"

)

function Main(){
    Clear-Host
    #if ($pscmdlet.ShouldProcess($SharedFolders)){
    #    Write-output "Going to fill the following folders $($SharedFolders)"
    #    break
    #    exit
    #}

    
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server=$SQL_ServerName;Database=$SQL_SearchDbName;Integrated Security=True;Application Name=Search.SharedFolderReader;MultipleActiveResultSets=True;"

    $sqlCmdGetFiles = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdGetFiles.Connection = $SqlConnection
    $sqlCmdGetFiles.CommandTimeout = 1200;
    $sqlCmdGetFiles.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdGetFiles.CommandText = "[dbo].[GetFilesForEntityRecognition]"
    $sqlCmdGetFiles.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdGetFiles.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FilePath",[Data.SQLDBType]::NVarChar, 512))) | Out-Null
    $sqlCmdGetFiles.Parameters.AddWithValue("@TopN", 1000) | Out-Null

    $sqlCmdAddFile = New-Object System.Data.SqlClient.SqlCommand
    $sqlCmdAddFile.Connection = $SqlConnection
    $sqlCmdAddFile.CommandType = [System.Data.CommandType]::StoredProcedure;
    $sqlCmdAddFile.CommandText = "[dbo].[AddFileEntity]"
    #$sqlCmdAddFile.CommandTimeout = 60;
    $sqlCmdAddFile.Parameters.AddWithValue("@SchemaName", "shared") | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@FileID",[Data.SQLDBType]::Int))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Type",[Data.SQLDBType]::VarChar, 3))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Mention",[Data.SQLDBType]::NVarChar, 256))) | Out-Null
    $sqlCmdAddFile.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@Count",[Data.SQLDBType]::Int))) | Out-Null

    if ($SqlConnection.State -ne 'Open')
    {
        $SqlConnection.Open()
    }
    foreach ($sharedFolder in $SharedFolders){
#$sharedFolder
        $sqlCmdGetFiles.Parameters["@FilePath"].Value = $sharedFolder
        $reader = $sqlCmdGetFiles.ExecuteReader()
        while ($reader.Read()) {
            [int]$fileID = [int]$reader["FileID"]
#$fileID
            if ($fileID -eq 0){
                break;
            }

            $fileContent = ([string]$reader["FileContent"])

            $sqlCmdAddFile.Parameters["@FileID"].Value = $fileID
            $sqlCmdAddFile.Parameters["@Type"].Value = [System.DBNull]::Value
            $sqlCmdAddFile.Parameters["@Mention"].Value = [System.DBNull]::Value
            $sqlCmdAddFile.Parameters["@Count"].Value = [System.DBNull]::Value 


            if ($fileContent -ne $null -and $fileContent -ne ""){
                $fileContent = $fileContent.Replace("'","").Replace("""","")
                [string]$request = '{
    "Inputs": {
        "input1": {
            "ColumnNames": [
                "Col1",
                "Col2"
            ],
            "Values": [
                [
                    "'+$fileID.ToString()+'",
                    "'+$fileContent+'"
                ]
            ]
        }
    },
    "GlobalParameters": {}
}'
#$fileContent
#$request
                [bool]$hasError = $false

                try{
                    $webRequest = Invoke-WebRequest -Method Post -Uri $AzureMLURI -Header @{ Authorization = "BEARER "+$apiKey} -ContentType "application/json" -Body $request # -TimeoutSec 180 -ErrorAction:Stop
                    #$webRequest = Invoke-RestMethod -Method Post -Uri $AzureMLURI -Header @{ Authorization = "BEARER "+$apiKey} -ContentType "application/json" -Body $request		
#Write-Host "response is ok"
                }
                catch{
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader2 = New-Object System.IO.StreamReader($result)
                    $responseBody = $reader2.ReadToEnd();
                    if ($responseBody -eq $null -or $responseBody -eq ""){
                        $responseBody = "Bad request"
                    }
Write-Host -BackgroundColor:Black -ForegroundColor:Yellow $responseBody

                    $sqlCmdAddFile.Parameters["@FileID"].Value = $fileID
                    $sqlCmdAddFile.Parameters["@Type"].Value = "ERR" 
                    $sqlCmdAddFile.Parameters["@Mention"].Value = [System.DBNull]::Value
                    $sqlCmdAddFile.Parameters["@Count"].Value = [System.DBNull]::Value 
                    $sqlCmdAddFile.ExecuteNonQuery() | Out-Null
#Write-Host "response is bad"
                   $hasError = $true
                }
                if ($hasError -eq $false){ #$webRequest.StatusCode -eq 200
                    $response = $webRequest.Content
                    #$response=$response -replace "\[\[","["
                    #$response=$response -replace "\]\]","]"
                    #Convert and parse response
                    $responseObject = ConvertFrom-Json $response
                    $results = New-Object System.Collections.Generic.List[System.Object]
		            for ($i=0;$i -lt $responseObject.Results.output1.value.Values.Count;$i++){
    		            $output = New-Object PSObject
		                for ($j=0;$j -lt $responseObject.Results.output1.value.ColumnNames.Count;$j++)
		                {
			                $a=$responseObject.Results.output1.value.ColumnNames[$j]
			                $b=$responseObject.Results.output1.value.ColumnTypes[$j]
			                $c=$responseObject.Results.output1.value.Values[$i][$j]
			                switch ($b) 
			                { 
				                "double"	{$output | add-member Noteproperty $a ([double]$c)}
				                "int"		{$output | add-member Noteproperty $a ([int]$c)}
				                "long"		{$output | add-member Noteproperty $a ([long]$c)}
				                "datetime"	{$output | add-member Noteproperty $a ([datetime]$c)}
				                "Boolean"	{$output | add-member Noteproperty $a ([boolean]$c)}
				                "Int16"		{$output | add-member Noteproperty $a ([int16]$c)}
				                "Int32"		{$output | add-member Noteproperty $a ([int32]$c)}
				                "Int64"		{$output | add-member Noteproperty $a ([int64]$c)}
				                "Single"	{$output | add-member Noteproperty $a ([single]$c)}
				                "Byte"		{$output | add-member Noteproperty $a ([byte]$c)}
				                "String"	{$output | add-member Noteproperty $a ([string]$c)}
				                default		{$output | add-member Noteproperty $a ($c)}
			                }
		                }
                        $results.Add($output)
                    }
                    $results | 
                        group-object -property Type, Mention -noelement | 
                            sort-object -property count –descending | % {
                            <#$t = New-Object psobject -Property @{
                                "Type" = $_.Name.Substring(0, $_.Name.IndexOf(', ')) 
                                 "Mention" = $_.Name.Substring($_.Name.IndexOf(', ')+1).Trim() 
                                 "Count" = $_.Count 
                            }#>

#$_.Name
#$_.Count
                            #split the name: "Type, Mention"
                            $sqlCmdAddFile.Parameters["@FileID"].Value = $fileID
                            $sqlCmdAddFile.Parameters["@Type"].Value = $_.Name.Substring(0, $_.Name.IndexOf(', '))  
                            $sqlCmdAddFile.Parameters["@Mention"].Value = $_.Name.Substring($_.Name.IndexOf(', ')+1).Trim()
                            $sqlCmdAddFile.Parameters["@Count"].Value = $_.Count 
                            $sqlCmdAddFile.ExecuteNonQuery() | Out-Null
                        }

                    #one more indicative record as indicator of end of entities for file
                    $sqlCmdAddFile.Parameters["@FileID"].Value = $fileID
                    $sqlCmdAddFile.Parameters["@Type"].Value = [System.DBNull]::Value
                    $sqlCmdAddFile.Parameters["@Mention"].Value = [System.DBNull]::Value
                    $sqlCmdAddFile.Parameters["@Count"].Value = [System.DBNull]::Value 
                    $sqlCmdAddFile.ExecuteNonQuery() | Out-Null
                }
            }
        }
        $reader.Close()
    }

    if ($SqlConnection.State -eq 'Open')
    {
        $SqlConnection.Close()
    }
}

Main
Echo Finish
