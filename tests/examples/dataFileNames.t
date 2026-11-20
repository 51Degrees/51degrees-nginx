#!/usr/bin/perl

# Tests of the names the example tests read their data file paths from. Only
# _51DEGREES_DD_PATH and _51DEGREES_IPI_PATH are read, and a path that names
# a missing file is reported with the name that gave it.

###############################################################################

use warnings;
use strict;
use Test::More tests => 10;
use File::Temp qw(tempfile);

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib '../lib';
use FiftyOneDataFiles qw(hash_file_path ipi_file_path);

###############################################################################

# make test-examples hands the tests the _51DEGREES_ names. make sets
# MAKELEVEL for what it runs.
SKIP: {
	skip 'not run by make', 1 unless defined $ENV{MAKELEVEL};
	ok(defined $ENV{_51DEGREES_DD_PATH} && defined $ENV{_51DEGREES_IPI_PATH},
		'make gives the _51DEGREES_ names');
}

# Runs the function with only the given names set, and returns its answer
# with the message it died with, if any.
sub read_with {
	my ($function, %names) = @_;
	local %ENV = (%ENV);
	delete @ENV{qw(_51DEGREES_DD_PATH _51DEGREES_IPI_PATH
		TEST_FILE_PATH TEST_FILE_PATH_IPI)};
	@ENV{keys %names} = values %names;
	my $path = eval { $function->() };
	return ($path, $@);
}

my (undef, $file) = tempfile(UNLINK => 1);
my $missing = "$file.missing";

my ($path, $error) = read_with(\&hash_file_path, _51DEGREES_DD_PATH => $file);
is($path, $file, 'The _51DEGREES_DD_PATH name is read');

($path, $error) = read_with(\&hash_file_path, TEST_FILE_PATH => $file);
like($error, qr/^_51DEGREES_DD_PATH is not set\./,
	'TEST_FILE_PATH is not read, and the missing name is reported');

($path, $error) = read_with(\&hash_file_path, _51DEGREES_DD_PATH => $missing);
is($error, "_51DEGREES_DD_PATH is set to $missing, which does not exist.\n",
	'A missing device detection file is reported with its name');

($path, $error) = read_with(\&ipi_file_path, _51DEGREES_IPI_PATH => $file);
is($path, $file, 'The _51DEGREES_IPI_PATH name is read');

($path, $error) = read_with(\&ipi_file_path, TEST_FILE_PATH_IPI => $file);
ok(!defined $path && $error eq '', 'TEST_FILE_PATH_IPI is not read');

($path, $error) = read_with(\&ipi_file_path, _51DEGREES_IPI_PATH => $missing);
is($error, "_51DEGREES_IPI_PATH is set to $missing, which does not exist.\n",
	'A missing IP intelligence file is reported with its name');

($path, $error) = read_with(\&ipi_file_path);
ok(!defined $path && $error eq '', 'No IP intelligence name gives no path');

# The Makefile and the CI scripts name the data files only with the
# _51DEGREES_ names.
my @read = ('../../Makefile', glob('../../ci/*.ps1'));
my (@oldNames, @newNames);
for my $name (@read) {
	open my $in, '<', $name or die "Can't read $name: $!";
	while (my $line = <$in>) {
		push @oldNames, "$name:$.: $1" if $line =~
			/((?<![A-Z_])51DEGREES_(?:DD|IPI)_PATH|FIFTYONEDEGREES_DATAFILE\w*)/;
		push @newNames, "$name:$."
			if $name =~ /\.ps1$/ && $line =~ /_51DEGREES_DD_PATH=/;
	}
	close $in;
}
is_deeply(\@oldNames, [],
	'The Makefile and CI scripts name no data file without _51DEGREES_')
	or diag(join("\n", @oldNames));
is(scalar @newNames, 4, 'The CI scripts give make _51DEGREES_DD_PATH');

###############################################################################
