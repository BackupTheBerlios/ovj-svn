#
# $Id$
#
# Copyright 2007 by Kai Pastor <dg0yt AT darc DOT de>

use strict;
use warnings FATAL => qw(all);

use Test::More tests => 2;

use_ok ("OVJ::Browser");

SKIP: {
	skip "OVJ::Browser::open test requires manual interaction", 1;
	ok (OVJ::Browser::open('doku/index.htm'));
};


