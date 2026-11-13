param(
    [string]$Name = "1.21.3_dynamic",
    [string]$NginxVersion = "1.21.3",
    [string]$BuildMethod = "dynamic",
    [bool]$FullTests = $False,
    [bool]$MemCheck = $False
)
# Temporary. Measures how long upstream_sticky_learn.t's reload takes against
# NGINX Plus, with no 51Degrees module, with the module and the Lite data file,
# and with the module and the TAC data file. Not for merging.
$ErrorActionPreference = "Stop"
$repo = (Get-Item $PSScriptRoot/..).FullName
Push-Location $repo
try {
    if (-not (Test-Path tests/nginx-tests/lib/Test/Nginx.pm)) {
        New-Item -ItemType Directory -Force tests/nginx-tests | Out-Null
        curl -fsSL "https://github.com/nginx/nginx-tests/archive/refs/heads/master.tar.gz" | tar -xzC tests/nginx-tests --strip-components 1
    }
    & ./cxx/data/get-data-files.ps1 51Degrees-LiteV4.1.hash
    $global:LASTEXITCODE = 0

    $source = Get-Content -Raw tests/nginx-tests/upstream_sticky_learn.t
    $timer = @'

no warnings 'redefine';
use Time::HiRes ();
sub reload {
	my ($t) = @_;
	my $start = Time::HiRes::time();
	$t->reload();
	for (1 .. 1200) {
		if ($t->read_file('error.log') =~ /exited with code/) {
			Test::More::diag(sprintf('RELOAD %.3f', Time::HiRes::time() - $start));
			return 1;
		}
		select undef, undef, undef, 0.05;
	}
	Test::More::diag('RELOAD over 60 seconds');
	return 0;
}
'@
    Set-Content -NoNewline -Path tests/nginx-tests/measure_reload.t -Value ($source + $timer)

    sudo chmod -R a+xrw /var/lib
    $env:ALLOW_PASSING_TODOS = 'yep'
    $env:TEST_NGINX_BINARY = "/usr/sbin/nginx"
    /usr/sbin/nginx -v

    $module = "load_module $repo/build/modules/ngx_http_51D_module.so;"
    $cases = [ordered]@{
        "none" = @("", "")
        "lite" = @($module, "51D_file_path $repo/cxx/data/device-detection/51Degrees-LiteV4.1.hash;")
        "tac"  = @($module, "51D_file_path $repo/cxx/data/device-detection/TAC-HashV41.hash;")
    }
    Get-ChildItem cxx/data/device-detection/*.hash | ForEach-Object { Write-Host "$($_.Name) $((Get-Item $_.FullName).Length) bytes" }
    for ($round = 1; $round -le 10; $round++) {
        foreach ($case in $cases.Keys) {
            $env:TEST_NGINX_GLOBALS = "mgmt {license_token /etc/nginx/license.jwt;} $($cases[$case][0])"
            $env:TEST_NGINX_GLOBALS_HTTP = $cases[$case][1]
            $out = prove -v tests/nginx-tests/measure_reload.t 2>&1 | Out-String
            $reload = ($out -split "`n" | Where-Object { $_ -match 'RELOAD' }) -join ' '
            $failedTests = ($out -split "`n" | Where-Object { $_ -match '^not ok' }) -join ' | '
            Write-Host "MEASURE round=$round case=$case $reload failed=[$failedTests]"
        }
    }
} finally {
    Pop-Location
}
exit 0
