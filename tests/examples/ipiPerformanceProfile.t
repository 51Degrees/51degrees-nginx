#!/usr/bin/perl

# Tests the performance profile of the 51Degrees IP Intelligence module.
# HighPerformance is the default. With some of the data file's properties
# named it holds only what they read, so it takes less shared memory than
# InMemory and gives the same answers, in workers that share it. A reload
# closes the master's handles to the data file it replaces, including one onto
# a configuration with no data file.

###############################################################################

use warnings;
use strict;
use Cwd qw/ abs_path /;
use File::Temp qw/ tempdir /;
use IO::Socket::INET;
use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $file = $ENV{TEST_FILE_PATH_IPI};
if (!defined $file || !-e $file) {
	plan(skip_all => 'No IP intelligence data file. Set TEST_FILE_PATH_IPI.');
}
if (!-d '/proc/self/fd') {
	plan(skip_all => 'The open files of the master are read from /proc.');
}

my $nginx = $ENV{TEST_NGINX_BINARY};
my $loadModule = $ENV{TEST_NGINX_STATIC} ? '' :
	"load_module $ENV{TEST_MODULE_PATH}modules/ngx_http_51D_ipi_module.so;";
my $dir = tempdir('nginx-ipi-profile-XXXXXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $port = 8099;
my $startSeconds = 300;
my $reloads = 2;

# Some but not all of the properties of the file, so that HighPerformance
# holds less than the whole file.
my $properties = $file =~ /Asn/ ? 'AsnName' :
	'RegisteredName,RegisteredCountry';

# IPv4 and IPv6 addresses from several networks.
my @addresses = (
	'212.58.224.22', '8.8.8.8', '1.1.1.1', '81.2.69.142', '50.154.29.201',
	'190.4.79.71', '2.248.13.139', '92.155.95.189', '138.67.87.157',
	'2001:4860:4860::8888', '2a00:1450:4009:81f::200e');

mkdir "$dir/html" or die "Can't create $dir/html: $!";
open my $page, '>', "$dir/html/ipi" or die "Can't create $dir/html/ipi: $!";
close $page;

sub read_text {
	my ($path) = @_;
	open my $fh, '<', $path or return '';
	local $/;
	return scalar <$fh>;
}

# Writes a configuration with the profile line given, which may be empty, and
# returns its path. With $noFile set it has no data file and no match.
sub write_conf {
	my ($name, $profile, $noFile) = @_;
	my $path = "$dir/$name.conf";
	my $fileLine = $noFile ? '' : "51D_file_path_ipi $file;";
	my $matchLine = $noFile ? '' :
		"51D_match_ipi x-answer $properties \$arg_client_ip;";
	open my $conf, '>', $path or die "Can't open $path: $!";
	print $conf <<EOF;
$loadModule
daemon on;
master_process on;
worker_processes 2;
pid $dir/$name.pid;
error_log $dir/$name.log notice;
events {
}
http {
	access_log off;
	$fileLine
	$profile
	server {
		listen 127.0.0.1:$port;
		root $dir/html;
		location /ipi {
			$matchLine
			add_header x-answer \$http_x_answer;
		}
	}
}
EOF
	close $conf or die "Can't close $path: $!";
	return $path;
}

# Runs NGINX with the configuration and arguments given, and returns its exit
# code and everything it wrote.
sub control {
	my ($name, @args) = @_;
	my $output = `timeout $startSeconds "$nginx" -p "$dir/" -c "$dir/$name.conf" -e "$dir/$name.log" @args 2>&1`;
	return ($? >> 8, $output);
}

# Runs the check once a second until it gives a true value or the seconds
# pass, and returns what it gave last.
sub wait_for {
	my ($seconds, $check) = @_;
	my $result = '';
	for (1 .. $seconds) {
		$result = $check->();
		last if $result;
		sleep 1;
	}
	return $result;
}

# Returns the response for the address, or an empty string when there is
# none.
sub fetch {
	my ($address) = @_;
	my $socket = IO::Socket::INET->new(
		PeerAddr => "127.0.0.1:$port", Timeout => 10) or return '';
	print $socket "GET /ipi?client_ip=$address HTTP/1.0\r\n" .
		"Host: localhost\r\n\r\n";
	local $/;
	my $response = <$socket> // '';
	close $socket;
	return $response;
}

# Returns the x-answer header for the address, or an empty string when there
# is no answer.
sub ask {
	my ($address) = @_;
	return fetch($address) =~ /^x-answer: ([^\r\n]*)/mi ? $1 : '';
}

sub ask_all {
	return { map { $_ => ask($_) } @addresses };
}

# Counts the descriptors the process has open on the data file.
sub handles {
	my ($pid) = @_;
	my $target = abs_path($file);
	opendir my $fds, "/proc/$pid/fd" or return -1;
	my $count = grep {
		my $link = readlink("/proc/$pid/fd/$_");
		defined $link && $link eq $target;
	} readdir $fds;
	closedir $fds;
	return $count;
}

# Returns the profile and the bytes of shared memory each time the module
# logged its data set, in order.
sub loads {
	my ($name) = @_;
	my $log = read_text("$dir/$name.log");
	my @loads;
	while ($log =~ /uses the (\w+) profile, with (\d+) bytes of shared memory/g) {
		push @loads, [$1, $2];
	}
	return @loads;
}

sub start {
	my ($name) = @_;
	my ($code, $output) = control($name);
	my $master = wait_for($startSeconds, sub {
		return read_text("$dir/$name.pid") =~ /(\d+)/ ? $1 : 0;
	});
	wait_for($startSeconds, sub { return ask($addresses[0]); });
	return $master;
}

# Stops NGINX, and any worker it started that outlived its master, so that a
# failure leaves nothing listening for the tests that follow.
sub stop {
	my ($name, $master) = @_;
	control($name, '-s', 'quit');
	wait_for(60, sub { return !-e "$dir/$name.pid"; });
	kill('TERM', $master) if $master && -e "$dir/$name.pid";
	my @workers = grep { opens_test_file($_) }
		read_text("$dir/$name.log") =~ /start worker process (\d+)/g;
	kill('QUIT', @workers) if @workers;
}

# Whether the process has a file in this test's folder open, so that only
# processes this test started are stopped.
sub opens_test_file {
	my ($pid) = @_;
	opendir my $fds, "/proc/$pid/fd" or return 0;
	my $found = grep {
		my $link = readlink("/proc/$pid/fd/$_");
		defined $link && index($link, $dir) == 0;
	} readdir $fds;
	closedir $fds;
	return $found;
}

plan(tests => 17);

###############################################################################
# The default.
###############################################################################

write_conf('default', '');
my $master = start('default');
ok($master, 'Default: NGINX starts') or diag(read_text("$dir/default.log"));
my @loads = loads('default');
is($loads[0][0], 'HighPerformance', 'Default: HighPerformance');
my $highPerformance = ask_all();
ok((grep { $_ ne '' && $_ !~ /NoMatch/ } values %$highPerformance) > 0,
	'Default: answers the addresses');

# The workers inherit the master's handles to the data file. A reload loads
# the file again, and closes the master's handles to the one it replaces.
my $handles = handles($master);
ok($handles > 0, 'Default: the master keeps handles to the data file');
for my $reload (1 .. $reloads) {
	control('default', '-s', 'reload');
	wait_for($startSeconds, sub { return loads('default') > $reload; });
}
is(scalar(loads('default')), 1 + $reloads, 'Default: the reloads load the file');
is(handles($master), $handles,
	'Default: the reloads leave the master the same handles');
is_deeply(ask_all(), $highPerformance, 'Default: the same answers after the reloads');

# A reload onto a configuration with no data file leaves the master running,
# and closes its handles to the data file it had.
write_conf('default', '', 1);
control('default', '-s', 'reload');
ok(wait_for(60, sub {
	my $response = fetch($addresses[0]);
	return $response =~ /^HTTP\/1\.\d 200/ && $response !~ /^x-answer:/mi;
}), 'No data file: the new workers answer without IP intelligence');
ok(read_text("/proc/$master/stat") =~ /^\d+ \(.*\) [^Z]/,
	'No data file: the master keeps running');
is(handles($master), 0, 'No data file: the master closes its handles');
stop('default', $master);
unlike(read_text("$dir/default.log"), qr/ERROR: (Address|Leak)Sanitizer/,
	'Default: no memory error');

###############################################################################
# InMemory, set with the directive.
###############################################################################

write_conf('in_memory', '51D_performance_profile_ipi IN_MEMORY;');
$master = start('in_memory');
my @inMemoryLoads = loads('in_memory');
is($inMemoryLoads[0][0], 'InMemory', 'IN_MEMORY: InMemory');
is_deeply(ask_all(), $highPerformance,
	'IN_MEMORY: the answers HighPerformance gives');
stop('in_memory', $master);
ok($loads[0][1] < $inMemoryLoads[0][1],
	"HighPerformance takes less shared memory, $loads[0][1] bytes against " .
	"$inMemoryLoads[0][1]");

###############################################################################
# HighPerformance, set with the directive, and a profile that is not offered.
###############################################################################

write_conf('high_performance',
	'51D_performance_profile_ipi HIGH_PERFORMANCE;');
my ($code, $output) = control('high_performance', '-t');
my @highPerformanceLoads = loads('high_performance');
is($highPerformanceLoads[0][0], 'HighPerformance',
	'HIGH_PERFORMANCE: HighPerformance') or diag($output);

write_conf('balanced', '51D_performance_profile_ipi BALANCED;');
($code, $output) = control('balanced', '-t');
isnt($code, 0, 'BALANCED: nginx -t fails');
like($output . read_text("$dir/balanced.log"), qr/invalid value "BALANCED"/,
	'BALANCED: logs the value it cannot use');
