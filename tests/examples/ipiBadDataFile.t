#!/usr/bin/perl

# Tests that the 51Degrees IP Intelligence module refuses a data file it cannot
# use, with a message naming the file, rather than starting without one, and
# that a reload onto such a file leaves NGINX answering from the file it has.

###############################################################################

use warnings;
use strict;
use File::Spec;
use File::Temp qw/ tempdir /;
use IO::Socket::INET;
use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

# The files that are refused are made from a good data file.
my $goodFile = $ENV{TEST_FILE_PATH_IPI};
if (!defined $goodFile || !-e $goodFile) {
	plan(skip_all => 'No IP intelligence data file. Set TEST_FILE_PATH_IPI.');
}

# Where the header of a data file holds its minor version and profile offset
# shift, as 32 bit integers.
my $minorVersionOffset = 4;
my $shiftOffset = 54;

my $nginx = $ENV{TEST_NGINX_BINARY};
my $dir = tempdir('nginx-ipi-XXXXXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $loadModule = $ENV{TEST_NGINX_STATIC} ? '' :
	"load_module $ENV{TEST_MODULE_PATH}modules/ngx_http_51D_ipi_module.so;";

sub read_binary {
	my ($path) = @_;
	open my $fh, '<:raw', $path or die "Can't open $path: $!";
	local $/;
	return scalar <$fh>;
}

sub write_binary {
	my ($name, $content) = @_;
	my $path = "$dir/$name";
	open my $fh, '>:raw', $path or die "Can't open $path: $!";
	print $fh $content;
	close $fh or die "Can't close $path: $!";
	return $path;
}

sub with_int32 {
	my ($content, $offset, $value) = @_;
	substr($content, $offset, 4) = pack('l<', $value);
	return $content;
}

# Runs NGINX with the arguments given, stopping it if it stays up. Returns its
# exit code, which is 124 if it had to be stopped and over 127 after a signal,
# and everything it wrote.
sub run_nginx {
	my ($file, @args) = @_;
	open my $conf, '>', "$dir/nginx.conf" or die "Can't open nginx.conf: $!";
	print $conf <<EOF;
$loadModule
daemon off;
master_process off;
pid $dir/nginx.pid;
error_log $dir/error.log;
events {
}
http {
	access_log off;
	51D_file_path_ipi $file;
	server {
		listen 127.0.0.1:8097;
	}
}
EOF
	close $conf or die "Can't close nginx.conf: $!";
	unlink "$dir/error.log";

	my $command = qq{timeout 60 "$nginx" -p "$dir/" -c "$dir/nginx.conf" } .
		qq{-e "$dir/error.log" @args 2>&1};
	my $output = `$command`;
	my $code = $? >> 8;
	if (-e "$dir/error.log") {
		$output .= read_binary("$dir/error.log");
	}
	return ($code, $output);
}

sub expect_refused {
	my ($name, $file, $reason, $mode, @args) = @_;
	my ($code, $output) = run_nginx($file, @args);
	ok($code != 0 && $code != 124 && $code < 128,
		"$name: $mode fails without a signal")
		or diag("Exit code $code\n$output");
	unlike($output, qr/ERROR: AddressSanitizer/,
		"$name: $mode has no memory error");
	like($output, qr/51Degrees.*\Q$file\E/,
		"$name: $mode logs a message naming the file");
	like($output, $reason, "$name: $mode logs the reason");
}

my $good = read_binary($goodFile);
my @files = (
	['Missing file', "$dir/missing.ipi", qr/could not be found/],
	['Empty file', write_binary('empty.ipi', ''),
		qr/unknown error occurred accessing the file/],
	['Too short for a header',
		write_binary('short.ipi', substr($good, 0, 16)),
		qr/not in the correct format/],
	['Cut short', write_binary('cut.ipi', substr($good, 0, 4096)),
		qr/not in the correct format/],
	['Minor version it cannot read',
		write_binary('version.ipi',
			with_int32($good, $minorVersionOffset, 5)),
		qr/is an unsupported version/],
	['Shift it cannot read',
		write_binary('shift.ipi', with_int32($good, $shiftOffset, 99)),
		qr/is an unsupported version/],
);

plan(tests => 1 + scalar(@files) * 8 + 8);

# A good file passes with the same configuration, so that the failures below
# come from the data file.
my ($goodCode, $goodOutput) = run_nginx($goodFile, '-t');
is($goodCode, 0, 'Good file: nginx -t passes') or diag($goodOutput);

foreach my $entry (@files) {
	my ($name, $file, $reason) = @$entry;
	expect_refused($name, $file, $reason, 'nginx -t', '-t');
	expect_refused($name, $file, $reason, 'starting');
}

# A reload onto a file the module cannot use is refused, and NGINX goes on with
# the configuration it has, so its workers still answer from the good file. The
# configuration names a link, so that only the file behind it changes.
my $startSeconds = 60;
my $reloadSeconds = 30;
my $reloadPort = 8098;
my $property = $goodFile =~ /Asn/ ? 'AsnName' : 'RegisteredName';
my $link = "$dir/reload.ipi";
my $log = "$dir/reload.log";
my $pidFile = "$dir/reload.pid";
mkdir "$dir/html" or die "Can't create $dir/html: $!";
write_binary('html/ipi', '');
symlink(File::Spec->rel2abs($goodFile), $link) or die "Can't link $link: $!";

open my $reloadConf, '>', "$dir/reload.conf"
	or die "Can't open reload.conf: $!";
print $reloadConf <<EOF;
$loadModule
daemon on;
master_process on;
worker_processes 1;
pid $pidFile;
error_log $log notice;
events {
}
http {
	access_log off;
	51D_file_path_ipi $link;
	server {
		listen 127.0.0.1:$reloadPort;
		root $dir/html;
		location /ipi {
			51D_match_ipi x-name-query $property \$arg_client_ip;
			add_header x-name-query \$http_x_name_query;
		}
	}
}
EOF
close $reloadConf or die "Can't close reload.conf: $!";

my $control = qq{timeout $startSeconds "$nginx" -p "$dir/" } .
	qq{-c "$dir/reload.conf" -e "$log"};

sub read_log {
	return -e $log ? read_binary($log) : '';
}

# Returns the x-name-query header NGINX gives for 212.58.224.22, or an empty
# string when there is no answer.
sub ask_name {
	my $socket = IO::Socket::INET->new(
		PeerAddr => "127.0.0.1:$reloadPort", Timeout => 10) or return '';
	print $socket "GET /ipi?client_ip=212.58.224.22 HTTP/1.0\r\n" .
		"Host: localhost\r\n\r\n";
	local $/;
	my $response = <$socket> // '';
	close $socket;
	return $response =~ /^x-name-query: ([^\r\n]*)/mi ? $1 : '';
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

my $startOutput = `$control 2>&1`;
my $master = wait_for($startSeconds, sub {
	return -s $pidFile && read_binary($pidFile) =~ /(\d+)/ ? $1 : 0;
});
my $before = wait_for($startSeconds, \&ask_name);
ok($master && $before ne '' && $before !~ /NoMatch/,
	'Reload: NGINX starts and answers from the good file')
	or diag("$startOutput\n" . read_log());

unlink $link or die "Can't remove $link: $!";
symlink("$dir/cut.ipi", $link) or die "Can't link $link: $!";
my $reloadOutput = `$control -s reload 2>&1`;
is($? >> 8, 0, 'Reload: the reload is sent') or diag($reloadOutput);
my $logged = wait_for($reloadSeconds, sub {
	my $text = read_log();
	return $text =~ /51Degrees.*\Q$link\E/ ? $text : '';
});
like($logged, qr/51Degrees.*\Q$link\E/,
	'Reload: logs a message naming the file') or diag(read_log());
like($logged, qr/not in the correct format/, 'Reload: logs the reason');
ok($master && kill(0, $master), 'Reload: the master keeps running');
is(ask_name(), $before, 'Reload: the workers still answer from the good file');

`$control -s quit 2>&1`;
wait_for($reloadSeconds, sub { return !-e $pidFile; });
ok(!-e $pidFile, 'Reload: NGINX stops') or ($master and kill('TERM', $master));
unlike(read_log(), qr/ERROR: (Address|Leak)Sanitizer/,
	'Reload: no memory error');
