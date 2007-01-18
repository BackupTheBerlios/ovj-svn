use strict;
use warnings FATAL => qw(all);

use Test::More tests => 5;

use_ok("OVJ::Inifile");

ok(my %foo = OVJ::Inifile::read("t/input/sample.ini"));
ok(my $foo = OVJ::Inifile::read("t/input/sample.ini"));
ok(OVJ::Inifile::write("t/output/sample.ini.1",%foo));
ok(OVJ::Inifile::write("t/output/sample.ini.2",$foo));

