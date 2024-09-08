[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

function Get-PathFromDialog {
    param (
        $Description
    )

    $getSource = New-Object System.Windows.Forms.FolderBrowserDialog
    $getSource.Description = $Description
    $getSource.rootfolder = "MyComputer"
    if ($getSource.ShowDialog() -eq "OK") {
        Return $getSource.SelectedPath
    }
    throw "Cancelled"
}

function Get-FilePathsFromFolder {
    param (
        $FolderToSearch,
        $Filter
    )

    Return Get-ChildItem -Path $FolderToSearch -Recurse -Filter $Filter | Select-Object -ExpandProperty FullName
}

function Get-ExactFilePathsFromFolder {
    param (
        $FolderToSearch,
        $Filter
    )

    $file = Get-ChildItem -Path $FolderToSearch -Recurse | Where-Object { $_.Name -eq $Filter }
    Return $file.FullName
}

function Get-ValidFilePath {
    param (
        $FolderToSearch,
        $FileName
    )

    $filePath = Get-ExactFilePathsFromFolder -FolderToSearch $FolderToSearch -Filter $FileName
    if ($null -eq $filePath) {
        throw "The $FileName was not found."
    }
    if ($filePath.Count -ne 1) {
        throw "Expected exactly one file matching '$FileName', but found $($filePath.Count)."
    }
    Return $filePath
}

function Test-FilePath {
    param (
        $FilePath,
        $ExpectedFileName
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw "The file '$FilePath' does not exist."
    }

    $fileName = [System.IO.Path]::GetFileName($FilePath)

    if ($fileName -ne $ExpectedFileName) {
        throw "The file '$FilePath' does not have the expected name '$ExpectedFileName'."
    }
}

function Search-FilePath {
    param (
        $FolderToSearch,
        $FileName
    )

    try {
        $filePath = Get-ValidFilePath -FolderToSearch $FolderToSearch -FileName $FileName
    } catch {
        $folderPathCandidate  = Get-PathFromDialog -Description "Select directory containing the $FileName."
        $filePathCandidate = Get-ValidFilePath -FolderToSearch $folderPathCandidate -FileName $FileName
        Test-FilePath -FilePath $filePathCandidate -ExpectedFileName $FileName
        $filePath = $filePathCandidate
    }
    Return $filePath
}

function Get-NameWithoutPartNumber {
    param (
        $FilePath
    )

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $nameWithoutNumber = $fileName -replace '\.\d+$', ''
    $extension = [System.IO.Path]::GetExtension($FilePath)
    Return $nameWithoutNumber + $extension
}

function Get-PathsAsStringArgument {
    param (
        $Paths
    )

    Return ($Paths | ForEach-Object { "`"$($_)`"" }) -join " + "
}

function Join-BinaryFileParts {
    param (
        $SortedFilePaths,
        $OutputFilePath
    )

    $pathsAsStringArgument = Get-PathsAsStringArgument -Paths $SortedFilePaths
    $copyCommand = "cmd.exe /c copy /b $pathsAsStringArgument `"$OutputFilePath`""
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c $copyCommand" -NoNewWindow -Wait
}

function Get-PartNumber {
    param (
        $FileName
    )

    $partNumber = $FileName -replace '.*\.(\d+)\.[^.]+$', '$1'

    if ($partNumber -match '^\d+$') {
        return [int]$partNumber
    } else {
        # When no part number, large number to sort first
        return [int]::MaxValue
    }
}

function Join-CovertedIsoParts {
    param (
        $IsoFolderPath,
        $SplitIsoPaths
    )

    $sortedIsoPaths = $splitIsoPaths | Sort-Object { Get-PartNumber $_ }

    $isoNameWithoutNumber = Get-NameWithoutPartNumber -FilePath $sortedIsoPaths[0]
    $outputIsoPath = Join-Path -Path $IsoFolderPath -ChildPath $isoNameWithoutNumber

    Join-BinaryFileParts -SortedFilePaths $sortedIsoPaths -OutputFilePath $outputIsoPath
    Remove-Item -Path $sortedIsoPaths

    Return $outputIsoPath
}

function Rename-ToIsoWithoutPartNumber {
    param (
        $IsoFolderPath,
        $OriginalIsoPath
    )

    $isoNameWithoutNumber = Get-NameWithoutPartNumber -FilePath $OriginalIsoPath
    $outputIsoPath = Join-Path -Path $IsoFolderPath -ChildPath $isoNameWithoutNumber
    Rename-Item -Path $OriginalIsoPath -NewName $outputIsoPath
    Return $outputIsoPath
}

function ConvertTo-OneIso {
    param (
        $IsoFolderPath
    )

    $splitIsoPaths = Get-FilePathsFromFolder -FolderToSearch $IsoFolderPath -Filter *.iso
    $numberOfIsoParts = $splitIsoPaths.Count
    if ($numberOfIsoParts -gt 1) {
        Write-Host "Repackinator split the `"redump`" ISO into $numberOfIsoParts parts after conversion. Joining them before repacking."
        $outputIsoPath = Join-CovertedIsoParts -IsoFolderPath $IsoFolderPath -SplitIsoPaths $splitIsoPaths
        Write-Host "The `"redump`" ISO was joined to  $outputIsoPath."
    } else {
        Write-Host "Repackinator converted the source into one `"redump`" ISO file. It will be used for repacking directly."
        $outputIsoPath = Rename-ToIsoWithoutPartNumber -IsoFolderPath $IsoFolderPath -OriginalIsoPath $splitIsoPaths
    }
    Return $outputIsoPath
}

function Get-RepackinatorConvertedFolder {
    param (
        $CciPath
    )

    $ParentFolderPath = (Get-Item -Path $CciPath).Directory.FullName
    Return Join-Path -Path $ParentFolderPath -ChildPath "Converted"
}

function Clear-RepackinatorConvertedIsoFolder {
    param (
        $CciPath
    )

    $convertedFolderPath = Get-RepackinatorConvertedFolder -CciPath $CciPath
    if (Test-Path $convertedFolderPath) {
        Remove-Item $convertedFolderPath -Recurse
    }
}

function ConvertTo-Iso {
    param (
        $CciPath
    )
    
    Write-Host "Converting CCI to `"redump`" ISO using repackinator: $CciPath"
    Clear-RepackinatorConvertedIsoFolder -CciPath $CciPath

    $quotedPath = Get-PathsAsStringArgument -Paths $CciPath
    $argumentList = "-a=convert", "-i=$quotedPath"
    Start-Process -FilePath $RepackinatorPath -ArgumentList $argumentList -NoNewWindow -Wait
    
    $convertedFolderPath = Get-RepackinatorConvertedFolder -CciPath $CciPath
    $isoPath = ConvertTo-OneIso -IsoFolderPath $convertedFolderPath
    Write-Host "CCI converted to `"redump`" ISO: $isoPath"
    Return $isoPath
}

function ConvertTo-Xiso {
    param (
        $RedumpIsoPath,
        $BaseXisoOutputFolderPath
    )

    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($RedumpIsoPath)
    $outputXisoFolderPath = Join-Path -Path $BaseXisoOutputFolderPath -ChildPath $fileName
    if (Test-Path -Path $outputXisoFolderPath) {
        Remove-Item $outputXisoFolderPath -Recurse
    }
    New-Item -Path $outputXisoFolderPath -ItemType Directory | Out-Null

    $quotedRedumpIsoPath = Get-PathsAsStringArgument -Paths $RedumpIsoPath
    $quotedOutputXisoFolderPath = Get-PathsAsStringArgument -Paths $outputXisoFolderPath
    $argumentList = "-d", "$quotedOutputXisoFolderPath", "-r", "$quotedRedumpIsoPath"
    Write-Host "Converting `"redump`" ISO to XISO using extract-xiso: $RedumpIsoPath"
    Start-Process -FilePath $ExtractXisoPath -ArgumentList $argumentList -NoNewWindow -Wait

    $xisoPath = Join-Path -Path $outputXisoFolderPath -ChildPath "$fileName.iso"
    Return $xisoPath
}

function Get-CciGamePathSet {
    param (
        $CciInputFolderPath
    )

    $allCciGamePaths = Get-FilePathsFromFolder -FolderToSearch $CciInputFolderPath -Filter *.cci

    $numberPostfixBeforeExtension = '\.\d+\.[^.]+$';
    $firstPartOnlyPaths = $allCciGamePaths | Group-Object {
        $_ -replace $numberPostfixBeforeExtension, ''
    } | ForEach-Object {
        $_.Group | Sort-Object { Get-PartNumber $_ } | Select-Object -First 1
    }
    return $firstPartOnlyPaths
}

function Split-File {
    param (
        $FilePath,
        $PartSizeMB,
        $Extension
    )

    $sourceStream = [System.IO.File]::OpenRead($FilePath)
    $partSizeBytes = $PartSizeMB * 1MB
    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($FilePath)

    $buffer = New-Object byte[] 8192  # 8 KB buffer
    $currentPartStream = $null
    $bytesReadTotal = 0
    $partIndex = 1
    $fileParts = @()
    while (($bytesRead = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        # Closing previous part if needed and creating new one
        if (-not $currentPartStream -or $bytesReadTotal + $bytesRead -gt $partSizeBytes) {
            if ($currentPartStream) {
                $currentPartStream.Close()
            }

            $outputFilePath = Join-Path -Path $outputDirectory -ChildPath "$fileNameWithoutExtension.$partIndex.$Extension"
            $currentPartStream = [System.IO.File]::OpenWrite($outputFilePath)
            $partIndex++
            $bytesReadTotal = 0

            $fileParts += $outputFilePath
        }

        # Writing data to current part
        $currentPartStream.Write($buffer, 0, $bytesRead)
        $bytesReadTotal += $bytesRead
    }

    # Closing last part
    if ($currentPartStream) {
        $currentPartStream.Close()
    }
    $sourceStream.Close()

    Return $fileParts
}

function Split-Iso {
    param (
        $IsoPath,
        $MaxSizeMB = 4094
    )

    $fileInfo = Get-Item -Path $IsoPath
    $fileSizeMB = [math]::Round($fileInfo.Length / 1MB)
    if ($fileSizeMB -le $MaxSizeMB) {
        Write-Host "The ISO file size ($fileSizeMB MB) is within the limit of $MaxSizeMB MB. No splitting needed."
        return
    }

    Write-Host "The ISO file size ($fileSizeMB MB) exceeds the limit of $MaxSizeMB MB. Splitting the file..."
    $fileParts = Split-File -FilePath $IsoPath -PartSizeMB $MaxSizeMB -Extension iso
    Remove-Item -Path $IsoPath
    Write-Host "The ISO file has been split into $($fileParts.Count) parts."
}

function Copy-FileToDestination {
    param (
        $SourceFile,
        $DestinationFolder
    )

    if (Test-Path $SourceFile) {
        Write-Host "Copying $SourceFile to $DestinationFolder"
        Copy-Item -Path $SourceFile -Destination $DestinationFolder
    } else {
        Write-Host "The file was not found in: $SourceFile"
    }
}

function Copy-DefaultTbn {
    param (
        $CciPath,
        $XisoPath
    )

    $sourceDirectory = [System.IO.Path]::GetDirectoryName($CciPath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($XisoPath)
    $defaultTbnPath = Join-Path -Path $sourceDirectory -ChildPath "default.tbn"

    Copy-FileToDestination -SourceFile $defaultTbnPath -DestinationFolder $outputDirectory
}

function Copy-AttachXbe {
    param (
        $CciPath,
        $XisoPath
    )

    $sourceDirectory = [System.IO.Path]::GetDirectoryName($CciPath)
    $outputDirectory = [System.IO.Path]::GetDirectoryName($XisoPath)
    $defaultXbePath = Join-Path -Path $sourceDirectory -ChildPath "default.xbe"

    Copy-FileToDestination -SourceFile $defaultXbePath -DestinationFolder $outputDirectory
}


Write-Host "OG Xbox CCI images will be converted into repacked XISO that is the most suitable for Project Stellar as it utilizes Virtual Disc Sector Map Emulation without the need of any ISO image padding and therefore the need to have compressed images."

Write-Host "Searching dependecies..."
$ExtractXisoPath = Search-FilePath -FolderToSearch ".\extract-xiso" -FileName "extract-xiso.exe"
Write-Host "The extract-xiso will be used from: $ExtractXisoPath"
$RepackinatorPath = Search-FilePath -FolderToSearch ".\repackinator" -FileName "repackinator.exe"
Write-Host "The repackinator will be used from: $RepackinatorPath"

Write-Host "Select image paths."
$CciInputFolderPath = Get-PathFromDialog -Description "Select CCI Source Directory"
Write-Host "Converting CCI images from: $CciInputFolderPath"
$XisoOutputFolderPath = Get-PathFromDialog -Description "Select XISO Output Directory"
Write-Host "Creating repacked XISO images to: $XisoOutputFolderPath"

$CciGamePaths = Get-CciGamePathSet -CciInputFolderPath $CciInputFolderPath
$total = $CciGamePaths.Count
$count = 1
Write-Host "Found $total CCI images."
foreach($CciPath in $CciGamePaths) {
    Write-Host "Converting CCI to XISO image. $count of $total"
    $redumpIsoPath = ConvertTo-Iso -CciPath $CciPath
    $xisoPath = ConvertTo-Xiso -RedumpIsoPath $redumpIsoPath -BaseXisoOutputFolderPath $XisoOutputFolderPath
    Clear-RepackinatorConvertedIsoFolder -CciPath $CciPath
    Split-Iso -IsoPath $xisoPath
    Copy-DefaultTbn -CciPath $CciPath -XisoPath $xisoPath
    Copy-AttachXbe -CciPath $CciPath -XisoPath $xisoPath
    $count++
}

Write-Host "The CCI -> XISO conversion has ended."
Start-Sleep -Seconds 3