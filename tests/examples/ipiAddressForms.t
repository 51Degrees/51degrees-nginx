#!/usr/bin/perl

# Tests which client IP values the 51Degrees IP Intelligence module reads.
# A value is read only when all of it is one address, as the IP Intelligence
# specification's "Reading the client IP value" section says. Any other value
# gives no value and is not an error.

###############################################################################

use warnings;
use strict;
use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../nginx-tests/lib';
use Test::Nginx;
use POSIX qw/ WNOHANG /;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

# A full IP Intelligence data file can take tens of seconds to load, longer
# than the five seconds Test::Nginx waits for the pid file.
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

my $ipiFilePath = $ENV{TEST_FILE_PATH_IPI};
if (!defined $ipiFilePath || !-e $ipiFilePath) {
	plan(skip_all => 'No IP intelligence data file. Set TEST_FILE_PATH_IPI.');
}

my $loadModule = $ENV{TEST_NGINX_STATIC} ? '' :
	"load_module $ENV{TEST_MODULE_PATH}modules/ngx_http_51D_ipi_module.so;";

# One worker, so that each request follows the one before on the same
# results. Two directives read the same header, so the second reuses the
# first one's lookup.
my $t = Test::Nginx->new()->has(qw/http/)->plan(25);
$t->write_file_expand('nginx.conf', <<"EOF");

%%TEST_GLOBALS%%

daemon off;
worker_processes 1;
$loadModule

events {
}

http {
	%%TEST_GLOBALS_HTTP%%

	51D_file_path_ipi $ipiFilePath;

	server {
		listen 127.0.0.1:8080;
		server_name localhost;

		location /ipi {
			51D_match_ipi x-asn AsnName \$http_x_test_ip;
			51D_match_ipi x-asn-again AsnName \$http_x_test_ip;
			add_header x-asn \$http_x_asn;
			add_header x-asn-again \$http_x_asn_again;
		}
	}
}

EOF

$t->write_file('ipi', '');
$t->run();

sub get_with_ip {
	my ($ip) = @_;
	return http(<<EOF);
HEAD /ipi HTTP/1.1
Host: localhost
X-Test-IP: $ip
Connection: close

EOF
}

###############################################################################

# An address with a stable registration present in every IP Intelligence
# data file.
my $knownIp = '212.58.224.22';

my $r = get_with_ip($knownIp);
my ($known) = $r =~ /x-asn: (.*)\r/;
ok(defined $known && $known ne 'NoMatch', 'A single address is read');

like(get_with_ip("$knownIp:80"), qr/x-asn: \Q$known\E\r/,
	'An address with a port is read as the address');

# Each value that is not one whole address gives no value, for both
# directives, after a request that gave a value on the same worker.
my @notRead = (
	["$knownIp, 2.248.13.139", 'A list of addresses'],
	['212.58.224.0/24', 'A prefix length'],
	["$knownIp x", 'Text after the address'],
	['256.58.224.22', 'A part above 255'],
	['212.058.224.22', 'A leading zero in a part'],
	['fe80::1%eth0', 'A zone index'],
	['unknown', 'Not an address'],
);
foreach my $case (@notRead) {
	my ($value, $name) = @$case;
	get_with_ip($knownIp);
	$r = get_with_ip($value);
	like($r, qr/^HTTP\/1\.1 200/, "$name: the request succeeds");
	like($r, qr/x-asn: NoMatch\r/, "$name: no value");
	like($r, qr/x-asn-again: NoMatch\r/, "$name: no value for the second directive");
}

like(get_with_ip($knownIp), qr/x-asn: \Q$known\E\r/,
	'A single address after the others is read again');

$t->stop();

unlike($t->read_file('error.log'), qr/\[(error|crit|alert|emerg)\]/,
	'A value that is not read is not an error');

###############################################################################
