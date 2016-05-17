<#
    cd C:\Search\Scripts\

    &$delete "bms_v1"
#>

function Main(){
    cls
    #generate 10 jobs
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}
    #[int]$Total = 1000000 #647840
    #[int]$Take =  [int]($Total / 10)

    $jobMask = "IndexTable"
    $indexName = "austender"
    $NewIndex = $true
    $SQL_DbName = "Integration" 
    $typeName = "contract" 
    $keyFieldName = "Id"

    $processRowBlock = {
        #echo $args[0]
        cd "$($args[0])"
        #echo "$((Get-Location).Path)" -NewIndex $($args[2]) 
        .\Search.Index.SQL.ps1 -indexName "$($args[1])" -SQL_DbName "$($args[3])" -typeName "$($args[4])" -keyFieldName "$($args[5])" -SQL_Query "$($args[6])"
    }

    Stop-Job  -State Running | Where Name -like "$jobMask-*"
    Remove-Job *  | Where Name -like "$jobMask-*" 
    #$i=0
    #time frame based index
    $year = 2002
    $thisyear = (Get-Date).year

    #generate jobs
    do{
        $SQL_Query = "SELECT [Id],[Parent_CN_ID],[CN_ID],[Publish_Date],[Amendment_Date],[Status],[StartDate],[EndDate]
                ,[Value],[Description],[Agency_Ref_ID],[Category],[Procurement_Method],[ATM_ID],[SON_ID],[Confidentiality_Contract]
                ,[Confidentiality_Contract_Reasons],[Confidentiality_Outputs],[Confidentiality_Outputs_Rea=sons],[Consultancy],[Consultancy_Reasons],[Amendment_Reason]
                ,[Supplier_Name],[Supplier_Address],[Supplier_City],[Supplier_Postcode],[Supplier_Latitude],[Supplier_Longitude]
                ,[Supplier_Country],[Supplier_ABNExempt],[Supplier_ABN]
                ,[Agency],[Agency_Branch],[Agency_Divison],[Agency_Postcode],[Agency_State],[Agency_Latitude],[Agency_Longitude]
            FROM [dbo].[t_AusTenderContractNotice]
            WHERE YEAR([Publish_Date]) = $year
            ORDER BY [Id]
            " #--OFFSET $i ROWS FETCH NEXT $take ROWS ONLY

        #Invoke-Command {param($Debug=$False, $Clear=$False) "$scripLocation\Search.Index.SQL.ps1"} -ArgumentList @{"indexName"="$indexName"; "SQL_DbName"="$SQL_DbName"; "typeName"= "$typeName"; "keyFieldName"="$keyFieldName"; "SQL_Query"="$SQL_Query"} 
        #Invoke-Command -FilePath "$scripLocation\Search.Index.SQL.ps1" -ArgumentList @{"indexName"="$indexName"; "SQL_DbName"="$SQL_DbName"; "typeName"= "$typeName"; "keyFieldName"="$keyFieldName"; "SQL_Query"="$SQL_Query"} 
        Write-Host "Start new job $jobMask-$($year)"
        Start-Job -Name "$jobMask-$($year)" -scriptblock $processRowBlock -ArgumentList @($scripLocation, "$($indexName)_$year", $NewIndex, $SQL_DbName, $typeName, $keyFieldName, $SQL_Query) | Out-Null
        $year++
        #$i = $i+$take
    #}while($i -le $Total)
        &$post "_aliases" -obj @{
            actions = @( @{ add = @{ 
                alias = "$indexName"
                index = "$($indexName)_$year" 
            }})}
    }while($year -le $thisyear)

    #monitor jobs
    do {
        Start-Sleep 1
        #Write-Host "." -NoNewline #heart beat
        # Getting the information back from the jobs
        foreach($job in Get-Job -State Completed | Where Name -like "$jobMask-*" | Sort $_.Name){
            #Echo $job.Name
            Receive-Job -Job $job #-OutVariable files | Out-Null
            Remove-Job $job
        }
    } while (Get-Job -State Running | Where Name -like "$jobMask-*") 

    #remove failed jobs
    Remove-Job *  | Where Name -like "$jobMask-*" 
}

Main