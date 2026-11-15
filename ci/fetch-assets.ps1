param (
    [string]$DeviceDetection,
    [string]$DeviceDetectionUrl
)
$ErrorActionPreference = "Stop"

$data = "$PSScriptRoot/../cxx/data"

# Every data file the tests read is an asset, which the run caches once, so a
# test job restores the files rather than downloading them.
$assets = "TAC-HashV41.hash", "20000 Evidence Records.yml", "20000 User Agents.csv"
$liteHash = "51Degrees-LiteV4.1.hash"
$asn = "51Degrees-IPIV4AsnIpiV41.ipi"
./steps/fetch-assets.ps1 -DeviceDetection:$DeviceDetection -DeviceDetectionUrl:$DeviceDetectionUrl -Assets ($assets + $liteHash + $asn)
foreach ($asset in $assets) {
    New-Item -ItemType SymbolicLink -Force -Target "$PWD/assets/$asset" -Path "$data/device-detection/$asset"
}

# The free files go where a fresh clone's data submodule keeps them, which is
# where the tests and examples look by default.
Copy-Item "assets/$liteHash" "$data/device-detection"
Copy-Item "assets/$asn" "$data/ip-intelligence"
