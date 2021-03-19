# Change log for OSDHashChecker.ps1

## 1.3.3 - Oct 16,2020

- Added dynamic Auto complete to TasksequenceID parameter in for LTIStorHashUI.ps1

## 1.3.2 - Aug 26,2020

- Fixed message output and placed in past tense
- Added progress update in both tasksequence and console

## 1.3.1 - Aug 25, 2020

- Added Invoke-StatusUpdate script to combine progress into one line. Simplifies the script and easier to manage.

## 1.3.0 - Aug 24, 2020

- Renamed Hash checkers to LTI to identify MDT only script
- Added TaskSequenceID parameter; forces ID incase it doesn't exist in CustomSettings.ini
- Added Synopsis to scripts to example parameters
- Changed Action parameter to StoreType/CompareType and defaulted them to store hash

## 1.2.0 - Aug 13, 2020

- Added parameter to excluded files. Defaults to excluding CustomSettings.ini,Audit.log,Autorun.inf file within MDT
- Changed the hash function of files and folders; instead of just counts, hash a collection grab all files with their sizes
- Split Hash checking and Hash storing into different scripts. Provides more security to ensure store action is not ran
- Extracted functions and xaml into separate folders. Easier change management and reduce main script complexity
- Added Esc function in UI, allows windows to be in front (to allow troubleshooting)

## 1.1.6 - Aug 12, 2020

- Added title parameter
- Added ExportFiles as an action; export file and folder in a list
- Added Get-stringHash Function; used to get the hash on folder and files counts; winpe hashing file output is different than Windows
- Removed working path from file and folder path; full path changes in media when hashing

## 1.1.5 - Aug 11, 2020

- Updated UI with canvas images and provide a cleaner output
- Added UI support for action StoreHash
- Countdown added when all hashed are valid
- Added TS environment variable Hash_Valid [boolean]

## 1.0.1 - Aug 10, 2020

- Added support to update customsettings.ini; added ini functions
- Changed hashing to check only WIM, TS.xml, File name and folder names. Removed individual file hashing; it took to long

## 1.0.0

- Initial design (noUI)