param(
    # Every entry of options.json.
    [Parameter(Mandatory)][object[]]$Options,
    # The files the pull request changes, less documentation.
    [string[]]$ChangedFiles,
    # Those of the changed files whose change touches only comments.
    [string[]]$CommentOnlyFiles
)
# Chooses the options.json entries a pull request is built on, for common-ci's
# steps/select-options.ps1. The branch itself and a release build every entry.
#
# Every entry runs, as each builds and tests the modules against its own NGINX
# version or build method in a few minutes. The full NGINX test suite, which
# FullTests runs twice in about 23 minutes, runs only for a change in more
# than its comments to anything but the examples, such as the modules, the
# cxx submodule, the tests or CI. Performance is left to the branch and
# release builds.

$code = @($ChangedFiles | Where-Object { $CommentOnlyFiles -notcontains $_ })
$full = @($code | Where-Object { !$_.StartsWith('examples/') }).Count -gt 0
Write-Host "A change to more than comments outside the examples: $full."

foreach ($entry in $Options) {
    if ($entry.FullTests -and !$full) {
        $entry.FullTests = $false
        Write-Host "$($entry.Name) runs without the full NGINX test suite"
    } else {
        Write-Host "$($entry.Name) runs"
    }
    $entry.RunPerformance = $false
    $entry
}
