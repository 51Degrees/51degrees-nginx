param(
    [string]$Name = "1.21.3_dynamic",
    [string]$NginxVersion = "1.21.3",
    [string]$BuildMethod = "dynamic",
    [bool]$MemCheck = $False
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

# A warning stops 51Degrees' own builds. Until the shared workflows set this
# for every job, the build scripts set it.
if (!$env:_51DEGREES_WARNINGS_AS_ERRORS) {
    $env:_51DEGREES_WARNINGS_AS_ERRORS = 'true'
}

$assets = "$PWD/assets"

Push-Location $PSScriptRoot/..
try {
    $build = $BuildMethod -eq 'static' ? '_51DEGREES_STATIC_BUILD=1' : $null
    $target = $MemCheck ? 'mem-check' : 'install'

    Write-Host "Building module, target $target $build"
    make _51DEGREES_DONT_CLEAN_TESTS=1 _51DEGREES_NGINX_VERSION=$NginxVersion "_51DEGREES_DD_PATH=$assets/TAC-HashV41.hash" $build $target
} finally {
    Pop-Location
}
