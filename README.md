# OG Xbox Batch Compressed image to XISO Converter

This PowerShell script converts OG Xbox compressed images into repacked XISO images, making them suitable for use with [Project Stellar](https://github.com/MakeMHz/project-stellar). 
Project Stellar has a Virtual Disc Sector Map Emulation that solves compability issues with some repacked ISO images that have trimmed padding. There is no need to play from compressed images on Project Stellar that have padding still present but scrubbed with zeroes for compressing.

The problems why I created this script were that redump ISOs are too large to archive for average Joes and repacked ISOs cannot be converted back to redump like ISOs for Repackinator to create CSO or CCI as the padding information is missing.

So my archive backup consists of scrubbed ISOs compressed to CCI by Repackinator for storage and ease of play on Cerbios. But Project Stellar does not support CCI (has its own CSO compressed format) and the best compatibility is repacked ISO.
Other issue is "Repackinator" repacking abilities are not impressive, extract-xiso still produces much smaller repacked ISO images but extract-xiso does not support any of the new compressed images - only the "redump-like" ISOs. 

To have the best of both worlds this script uses both - Repackinator and extract-xiso, to convert from compressed CCI to XISO that is almost the same size as the CCI image with compressed padding.

## Prerequisites

1. **PowerShell**: This script requires PowerShell to run. It was an excuse to try my first PowerShell script and it will be maybe last for a long time. I found out I do not like it as it has some weird convetions. So the script code may annoy some PowerShell purists. :)
2. **repackinator**: The executable `repackinator.exe` can be placed in a default folder named `repackinator` in the current working directory. https://github.com/Team-Resurgent/Repackinator
3. **extract-xiso**: The executable `extract-xiso.exe` can be placed in a default folder named `extract-xiso` in the current working directory. https://github.com/XboxDev/extract-xiso

## How to Use

1. Clone this repository or download the script file.

2. Run the convertCciToXiso.ps1 in PowerShell

4. Follow the prompts:
   - **Select CCI Source Directory**: Choose the folder containing your CCI images with scrubbed padding - trimmed may not work I guess. The structure I have is that each game has it's CCI images in separate folder along with optional default.xbe and default.tbn. I did not test when all images of all games are in one folder.
   - **Select XISO Output Directory**: Choose the folder where the output XISO images will be saved. Each Game will have XISO images created in a folder named after the image and default.xbe and default.tbn may be copied from source folder when present. 

5. The script will:
   - Find and select the required tools (`repackinator` and `extract-xiso`).
   - Convert each CCI image to a redump-like ISO (without the video partition).
   - Combine ISO parts (if split) into a single image as Repackinator does not have any cli parameters to disable splitting.
   - Repacking the redump-like ISO to XISO with extract-xiso.
   - Split the resulting XISO if it exceeds a 4 GB (limitation of FATX file system). If the image is split it the files have a part number before .iso extension.
   - Copy the `default.tbn` and `default.xbe` files from source directory if present to the output directory.

6. When the conversion is complete, you will find the XISO files in the selected output directory. The script does not remove the source CCI images but will clean all the temporary images (Repackinator's redump-like ISO, any parts after joning, large XISO after spliting)

## Features

- **Batch Conversion**: Repacks multiple CCI files to XISO from a chosen directory.
- **Automated Merging**: Automatically splits large XISO files.

## Additional Notes

- Ensure that your system has the required permissions to execute PowerShell scripts. You may need to change the execution policy by running:

    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
    ```

- For best performance, run the script on a machine with sufficient disk space and processing power, as the conversion process can be resource-intensive.


## Acknowledgments

- **repackinator**: For scrubbed CCI to ISO conversion.
- **extract-xiso**: For ISO to repacked XISO conversion.

## Disclaimer

Use this script at your own risk. Ensure you have backups of your files before proceeding with the conversion process.

## Known issues

- The script did not work with files on my NAS and I had to copy all files to my local disks. The "Get-ChildItem" never returned any results when searching mounted network drives on my machine. :(

## Future development

- It might be easy to add CSO to XISO support.
- I would like to add the posibility to put custom attach.xbe to the output but it requires some hex edit of the xbe file by the script to edit a title. If I tried to copy the [stellar-attach](https://github.com/MakeMHz/stellar-attach/) everything was named STELLARATTACHXBE in the [XBMC4Gamers](https://github.com/Rocky5/XBMC4Gamers)
    - currently it just copies a default.xbe from a source folder (I had it created by Repackinator in the past so it has proper title encoded).