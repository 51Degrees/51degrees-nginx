package FiftyOneDataFiles;

# The data files the example tests use. The device detection path comes from
# _51DEGREES_DD_PATH and the IP intelligence path from _51DEGREES_IPI_PATH.
# make test-examples sets both. A name that is set to a missing file stops the
# test with that name. The device detection tests can't run without their
# file, so an unset _51DEGREES_DD_PATH stops them too. An unset
# _51DEGREES_IPI_PATH gives no path, and the IP intelligence tests skip.

use warnings;
use strict;

use Exporter 'import';
our @EXPORT_OK = qw(hash_file_path ipi_file_path);

sub from_environment {
	my ($name) = @_;
	my $path = $ENV{$name};
	return undef unless defined $path && $path ne '';
	die "$name is set to $path, which does not exist.\n" unless -f $path;
	return $path;
}

sub hash_file_path {
	my $path = from_environment('_51DEGREES_DD_PATH');
	die "_51DEGREES_DD_PATH is not set. Set it to the device detection " .
		"data file.\n" unless defined $path;
	return $path;
}

sub ipi_file_path {
	return from_environment('_51DEGREES_IPI_PATH');
}

1;
