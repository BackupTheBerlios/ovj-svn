#
# $Id$
#
# Copyright 2007 by Kai Pastor <dg0yt AT darc DOT de>

use strict;
use warnings FATAL => qw(all);

use Test::More tests => 4;

use_ok ("OVJ");

is (OVJ::get_path('.../config/Demo/Demo.txt','output'), '.../output/Demo');
is (OVJ::get_path('.../config/Demo/Demo.ovj','output'), '.../output/Demo');
is (OVJ::get_path('.../foo/Demo.ovj','output'), '.../foo/Demo-output');

