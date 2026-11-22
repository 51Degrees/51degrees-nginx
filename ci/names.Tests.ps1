# Checks the names this repository reads and sets. Every setting that
# 51Degrees defines is named _51DEGREES_<NAME>, whether it is a make option, an
# environment variable, a Docker build argument or a workflow variable. A name
# another tool defines is used as that tool requires, and those are listed
# below. The README lists every _51DEGREES_ name.
#
# Run it from the repository root in a process of its own:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ci"

BeforeAll {
    $script:Repo = (Resolve-Path "$PSScriptRoot/..").Path
    $script:Ours = '^_51DEGREES_[A-Z0-9_]+$'

    # Names that belong to another tool: NGINX's test library, the sanitizers,
    # make, the shell and GitHub Actions.
    $script:Tools = @(
        'TEST_NGINX_BINARY', 'TEST_NGINX_GLOBALS', 'TEST_NGINX_GLOBALS_HTTP',
        'ALLOW_PASSING_TODOS', 'ASAN_OPTIONS', 'LSAN_OPTIONS', 'MAKELEVEL',
        'PATH', 'PWD', 'BASH_SOURCE', 'GITHUB_TOKEN'
    )

    function script:Get-RepoFile ([string[]]$Pattern) {
        Push-Location $script:Repo
        try {
            @(git ls-files -- $Pattern) | Where-Object { $_ } | ForEach-Object {
                [pscustomobject]@{
                    Name  = $_
                    Lines = @(Get-Content -LiteralPath (Join-Path $script:Repo $_))
                }
            }
        } finally {
            Pop-Location
        }
    }

    # The matches of a pattern's first group in each line of the files, less
    # the names that are ours or a tool's, as "file:line: name".
    function script:Find-OtherName ($Files, [string]$Pattern, [string]$LineFilter = '') {
        foreach ($file in $Files) {
            for ($i = 0; $i -lt $file.Lines.Count; $i++) {
                $line = $file.Lines[$i]
                if ($LineFilter -and $line -notmatch $LineFilter) { continue }
                foreach ($match in [regex]::Matches($line, $Pattern)) {
                    $name = $match.Groups[1].Value
                    if ($name -cnotmatch $script:Ours -and $script:Tools -cnotcontains $name) {
                        "$($file.Name):$($i + 1): $name"
                    }
                }
            }
        }
    }

    $script:Makefile = Get-RepoFile 'Makefile'
    $script:CiScripts = Get-RepoFile 'ci/*.ps1' | Where-Object { $_.Name -notlike '*.Tests.ps1' }
    $script:PerlTests = Get-RepoFile 'tests/*.t', 'tests/*.pm', 'tests/*.pl'
    $script:ShellScripts = Get-RepoFile '*.sh'
    $script:Workflows = Get-RepoFile '.github/workflows/*.yml'
    $script:Dockerfiles = Get-RepoFile '*Dockerfile'
}

Describe 'The names the Makefile takes' {
    It 'tests only _51DEGREES_ names with ifdef and ifndef' {
        Find-OtherName $Makefile '^\s*ifn?def\s+(\w+)' | Should -BeNullOrEmpty
    }

    It 'compares only _51DEGREES_ options with ifeq and ifneq' {
        # The Makefile's own working values are compared only with each other.
        $own = 'FILEPATH', 'FILEPATH_IPI', 'DEFAULT_FILEPATH', 'DEFAULT_FILEPATH_IPI', 'FULLPATH', 'MAKECMDGOALS'
        Find-OtherName $Makefile '\$\((\w+)\)' '^\s*(else\s+)?ifn?eq\b' |
            Where-Object { $own -cnotcontains ($_ -split ': ')[-1] } |
            Should -BeNullOrEmpty
    }

    It 'gives another make only _51DEGREES_ names' {
        Find-OtherName $Makefile '(?<![\w$(])([A-Za-z_]\w*)=' '\$\(MAKE\)' | Should -BeNullOrEmpty
    }

    It 'gives the tests only _51DEGREES_ names and the test library''s own' {
        Find-OtherName $Makefile '(?<![\w$(])([A-Za-z_]\w*)="' '\bprove\b' | Should -BeNullOrEmpty
    }
}

Describe 'The names the CI scripts use' {
    It 'reads and sets only _51DEGREES_ environment variables and tools'' own' {
        Find-OtherName $CiScripts '(?i)\$env:(\w+)' | Should -BeNullOrEmpty
    }

    It 'gives make only _51DEGREES_ options' {
        Find-OtherName $CiScripts '(?<![\w$:.-])([A-Z_][A-Z0-9_]+)=(?!=)' | Should -BeNullOrEmpty
    }

    It 'takes no secret as a parameter' {
        $found = foreach ($file in $CiScripts) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                (Join-Path $Repo $file.Name), [ref]$null, [ref]$null)
            if ($ast.ParamBlock) {
                foreach ($parameter in $ast.ParamBlock.Parameters) {
                    $name = $parameter.Name.VariablePath.UserPath
                    if ($name -match '(Key|Keys|Cert|Token|Password|Secret|Url)$' -or
                        $name -match '^(DeviceDetection|IpIntelligence)') {
                        "$($file.Name): $name"
                    }
                }
            }
        }
        $found | Should -BeNullOrEmpty
    }
}

