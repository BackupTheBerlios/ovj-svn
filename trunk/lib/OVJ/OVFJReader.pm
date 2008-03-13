# $Id: OVJ.pm 421 2008-01-18 22:57:10Z kpa $
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

use OVJ;

use constant {
  ERROR   => 0,
  EXACT   => 1,
  SIMILAR => 2,
};

# Suche Teilnehmer in Peilmeisterdatei
sub suche {
	my $pmfilename = shift
	  or croak "Name der Peilmeisterdatei fehlt";

	my @pm = read_pm_file($pmfilename) or return;
}


=alter code
# Suche in PM Daten
#  Parameter:
#    Handle für Ausgabedatei
#    Referenz auf Peilmeister-Array
#    Referenz auf Nachname
#    Referenz Vorname
#    Geburtsjahr
#    Call
#    DOK
#    ? Flag für PM-Vorjahr ignorieren, 2: sofortiges return, 1: ???
#    Flag für aktuelles Jahr, 0: Vorjahr 
#    Nickname-Daten (String)
sub SucheTlnInPM {
	local *FH = shift;
	my ($pmarray,$nachname,$vorname,$gebjahr,$call,$dok,$override_IsInPmvj,$CheckInAktPM,$nicknames) = @_;
	my ($rest,$name);
	my ($nname,$vname);
	my $callmismatch = 0;
	my $arindex;
	my ($listelem,$lelem2);
	my $PMJahr = $CheckInAktPM == 0 ? "PMVorjahr" : "akt. PM Daten";
	my $foundbydokgeb;
	my $foundnachname = 0;
	
	if ($override_IsInPmvj == 2)
	{
		RepMeld(*FH,"INFO: $$nachname, $$vorname durch Override 'NichtInPMVJ' von Suche in $PMJahr ausgeschlossen");
		return (0,"Ausschluss wegen Override 'NichtInPMVJ'");
	}

	$call = uc($call);
	if ($call !~ /^(---|SWL|)$/)
	{
		$callmismatch = 1;	# fuer unten merken
		for ($arindex = 0; $arindex < @$pmarray; $arindex++) {
			if ($pmarray->[$arindex]->[2] eq $call)
			{
				$callmismatch = 0;
				$nname = $pmarray->[$arindex]->[0];
				$vname = $pmarray->[$arindex]->[1];
				$rest = $pmarray->[$arindex];
				if ($nname eq $$nachname && $vname eq $$vorname)
				{
					return (1,"Call,Nachname,Vorname",$rest);		# Gefunden ueber Rufzeichen, Nachname und Vorname
				}
			
				if ($nname eq $$nachname)
				{ # Nachname stimmt, aber nicht der Vorname
					if ($nicknames =~ /^(".*?$$vorname.*)$/m)
					{
						$_ = $1;
						if (/\"$vname\"/)
						{
							RepMeld(*FH,"INFO: $$nachname, $$vorname als $$nachname, $vname ueber Rufzeichen und Spitznamen in $PMJahr gefunden, verwende neuen Vornamen");
							$$vorname = $vname;
							return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname
						}
					}
					# FIXME: gleiche Funktionalität wie vorangegangener if-Zweig, nur anderer Text?
					RepMeld(*FH,"INFO: $$nachname, $$vorname als $$nachname, $vname ueber Rufzeichen in $PMJahr gefunden, verwende neuen Vornamen");
					$$vorname = $vname;
					return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname				
				}
			
				if ($vname eq $$vorname)
				{ # Vorname stimmt, aber nicht der Nachname
					RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$$vorname." ueber Rufzeichen in ".$PMJahr." gefunden, verwende neuen Nachnamen");
					$$nachname = $nname;
					return (11,"Call,Vorname;Nachname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Vorname; Nachname passt nicht
				}
			
				if ($dok ne "---" && $dok ne "") # jetzt zusaetzlich Abgleich ueber DOK 
				{
					if ($rest =~ /^\"$call\",\"$dok\"/)
					{# Vorname und Nachname stimmen nicht, aber DOK !
						RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen und DOK in ".$PMJahr." gefunden, verwende neue Namen");
						$$nachname = $nname;
						$$vorname = $vname;
						return (12,"Call,DOK",$rest);		# Gefunden ueber Rufzeichen, DOK; Vorname, Nachname passen nicht
					}
					else
					{# Vorname und Nachname und DOK stimmen nicht
						RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen aber mit falschem DOK in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
						return (0,"Call",$rest);		# Gefunden ueber Rufzeichen; DOK, Vorname, Nachname passen nicht
					}
				}
				else
				{
					RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen (kein DOK in OVFJ) in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
					return (0,"Call",$rest);		# Gefunden ueber Rufzeichen; Vorname, Nachname passen nicht; DOK nicht vorhanden zum Pruefen
				}
			}
		} # Ende Rufzeichen passt
	} # Ende Suche ueber Rufzeichen
	
	# Jetzt Suche ueber Namen, Vornamen und DOK
	# zunaechst alle mit passenden Nachnamen heraussuchen
	my @mlist;
	for ($arindex = 0; $arindex < @$pmarray; $arindex++)
	{
		if ($pmarray->[$arindex]->[0] eq $$nachname)
		{
			push (@mlist,$pmarray->[$arindex]);
		}
		elsif (@mlist > 0) 
		{
			last;	# Nachnamen sind zusammenhaengend in PM Datei, verlasse Schleife sobald 
		}	        # nach gefundenen Nachnamen der erste nicht mehr stimmt
	}
	if (@mlist == 0)	# kein Eintrag mit passenden Nachnamen gefunden
	{
		return (0,"",undef);		# Nicht ueber Nachname gefunden, verwerfe Eintrag
	}	

	my @mlist2;
	foreach $listelem (@mlist) {
		if ($nicknames =~ /^(".*?$$vorname.*)$/m)
		{
			$_ = $1;
			tr/\"//d;							# entferne alle Anführungszeichen
			foreach $lelem2 (split(/=/)) {
				if ($listelem->[1] eq $lelem2)
				{
					push (@mlist2,$listelem);
					last;
				}
			}
		}
		else
		{
			push (@mlist2,$listelem) if ($listelem->[1] eq $$vorname);
		}
	}
	if (@mlist2 == 0)	# kein Eintrag mit passenden Vornamen gefunden
	{
		return (0,"Nachname",undef);		# Gefunden ueber Nachname, Vorname passt nicht, verwerfe Eintrag
	}

	my @mlist3;
	$dok = "" if ($dok eq "---");
	$foundbydokgeb = 0;
	foreach $listelem (@mlist2) {
		if ($listelem->[3] eq $dok)
		{
			push (@mlist3,$listelem);
			$foundbydokgeb = 1;
			next;
		}
		if ($listelem->[4] eq $gebjahr && $gebjahr !~ /^-*$/)
		{
			push (@mlist3,$listelem);
			$foundbydokgeb = 2;
			next;
		}		
	}
#	$dok = "---" if ($dok eq "");
	if (@mlist3 == 1)
	{
		$rest = $mlist3[0];
		if ($callmismatch == 1)
		{
			if ($foundbydokgeb == 1)
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit passendem DOK in PMVorjahr gefunden, aber Call: ".$call." stimmt nicht, verwende trotzdem PM Eintrag") if ($CheckInAktPM == 0);
				RepMeld(*FH,"INFO: ".join(',',@{$mlist3[0]})) if ($CheckInAktPM == 0);
				return (1,"Nachname,Vorname,DOK;Call stimmt nicht",$rest) 		# Gefunden ueber Nachname, Vorname und DOK; Call stimmt nicht!
			}
			if ($foundbydokgeb == 2)
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit passendem Geb.jahr in PMVorjahr gefunden, aber Call: ".$call." stimmt nicht, verwende trotzdem PM Eintrag") if ($CheckInAktPM == 0);
				RepMeld(*FH,"INFO: ".join(',',@{$mlist3[0]})) if ($CheckInAktPM == 0);
				return (1,"Nachname,Vorname,Geb.jahr;Call stimmt nicht",$rest) 		# Gefunden ueber Nachname, Vorname und Geb.jahr; Call stimmt nicht!
			}
		}
		return (1,"Nachname,Vorname,DOK",$rest) if ($foundbydokgeb == 1);		# Gefunden ueber Nachname, Vorname und DOK
		return (1,"Nachname,Vorname,Geb.jahr",$rest) if ($foundbydokgeb == 2);		# Gefunden ueber Nachname, Vorname und Geb.jahr
	}

	if (@mlist3 == 0)
	{
		if (@mlist2 == 1 && $override_IsInPmvj == 1)
		{
			if ($callmismatch == 1)
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." und Call: ".$call." stimmen nicht, verwende Daten aufgrund von 'IstInPMVJ Override'") if ($CheckInAktPM == 0);
			}
			else
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." stimmt nicht, verwende Daten aufgrund von 'IstInPMVJ Override'") if ($CheckInAktPM == 0);
			}
			$rest = $mlist2[0];
			return (1,"Nachname,Vorname,! 'IstInPMVJ' Override !",$rest);		# Gefunden ueber Nachname, Vorname und 'IstInPMVJ' Override
		}
		
		if ($callmismatch == 1)
		{
			RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." und Call: ".$call." stimmen nicht, verwende Daten nicht") if ($CheckInAktPM == 0);
		}
		else
		{
			RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." stimmt nicht, verwende Daten nicht") if ($CheckInAktPM == 0);
		}
		RepMeld(*FH,"INFO: mögliche Teilnehmer: ") if ($CheckInAktPM == 0);
		foreach $listelem (@mlist2) {
			RepMeld(*FH,join(',',@$listelem)) if ($CheckInAktPM == 0);
		}
		return (0,"Nachname,Vorname",undef);		# Gefunden ueber Nachname, Vorname, aber DOK stimmt nicht, verwerfe Eintrag
	}
	RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit DOK ".$dok." bzw. Geb.jahr ".$gebjahr." mehrmals in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
	foreach $listelem (@mlist3) {
		RepMeld(*FH,join(',',@$listelem)) if ($CheckInAktPM == 0);
	}
	return (0,"Nachname,Vorname,DOK",undef);		# Gefunden ueber Nachname, Vorname, DOK, aber mehrmals vorhanden, verwerfe Eintrag
}

# TODO: Ende Baustelle
=cut



#Lesen der Spitznamen Datei
sub read_pm_file {
	my $filename = shift;
	my $anonarray = [];	# anonymes Array
	my ($pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum);

	my $infile;
	open $infile, '<', $filename
	 or return OVJ::meldung(OVJ::FEHLER, "Kann PM-Datei '$filename' nicht finden");

	my @pm;
	while (<$infile>) {
		next unless (/^\"/);	# Zeile muss mit Anfuehrungszeichen beginnen
		s/\r//;
		tr/\"//d;				# entferne alle Anführungszeichen
		($pmname,$pmvorname,$pmcall,$pmdok,undef,undef,$pmgebjahr,undef,$pmpm,undef,$pmdatum,undef) = split(/,/);
		$anonarray = [$pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum];
		push @pm, $anonarray;
	}
	close $infile or die "close: $!";
	return @pm;
}

1;
