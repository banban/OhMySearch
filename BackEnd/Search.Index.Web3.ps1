<#
This script allows to index SharePoint document libraries
Unit tests:
    cd C:\Search\Scripts
    
Test 1. Process document:
    .\Search.Index.Web3.ps1 -rootPath "https://intranet/bms/wiki/Forms/AllPages.aspx" -mask "acrftreg.csv" -delimeter "," -keyFieldName "Serial" -indexName "aircraft_v1" -aliasName "aircraft" -typeName "casa" -newIndex

 2 records rejected

 test API:
    $global:Debug = $true
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force -Verbose
    &$cat
    &$get "aircraft_v1/_mapping"
    &$get "aircraft_v1/casa"
    &$get "aircraft_v1/casa/_query?q=*"
    &$get "aircraft_v1"
    &$get "aircraft_v1/casa/AVUQ7SGd4sw0coEpumpQ"

    &$post "aircraft_v1/casa/_search" -obj @{
        size = 0
        aggs = @{
            Agencies = @{
                terms = @{
                    field = "Agency"
                }
            }
        }
    }

    &$delete "aircraft_v1" 

#>

[CmdletBinding(PositionalBinding=$false, DefaultParameterSetName = "SearchSet")] #SupportShouldProcess=$true, 
Param(
    [string]$url ,
    [string]$rootPath,
    [string]$delimeter,
    [string]$keyFieldName,
    [string]$indexName,
    [string]$aliasName,
    [string]$typeName,
    [string]$mask,
    [Parameter(HelpMessage = 'Represents manual mapping - most accurate approach')]
    [string]$typeMapping,

    #[Parameter(HelpMessage = '~1 Mb. A good place to start is with batches of 1,000 to 5,000 documents or, if your documents are very large, with even smaller batches.')]
    [int]$batchMaxSize = 1000000,
    [int]$rowMinLength = 25,
    #[parameter(parametersetname="indexSwitches")]
    [switch]$newIndex
)

