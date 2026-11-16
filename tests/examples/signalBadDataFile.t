#!/usr/bin/perl

# Tests that nginx -s, which only sends a signal to the running master, does
# not read the data file the configuration names, so that it still works when
# that file is missing or cannot be used.

###############################################################################

use warnings;
use strict;
use File::Temp qw/ tempdir /;
use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $nginx = $ENV{TEST_NGINX_BINARY};
my $static = $ENV{TEST_NGINX_STATIC};
my $dir = tempdir('nginx-signal-XXXXXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $signalSeconds = 60;

# A dynamic build loads both modules. A static build links one, which nginx -V
# names among its configure arguments.
my @modules = ('hash', 'ipi');
if ($static) {
	my $built = `"$nginx" -V 2>&1`;
	@modules = grep { $built =~ /51Degrees_${_}_module/ } @modules;
}

my %directive = (hash => '51D_file_path', ipi => '51D_file_path_ipi');
my %library = (
	hash => 'ngx_http_51D_module.so',
	ipi => 'ngx_http_51D_ipi_module.so');

plan(tests => 2 * scalar(@modules));

foreach my $module (@modules) {
	my $load = $static ? '' :
		"load_module $ENV{TEST_MODULE_PATH}modules/$library{$module};";
	my $pidFile = "$dir/$module.pid";
	my $log = "$dir/$module.log";
	open my $conf, '>', "$dir/$module.conf"
		or die "Can't open $module.conf: $!";
	print $conf <<EOF;
$load
pid $pidFile;
error_log $log;
events {
}
http {
	$directive{$module} $dir/missing-$module.dat;
}
EOF
	close $conf or die "Can't close $module.conf: $!";

	# No master is running, so the signal cannot be sent, and nginx -s says
	# so once it reads the pid file.
	my $command = qq{timeout $signalSeconds "$nginx" -p "$dir/" } .
		qq{-c "$dir/$module.conf" -e "$log" -s quit 2>&1};
	my $output = `$command`;
	if (-e $log) {
		open my $fh, '<', $log or die "Can't open $log: $!";
		local $/;
		$output .= <$fh>;
	}
	unlike($output, qr/51Degrees/,
		"$module: nginx -s does not read the data file") or diag($output);
	like($output, qr/\Q$pidFile\E/,
		"$module: nginx -s goes on to the pid file") or diag($output);
}
