#!/usr/bin/perl

# Tests what 51D_get_javascript_all serves in a location whose content comes
# from an upstream, when another request is matched on the worker between the
# upstream's headers and its body.

###############################################################################

use warnings;
use strict;
use Test::More;
use IO::Socket::INET;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'nginx-tests/lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

# PlatformName is in every data file, so the directive serves its value where
# a script would be.
my $t = Test::Nginx->new()->has(qw/http proxy/)->plan(4)
	->write_file_expand('nginx.conf', <<'EOF');

daemon off;

%%TEST_GLOBALS%%
events {
}

http {
	%%TEST_GLOBALS_HTTP%%

	server {
		listen       127.0.0.1:8080;
		server_name  localhost;

		location /script-upstream {
			51D_get_javascript_all PlatformName;
			proxy_pass http://127.0.0.1:8082/;
		}

		location /script-static {
			51D_get_javascript_all PlatformName;
		}

		location /match {
			51D_match_all x-platform PlatformName;
			add_header x-platform $http_x_platform;
		}
	}
}

EOF

$t->write_file('script-static', '');
$t->write_file('match', '');

$t->run_daemon(\&upstream_daemon);
$t->run();
$t->waitforsocket('127.0.0.1:8082');

###############################################################################

my $iphone = 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D167 Safari/9537.53';
my $firefox = 'Mozilla/5.0 (Windows NT 6.3; WOW64; rv:41.0) Gecko/20100101 Firefox/41.0';

sub request {
	my ($uri, $ua, %extra) = @_;
	return http("GET $uri HTTP/1.1\nHost: localhost\nConnection: close\n"
		. "User-Agent: $ua\n\n", %extra);
}

sub body {
	my ($r) = @_;
	my ($body) = $r =~ /\r\n\r\n(.*)$/s;
	return $body;
}

# From a file the value is the request's own.
my $r = request('/script-static', $iphone);
is(body($r), 'iOS', 'The value from a file is for the request');

# The upstream answers with its headers and holds its body back. Another
# device is then matched on the same worker, and the upstream is let go.
my $s = request('/script-upstream', $iphone, start => 1);
select undef, undef, undef, 2;
$r = request('/match', $firefox);
like($r, qr/^x-platform: Windows\r$/m, 'Another device is matched meanwhile');
IO::Socket::INET->new(Proto => 'tcp', PeerAddr => '127.0.0.1:8082')
	or die "Can't let the upstream go: $!\n";
$r = Test::Nginx::http_end($s);
print "# The answer from the upstream location:\n";
print "# $_\n" for split(/\r?\n/, $r);
my $body = body($r);
my $values = () = $body =~ /iOS|Windows/g;
is($values, 1, 'The value behind an upstream is served once');
is($body, 'iOS', 'The value behind an upstream is for the request');

###############################################################################

# Answers each request with its headers at once, and with its body only when
# the next connection arrives.
sub upstream_daemon {
	my $server = IO::Socket::INET->new(
		Proto => 'tcp',
		LocalAddr => '127.0.0.1:8082',
		Listen => 5,
		Reuse => 1
	)
		or die "Can't create listening socket: $!\n";

	local $SIG{PIPE} = 'IGNORE';

	while (my $client = $server->accept()) {
		$client->autoflush(1);
		my $request = '';
		while (<$client>) {
			$request .= $_;
			last if (/^\x0d?\x0a?$/);
		}
		# A connection that sends nothing only checks that the port is open.
		if ($request eq '') {
			close $client;
			next;
		}
		print $client "HTTP/1.1 200 OK\r\nContent-Length: 8\r\n"
			. "Connection: close\r\n\r\n";
		my $release = $server->accept();
		close $release;
		print $client "upstream";
		close $client;
	}
}

###############################################################################
