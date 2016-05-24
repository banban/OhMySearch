[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")]
#param test script
Param(
    [string]$srvSource, [string]$dbSource, [string]$procSource, 
    [string]$srvDest, [string]$dbDest, [string]$tblDest
)


function Main(){
    $cnSource = new-object System.Data.SqlClient.SqlConnection("Data Source=$($srvSource);Integrated Security=SSPI;Initial Catalog=$($dbSource)");
    $cnSource.Open()

    $cmdSource = New-Object System.Data.SqlClient.SqlCommand
    $cmdSource.CommandType = [System.Data.CommandType]::StoredProcedure;
    $cmdSource.CommandText = $procSource
    $cmdSource.Connection = $cnSource
    $cmdSource.CommandTimeout = 600;

    $dt = New-Object System.Data.Datatable "Results"
    $dt.Load($cmdSource.ExecuteReader());
    $cnSource.Close()

    $cnDest = new-object System.Data.SqlClient.SqlConnection("Data Source=$($srvDest);Integrated Security=SSPI;Initial Catalog=$($dbDest)");
    $cnDest.Open()

    $cmdDest = New-Object System.Data.SqlClient.SqlCommand
    $cmdDest.CommandType = [System.Data.CommandType]::Text;
    $cmdDest.CommandText = "TRUNCATE TABLE $($tblDest)"
    $cmdDest.Connection = $cnDest
    $cmdDest.CommandTimeout = 600;
    $cmdDest.ExecuteNonQuery()


    $bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cnDest
    $bc.DestinationTableName = $tblDest
    $bc.BulkCopyTimeout = 600;
    $bc.ColumnMappings.Add("table", "table");
    $bc.ColumnMappings.Add("field", "field");
    $bc.ColumnMappings.Add("id", "id");
    $bc.ColumnMappings.Add("value", "value");
    $bc.ColumnMappings.Add("updated", "updated");
    $bc.WriteToServer($dt)
    $cnDest.Close()
}

Clear-Host
Main
#prod
#powershell -ExecutionPolicy ByPass -command ".\Search.LoadLinkedData.ps1" -srvSource "SVRADLDB02" -dbSource "Integrations_NOVA" -procSource "search.RebuildCatalog" -srvDest "SVRSA1DB04" -dbDest "Nova_Search" -tblDest "intgr.Data"
#powershell -ExecutionPolicy ByPass -command ".\Search.LoadLinkedData.ps1" -srvSource "SVRADLDB02" -dbSource "Openair" -procSource "search.RebuildCatalog" -srvDest "SVRSA1DB04" -dbDest "Nova_Search" -tblDest "oa.Data"
#powershell -ExecutionPolicy ByPass -command ".\Search.LoadLinkedData.ps1" -srvSource "SVRSA1DB04" -dbSource "Nova_Datamart" -procSource "people.RebuildCatalog" -srvDest "SVRSA1DB04" -dbDest "Nova_Search" -tblDest "people.Data"

#dev
#cd C:\SVN\AB\Nova_Scripts\trunk\
#powershell -ExecutionPolicy ByPass -command ".\Search.LoadLinkedData.ps1" -srvSource "NB-HWLW3X1\SQL2014" -dbSource "Integrations_NOVA" -procSource "search.RebuildCatalog" -srvDest "NB-HWLW3X1\SQL2014" -dbDest "Nova_Search" -tblDest "intgr.Data"
#powershell -ExecutionPolicy ByPass -command ".\Search.LoadLinkedData.ps1" -srvSource "NB-HWLW3X1\SQL2014" -dbSource "Openair" -procSource "search.RebuildCatalog" -srvDest "NB-HWLW3X1\SQL2014" -dbDest "Nova_Search" -tblDest "oa.Data"
#powershell -ExecutionPolicy ByPass -command ".\Search.LoadLinkedData.ps1" -srvSource "NB-HWLW3X1\SQL2014" -dbSource "Nova_Datamart" -procSource "people.RebuildCatalog" -srvDest "NB-HWLW3X1\SQL2014" -dbDest "Nova_Search" -tblDest "people.Data"

