param(
    [string]$Name = "1.21.3_dynamic",
    [string]$NginxVersion = "1.21.3",
    [string]$BuildMethod = "dynamic"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$repo = (Get-Item $PSScriptRoot/..).FullName
$summary = New-Item -ItemType directory -Force -Path $repo/test-results/performance-summary

# Write the results of the last runPerf.sh run for comparison under the
# given configuration name. The figure is the clock time for every request,
# the same measure as the console performance examples, as each request makes
# one detection. A run that failed writes no results and only warns, because
# failing here would fail the Test job and stop the night's release.
function Write-Results {
    param([Parameter(Mandatory)][string]$ResultsName)
    $results = Get-Content -Raw ./summary.json | ConvertFrom-Json
    $seconds = $results.request_s_process
    if ($seconds -le 0 -or $results.failed_process -ne 0) {
        Write-Warning "No results for ${ResultsName}: $seconds seconds a request, $($results.failed_process) failed"
        return
    }
    @{
        HigherIsBetter = @{
            DetectionsPerSecond = 1 / $seconds
        }
        LowerIsBetter = @{
            AvgMillisecsPerDetection = $seconds * 1000
        }
    } | ConvertTo-Json > $summary/results_$ResultsName.json
}

# The IP intelligence results are published under the _IPI suffixed
# configuration name so that they get their own performance graph. Each
# configuration runs only its own engine's performance test and writes
# the results under its own name.
$ipiOnly = $Name -like '*_IPI'

# The device detection data file, which ci/fetch-assets.ps1 links into
# cxx/data/device-detection.
$hashFile = "$repo/cxx/data/device-detection/TAC-HashV41.hash"

# The IP intelligence data file, the free Asn file that ci/fetch-assets.ps1
# copies into cxx/data/ip-intelligence.
$asnFile = "$repo/cxx/data/ip-intelligence/51Degrees-IPIV4AsnIpiV41.ipi"

$build = New-Item -ItemType directory -Force -Path "$repo/tests/performance/build"
Push-Location $build
try {
    # Build the performance tests
    Write-Host "Building performance test"
    cmake ..
    cmake --build .

    if (-not $ipiOnly) {
        # The device detection performance test reads the data file that
        # _51DEGREES_DD_PATH names, which is set only while it runs.
        Write-Host "Running device detection performance test"
        $env:_51DEGREES_DD_PATH = $hashFile
        try {
            ./runPerf.sh hash
        } finally {
            $env:_51DEGREES_DD_PATH = $null
        }

        Write-Host "Writing device detection performance test results"
        Write-Results $Name
    }

    if ($ipiOnly) {
        # The IP intelligence performance test reads the data file that
        # _51DEGREES_IPI_PATH names, which is set only while it runs.
        Write-Host "Running IP intelligence performance test"
        $env:_51DEGREES_IPI_PATH = $asnFile
        try {
            ./runPerf.sh ipi
        } finally {
            $env:_51DEGREES_IPI_PATH = $null
        }

        Write-Host "Writing IP intelligence performance test results"
        Write-Results $Name
    }
} finally {
    Pop-Location
}


if (-not $ipiOnly) {
    Push-Location $repo
    try {
        # Run the stress test script. ApacheBench will already be built from the previous test
        Write-Host "Run stress tests using ApacheBench"
        if (Test-Path -Path "tests/performance/build/ApacheBench-prefix/src/ApacheBench-build/bin/ab") {
            $env:_51DEGREES_DD_PATH = $hashFile
            try {
                ./test.sh
            } finally {
                $env:_51DEGREES_DD_PATH = $null
            }
        } else {
            Write-Error 'The performance test need to be build first.'
        }
    } finally {
        Pop-Location
    }
}
