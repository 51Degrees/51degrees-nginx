#!/usr/bin/perl

# (C) Sergey Kandaurov
# (C) Maxim Dounin
# (C) Nginx, Inc.

# Tests for 51Degrees Hash module.

###############################################################################

use warnings;
use strict;
use File::Temp qw/ tempdir /;
use Test::More;
use File::Copy;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../nginx-tests/lib';
use Test::Nginx;
use URI::Escape;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

sub read_example($) {
	my ($name) = @_;
	open my $fh, '<', '../../examples/hash/' . $name or die "Can't open file $name: $!";
	read $fh, my $content, -s $fh;
	close $fh;

	return $content;
}

my $t = Test::Nginx->new()->has(qw/http/)->plan(5);

my $t_file = read_example('gettingStarted.conf');
# Remove the documentation block
$t_file =~ s/\/\*\*.+\*\//''/gmse;
# Replace all variable place holders.
$t_file =~ s/%%DAEMON_MODE%%/'off'/gmse;
$t_file =~ s/%%MODULE_PATH%%/$ENV{TEST_MODULE_PATH}/gmse;
# A static build links the module into the Nginx binary, so omit the
# load_module directive, which would fail to open a non existent shared
# object.
$t_file =~ s/^.*load_module.*
//mg if $ENV{TEST_NGINX_STATIC};
$t_file =~ s/%%FILE_PATH%%/$ENV{TEST_FILE_PATH}/gmse;
$t->write_file_expand('nginx.conf', $t_file);

$t->write_file('hash', '');

$t->run();

sub get_with_ua {
	my ($uri, $ua) = @_;
	return http(<<EOF);
HEAD $uri HTTP/1.1
Host: localhost
Connection: close
User-Agent: $ua

EOF
}

###############################################################################
# Constants.
###############################################################################

my $mobileUserAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53';

###############################################################################
# Test gettingStarted.conf example.
###############################################################################

my $r = get_with_ua('/hash', $mobileUserAgent);
like($r, qr/x-mobile: True/, 'Mobile match (single User-Agent)');
like($r, qr/x-device: [a-zA-Z ]+,[a-zA-Z ]+/, 'Mobile match (single User-Agent)');
like($r, qr/x-device-hinted: [a-zA-Z ]+,[a-zA-Z ]+/, 'Mobile match (single User-Agent)');

# The hardware properties are only in the Enterprise data file. On the free
# Lite data file they read NoMatch, and x-enterprise links to ask for a copy.
if (index($ENV{TEST_FILE_PATH}, '51Degrees-Lite') != -1) {
	like($r, qr/x-hardware: NoMatch,NoMatch,NoMatch\r/, 'Hardware needs the Enterprise data file');
	like($r, qr/x-enterprise: .+https:\/\/51degrees\.com\/contact-us\?/, 'Link to ask for the Enterprise data file');
}
else {
	unlike($r, qr/x-hardware: .*NoMatch/, 'Hardware matched');
	unlike($r, qr/x-enterprise:/, 'No link with the Enterprise data file');
}

###############################################################################

