#!/usr/bin/perl

# (C) Sergey Kandaurov
# (C) Maxim Dounin
# (C) Nginx, Inc.

# Tests for the 51Degrees Hash module's JavaScript example.

###############################################################################

use warnings;
use strict;
use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../nginx-tests/lib';
use Test::Nginx;

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

my $t = Test::Nginx->new()->has(qw/http/)->plan(4);

my $t_file = read_example('jsExample/javascript.conf');
# Remove the documentation block
$t_file =~ s/\/\*\*.+\*\//''/gmse;
# The example is written to run as it is, so the test adds what Test::Nginx
# needs and points it at the module and the data file under test.
$t_file =~ s/^(worker_processes .*)$/daemon off;\n$1\n%%TEST_GLOBALS%%/m;
$t_file =~ s/^http \{$/http {\n%%TEST_GLOBALS_HTTP%%/m;
$t_file =~ s/load_module modules\//load_module $ENV{TEST_MODULE_PATH}modules\//;
# A static build links the module into the Nginx binary, so omit the
# load_module directive, which would fail to open a non existent shared
# object.
$t_file =~ s/^.*load_module.*
//mg if $ENV{TEST_NGINX_STATIC};
$t_file =~ s/51D_file_path [^;]+;/51D_file_path $ENV{TEST_FILE_PATH};/;
$t_file =~ s/listen 8888;/listen 127.0.0.1:8080;/;
$t->write_file_expand('nginx.conf', $t_file);

# The example's instructions create a static file for /overrides, without
# which NGINX answers 404 and adds none of the headers.
$t->write_file('overrides', '');

$t->run();

sub get_with_ua {
	my ($uri, $ua) = @_;
	return http(<<EOF);
GET $uri HTTP/1.1
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
# Test javascript.conf example.
###############################################################################

my $js = get_with_ua('/51D.js', $mobileUserAgent);
my $r = get_with_ua('/overrides', $mobileUserAgent);

# ScreenPixelsWidth and ScreenPixelsWidthJavascript are only in the Enterprise
# data file. On the free Lite data file there is no JavaScript, the width reads
# NoMatch, and x-enterprise links to ask for a copy.
if (index($ENV{TEST_FILE_PATH}, '51Degrees-Lite') != -1) {
	like($js, qr/51Degrees Javascript not available/, 'No JavaScript without the Enterprise data file');
	like($r, qr/x-screenpixelswidth: NoMatch\r/, 'Width needs the Enterprise data file');
	like($r, qr/x-enterprise: .+https:\/\/51degrees\.com\/contact-us\?/, 'Link to ask for the Enterprise data file');
	like($r, qr/Access-Control-Expose-Headers: \*/, 'The page can read the link');
}
else {
	unlike($js, qr/51Degrees Javascript not available/, 'JavaScript returned');
	unlike($r, qr/x-screenpixelswidth: NoMatch/, 'Width matched');
	unlike($r, qr/x-enterprise:/, 'No link with the Enterprise data file');
	like($r, qr/Access-Control-Expose-Headers: \*/, 'The page can read the headers');
}

###############################################################################
