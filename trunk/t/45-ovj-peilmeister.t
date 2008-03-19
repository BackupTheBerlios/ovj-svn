#
# $Id$
#
# Copyright 2008 by Kai Pastor <dg0yt AT darc DOT de>

use strict;
use warnings FATAL => qw(all);

use constant {
  TESTFILE => "t/input/pm.txt",
};

#use Test::More tests => 3;
use Test::More qw(no_plan);

BEGIN {
	use_ok ("OVJ::Peilmeister");
}

ok( my $pm = new OVJ::Peilmeister(TESTFILE), "new" );

is( scalar $pm->finde(["Albrecht","Alf","SWL","","",""],0), 1, "Albrecht, Alf, SWL" );
is( scalar $pm->finde(["Albrecht","","SWL","","",""],0),    2, "Albrecht, SWL" );
is( scalar $pm->finde(["Albrecht","","SWL","A01","",""],0), 2, "Albrecht, SWL, A01" );
is( scalar $pm->finde(["","","DA1ANN","","",""],0),         1, "DA1ANN" );
is( scalar $pm->finde(["","Alf","SWL","A02","",""],0),      3, "Alf, SWL, A02" );

0;
