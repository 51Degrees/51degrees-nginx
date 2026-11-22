package FiftyOneBuild;

# What the example tests need to know about the build. The modules are in the
# build folder at the root of the repository, which is two folders above this
# one. A static build links the module into the NGINX binary, which the
# binary's own configure arguments show, and then there is no module to load.

use warnings;
use strict;

use Cwd qw(abs_path);
use File::Basename qw(dirname);

use Exporter 'import';
our @EXPORT_OK = qw(build_path static_build);

# The repository root, found when the module is loaded, before a test moves
# to another folder.
my $root = abs_path(dirname(__FILE__) . '/../..');

# The path of the build folder, ending with a slash, so that
# build_path() . 'modules/<name>.so' is the path of a module.
sub build_path {
	return "$root/build/";
}

# True when the NGINX binary under test has a module linked in, and so
# needs no load_module directive. nginx -V prints --add-module for a module
# that is linked in, and --add-dynamic-module for one that is loaded.
sub static_build {
	my $nginx = $ENV{TEST_NGINX_BINARY};
	return 0 unless defined $nginx && $nginx ne '';
	my $arguments = `"$nginx" -V 2>&1`;
	return defined $arguments && $arguments =~ /--add-module=/ ? 1 : 0;
}

1;
