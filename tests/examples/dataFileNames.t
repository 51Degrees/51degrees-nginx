#!/usr/bin/perl

# Tests of the names the example tests read their data file paths from.

###############################################################################

use warnings;
use strict;
use Test::More tests => 9;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../lib';
use FiftyOneDataFiles qw(hash_file_path ipi_file_path);

###############################################################################

# make test-examples hands the tests the _51DEGREES_ names and neither
# deprecated name. make sets MAKELEVEL for what it runs.
SKIP: {
	skip 'not run by make', 2 unless defined $ENV{MAKELEVEL};
	ok(defined $ENV{_51DEGREES_DD_PATH} && defined $ENV{_51DEGREES_IPI_PATH},
		'make gives the _51DEGREES_ names');
	ok(!defined $ENV{TEST_FILE_PATH} && !defined $ENV{TEST_FILE_PATH_IPI},
		'make gives neither deprecated name');
}

# Runs the function with only the given names set, and returns its answer
# with what it printed to standard error.
sub read_with {
	my ($function, %names) = @_;
	local %ENV = (%ENV);
	delete @ENV{qw(_51DEGREES_DD_PATH _51DEGREES_IPI_PATH
		TEST_FILE_PATH TEST_FILE_PATH_IPI)};
	@ENV{keys %names} = values %names;
	my $printed = '';
	open my $saved, '>&', \*STDERR or die "Can't keep standard error: $!";
	close STDERR;
	open STDERR, '>', \$printed or die "Can't catch standard error: $!";
	my $path = $function->();
	close STDERR;
	open STDERR, '>&', $saved or die "Can't restore standard error: $!";
	return ($path, $printed);
}

my ($path, $printed) = read_with(\&hash_file_path,
	_51DEGREES_DD_PATH => '/new.hash', TEST_FILE_PATH => '/old.hash');
is($path, '/new.hash', 'The _51DEGREES_ name comes first');
is($printed, '', 'Nothing is printed when the _51DEGREES_ name is set');

($path, $printed) = read_with(\&hash_file_path,
	_51DEGREES_DD_PATH => '', TEST_FILE_PATH => '/old.hash');
is($path, '/old.hash', 'The deprecated name is read when the new one is empty');
like($printed, qr/^# TEST_FILE_PATH is deprecated, use _51DEGREES_DD_PATH instead\.$/,
	'The deprecated name is reported');

($path, $printed) = read_with(\&hash_file_path, TEST_FILE_PATH => '/old.hash');
is($printed, '', 'The deprecated name is reported once');

($path, $printed) = read_with(\&ipi_file_path,
	TEST_FILE_PATH_IPI => '/old.ipi');
is($path, '/old.ipi', 'The deprecated IP intelligence name is read');

($path, $printed) = read_with(\&ipi_file_path);
ok(!defined $path, 'No name set gives no path');

###############################################################################
