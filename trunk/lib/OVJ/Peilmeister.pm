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

my $debug = defined $ENV{DEBUG_OVJ_PEILMEISTER};

use vars qw(
	$REVISION
	$REVDATE
	$VERSION
);

use constant {
	ANY_MATCH   => 0,
	GOOD_MATCH  => 4,
	EXACT_MATCH => 6,
};

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
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = {
		files   => [ ],
		records => [ ],
	};
	bless $self, $class;
	$self->read_pmfile(@_);
	return $self;
}


#Lesen von Peilmeisterdateien
sub read_pmfile {
	my $self = shift;

	my ($name,$vorname,$call,$dok,$gebjahr,$pm,$datum);
	my $infile;

	while (my $filename = shift) {
		push @{$self->{files}}, $filename;
		open $infile, '<', $filename or return;
		while (<$infile>) {
			next unless (/^"/);	# Zeile muss mit Anfuehrungszeichen beginnen
			s/\r|"//g;
			($name,$vorname,$call,$dok,undef,undef,$gebjahr,undef,$pm,undef,$datum,undef) = split(/,/);
			push @{$self->{records}}, [$name,$vorname,$call,$dok,$gebjahr,$pm,$datum,$filename,0];
		}
		close $infile or return;
	}
}

sub suche {
	my ($self, $person, $best) = @_;
	$best = GOOD_MATCH unless defined $best;
	my @treffer;
	foreach (@{$self->{records}}) {
		my $score = 0;
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
		$_->[-1] = $score;
		if ($score == $best) {
			push @treffer, $_;
		}
		elsif ($score > $best) {
			$best = $score;
			@treffer = ( $_, );
		}
warn join(", ", @$_)."\n" if $debug;
	};
	return @treffer;

}

1;
