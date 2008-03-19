# $Id$
#
# (C) 2007-2008 Kai Pastor, DG0YT <dg0yt AT darc DOT de>
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

package OVJ::Eval;

use warnings;
use strict;
use Carp;

use OVJ::FjParser;
use OVJ::Peilmeister;

use OVJ; warn "FIXME: Pruefe Abh�ngigkeit von package OVJ";

use vars qw(%idx_call %idx_name);

use constant {
  # Zust�nde
  ERROR   => 0,
  READY   => 1,
  STOPPED => 2,

  # Handlungsm�glichkeiten
  NONE    => 0,
  YES_NO  => 1,
  STRING  => 2,
};

# Erstellt eine neue Auswertung.
# optionale Parameter, nur Reihenfolge wichtig:
#  - Allgemeine Daten
#  - Name der Peilmeisterdatei des Vorjahrs
#  - Name der Peilmeisterdatei des aktuellen Jahres
#  - Nickname-Daten (String)
#  - Override-Daten (String)
sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
my $general = shift;
	my $pm_vorjahr = new OVJ::Peilmeister(shift) or return;
	my $self = {
	  general    => $general,
	  pm_vorjahr => $pm_vorjahr,
	  pm_aktuell => @_ ? \(OVJ::read_pm_file(shift) || ()) : [],
	  nicknames  => @_ ? OVJ::get_nicknames(shift) : '',
	  overrides  => @_ ? OVJ::get_overrides(shift) : '',
	  ovfj       => [],
	  ovfj_todo  => [],
	  facts      => {},
	  persons    => {},
	  report     => [],
	};
	bless $self, $class;
	$self->state(READY,"Wettkampf hinzuf�gen",NONE);
	return $self;
}

# Gibt aktuellen Zustand zur�ck, wenn ohne Parameter aufgerufen.
# �ndert Zustand, wenn mit Parametern auf gerufen.
# Parameter:
#  - Zustand
#  - Mitteilung/Frage
#  - Antwortm�glichkeiten (YES_NO, STRING, ...)
sub state {
	my $self = shift;
	unless (@_) {
		if (wantarray) {
			return ($self->{state}, $self->{action_message}, $self->{action_options});
		}
		return $self->{state};
	}

	$self->{state} = shift;
	($self->{action_message}, $self->{action_options}, $self->{action_ovfj}) =
	  ($self->{state} == READY) ? ( "Wettkampf hinzuf�gen", NONE, '' ) : @_;
	return $self->{state};
}

# F�gt Wettk�mpfe hinzu.
# Parameter:
#  - Wettkampf-Datens�tze (Hash-Referenzen)
# Liefert die Anzahl der unbearbeiteten Wettk�mpfe
sub add {
	my $self = shift;
	push @{$self->{ovfj_todo}}, @_;
}

sub current {
	my $self = shift;
	return $self->{ovfj_todo}->[0];
}


# Beginnt die Auswertung
sub start {
	my $self = shift;

	while (@{$self->{ovfj_todo}}) {
		my $race = @{$self->{ovfj_todo}}[0];

#print STDERR join (", ", keys %$race)."\n";
#$self->report("***************  $race->{Name}  ***************");

		if (! $race->{OVFJDatei} || $race->{OVFJDatei} eq "") {
			return $self->state(ERROR, "Keine OVFJ Datei angegeben.");
		}	
		
		open (my $infile, '<', $race->{OVFJDatei})
		  or return $self->state(ERROR, "Kann OVFJ Datei '$race->{OVFJDatei}' nicht lesen: $!");

#		my ($Ignoriermode, $Helfermode, $KeineSonderpunkte) = (0, 0, 0);
#		my $evermatched = 0;
		my $p = new OVJ::FjParser();
		my $muster = $race->{Auswertungsmuster} || '';
		if ($muster =~ /[Nn]ame/) {
			$p->muster($muster);
		}
		elsif ($muster !~ /^Auto$|^$/i) {
			return $self->state(ERROR, "Muster muss 'Name' beinhalten".
			                    "oder auf 'Auto' gesetzt werden.");
		}
		else {
			$muster = undef;
		}

		$self->{facts}->{$race} = {};
		my $nicht_pm_rang = 0;
		my $platz_zuvor = 0;
		while (<$infile>) {
			my ($type, @data) = $p->parseline($_);

			if ($type eq OVJ::FjParser::MUSTER && ! $muster) {
				$p->muster($data[0]);
			}
			elsif ($type eq OVJ::FjParser::AUSRICHTER) {
				my $person = $self->find_person(@data);
				$self->record($race, $person, "Ausrichter");
			}
			elsif ($type eq OVJ::FjParser::HELFER) {
				my $person = $self->find_person(@data);
				$self->record($race, $person, "Helfer");
			}
			elsif ($type eq OVJ::FjParser::TEILNEHMER) {
				my $platz = shift @data;
				my $person = $self->find_person(@data);
				$self->record($race, $person, "Teilnehmer");

				if (! $self->peilmeister($person)) {
					$nicht_pm_rang++ if $platz ne $platz_zuvor;
					$self->record($race, $person, "Nicht-PM-$nicht_pm_rang");
					$platz_zuvor = $platz;
				}
			}
		}
	
		close $infile
		  or return $self->state(ERROR, "Konnte Datei '$race->{OVFJDatei}' nicht schlie�en: $!");
		push @{$self->{ovfj}}, shift @{$self->{ovfj_todo}};
	}

	return $self->state(READY, "Auswertung abgeschlossen");
}