function Main(){
    Clear-Host

    if ($url -ne $null -and $url -ne ""){
        #ignore test ssl certificate warning, do not use for external resources
        #[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} 

        $fileName = split-path $url -Leaf
        [IO.FileInfo]$archiveFileInfo = "$rootPath\$fileName"
        Echo "Downloading archive  $url ..."

        if ((Test-Path $archiveFileInfo.FullName) -eq $true){
            Remove-Item $archiveFileInfo.FullName -Confirm:$false
        }
        (New-Object Net.WebClient).DownloadFile($url,$archiveFileInfo.FullName);
        Unblock-File -Path $archiveFileInfo.FullName
        #extract from archive
        (new-object -com shell.application).namespace($rootPath).CopyHere((new-object -com shell.application).namespace("$($archiveFileInfo.FullName)").Items(),16)
    }

    [bool]$firstRecord = $true
    #index all files
    [string]$scripLocation = (Get-Variable MyInvocation).Value.PSScriptRoot
    if ($scripLocation -eq ""){$scripLocation = (Get-Location).Path}

    #index helper functions
    Import-Module -Name "$scripLocation\ElasticSearch.Helper.psm1" -Force #-Verbose
    #&$call "Get" "/_cluster/state"
    [int]$rowcount = 0
    [string]$BulkBody = ""
    $headers = @{} #cached mapping between original and clean names
    $fieldTypeMapping = @{} #cached mapping between field name and data type
    
    if ($typeMapping -ne $null -and $typeMapping -ne ""){
        $meatadata = ConvertFrom-Json $typeMapping
    }
    else{
        #read existing index mapping metadata
        try{
            #$indexName = "aircraft_v1"; $typeName = "casa"; 
            $meatadata = ConvertFrom-Json (&$get "$indexName/_mapping")
        }
        catch{}
    }
    $mappingProperties = New-Object PSObject
    if ($meatadata -ne $null){
        $index_mt = $meatadata.psobject.properties | Where {$_.Name -eq "$indexName"} 
        if ($index_mt -ne $null){
            $type_mt = $index_mt.Value.mappings.psobject.properties | Where {$_.Name -eq "$typeName"}
            if ($type_mt -ne $null){
                $mappingProperties = $type_mt.Value.properties
                $mappingProperties.psobject.properties | %{
                    $fieldTypeMapping.Set_Item($_.Name, $_.Value.type)
                }
            }
        }
    }

    Get-ChildItem $rootPath -Filter "$mask" -File -Force -ErrorAction SilentlyContinue |
        Where-Object {$_ -is [IO.FileInfo]} |
        % {
            $filePath = $_.FullName.ToLower()

            ##remove empty and useless short rows
            #(Get-Content $filePath | Select-Object | Where-Object {$_.Length -gt $rowMinLength}) | Set-Content $filePath -Force

            #load file content
            $content = Import-Csv -LiteralPath $filePath -Delimiter $delimeter

            if ($firstRecord -eq $true -and $content.Count -gt 0){
                if ($newIndex.IsPresent){
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
                    }
                }

                if ($newIndex.IsPresent -or $newType.IsPresent){
                    $fields = $content | Get-Member -MemberType NoteProperty -force | %{$_.Name}

                    #clean field names
                    for($i=0; $i -lt $fields.Count;$i++){
                        $name = $fields[$i].TrimStart('=').Trim('"').Trim()
                        $name = $name -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                        $name = $name -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                        $name = $name -replace '[\-\,\.\\/''~?!*“"%&•â€¢©ø\[\]{}\(\)]', ' ' #special symbols and punctuation
                        $name = $name.Trim() -replace '\s+', '_' #remove extra spaces and raplace with _
                        $headers.Set_Item("$($fields[$i])", "$name")
                    }

                    #let's try to guess missed data type based on first 1 (or more, some fields in 1st row might be empty!) record(s)
                    $content[0].psobject.properties | % {
                        $name = $headers.Get_Item($_.Name)
                        if ($_.Value -ne $null -and $_.Value -ne "" -and $fieldTypeMapping.Get_Item($name) -eq $null){
                            $value = $_.Value
                            $value = $($value.TrimStart('=').Trim('"').Trim())
                            $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                            $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                            $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                            $value = $value -replace '\s+', ' ' #remove extra spaces
                            if (($value -as [DateTime]) -ne $null){ #check value is a date
                                $fieldTypeMapping.Set_Item("$name", "date")
                            }
                            else{
                                $fieldTypeMapping.Set_Item("$name", "text")
                                # if you do not need to aggregate by this field - do not set doc_values = true
                                $fieldTypeMapping.Set_Item("$doc_values", $true) 
                            }
                        }
                    }

                    $fieldTypeMapping.GetEnumerator() | %{
                        [bool]$isNewProp = $false
                        try{
                            if ($mappingProperties.psobject.properties.Item($_.Key) -eq $null){
                                $isNewProp = $true
                            }
                        }
                        catch{
                            $isNewProp = $true
                        }

                        if ($isNewProp){ #add new field mapping
                            if ($_.Value -eq "text"){
                                $mappingProperties | Add-Member Noteproperty $_.Key @{
                                    type = "$($_.Value)"
                                    fielddata = $true
                                }
                            }
                            else{
                                $mappingProperties | Add-Member Noteproperty $_.Key @{
                                    type = "$($_.Value)"
                                }
                            }
                        }
                    }

                    &$put "$($indexName)/_mapping/$($typeName)?update_all_types" -obj @{
                        dynamic = $true #will create new fields dynamically.
                        date_detection = $true #avoid “malformed date” exception
                        properties = $mappingProperties
                    }
                }

                if ($aliasName -ne ""){
                    &$put "$indexName/_alias/$aliasName"
                }

                $firstRecord = $false
            }

            #mutate data
            for($i=0; $i -lt $content.count;$i++){
                $entryProperties = @{}
                $id = ""
                $content[$i].psobject.properties | % {
                    $name = $headers.Get_Item($_.Name)
                    if ($_.Value -eq $null -or $_.Value -eq ""){
                        $value = $null
                    }

                    if ($fieldTypeMapping.Get_Item($name) -ne $null){
                        $type = $fieldTypeMapping.Get_Item($name)
                    }
                    else{
                        $type = "keyword"
                    }

                    if ($type -in "string","text","keyword"){
                        $value = $_.Value
                        if ($value -ne $null){
                            $value = $($value.TrimStart('=').Trim('"').Trim())
                            $value = $value  -replace '\\u0027|\\u0091|\\u0092|\\u2018|\\u2019|\\u201B', '''' #convert quotes
                            $value = $value -replace '\\u\d{3}[0-9a-zA-Z]', '?' # remove encodded special symbols like '\u0026' '\u003c'
                            $value = $value -replace '[\\/''~?!*“"%&•â€¢©ø\[\]{}]', ' ' #special symbols and punctuation
                            $value = $value -replace '\s+', ' ' #remove extra spaces
                        }
                        else{
                            $value = ""
                        }
                    }
                    elseif ($type -eq "date"){ # reformat date
                        try{
                            if (($_.Value -as [DateTime]) -ne $null){ #check value is a date
                                $value =  Get-Date -Date $_.Value -Format "yyyy-MM-dd"
                            }
                        }
                        catch{
                            Write-Host "can't convert date value in row $i"  -f Red 
                        }
                    }
                    elseif ($type -in "short","integer","long", "double", "decimal", "float", "number"){
                        $value = 0
                        if ($type -in "double", "number"){
                            try{
                                if (($_.Value -as [double]) -ne $null){
                                    $value =  [double]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "float"){
                            try{
                                if (($_.Value -as [float]) -ne $null){
                                    $value =  [float]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "decimal"){
                            try{
                                if (($_.Value -as [decimal]) -ne $null){
                                    $value =  [decimal]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "long"){
                            try{
                                if (($_.Value -as [long]) -ne $null){
                                    $value =  [long]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "integer"){
                            try{
                                if (($_.Value -as [integer]) -ne $null){
                                    $value =  [integer]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                        elseif ($type -eq "short"){
                            try{
                                if (($_.Value -as [short]) -ne $null){
                                    $value =  [short]$_.Value
                                }
                            }
                            catch{
                                $value = 0
                            }
                        }
                    }
                    if ($value -ne $null){ 
                        if ($name -eq $keyFieldName){ 
                            $id = ", ""_id"": ""$value""" 
                        }
                        else{
                           $entryProperties += @{"$name" = $value}
                        }
                    }
                }

                $entry = '{"index": {"_type": "'+$typeName+'"'+$id+'}'+ "`n" +($entryProperties | ConvertTo-Json -Compress| Out-String)  + "`n"
                $rowcount++
#$entry
                $BulkBody += $entry
                $percent = [decimal]::round(($BulkBody.Length / $batchMaxSize)*100)
                if ($percent -gt 100) {$percent = 100}
                Write-Progress -Activity "Batching in progress: $($_.Name) $rowcount rows" -status "$percent% complete" -percentcomplete $percent;
                if ($BulkBody.Length -ge $batchMaxSize){
                    $result = &$post "$indexName/_bulk" $BulkBody

                    #validate bulk errors
                    $resultObj = ConvertFrom-Json $result 
                    $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
                    if ($errors -ne $null -and $errors.Count -gt 0){
                        $errors | %{ Write-Host "path: $($filePath); _type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
                    }

                    $BulkBody = ""
                }
            }
        }

    if ($BulkBody -ne ""){
        $result = &$post "$indexName/_bulk" $BulkBody
        $errors = (ConvertFrom-Json $result).items| Where-Object {$_.index.error}
        if ($errors -ne $null -and $errors.Count -gt 0){
            $errors | %{ Write-Host "_type: $($_.index._type); _id: $($_.index._id); error: $($_.index.error.type); reason: $($_.index.error.reason); status: $($_.index.status)" -f Red }
        }

        $BulkBody = ""
    }
}

Main

<#

            DirectoryInfo di = new DirectoryInfo(folderPath);
            string resultFilePath = di.FullName + "\\"+fileName.Replace(".pdf",".csv");
            if (File.Exists(resultFilePath))
            {
                File.Delete(resultFilePath);
            }
            using (StreamWriter fs = File.CreateText(resultFilePath))
            {
                fs.WriteLine("REG|MAKE|MODEL|SERIES|MSN|OWNER_NAME|OWNER_ADDRESS");
                fs.Close();
            }

            string filePath = di.FullName + "\\" + fileName;
            if (File.Exists(filePath))
            {
                StringBuilder text = new StringBuilder();
                using (PdfReader pdfReader = new PdfReader(filePath))
                {
                    for (int page = 1; page <= pdfReader.NumberOfPages; page++)
                    {
                        ITextExtractionStrategy strategy = new SimpleTextExtractionStrategy();
                        string currentText = PdfTextExtractor.GetTextFromPage(pdfReader, page, strategy);
                        currentText = Encoding.UTF8.GetString(ASCIIEncoding.Convert(Encoding.Default, Encoding.UTF8, Encoding.Default.GetBytes(currentText)));
                        text.Append(currentText);
                    }
                    pdfReader.Close();
                }
                //string fileContent = text.ToString();
                string[] lines = text.ToString().Split(new string[] { "\r\n", "\n" }, StringSplitOptions.None);
                using (StreamWriter fs = File.AppendText(resultFilePath))
                {
                    string fullLine = string.Empty;
                    for (int i = 4; i < lines.Length; i++)
                    {
                        if (!lines[i].Contains("REG MAKE MODEL SERIES MSN OWNER_NAME OWNER_ADDRESS"))
                        {
                            if (lines[i].StartsWith("P2-"))
                            {
                                if (!string.IsNullOrEmpty(fullLine))
                                {
                                    fs.WriteLine(GetFormattedFieldsValues(fullLine));
                                }
                                fullLine = lines[i];
                            }
                            else
                            {
                                fullLine += " "+ lines[i];
                            }
                        }
                    }
                    if (!string.IsNullOrEmpty(fullLine))
                    {
                        fs.WriteLine(GetFormattedFieldsValues(fullLine));
                    }
                    fs.Close();
                }

                DataTable csvData = new DataTable();
                try
                {
                    using (TextFieldParser csvReader = new TextFieldParser(resultFilePath))
                    {
                        csvReader.SetDelimiters(new string[] { "|" });
                        csvReader.HasFieldsEnclosedInQuotes = true;
                        string columnNames = string.Empty;
                        string[] colFields = csvReader.ReadFields();
                        foreach (string csvColumnName in colFields)
                        {
                            DataColumn csvColumn = new DataColumn(csvColumnName);
                            csvColumn.AllowDBNull = true;
                            csvData.Columns.Add(csvColumn);
                            columnNames += csvColumn.ColumnName + ",";
                        }
                        while (!csvReader.EndOfData)
                        {
                            string[] fieldData = csvReader.ReadFields();
                            //copy array values to the left x times
                            if (fieldData.Length > colFields.Length)
                            {
                                for (int x = 0; x < fieldData.Length - colFields.Length; x++)
                                {
                                    for (int i = 0; i < colFields.Length; i++)
                                    {
                                        if (string.IsNullOrEmpty(fieldData[i]))
                                        {
                                            for (int j = i + 1; j < fieldData.Length; j++)
                                            {
                                                fieldData[j - 1] = fieldData[j];
                                            }
                                            break; //do not copy more than x times
                                        }
                                    }
                                }
                            }
                            for (int i = 0; i < colFields.Length; i++)
                            {
                                colFields[i] = null;
                                if (i < fieldData.Length)
                                {
                                    if (fieldData[i].Trim() != "")
                                    {
                                        colFields[i] = fieldData[i].Trim();
                                    }
                                }
                            }

                            csvData.Rows.Add(colFields);
                        }
                    }
                }
                catch (Exception ex)
                {
                    Dts.TaskResult = (int)ScriptResults.Failure;
                    return;
                }
                using (SqlConnection con = new SqlConnection(commandConnectionString))
                {
                    con.Open();
                    System.Data.SqlClient.SqlBulkCopy bulkCopy = new System.Data.SqlClient.SqlBulkCopy(con);
                    bulkCopy.DestinationTableName = "staging.t_Aircraft_PNG";
                    SqlCommand cmd = new SqlCommand();
                    cmd.Connection = con;
                    cmd.CommandTimeout = 600;
                    cmd.CommandType = CommandType.Text;
                    cmd.CommandText = "IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[staging].[t_Aircraft_PNG]') AND type in (N'U')) DROP TABLE [staging].[t_Aircraft_PNG];";
                    cmd.ExecuteNonQuery();
                    string columnNames = string.Empty;
                    foreach (DataColumn column in csvData.Columns)
                    {
                        columnNames += "[" + column.ColumnName + "] varchar(max),";
                    }
                    cmd.CommandText = "CREATE TABLE [staging].[t_Aircraft_PNG] (" + columnNames.TrimEnd(new char[] { ',' }) + ")";
                    cmd.ExecuteNonQuery();
                    try
                    {
                        bulkCopy.WriteToServer(csvData);
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine(ex.Message);
                    }
                    finally
                    {
                        bulkCopy.Close();
                    }
                    con.Close();
                }//using

            }
            Dts.TaskResult = (int)ScriptResults.Success;
        }

        private string[] fieldExceptions = new string[] { "DE HAVILLAND", "BRITTEN NORMAN", "AIR TRACTOR", "FALCON900 EX" };
        private string GetFormattedFieldsValues(string fullLine)
        {
            string result = string.Empty;
            string cleanLine = fullLine.Replace("|", "/").Replace("  ", " ").Replace("   ", " ").Replace(" ", "|").Replace(",|", ", ");
            foreach (string fieldException in fieldExceptions)
            {
                cleanLine = cleanLine.Replace(fieldException.Replace(" ", "|"), fieldException);
                
            }
            string[] fields = cleanLine.Split('|');
            for (int i = 0; i < fields.Length; i++)
            {
                result += (i == 0 ? "" : (i < 6 ? "|" : " ")) + fields[i];
            }
            if (result.Contains(" PO BOX ") || (result.Contains(" P.O.BOX ")))
            {
                result = result.Replace(" PO BOX ", "|PO BOX ").Replace(" P.O. BOX ", "|PO BOX ");
            }
            else
            {
                result = result + "|"; //can't distinct name from address. put all of them into name and leave address blank
            }
            return result;
        }
    }


#>