$ErrorActionPreference = "Stop"

$data = "$PSScriptRoot/../cxx/data"

# Every data file the tests read is an asset, which the run caches once, so a
# test job restores the files rather than downloading them. The step that
# fetches them reads the License Key from _51DEGREES_LICENSE_KEY.
$assets = "TAC-HashV41.hash", "20000 Evidence Records.yml"
$liteHash = "51Degrees-LiteV4.1.hash"
$asn = "51Degrees-IPIV4AsnIpiV41.ipi"
$liteIpi = "51Degrees-LiteIpiV41.ipi"
./steps/fetch-assets.ps1 -Assets ($assets + $liteHash + $asn + $liteIpi)
foreach ($asset in $assets) {
    New-Item -ItemType SymbolicLink -Force -Target "$PWD/assets/$asset" -Path "$data/device-detection/$asset"
}

# The free files go where a fresh clone's data submodule keeps them, which is
# where the tests and examples look by default. The examples use the two Lite
# files, and the IP intelligence performance test the Asn file. The data
# repository names the Lite IP intelligence file 51Degrees-LiteV41.ipi.
Copy-Item "assets/$liteHash" "$data/device-detection"
Copy-Item "assets/$asn" "$data/ip-intelligence"
Copy-Item "assets/$liteIpi" "$data/ip-intelligence/51Degrees-LiteV41.ipi"
