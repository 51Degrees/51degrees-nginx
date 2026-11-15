#!/usr/bin/perl
# Leaves LeakSanitizer's false "ptrace appears to be blocked" warning out of
# the "no sanitizer errors" check of NGINX's test library.
#
# At its first leak check, LeakSanitizer forks a child to try ptrace and waits
# for it. An NGINX worker's SIGCHLD handler can reap that child first, and the
# sanitizer then reads an unset status, so it warns although ptrace works. A
# leak check that really fails prints its own report, which the check still
# counts. Running this again changes nothing.

use strict;
use warnings;

my $file = shift or die "Usage: $0 <path to lib/Test/Nginx.pm>\n";

open my $in, '<', $file or die "Can't open $file: $!\n";
my $text = do { local $/; <$in> };
close $in;

my $old = q{$errors = join "\n", $errors =~ /.+Sanitizer.+/gm;};
my $new = q{$errors = join "\n", grep { !/ptrace appears to be blocked/ }}
	. q{ $errors =~ /.+Sanitizer.+/gm;};

exit 0 if index($text, $new) >= 0;

if (index($text, $old) < 0) {
	print "WARNING: the sanitizer check in $file has changed, so it is left as it is\n";
	exit 0;
}

$text =~ s/\Q$old\E/$new/;
open my $out, '>', $file or die "Can't write $file: $!\n";
print $out $text;
close $out;
print "The sanitizer check in $file leaves out the false ptrace warning\n";
