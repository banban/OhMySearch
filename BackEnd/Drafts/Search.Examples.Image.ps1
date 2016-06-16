<#
 1. Install PowerShell Image module from here: https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Image-module-caa4405a 
      to here: $env:PSModulePath -> C:\Program Files\WindowsPowerShell\Modules\Image
 This script is not for execution. It is just set of tests.
#>
Import-Module Image

#Image Magic 6 convert.exe was replaced with magic.exe in version 7
&"$env:MAGICK_HOME\convert.exe" "c:\temp\test2.jpg" -charcoal 2 -threshold 50% -strip -trim -contrast -density 200 "c:\temp\test7.png"
#was replaced with magic.exe in version 7. Option -contrast was depricated and replaced with  -level 50% 
&"$env:MAGICK_HOME\magick.exe" "c:\temp\test2.jpg" -charcoal 2 -threshold 50% -strip -trim -level 50% -density 200 "c:\temp\test7.png"
&"$env:MAGICK_HOME\magic.exe" -strip -trim -monochrome -limit memory 10GB -limit area 10GB -limit disk 15GB -limit map 10GB -density 200 "$($filePathCopy)" "$($ImageMagickTempPath)\ocr-%04d.png" | Out-Null


[IO.FileInfo]$file = "C:\Users\andrew.butenko\Pictures\Idontneed Google.png"
[IO.FileInfo]$file = "C:\Users\andrew.butenko\Pictures\20150819_144945.jpg"
&"C:\Program Files\Inkscape\inkscape.exe" --file=$file --export-png
#extract text by OCR
&"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe" "C:\Temp\ImageCompare\Idontneed_Google_cc.png" "Idontneed_Google" -l eng -psm 1 | Out-Null
#vector transformations
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


