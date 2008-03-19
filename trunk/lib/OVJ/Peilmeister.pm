# $Id$
#
# Copyright (C) 2007-2008 
#   Kai Pastor, DG0YT <dg0yt AT darc DOT de>,
#   Matthias Kuehlewein, DL3SDO
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
#

package OVJ::Peilmeister;

use strict;
use warnings;
use Carp;

use vars qw(
	$REVISION
	$REVDATE
	$VERSION
);

BEGIN {
	$VERSION = 0.1;
	'$Id$' =~ 
	 /Id: [^ ]+ (\d+) (\d{4})-(\d{2})-(\d{2}) /
	 or die "Revision format has changed";
	$REVISION = $1;
	$REVDATE = "$4.$3.$2";
}


# PM-Objekt erzeugen
# Fehler stehen in $!
sub new {
	my ($proto, $pmfile) = @_;
	$pmfile or croak "Dateiname fehlt";
	my $class = ref($proto) || $proto;
	my $self = {
		pmfile  => $pmfile,
		records => [ ],
	};
	bless $self, $class;
	$self->read_pm_file() or return;
	return $self;
}


#Lesen der Spitznamen Datei
sub read_pm_file {
	my $self = shift;
	my ($pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum);

	my $infile;
	open $infile, '<', $self->{pmfile} or return;
	while (<$infile>) {
		next unless (/^\"/);	# Zeile muss mit Anfuehrungszeichen beginnen
		s/\r//;
		tr/\"//d;				# entferne alle Anf�hrungszeichen
		($pmname,$pmvorname,$pmcall,$pmdok,undef,undef,$pmgebjahr,undef,$pmpm,undef,$pmdatum,undef) = split(/,/);
		push @{$self->{records}},
		     [$pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum];
	}
	close $infile;
}

sub finde {
	my ($self, $person, $best) = @_;
	$best = 5 unless defined $best;
	my @treffer;
	foreach (@{$self->{records}}) {
		my $score = 1;
		$score += $person->[0] eq $_->[0] ? 2 : -1; # Nachname
		$score += $person->[1] eq $_->[1] ? 2 : -1; # Vorname
		$score += 1 if ($person->[3] ne '' && $person->[3] eq $_->[3]); # DOK
		$score += 1 if ($person->[4] && $person->[4] eq $_->[4]); # Geb.-jahr
		# Call
		if ($person->[2] eq 'SWL') {
			$score += 1 if ($person->[2] eq $_->[2]);
		}
		elsif ($person->[2] eq $_->[2]) {
			$score += 4;
		}
		elsif ($_->[2] ne 'SWL') {
			$score -= 1;
		}
		$_->[7] = $score;
		if ($score == $best) {
			push @treffer, $_;
		}
		elsif ($score > $best) {
			$best = $score;
			@treffer = ( $_, );
		}
	};
	return @treffer;

}

sub ist_pm {
	my $self = shift;
	if (@_ > 1) {
		return $_[5] eq 'PM';
	}
	else {
		return $$_[0][5] eq 'PM';
	}
}

1;
