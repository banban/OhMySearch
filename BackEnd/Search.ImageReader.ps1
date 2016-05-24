[IO.FileInfo]$file = "C:\Users\andrew.butenko\Pictures\Idontneed Google.png"
[IO.FileInfo]$file = "C:\Users\andrew.butenko\Pictures\20150819_144945.jpg"
[IO.FileInfo]$file = "\\nova\fs\bus\aa\ea\c\2931\02931.0001 stretcher system\photos\production photos\2014-04-01 16.24.36.jpg"
[IO.FileInfo]$file = "\\nova\fs\bus\ba\bc\c\4453\work\j453 data\hood.jpg"
&"C:\Program Files\Inkscape\inkscape.exe" --file=$file --export-png
&"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe" "C:\Temp\ImageCompare\Idontneed_Google_cc.png" "Idontneed_Google" -l eng -psm 1 | Out-Null
inkscape --file="C:\Temp\ImageCompare\WP_20140314_002.svg" --export-plain-svg="C:\Temp\ImageCompare\WP_20140314_002_ink2.svg"
"C:\Temp\potrace-1.12.win64\potrace.exe" --svg --output "C:\Temp\ImageCompare\WP_20140314_002_potrace.svg" "C:\Temp\ImageCompare\WP_20140314_002.svg"

Import-Module Image
$image  = New-Object -ComObject Wia.ImageFile
$image.LoadFile($file.FullName)
$exif = Get-Exif($image)
"$([math]::Round($(get-ExifItem -image $image -ExifID $ExifIDGPSAltitude)))M above Sea Level"

$names = $exif | Get-Member -membertype properties | % {$_.Name}
foreach ($name in $names){
    $value = $exif | Select -ExpandProperty "$name"
    if ($value -and $value -ne "") { 
        Write-Host $name ": " $value
    }
}

            $property = $fileProperties.CreateElement("$name")
            $xmlSubText = $fileProperties.CreateTextNode("$value")
            $property.AppendChild($xmlSubText)
            $properties.AppendChild($property)

[xml]$fileProperties = [xml]"<File/>"
Get-Exif($image).Properties | select Name, value | where { $_.value -ne ""} | % {$_.Value}
foreach ($name in $names){
    $value = $officeDoc.PackageProperties | Select -ExpandProperty "$name"
    if ($value) { 
        #Write-Host $name ":" $value
        $property = $fileProperties.CreateElement("$name")
        $xmlSubText = $fileProperties.CreateTextNode("$value")
        $property.AppendChild($xmlSubText)
        $properties.AppendChild($property)
    }
}


    if($obj.ServiceState -eq "Running")
    {
        $obj.DisplayName;
    }

ConvertTo-Xml -InputObject (Get-Exif($image))



$word = New-Object -comobject word.application
$word.visible = $true
$doc = $word.documents.open("C:\Tests\SpellCheck.docx")
$doc.checkSpelling()
$doc.checkGrammar()
#$doc.save()
$doc.printOut()
$doc.close()
$doc = $null

$dictionary = New-Object -COM Scripting.Dictionary
$dic = New-Object -COM Scripting.Dictionary #credits to MickyB
$w = New-Object -COM Word.Application
$w.Languages | % {if($_.Name -eq "English (AUS)"){$dic=$_.ActiveSpellingDictionary}}
$a = $null
$b = $null
$w.checkSpelling("Color", [ref]$a, [ref]$b, [ref]$dic)
$a
$b
$w = $null