# $Id$
#
# Some portions (C) 2007 Kai Pastor, DG0YT <dg0yt AT darc DOT de>
#
# Based on / major work:
#
# Script zum Erzeugen der OV Jahresauswertung für
# OV Peilwettbewerbe
# Autor:   Matthias Kuehlewein, DL3SDO
# Version: 0.96
# Datum:   14.1.2007
#
#
# Copyright (C) 2007  Matthias Kuehlewein, DL3SDO
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#

=head1 OVJ::Inifile;

=head2 Synopsis

	OVJ::Browser::open("index.html")
	 or warn "Konnte Browser nicht starten";

=cut

package OVJ::Browser;

use strict;
use Carp;	# carp/croak instead of warn/die

use vars qw(
	$VERSION
);

BEGIN {
	$VERSION = "0.1";
}

sub open {
	my @arg = @_
	 or carp "usage: OVJ::Browser::open('index.htm')", return ;
	
	my $pid = fork;
	if (! $pid)  {
		# Kindprozess ($pid == 0) oder fork fehlgeschlagen ($pid == undef)
		my $ret;
		if ($^O =~ /Win/i) {
			# Windows
			unshift @arg, qw(cmd /c start);
			$ret = { exec @arg };
		}
		else {
			# Linux et al.
			foreach (qw/firefox konqueror/) {
				$ret = { exec $_, @arg }; # Endet bei Erfolg!
			}
		}
		if ($ret) {
			print STDERR "Konnte Browser nicht starten: $!\n";
		}
		exit ($ret == 0) if defined $pid; # Kindprozess bei Fehler beenden
	}
}

1;