Describe 'The names the tests read' {
    It 'reads only _51DEGREES_ environment variables and the test library''s own in Perl' {
        $found = @(Find-OtherName $PerlTests '\$ENV\{\s*["'']?([A-Za-z_]\w*)')
        # A list of names, as in @ENV{qw(ONE TWO)}, may run over several lines.
        foreach ($file in $PerlTests) {
            foreach ($list in [regex]::Matches(($file.Lines -join "`n"), '@ENV\{qw\(([^)]*)\)')) {
                foreach ($name in (-split $list.Groups[1].Value)) {
                    if ($name -cnotmatch $Ours -and $Tools -cnotcontains $name) {
                        $found += "$($file.Name): $name"
                    }
                }
            }
        }
        $found | Should -BeNullOrEmpty
    }

    It 'reads only _51DEGREES_ names from the environment in shell scripts' {
        # A variable a script reads before it sets it comes from the
        # environment.
        $found = foreach ($file in $ShellScripts) {
            $set = [System.Collections.Generic.HashSet[string]]::new()
            for ($i = 0; $i -lt $file.Lines.Count; $i++) {
                $line = $file.Lines[$i]
                if ($line -match '^\s*#') { continue }
                foreach ($match in [regex]::Matches($line, '(?<!\\)\$\{?([A-Za-z_]\w*)')) {
                    $name = $match.Groups[1].Value
                    if (-not $set.Contains($name) -and $name -cnotmatch $Ours -and
                        $Tools -cnotcontains $name) {
                        "$($file.Name):$($i + 1): $name"
                    }
                }
                foreach ($match in [regex]::Matches($line, '(?:^|[\s;(])(?:export\s+|local\s+|for\s+|read\s+)?([A-Za-z_]\w*)(?:=|\s+in\s)')) {
                    [void]$set.Add($match.Groups[1].Value)
                }
            }
        }
        $found | Should -BeNullOrEmpty
    }
}

Describe 'The names the workflows and the Docker example use' {
    It 'sets only _51DEGREES_ variables in a workflow env block' {
        $found = foreach ($file in $Workflows) {
            $indent = -1
            for ($i = 0; $i -lt $file.Lines.Count; $i++) {
                $line = $file.Lines[$i]
                if ($line -match '^\s*(#.*)?$') { continue }
                $depth = ($line -replace '^(\s*).*$', '$1').Length
                if ($indent -ge 0 -and $depth -le $indent) { $indent = -1 }
                if ($indent -ge 0 -and $line -match '^\s*([A-Za-z_]\w*)\s*:') {
                    $name = $Matches[1]
                    if ($name -cnotmatch $Ours -and $Tools -cnotcontains $name) {
                        "$($file.Name):$($i + 1): $name"
                    }
                }
                if ($line -match '^\s*env:\s*$') { $indent = $depth }
            }
        }
        $found | Should -BeNullOrEmpty
    }

    It 'reads only _51DEGREES_ secrets and variables in a workflow' {
        Find-OtherName $Workflows '\b(?:secrets|vars)\.(\w+)' | Should -BeNullOrEmpty
    }

    It 'gives Docker only _51DEGREES_ build arguments' {
        Find-OtherName $Workflows '--build-arg\s+"?([A-Za-z_]\w*)' | Should -BeNullOrEmpty
    }

    It 'takes only _51DEGREES_ build arguments in a Dockerfile' {
        Find-OtherName $Dockerfiles '^\s*ARG\s+(\w+)' | Should -BeNullOrEmpty
    }
}

Describe 'The evidence the tests send' {
    It 'is YAML, so no file names a CSV file' {
        $files = Get-RepoFile 'Makefile', '*.sh', '*.ps1', '*.md', '*.t', '*.txt', '*.yml', '*.template' |
            Where-Object { $_.Name -notlike '*.Tests.ps1' }
        Find-OtherName $files '(\S*\.csv)\b' | Should -BeNullOrEmpty
    }
}

Describe 'The list of names in the README' {
    It 'has every _51DEGREES_ name the repository reads' {
        $readme = Get-Content -Raw -LiteralPath (Join-Path $Repo 'README.md')
        $files = @($Makefile) + @($CiScripts) + @($PerlTests) + @($ShellScripts) + @($Workflows) + @($Dockerfiles)
        $names = foreach ($file in $files) {
            foreach ($line in $file.Lines) {
                [regex]::Matches($line, '(?<![\w.])_51DEGREES_[A-Z0-9_]+') | ForEach-Object { $_.Value }
            }
        }
        $missing = $names | Sort-Object -Unique |
            Where-Object { $readme -cnotmatch ('`' + [regex]::Escape($_) + '`') }
        $missing | Should -BeNullOrEmpty
    }
}
