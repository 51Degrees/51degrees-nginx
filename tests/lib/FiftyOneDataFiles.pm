package FiftyOneDataFiles;

# The data files the example tests use. Each path comes from its _51DEGREES_
# environment variable, or from the older name when that is unset or empty,
# which prints once that the older name is deprecated. make test-examples
# sets the _51DEGREES_ names.

use warnings;
use strict;

use Exporter 'import';
our @EXPORT_OK = qw(hash_file_path ipi_file_path);

my %warned;

sub from_environment {
	my ($name, $old) = @_;
	return $ENV{$name} if defined $ENV{$name} && $ENV{$name} ne '';
	return undef unless defined $ENV{$old} && $ENV{$old} ne '';
	print STDERR "# $old is deprecated, use $name instead.\n"
		unless $warned{$old}++;
	return $ENV{$old};
}

sub hash_file_path {
	return from_environment('_51DEGREES_DD_PATH', 'TEST_FILE_PATH');
}

sub ipi_file_path {
	return from_environment('_51DEGREES_IPI_PATH', 'TEST_FILE_PATH_IPI');
}

1;
