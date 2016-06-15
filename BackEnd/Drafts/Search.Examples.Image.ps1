<#
 1. Install PowerShell Image module from here: https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Image-module-caa4405a 
      to here: $env:PSModulePath -> C:\Program Files\WindowsPowerShell\Modules\Image

#>
Import-Module Image


[IO.FileInfo]$file = "C:\Users\andrew.butenko\Pictures\Idontneed Google.png"
[IO.FileInfo]$file = "C:\Users\andrew.butenko\Pictures\20150819_144945.jpg"
&"C:\Program Files\Inkscape\inkscape.exe" --file=$file --export-png
&"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe" "C:\Temp\ImageCompare\Idontneed_Google_cc.png" "Idontneed_Google" -l eng -psm 1 | Out-Null
inkscape --file="C:\Temp\ImageCompare\WP_20140314_002.svg" --export-plain-svg="C:\Temp\ImageCompare\WP_20140314_002_ink2.svg"
"C:\Temp\potrace-1.12.win64\potrace.exe" --svg --output "C:\Temp\ImageCompare\WP_20140314_002_potrace.svg" "C:\Temp\ImageCompare\WP_20140314_002.svg"

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


