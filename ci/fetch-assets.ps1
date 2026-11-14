param (
    [string]$DeviceDetection,
    [string]$DeviceDetectionUrl
)
$ErrorActionPreference = "Stop"

$data = "$PSScriptRoot/../cxx/data"

$assets = "TAC-HashV41.hash", "20000 Evidence Records.yml", "20000 User Agents.csv"
./steps/fetch-assets.ps1 -DeviceDetection:$DeviceDetection -DeviceDetectionUrl:$DeviceDetectionUrl -Assets $assets
foreach ($asset in $assets) {
    New-Item -ItemType SymbolicLink -Force -Target "$PWD/assets/$asset" -Path "$data/device-detection/$asset"
}

# The examples use the free Lite files, and the IP intelligence performance
# test the free Asn file. The data repository links to these rather than
# stores them, so its script downloads them.
$global:LASTEXITCODE = 0
& "$data/get-data-files.ps1" 51Degrees-LiteV41.ipi 51Degrees-IPIV4AsnIpiV41.ipi 51Degrees-LiteV4.1.hash
if ($LASTEXITCODE -ne 0) {
    throw "The free data files were not downloaded"
}
