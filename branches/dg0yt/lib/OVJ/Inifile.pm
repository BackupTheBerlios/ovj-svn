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

	my %config = OVJ::Inifile::read("OVJ.ini");
	my $param = $config{param};
	$config{param} = "foo";
	OVJ::Inifile::save("OVJ.ini",%config);

=cut

package OVJ::Inifile;

use strict;
use Carp;	# carp/croak instead of warn/die

sub read {
	my $inifilename = shift
	  or croak "Dateiname fehlt";
	open (my $inifile,"<",$inifilename)
	  or return;
	my %inihash = ( '.comment' => '' );
	while (<$inifile>) {
		s/\r//;
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s*$/) {
			$inihash{$1} = $2;
		}
		else {
			$inihash{'.comment'} .= $_;
		}
	}
	close ($inifile) 
	  or warn "Kann INI-Datei '$inifilename' nicht schließen: $!";
	return wantarray ? %inihash : \%inihash;
}


sub write {
	my $inifilename = shift
	  or croak "Dateiname fehlt";
	my %inihash = (ref $_[0]) ? %{$_[0]} : @_;
	my $key;
	open (my $inifile,">",$inifilename)
	  or return;
	print $inifile $inihash{'.comment'};
	foreach $key (keys %inihash) {
		next if $key eq '.comment';
		print $inifile "$key = $inihash{$key}\n";
	}
	close ($inifile);
}

1;
