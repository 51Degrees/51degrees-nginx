param(
    [string]$Name = "1.21.3_dynamic",
    [string]$NginxVersion = "1.21.3",
    [string]$BuildMethod = "dynamic"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

Push-Location $PSScriptRoot/..
try {
    # Create the output directory
    $results = New-Item -ItemType directory -Force -Path test-results/integration

    # Disable leak checks here, as they are for the unit tests.
    $env:ASAN_OPTIONS="detect_odr_violation=0:detect_leaks=0"

    Write-Host "Setting up the JavaScript example"
    # Copy the example config
    Copy-Item examples/hash/jsExample/javascript.conf build/nginx.conf
    # Set the data file
    sed -i "s/51Degrees-LiteV4\.1\.hash/TAC-HashV41\.hash/g" build/nginx.conf
    # Remove the documentation block
    sed -i "/\/\*\*/,/\*\//d" build/nginx.conf
    # A static build links the module into the Nginx binary, so remove the
    # load_module directive which would otherwise fail to open a shared
    # object that a static build does not produce.
    if ($BuildMethod -eq 'static') {
        sed -i "/load_module/d" build/nginx.conf
    }
    # The example's instructions create a static file for /overrides, without
    # which NGINX answers 404 with none of the headers the page reads.
    New-Item -ItemType File -Force build/html/overrides | Out-Null
    # NGINX serves the example's page as well, because Chrome keeps no cookie
    # for a page opened from a file, so the evidence the module's JavaScript
    # writes would never reach the module.
    New-Item -ItemType Directory -Force build/html/jsExample | Out-Null
    Copy-Item examples/hash/jsExample/index.html build/html/jsExample/index.html

    # The browser test is the ModuleJavaScript category of the shared browser
    # test suite, checked out beside this repository as the API repositories
    # do. The suite finds and starts Chrome, Firefox and their drivers, so
    # nothing here does. It is built before NGINX starts.
    $suite = [IO.Path]::GetFullPath("$PSScriptRoot/../../selenium-api-tests")
    if (-not (Test-Path $suite)) {
        git clone --depth 1 https://github.com/51Degrees/selenium-api-tests.git $suite
    }
    git -C $suite log -1 --format="selenium-api-tests at %H %s"
    dotnet build $suite -c Release

    # Start NGINX
    ./nginx
    try {
        $env:_51DEGREES_EXAMPLE_URL = "http://localhost:8888/jsExample/index.html"
        # Seconds NGINX has to serve the page before the tests start.
        $pageWaitSeconds = 30
        curl -sS -o /dev/null --retry $pageWaitSeconds --retry-delay 1 --retry-connrefused $env:_51DEGREES_EXAMPLE_URL

        Write-Host "Running the browser test of the JavaScript example"
        $browserResults = New-Item -ItemType directory -Force -Path test-results/browser
        $trx = "module-javascript.trx"
        # The exit code is checked after the results file is read, so a
        # failing run still says how many tests passed.
        $PSNativeCommandUseErrorActionPreference = $false
        dotnet test $suite -c Release --no-build --filter TestCategory=ModuleJavaScript `
            --logger "trx;LogFileName=$trx" --logger "console;verbosity=normal" `
            --results-directory $browserResults
        $testExit = $LASTEXITCODE
        $PSNativeCommandUseErrorActionPreference = $true
        # dotnet test passes a run that found no test, or whose tests were
        # skipped, so the results file decides, and every test in it must
        # have passed.
        $counters = $null
        if (Test-Path "$browserResults/$trx") {
            $counters = ([xml](Get-Content -Raw "$browserResults/$trx")).TestRun.ResultSummary.Counters
            Write-Host "ModuleJavaScript: $($counters.passed) of $($counters.total) passed"
        }
        if ($testExit -ne 0 -or -not $counters -or [int]$counters.total -eq 0 -or
            $counters.passed -ne $counters.total) {
            throw "The browser test of the JavaScript example failed"
        }
    }
    finally {
        Remove-Item Env:_51DEGREES_EXAMPLE_URL -ErrorAction SilentlyContinue
        Write-Host "Stopping NGINX"
        ./nginx -s quit
    }

    # Test the examples. A static build links a single module, so make
    # runs only that module's examples, and they leave out load_module.
    $staticBuild = $BuildMethod -eq 'static' ? '_51DEGREES_STATIC_BUILD=1' : $null
    Write-Host "Looking for HASH file(s)..."
    Get-ChildItem -Recurse -Filter 'TAC-HashV41.hash'

    $HashFilePath = (Get-ChildItem "$PSScriptRoot/../../assets/TAC-HashV41.hash" | Select-Object -ExpandProperty FullName)
    Write-Host "Checking ($HashFilePath)..."
    Get-ChildItem "$HashFilePath"

    # The IP intelligence examples read the free Lite file that
    # ci/fetch-assets.ps1 puts in the assets folder.
    $IpiFilePath = (Get-Item "$PSScriptRoot/../../assets/51Degrees-LiteIpiV41.ipi").FullName
    Write-Host "Checking ($IpiFilePath)..."

    Write-Host "Testing examples"
    make test-examples $staticBuild _51DEGREES_DONT_CLEAN_TESTS=1 _51DEGREES_DD_PATH="$HashFilePath" _51DEGREES_IPI_PATH="$IpiFilePath" _51DEGREES_TEST_OUTPUT=$results/${Name}_Examples.xml

    # A fresh clone has the free Lite data file, which the Makefile uses when
    # no other file is named, so the examples run on it as well.
    Write-Host "Testing examples on the free Lite data file"
    make test-examples $staticBuild _51DEGREES_DONT_CLEAN_TESTS=1 _51DEGREES_TEST_OUTPUT=$results/${Name}_Examples_Lite.xml
} finally {
    Pop-Location
}
