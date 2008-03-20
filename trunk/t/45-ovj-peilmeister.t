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

is( scalar $pm->suche(["Albrecht","Alf","SWL","","",""],OVJ::Peilmeister::ANY_MATCH), 1, "Albrecht, Alf, SWL" );
is( scalar $pm->suche(["Albrecht","","SWL","","",""],   OVJ::Peilmeister::ANY_MATCH), 2, "Albrecht, SWL" );
is( scalar $pm->suche(["Albrecht","","SWL","A01","",""],OVJ::Peilmeister::ANY_MATCH), 2, "Albrecht, SWL, A01" );
is( scalar $pm->suche(["","","DA1ANN","","",""],        OVJ::Peilmeister::ANY_MATCH), 1, "DA1ANN" );
is( scalar $pm->suche(["","Alf","SWL","A02","",""],     OVJ::Peilmeister::ANY_MATCH), 3, "Alf, SWL, A02" );

0;
