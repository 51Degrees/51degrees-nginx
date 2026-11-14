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

# The IP intelligence tests use the free Asn file, which the data repository
# links to rather than stores, so its script downloads it.
$global:LASTEXITCODE = 0
& "$data/get-data-files.ps1" 51Degrees-IPIV4AsnIpiV41.ipi 51Degrees-LiteV4.1.hash
if ($LASTEXITCODE -ne 0) {
    throw "The free data files were not downloaded"
}
