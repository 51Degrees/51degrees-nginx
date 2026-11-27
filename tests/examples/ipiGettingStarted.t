#!/usr/bin/perl

# (C) Sergey Kandaurov
# (C) Maxim Dounin
# (C) Nginx, Inc.

# Tests for 51Degrees IP Intelligence module.

###############################################################################

use warnings;
use strict;
use File::Temp qw/ tempdir /;
use Test::More;
use File::Copy;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../nginx-tests/lib';
use lib '../lib';
use FiftyOneBuild qw(build_path static_build);
use FiftyOneDataFiles qw(ipi_file_path);
use Test::Nginx;
use URI::Escape;
use POSIX qw/ WNOHANG /;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

# A full IP intelligence data file is loaded into shared memory before the
# master process writes its pid file, which can take tens of seconds. The
# five second wait in Test::Nginx::waitforfile is too short for that, so
# extend it to two minutes. The loop still returns as soon as the pid file
# appears, so small data files are unaffected.
{
	no warnings 'redefine';
	*Test::Nginx::waitforfile = sub ($;$) {
		my ($self, $file, $pid) = @_;
		my $exited;

		for (1 .. 1200) {
			return 1 if -e $file;
			return 0 if $exited;
			$exited = waitpid($pid, WNOHANG) != 0 if $pid;
			select undef, undef, undef, 0.1;
		}

		return undef;
	};
}

sub read_example($) {
	my ($name) = @_;
	open my $fh, '<', '../../examples/ipi/' . $name or die "Can't open file $name: $!";
	read $fh, my $content, -s $fh;
	close $fh;

	return $content;
}

# The IP intelligence data file is optional for the test suite. Skip the
# tests when _51DEGREES_IPI_PATH is not set.
my $ipiFilePath = ipi_file_path();
if (!defined $ipiFilePath) {
	plan(skip_all => 'No IP intelligence data file. Set _51DEGREES_IPI_PATH.');
}

my $t = Test::Nginx->new()->has(qw/http/)->plan(10);

my $t_file = read_example('gettingStarted.conf');
# Remove the documentation block
$t_file =~ s/\/\*\*.+\*\//''/gmse;
# Replace all variable place holders.
$t_file =~ s/%%DAEMON_MODE%%/'off'/gmse;
$t_file =~ s/%%MODULE_PATH%%/build_path()/gmse;
# A static build links the module into the Nginx binary, so omit the
# load_module directive, which would fail to open a non existent shared
# object.
$t_file =~ s/^.*load_module.*
//mg if static_build();
$t_file =~ s/%%FILE_PATH_IPI%%/$ipiFilePath/gmse;
$t->write_file_expand('nginx.conf', $t_file);

$t->write_file('ipi', '');

$t->run();

sub get_uri {
	my ($uri) = @_;
	return http(<<EOF);
HEAD $uri HTTP/1.1
Host: localhost
Connection: close

EOF
}

###############################################################################
# Constants.
###############################################################################

# An IP address with a stable, well known network registration which is
# expected to be present in all IP intelligence data files. The test runs
# on a local machine where the client IP address reported by Nginx is a
# loopback address, so this address is passed in the client_ip query
# string argument to override the reported client IP address for the
# match.
my $knownIp = '212.58.224.22';

###############################################################################
# Test ipi/gettingStarted.conf example.
###############################################################################

my $r = get_uri('/ipi?client_ip=' . $knownIp);
like($r, qr/x-registered-name: .+/, 'Registered name set (client IP)');
like($r, qr/x-registered-name-query: .+/, 'Registered name set (query IP)');
unlike($r, qr/x-registered-name-query: (NoMatch)?\r/, 'Query IP matched');

# The location properties are only in the Enterprise data file. On a free
# data file they read NoMatch, and x-enterprise links to ask for a copy.
if (index($ipiFilePath, 'Enterprise') == -1) {
	like($r, qr/x-location-query: NoMatch,NoMatch,NoMatch\r/, 'Location needs the Enterprise data file');
	like($r, qr/x-enterprise: .+https:\/\/51degrees\.com\/contact-us\?/, 'Link to ask for the Enterprise data file');
}
else {
	unlike($r, qr/x-location-query: .*NoMatch/, 'Location matched');
	unlike($r, qr/x-enterprise:/, 'No link with the Enterprise data file');
}

# Where the client_ip query argument is absent the directive which uses
# $arg_client_ip falls back to the client IP address, so both headers
# carry the same value.
$r = get_uri('/ipi');
my ($registered) = $r =~ /x-registered-name: (.*)\r/;
my ($registeredQuery) = $r =~ /x-registered-name-query: (.*)\r/;
like($r, qr/x-registered-name-query: .+/, 'Registered name set without client_ip argument');
is($registeredQuery, $registered, 'Empty variable falls back to the client IP match');

# The client IP address text held by nginx is not null terminated, so a
# parse failure here indicates the module has passed it to the engine
# without taking a null terminated copy.
unlike($t->read_file('error.log'), qr/IP address format is incorrect/,
	'Client IP address parsed');

# The example ends its own headers with where to find out more.
my $findOutMore = 'This module is at https://github.com/51Degrees/51degrees-nginx and the engine it uses at https://github.com/51Degrees/51degrees-cxx. Read about IP intelligence at https://51degrees.com/ip-intelligence?utm_source=code&utm_medium=example&utm_campaign=51degrees-nginx&utm_content=examples-ipi-gettingstarted.conf&utm_term=ip-intelligence and about data files and pricing at https://51degrees.com/pricing?utm_source=code&utm_medium=example&utm_campaign=51degrees-nginx&utm_content=examples-ipi-gettingstarted.conf&utm_term=pricing';
like($r, qr/^x-find-out-more: \Q$findOutMore\E\r$/m, 'Find out more');
unlike($r, qr/\nx-find-out-more:[^\n]*\n(?:[^\n]*\n)*?x-/,
	'No example header after Find out more');

###############################################################################
