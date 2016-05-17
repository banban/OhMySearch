<#
Unit tests:
    cd C:\Search\Scripts
    &$delete "austender_web_v1"

    .\Search.Index.Web.ps1 -WebSite "https://www.tenders.gov.au/"-RootPath "C:\Import\AusTender" -Delimeter "	" -indexName "web_v1" -aliasName "web" -typeName "austender" -NewIndex
#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [string]$WebSite ,
    [string]$RootPath,
    [string]$Delimeter,

    [string]$indexName,
    [string]$aliasName,
    [string]$typeName,
    [int]$MaxFileBiteSize = 1000000,  #~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.

    #[parameter(parametersetname="indexSwitches")]
    [switch]$NewIndex
)

function Main(){
    Clear-Host

    [System.Net.ServicePointManager]::CheckCertificateRevocationList = $false;
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true; };

    Add-Type @"
  using System.Net;
  using System.Security.Cryptography.X509Certificates;
  public class TrustAllCertsPolicy : ICertificatePolicy {
     public bool CheckValidationResult(
      ServicePoint srvPoint, X509Certificate certificate,
      WebRequest request, int certificateProblem) {
      return true;
    }
  }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

    $uri = "$($WebSite)?event=public.reports.listCNWeeklyExport"
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} #ignore test ssl certificate warning
    try{
        $HTML = Invoke-WebRequest -Uri "$uri" -Method Get -ContentType "text/html;charset=UTF-8" -UseDefaultCredentials

        #load new files
        foreach($link in $HTML.Links){
            if ($link.href.StartsWith("?event=public.reports.downloadCNWeeklyExport&amp;CNWeeklyExportUUID=")){
                $filePath = $fileDir.Trim('\') + "\"+ $link.innerText + ".csv"
                if (!(Test-Path $filePath)){
                    $uri = $WebSite + $link.href.Replace("&amp;","&")
                    Write-Output "Downloading file  $uri ..."
            
                    (New-Object Net.WebClient).DownloadFile($uri,$filePath);
                }
            }
        }
    }
    catch{}


    #index all files
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}

    #index helper functions
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose
    #&$get
    #&$call "Get" "/_cluster/state"

    if ($NewIndex.IsPresent){
        try{
            &$delete $indexName 
        }
        catch{}


        <#Some types of analysis are extremely unfriendly with regards to memory.
        There is a reason to avoid aggregating analyzed fields: high-cardinality fields consume a large amount of memory when loaded into fielddata. 
        The analysis process often (although not always) generates a large number of tokens, many of which are unique. 
        This increases the overall cardinality of the field and contributes to more memory pressure.
         use index = "not_analyzed" for strings where possible#>
        &$createIndex "$indexName" -obj @{
            settings = @{
                analysis = @{
                  char_filter = @{ 
                    quotes = @{
                      type = "mapping"
                      mappings = @( "\\u0091=>\\u0027", "\\u0092=>\\u0027", "\\u2018=>\\u0027","\\u2019=>\\u0027","\\u201B=>\\u0027" )
                    }
                  }
                  analyzer = @{
                    quotes_analyzer= @{
                      tokenizer = "standard"
                      char_filter = @( "quotes" )
                    }
                  }#analyzer
                } #analysis
            } #| ConvertTo-Json -Depth 4

            mappings = @{
                "$typeName" = @{
                     dynamic = $true #will additional fields dynamically.
                     date_detection = $false #avoid “malformed date” exception
                }
            }
        }
    }
    [string]$BulkBody = ""
    Get-ChildItem $RootPath -Filter "*.csv" -File -Force -ErrorAction SilentlyContinue |
        Where-Object {$_ -is [IO.FileInfo]} |
        % {
            $file = Get-Content $_.FullName
            $recordType = $file[0].Trim()
            $headers = $file[2] -split $Delimeter
            for($i=3; $i -lt $file.count;$i++)
            {
	            $values = $file[$i] -split $Delimeter
                #generate json record
                $entryObj = New-Object PSObject
                #$entryObj | add-member Noteproperty "RecordType" $recordType
                for($j=0; $j -lt $values.count;$j++)
                {
                    if ($headers[$j] -ne $null -and $headers[$j] -ne ""){
                        $name = $headers[$j]
                        $value = ""
                        if ($values[$j] -ne $null){
                            $value = $($values[$j].TrimStart('=""').TrimStart('=').Trim('"').Trim())
                            $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                            $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                            $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                            $value = $value -replace '\s+', ' ' #remove extra spaces
                        }

                        $entryObj | Add-Member Noteproperty $name $value
                    }
                }
                $entry = '{"index": {"_type": "'+$typeName+'"}'+ "`n" +($entryObj | ConvertTo-Json -Compress| Out-String)  + "`n"
        #$entry
                $BulkBody += $entry
                $percent = [decimal]::round(($BulkBody.Length / $MaxFileBiteSize)*100)
                if ($percent -gt 100) {$percent = 100}
                Write-Progress -Activity "Batching in progress: $($_.Name) $($BulkBody.Length)" -status "$percent% complete" -percentcomplete $percent;
                if ($BulkBody.Length -ge $MaxFileBiteSize){
                    $result = &$post "$indexName/_bulk" $BulkBody
#validate $result here for errors
                    $BulkBody = ""
                }
            }
        }

    if ($BulkBody -ne ""){
        $result = &$post "$indexName/_bulk" $BulkBody
        $BulkBody = ""
    }
}

Main