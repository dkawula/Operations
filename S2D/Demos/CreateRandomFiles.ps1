Function Create-RandomFiles{
<#
.SYNOPSIS
Generates a number of dumb files for a specific size.
 
.DESCRIPTION
Generates a defined number of files until reaching a maximum size.
 
.PARAMETER Totalsize
Specify the total size you would all the files combined should use on the harddrive.
This parameter accepts the following size values (KB,MB,GB,TB)
	5MB
	3GB
	200KB
 
.PARAMETER NumberOfFiles
	Specify a number of files that need to be created. This can be used to generate a big number of small files in order to simulate
	User backup specefic behaviour.
 
.PARAMETER FilesTypes
	This parameter is not mandatory, but two choices are valid:
		Office : Will generate files with the following extensions: ".pptx",".docx",".doc",".xls",".docx",".doc",".pdf",".ppt",".pptx",".dot"
		Multimedia : Will create random files with the following extensions : ".avi",".midi",".mov",".mp3",".mp4",".mpeg",".mpeg2",".mpeg3",".mpg",".ogg",".ram",".rm",".wma",".wmv"
	If Filestypes parameter is not set, by default, the script will create both office and multimedia type of files.
 
.PARAMETER Path
	Specify a path where the files should be generated.
 
.PARAMETER Whatif
	Permits to launch this script in "draft" mode. This means it will only show the results without really making generating the files.
 
.PARAMETER Verbose
	Allow to run the script in verbose mode for debbuging purposes.
 
.EXAMPLE
   .\Create-Files.ps1 -totalsize 50MB -NumberOfFiles 13 -Path C:\Users\Svangulick\
 
   Will generate randonmly 13 files for a total of 50mb in the path c:\users\svangulick\
 
.EXAMPLE
   .\Create-Files.ps1 -totalsize 5GB -NumberOfFiles 3 -Path C:\Users\Svangulick\
 
   Will generate randonmly 3 files for a total of 5Gigabytes in the path c:\users\svangulick\
 
.NOTES
	-Author: Stéphane van Gulick
	-Email : Svangulick@gmail.com
	-Version: 1.0
	-History:
		-Creation V0.1 : SVG
		-First final draft V0.5 : SVG
		-Corrected minor bugs V0.6 : SVG
		-Functionalized the script V0.8 : SVG
		-Simplified code V1.0 : SVG
.LINK
	 http://www.PowerShellDistrict.com
#>
[cmdletbinding()]
param(
	[Parameter(mandatory=$true)]$NumberOfFiles,
	[Parameter(mandatory=$true)]$path,
	[Parameter(mandatory=$true)]$TotalSize
)
 
begin{
	Write-verbose "Generating files"
	$AllCreatedFilles = @()
 
function Create-FileName{
[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(mandatory=$false)][validateSet("Multimedia","Office","all","")][String]$filesType=$all
	)
	begin {
		$AllExtensions = @()
		$MultimediaExtensions = ".avi",".midi",".mov",".mp3",".mp4",".mpeg",".mpeg2",".mpeg3",".mpg",".ogg",".ram",".rm",".wma",".wmv"
		$OfficeExtensions = ".pptx",".docx",".doc",".xls",".docx",".doc",".pdf",".ppt",".pptx",".dot"
		$AllExtensions = $MultimediaExtensions + $OfficeExtensions
		$extension = $null
	}
	process{
		Write-Verbose "Creating file Name"
		#$Extension = $MultimediaFiles | Get-Random -Count 1
 
		switch ($filesType)
			{
				"Multimedia"{$extension = $MultimediaExtensions | Get-Random}
				"Office"{$extension = $OfficeExtensions | Get-Random }
				default
						{
						$extension = $AllExtensions | Get-Random
 
						}
 
			}
 
		Get-Verb | Select-Object verb | Get-Random -Count 2 | %{$Name+= $_.verb}
		$FullName = $name + $extension
		Write-Verbose "File name created : $FullName"
	}
	end{
 
	return $FullName
	}
 
}
 
}
#----------------Process-----------------------------------------------
 
process{
 
	$FileSize = $TotalSize / $NumberOfFiles
	$FileSize = [Math]::Round($FileSize, 0)
 
	while ($TotalFileSize -lt $TotalSize) {
		$TotalFileSize = $TotalFileSize + $FileSize
 
		$FileName = Create-FileName -filesType $filesType
 
		Write-verbose "Creating : $filename of $FileSize"
 
		Write-Verbose "Filesize = $filesize"
 
		$FullPath = Join-Path $path -ChildPath $fileName
		Write-Verbose "Generating file : $FullPath of $Filesize"
		try{
			fsutil.exe file createnew $FullPath $FileSize | Out-Null
			}
		catch{
			$_
		}
 
		$FileCreated = ""
		$Properties = @{'FullPath'=$FullPath;'Size'=$FileSize}
 
		$FileCreated = New-Object -TypeName psobject -Property $properties
		$AllCreatedFilles += $FileCreated
		Write-verbose "$($AllCreatedFilles) created $($FileCreated)"
	}
 
}
end{
	Write-Output $AllCreatedFilles
}
}