sub find_person {
	my $self = shift;
	my ($nachname, $vorname, $call, $dok) = @_;
	$call ||= 'SWL';
	$dok  ||= '';
	my $name = $nachname . $vorname;
	my $id = $name . $call;
	my $person = $self->{persons}->{$id} || 
	             $idx_name{$name} ||
	             $idx_call{$call} ||
	             [ $nachname, $vorname, $call, $dok, '', '', 'Neu', ];
	if (! defined $idx_call{$call} && ! defined $idx_name{$name}) {
		# Neuer Datensatz
		my @treffer = $self->{pm_vorjahr}->suche($person, 5);
		if (@treffer == 1) {
			$person->[6] = '';
			if ($person->[0] ne $treffer[0]->[0]) {
				$person->[6] .= "Nachname '$nachname' ersetzt. ";
				$person->[0] = $treffer[0]->[0];
			}
			if ($person->[1] ne $treffer[0]->[1]) {
				$person->[6] .= "Vorname '$vorname' ersetzt. ";
				$person->[1] = $treffer[0]->[1];
			}
			if ($person->[2] eq 'SWL' && $treffer[0]->[2] ne 'SWL') {
				$person->[6] .= "Rufzeichen '$call' ersetzt. ";
				$person->[2] = $treffer[0]->[2];
			}
			elsif ($person->[2] ne $treffer[0]->[2]) {
				$person->[6] .= "Neues Rufzeichen, alt: $treffer[0]->[2]. ";
			} 
			if ($person->[3] eq '' && $treffer[0]->[3] ne '') {
				$person->[3] = $treffer[0]->[3];
				$person->[6] .= "DOK ergänzt. ";
			}
			elsif ($person->[3] ne $treffer[0]->[3]) {
				$person->[6] .= "Neuer DOK, alt: '$treffer[0]->[3]'. ";
			} 
			$person->[4] = $treffer[0]->[4];
			$person->[5] = $treffer[0]->[5];
		}
		elsif (@treffer > 1) {
			warn "Mehrere Treffer für $nachname, $vorname, $call, $dok";
			$person->[6] = scalar(@treffer) . " Kandidaten";
			$person->[7] = \@treffer;
		}
	}
	if ($person->[2] eq 'SWL') {
		$person->[2] = $call;
	}
	if ($person->[2] ne $call && $call ne 'SWL') {
		warn "$person->[2] ne $call"; #TODO
		$person = [ $nachname, $vorname, $call, $dok, '', '', "Rufzeichen $person->[2]?", [ $person ] ];
	}
	if ($person->[3] eq '') {
		$person->[3] = $dok;
	}
	if ($person->[3] ne $dok && $dok ne '') {
		warn "$person->[3] ne $dok";
		$person = [ $nachname, $vorname, $call, $dok, '', '', "DOK $person->[3]?", [ $person ] ];
	}
	$self->{persons}->{$person} = $person;
	$idx_name{$name} = $person;
	$idx_call{$call} = $person unless $call eq 'SWL';
	return $person;
}

sub peilmeister {
	my ($self, $person) = @_;
	return $person->[5] eq 'FM';
}

