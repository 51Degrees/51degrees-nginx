# Checks that the CI scripts name the data files the examples and tests read,
# so that they read the files ci/fetch-assets.ps1 fetches. A test run with no
# file named uses the free file in cxx/data.
#
# Run it from the repository root in a process of its own:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ci"

BeforeAll {
    $script:Repo = (Resolve-Path "$PSScriptRoot/..").Path

    function script:Get-ScriptAst ([string]$Name) {
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $script:Repo $Name), [ref]$null, [ref]$null)
    }

    # The commands in a script whose name and arguments start with the words
    # given, as "make test-examples".
    function script:Find-Command ($Ast, [string[]]$Words) {
        $Ast.FindAll({
            param($node)
            if ($node -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
            $elements = $node.CommandElements
            if ($elements.Count -lt $Words.Count) { return $false }
            for ($i = 0; $i -lt $Words.Count; $i++) {
                if ($elements[$i].Extent.Text -ne $Words[$i]) { return $false }
            }
            return $true
        }, $true)
    }

    # The names a command gives make, as NAME=value, by name.
    function script:Get-MakeName ($Command) {
        $names = @{}
        foreach ($element in $Command.CommandElements) {
            if ($element.Extent.Text -match '^(_51DEGREES_\w+)=(.*)$') {
                $names[$Matches[1]] = $Matches[2]
            }
        }
        $names
    }

    # The assets ci/fetch-assets.ps1 fetches, from the string constants it
    # names them with.
    $fetch = Get-ScriptAst 'ci/fetch-assets.ps1'
    $script:Assets = @($fetch.FindAll({
        param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
    }, $true) | ForEach-Object Value)
}

Describe 'The data files the examples read in CI' {
    It 'names the IP intelligence file where the device detection file is named' {
        $ast = Get-ScriptAst 'ci/run-integration-tests.ps1'
        $named = @(Find-Command $ast 'make', 'test-examples' |
            Where-Object { (Get-MakeName $_).ContainsKey('_51DEGREES_DD_PATH') })
        $named.Count | Should -BeGreaterThan 0 -Because 'the examples run on the device detection file CI fetches'
        foreach ($command in $named) {
            (Get-MakeName $command).Keys | Should -Contain '_51DEGREES_IPI_PATH' -Because $command.Extent.Text
        }
    }

    It 'names an IP intelligence file that ci/fetch-assets.ps1 fetches' {
        $text = Get-Content -Raw -LiteralPath (Join-Path $Repo 'ci/run-integration-tests.ps1')
        $files = @([regex]::Matches($text, 'assets/([^"/]+\.ipi)') | ForEach-Object { $_.Groups[1].Value })
        $files.Count | Should -BeGreaterThan 0
        foreach ($file in $files) {
            $Assets | Should -Contain $file
        }
    }
}

Describe 'The data file the IP intelligence performance test reads in CI' {
    It 'is named with _51DEGREES_IPI_PATH before the test runs' {
        $ast = Get-ScriptAst 'ci/run-performance-tests.ps1'
        $run = @(Find-Command $ast './runPerf.sh', 'ipi')
        $run.Count | Should -Be 1
        $set = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left.Extent.Text -eq '$env:_51DEGREES_IPI_PATH' -and
            $node.Right.Extent.Text -ne '$null'
        }, $true) | Where-Object { $_.Extent.EndOffset -lt $run[0].Extent.StartOffset })
        $set.Count | Should -BeGreaterThan 0
    }
}

Describe 'The data file the Docker example loads in CI' {
    BeforeAll {
        $script:Workflow = Get-Content -Raw -LiteralPath (
            Join-Path $Repo '.github/workflows/docker-example.yml')
        # The Dockerfile's instructions, one to a line, with the lines a
        # backslash continues joined.
        $dockerfile = Get-Content -Raw -LiteralPath (
            Join-Path $Repo 'examples/curl/Dockerfile')
        $script:Instructions = @(($dockerfile -replace '\\\r?\n', ' ') -split '\r?\n')
        $script:Download = @($Instructions | Where-Object {
            $_ -match '^RUN .*get-data-files\.sh' })
        # The data files the script is asked for, the words after its name
        # that are not options.
        $script:DataFiles = @(if ($Download.Count -eq 1) {
            ($Download[0] -split 'get-data-files\.sh', 2)[1] -split '\s+' |
                Where-Object { $_ -match '^51Degrees-[\w.-]+\.(hash|ipi)$' }
        })
    }

    It 'is asked of the data repository''s script in one instruction' {
        $Download.Count | Should -Be 1
        $DataFiles.Count | Should -BeGreaterThan 0
    }

    It 'is taken from beside the Dockerfile, through a mount, before the script' {
        $Download[0] | Should -Match '^RUN --mount=type=bind,target=(\S+) '
        $context = [regex]::Escape(
            ([regex]::Match($Download[0], 'target=(\S+)')).Groups[1].Value)
        foreach ($file in $DataFiles) {
            $Download[0] | Should -Match "cp $context/$([regex]::Escape($file)) .*get-data-files\.sh" -Because $file
        }
        # A COPY of a data file would keep a second copy in an image layer.
        $Instructions | Where-Object { $_ -match '^(COPY|ADD) .*\.(hash|ipi)\b' } |
            Should -BeNullOrEmpty
    }

    It 'is fetched by the fetch-assets action and put in the build context' {
        $Workflow | Should -Match 'uses: 51Degrees/common-ci/actions/fetch-assets@'
        $Workflow | Should -Match '(?m)^\s+cache: true\s*$'
        # A cache restore of its own finds nothing for many runs and leaves
        # the image to download the file.
        $Workflow | Should -Not -Match 'actions/cache'
        $assets = [regex]::Match($Workflow, '(?m)^\s+assets: (.+)$').Groups[1].Value
        foreach ($file in $DataFiles) {
            $assets -split '\s+' | Should -Contain $file
            $Workflow | Should -Match "cp assets/$([regex]::Escape($file)) examples/curl/"
        }
    }

    It 'is built with the Distributor out of reach' {
        $build = ($Workflow -split '\r?\n' |
            Select-String -Pattern 'docker build' -Context 0, 3 |
            Select-Object -First 1)
        $build | Should -Not -BeNullOrEmpty
        ($build.Line + ' ' + ($build.Context.PostContext -join ' ')) |
            Should -Match '--add-host distributor\.51degrees\.com:127\.0\.0\.1'
    }
}
