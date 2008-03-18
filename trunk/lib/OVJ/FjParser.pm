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

package OVJ::FjParser;

use strict;
use warnings;
use Carp;

my $debug = defined $ENV{DEBUG_OVJ_FJPARSER};

use constant {
  TEILNEHMER => 'Teilnehmer',
  AUSRICHTER => 'Ausrichter',
  HELFER     => 'Helfer',
  MUSTER     => 'Muster',
  TITEL      => 'Titel',
  BAND       => 'Band',
  DATUM      => 'Datum',
  ORT        => 'Ort',
  OV         => 'OV',
  DOK        => 'DOK',
  IGNORIERT  => 'Ignoriert',
  UNBEKANNT  => 'Unbekannt',
  ANZAHL_TLN => 'Anzahl Teilnehmer',
};

sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;

	my $self = {
	  m_ignoriere => 0,
	  m_helfer    => 0,
# unused
#	  m_sonderpkt => 1,
	};
	bless $self, $class;
	if (@_) {
		$self->muster(shift);
	}

	return $self;
}


sub parseline {
	my $self = shift;
	local $_ = shift;
	s/\r//;
	chomp;

	if (/<(\/?)Ignoriere?>/) {
		$self->{m_ignoriere} = $1 eq '/' ? 0 : 1;
		return (IGNORIERT, $_);
	}
	if ($self->{m_ignoriere} || /^-+$|^=+$|^[*]+$|^\s*$/) {
		return (IGNORIERT, $_);
	}

	if (/<(\/?)Helfer>/) {
		$self->{m_helfer} = $1 eq '/' ? 0 : 1;
		return (IGNORIERT, $_);
	}
# unused
#	elsif (/<(\/?)Keine Sonderpunkte>/)  {
#		$self->{m_sonderpkt} = $1 eq '/' ? 1 : 0;
#	}


	if (/^(\w.*?):\s*(.*)/) {
		$self->{m_helfer} = 0;

		if ($1 eq "Band") {
			return (BAND, $2);
		}
		elsif ($1 eq "Datum" | $1 eq "am") {
			$2 =~ /^(\S*)/;
			return (DATUM, $1);
		}
		elsif ($1 eq "Ort" || $1 eq "Treffpunkt") {
			return (ORT, $2);
		}
		elsif ($1 eq "Organisation") {
			return (OV, $2);
		}
		elsif ($1 eq "DOK" || $1 eq "Dok" || $1 eq "Ausrichter OV") {
			$2 =~ /\b([A-Za-z])-?(\d\d)\b/;
			return (DOK, uc($1).$2);
		}
		elsif ($1 eq "Teilnehmerzahl") {
			return (ANZAHL_TLN, $2);
		}
		elsif ($1 eq "Verantwortlich" || $1 eq "Ausrichter") {
			return (AUSRICHTER, person($2));
		}
		elsif ($1 eq "Helfer") {
			$self->{m_helfer} = 2; # einmal
			my @ret = $self->parseline($2);
			$self->{m_helfer} = 2; # und noch einmal
			return @ret;
		}
		else {
			return (UNBEKANNT, $_);
		}
	}

	if (/Platz/ && /[Nn]ame/) {
		$self->{m_helfer} = 0;
		return (MUSTER, $_);
	}

	if ($self->{m_helfer}) {
		if ($self->{m_helfer} == 2 && /^\s*(.*\S)\s*/) { 
			return (HELFER, person($1));
		}
		elsif ($self->{muster} && (my $helfer = &{$self->{sub_tln}}($_)) ) {
			shift @$helfer; # Platz entfernen
			return (HELFER, @$helfer);
		}
		else {
			$self->{m_helfer} = 0;
			return (UNBEKANNT, $_);
		}
	}

	if ($self->{muster} && (my $tln = &{$self->{sub_tln}}($_)) ) {
		return (TEILNEHMER, @$tln);
	}

	return (UNBEKANNT, $_);
}


sub person {
	my @person = split /\s+/, $_[0];
	my ($vorname, $nachname, $call, $dok) =	('', '', 'SWL', '');
print "person: $_[0]\n" if $debug;
	while (my $field = shift @person) {
print "  '$field'\n" if $debug;
		if ($field =~ /^(?:Rufzeichen|OV|DOK):?$/) {
			next;
		}
		elsif ($field =~ /^([A-Za-z])[-]?(\d\d),?$/) {
			$dok = uc($1).$2;
		}
		elsif ($field =~ /\d|SWL/ && $field =~ /^(\w{3,6}),?$/) {
			$call = uc($1);
		}
#		elsif ($field eq 'SWL') {
#			$call = $field;
#		}
		elsif ($field =~ /(.*),$/) {
			if ($nachname) {
				$vorname = $1;
			}
			else { 
				$nachname = $1;
			}
		}
		elsif (! $vorname) {
			$vorname = $field;
		}
		else {
			$nachname = $field;
		}
	}
	return ($nachname, $vorname, $call, $dok);
}

sub muster {
	my $self = shift;
	$self->{muster} = shift;
	1 while ($self->{muster} =~ s/^(.*?)\t/$1 . ' 'x(8 - length($1) % 8)/e);
	my @parts = split /(?<!,) (?=\S)/, $self->{muster};
	my @patterns;
	my @keys;
	my @lengths;
	foreach (@parts) {
		my $length = length($_);
		my $less = $length - 1;
		push @lengths, $length;
		push @patterns, qr/(.{0,$length}?(?<=\S) +|.{$length,}?| {0,$length}\S+) /;

		if (/Pl.{0,3}/) {
			push @keys, 'Platz';
		}
		elsif (/[Nn]ame/) {
			push @keys, 'Name';
		}
		elsif (/Call|Rufzeichen/) {
			push @keys, 'Call';
		}
		elsif (/DOK|Dok|OV/) {
			push @keys, 'DOK';
		}
		elsif (/^\s*$/) {
			warn "Leeres Muster - sollte nicht vorkommen";
			push @keys, 'Misc.Space';
		}
		else {
			push @keys, "Misc.$_";
		}
print ">>> '$_', $keys[-1], $lengths[-1], $patterns[-1]\n" if $debug;
	}
	$patterns[-1] = qr/(.*)/;

	$self->{sub_tln} = sub {
		my $line = shift;
		1 while ($line =~ s/^(.*?)\t/$1 . ' 'x(8 - length($1) % 8)/e);
		my %record;
		for (my $i = 0; $i < @patterns; $i++) {
print " $line\n" if $debug;
print "  $keys[$i] $patterns[$i] " if $debug;
			($line || '') =~ /^$patterns[$i](.*)$/
			  or return;
			if (defined $2) {
				$record{$keys[$i]} = $1;
				$line = $2;
print "> $1 | " if $debug;
				$record{$keys[$i]} =~ s/^\s+|\s+$//g;
			}
			else {
				$line = $1;
			}
		}
print "\n" if $debug;
		my @tln = person($record{Name});
		if (defined $record{Call} && $record{Call} =~ /\w{4,6}/) {
			$tln[2] = uc($record{Call});
		}
		if (defined $record{DOK} && $record{DOK} =~ /[A-Z]\d\d/) {
			$tln[3] = uc($record{DOK});
		}
		unshift @tln, $record{Platz};
		return wantarray ? @tln : \@tln;
	};
}


1;
