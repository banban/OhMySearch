$data = Get-Content "C:\Users\andrew.butenko\Downloads\acronyms.txt"
write-host $data.count total lines read from file
$stuff=@()
$i=0
while ($i -le $data.count)
{
""
    [string]$key = $data[$i]
    while ($data[$i+1] -ne "" -and $i+1 -le $data.count)
    {
        $i++
        $key += " "+ $data[$i]
    }
    $i++
    [string]$value = $data[$i]
    while ($data[$i+1] -ne "" -and $i+1 -le $data.count)
    {
        $i++
        $value += " "+ $data[$i]
    }
    $i++

    if ($key -ne "" -and $value -ne "")
    {
        $obj = new-object PSObject
        $obj | add-member -membertype NoteProperty -name "Key" -value $key.Trim()
        $obj | add-member -membertype NoteProperty -name "Value" -value $value.Trim()
        $stuff += $obj
    }
}
$stuff | export-csv C:\Users\andrew.butenko\Downloads\acronyms.csv