sub record {
	my ($self, $race, $person, $activity) = @_;
	unless (exists $self->{persons}->{$person}) {
		carp "Person '$person' wurde noch nicht mit find_person geprüft";
	}
	my $record = $self->{facts}->{$race}->{$person} || {};
	if (exists $record->{$activity}) {
		return $self->state(ERROR, "Person '$person' darf nicht mehrfach für Aktivität '$activity' gewertet werden.");
	}
	$record->{$activity} = 1;
	$self->{facts}->{$race}->{$person} = $record;
#print  join("/", @_)."\n";
}

sub eval_person {
	my ($self, $person) = @_;

	my @races = grep { 
	  exists $self->{facts}->{$_}->{$person}
	} @{$self->{ovfj}};
	my $races = @races;
	my $races_pretty = join( ',', grep {
		exists $self->{facts}->{${$self->{ovfj}}[$_-1]}->{$person}
	} 1..@{$self->{ovfj}} );
	my $nicht_pm_1 = grep { 
		exists $self->{facts}->{$_}->{$person}->{'Nicht-PM-1'} 
	} @races;
	my $nicht_pm_2 = grep {
		exists $self->{facts}->{$_}->{$person}->{'Nicht-PM-2'} 
	} @races;
	my $ausrichter = grep { 
		exists $self->{facts}->{$_}->{$person}->{'Ausrichter'} 
	} @races;
	my $helfer = grep { 
		exists $self->{facts}->{$_}->{$person}->{'Helfer'} 
	} @races;

	my $total = 
	  $races + 2*$nicht_pm_1 + 1*$nicht_pm_2 + 2*$ausrichter + $helfer;

	return (
	  "${$self->{persons}->{$person}}[0], ${$self->{persons}->{$person}}[1]",
	  ${$self->{persons}->{$person}}[2],
	  ${$self->{persons}->{$person}}[3],
	  ${$self->{persons}->{$person}}[4],
	  ${$self->{persons}->{$person}}[5] eq 'FM' ? 'JA' : '--',
	  $races_pretty,
	  $races || '',
	  $nicht_pm_1 || '',
	  $nicht_pm_2 || '',
	  $ausrichter || '',
	  $helfer || '',
	  $total,
	  ${$self->{persons}->{$person}}[6], # Kommentar
	);
}

# Liefert Auswertung als Text
sub text {
	my $self = shift;
	my $head = "Text Kopf";
	my $i = 1;
	my $ovfj = join("\n", map { $i++ . " " . $_->{Name} } @{$self->{ovfj}});
	my $format = 
#	  "%-21s %-7s %-4s %-8s %-6s %-11s %-6s %-7s %-7s %-11s %-7s %-6s %-9s\n";
	  "%-21s %-8s %-4s %-5s %-3s %-15s %-3s %-3s %-3s %-3s %-3s %-3s %-9s\n";
	my $people = 
	  sprintf($format, 'Name, Vorname', qw(Call DOK GebJ PM Wettbewerbe Anz Pl1 Pl2 Aus Hlf Pkt Kommentar));
	$people .= "-"x(length($people)-1)."\n".
	  join('', map {
		sprintf $format, $self->eval_person($_)
	  } sort { by_name($self->{persons}, $a, $b) } keys %{$self->{persons}} );
	return "$head\n\n$ovfj\n\n$people\n";
}

sub by_name {
	my ($persons, $a, $b) = @_;
	$persons->{$a}->[0] cmp $persons->{$b}->[0] ||
	$persons->{$a}->[1] cmp $persons->{$b}->[1];
}

# Liefert Auswertung als HTML
sub html {
	my $self = shift;
	my $head = "HTML Kopf";
	my $ovfj = join("\n", @{$self->{ovfj}});
	my $people = join("\n", keys %{$self->{persons}});
	return "$head\n$ovfj\n$people\n";
}

# Liefert alle Meldungen, wenn ohne Parameter aufgerufen
# Registriert neue Meldung, wenn mit Parameter aufgerufen
# Parameter (optional):
#  - Meldung
sub report {
	my $self = shift;
	if (@_) {
		push @{$self->{report}}, @_;
		foreach (@_) { print "$_\n"; }
	}
	else {
		return join("\n", @{$self->{report}})."\n";
	}
}

1;
