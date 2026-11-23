# The organization secrets that only this repository's own CI scripts read.
# common-ci exports the names under Scripts to the jobs that run this
# repository's build and test scripts, and to no job that publishes or signs.
# setup-environment.ps1 reads these three to install NGINX Plus for the full
# tests.
@{
    Scripts = @(
        'NGINX_PLUS_KEY'
        'NGINX_PLUS_CERT'
        'NGINX_PLUS_JWT_TOKEN'
    )
}
