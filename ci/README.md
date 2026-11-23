# API Specific CI Approach

For the general CI Approach, see [common-ci](https://github.com/51degrees/common-ci).

The following secrets are required:
* `CI_ACCESS_TOKEN` - an organization secret that only CI uses, so it has no `_51DEGREES_` prefix. GitHub [access token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#about-personal-access-tokens) for cloning repos, creating PRs, etc.
    * Example: `github_pat_l0ng_r4nd0m_s7r1ng`
  
The following secrets are required to run tests:
* `_51DEGREES_LICENSE_KEY` - [license key](https://51degrees.com/pricing?utm_source=github&utm_medium=readme&utm_campaign=51degrees-nginx&utm_content=ci-readme.md&utm_term=api-specific-ci-approach) for downloading assets (the TAC data file)
    * Example: `V3RYL0NGR4ND0M57R1NG`

The following secrets are required to run the full set of tests against NGINX Plus. `setup-environment.ps1` reads each from the environment variable of the same name:
* `NGINX_PLUS_KEY` - Signing key used for installing NGINX Plus
* `NGINX_PLUS_CERT` - NGINX Plus certificate
* `NGINX_PLUS_JWT_TOKEN` - NGINX Plus license token

The [README](../README.md#names) lists the other names this repository reads. `names.Tests.ps1` checks that every name starts `_51DEGREES_`, except the names other tools define and the three NGINX Plus secrets above, which only CI uses and only the CI scripts may read. `run-unit-tests.ps1` runs it.

common-ci's export step puts a secret in the environment only when its name starts `_51DEGREES_`, common-ci's own list names it, or this repository's [`ci-secrets.psd1`](ci-secrets.psd1) lists it under `Scripts`. That file lists the three NGINX Plus secrets, so they reach `setup-environment.ps1` in the jobs that build and test, and no job that publishes.

### Differences
- There are no packages produced by this repository, so the only output from the `Nightly Publish Main` workflow is a new tag and release.
- The package update step does not update dependencies from a package manager in the same way as other repos. Instead it checks the supported versions on the [NGINX Plus Releases](https://docs.nginx.com/nginx/releases/) page, and uses that to update `options.json` to ensure they are tested.
- The configuration that installs NGINX Plus for the full test suite, the first in `options.json`, runs on `ubuntu-24.04`, and every other on `ubuntu-latest`. NGINX publishes NGINX Plus R36 and earlier for Ubuntu 24.04 but not for Ubuntu 26.04, which `ubuntu-latest` now is. Ubuntu 26.04 support came with NGINX Plus PLS.37, whose releases `update-packages.ps1` does not read.
- As Windows is not supported, the scripts here can be a little less strict with implementation. e.g. using `cp` rather than `Copy-Item` as we know we're in a Linux environment.
- The performance test configurations in `options.json` use stable names with no NGINX version, `ubuntu-latest` for device detection and `ubuntu-latest_IPI` for IP intelligence. The performance graphs published to the gh-images branch are named after the configuration, and the graph URLs are referenced from the documentation, so the names must not change between version updates. Each configuration runs only its own engine's performance test, selected by the `_IPI` name suffix in `run-performance-tests.ps1`.

### Build Options

The additional build options for this repo are:
| Option | Type | Default | Purpose |
| ------ | --------- | ---- | ------- |
| `NginxVersion` | string | `1.21.3` | The version of the opensource NGINX code to use for building and testing. |
| `MemCheck` | bool | `false` | If true the binaries are built in Debug, with memory checks enabled. |
| `BuildMethod` | string | `dynamic` | Can be either `static` or `dynamic` to determine how the nginx module is built |
| `FullTests` | bool | `false` | If true, then the full NGINX test suite is run. This should be set to true for the latest NGINX Plus version. |

`select-options.ps1` chooses what a pull request runs. Every entry runs, and
the full NGINX test suite only for a change in more than its comments outside
the examples. Performance runs only when `rc` itself or the release pull
request is built, which `.github/workflows/release-pull-request.yml` does on
every entry.

## Prerequisites

In addition to the [common prerequisites](https://github.com/51Degrees/common-ci#prerequisites), the following environment variables are required:
- `_51DEGREES_LICENSE_KEY` - License key to download a data file for testing
- `NGINX_PLUS_KEY` - Signing key used for installing NGINX Plus
- `NGINX_PLUS_CERT` - NGINX Plus certificate
- `NGINX_PLUS_JWT_TOKEN` - NGINX Plus license token
