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
#

package OVJ;

use strict qw(vars);
use Carp;

use vars qw(
	$ovjdate
	$ovjvers
	$ovjinfo
	$error
	$lfdauswert
);

'$Id$' =~ /Id: [^ ]+ (\d+) (\d{4})-(\d{2})-(\d{2}) /;
$ovjdate = "$4.$3.$2";
$ovjvers = "0.96-rev$1";
$ovjinfo = "OVJ $OVJ::ovjvers by DL3SDO, DG0YT, $OVJ::ovjdate";

use constant {
	INFO    => 'Information',
	HINWEIS => 'Hinweis',
	WARNUNG => 'Warnung',
	FEHLER  => 'Fehler',
};

use vars qw(
	$configpath
	$inputpath
	$outputpath
	$reportpath
	$genfilename
	$sep
);

$sep = ($^O =~ /Win/i) ? '\\' : '/';	# Kai, fuer Linux und Win32 Portabilitaet

my $patternfilename = "OVFJ_Muster.txt";
my $overridefilename = "Override.txt";

$configpath = "config";		# Pfad für die Konfigurationsdaten
$inputpath  = "input";		# Pfad für die Eingangsdaten
$outputpath = "output";		# Pfad für die Ergebnisdaten
$reportpath = "report";		# Pfad für die Reportdaten

$lfdauswert = 0; # Nummer der lfd. OVFJ Auswertung

my @meldung_callback;

#Vergleiche Zeile aus Auswertungsdatei mit Pattern
# FIXME: Rewrite 
sub MatchPat {
	@_ == 2 
	 or croak "2 Argumente erforderlich: Zeile, Muster";
	my ($line, $pattern) = @_;
	
	my $patmatched = 0;
	my $platz = "";
	my ($nachname,$vorname,$gebjahr) = ("","","");
	my ($call,$dok) = ("","");
	my ($quest,$kw);
	my $validkeyword;
	
	local $_ = undef; # FIXME: Löschen
	$pattern =~ s/^\s+|\s+$//g; # Umgebende Leerzeichen entfernen
	
	$line =~ s/^\s+//; # entferne evtl. vorhandene Leerzeichen am Anfang
	$line .= ' ';	# fuer den Sonderfall, dass am Ende optionale Elemente (d.h. mit Schlüsselwort?) kommen
						# wenn das Schlüsselwort? nach einem Leerzeichen folgt, so wuerden normale Matches das Leerzeichen
						# am Ende erwarten.
	
	while ($pattern ne "") { # FIXME: kein While?
		if ($pattern =~ /^([A-Z][a-z]+)(\?)?/) {
			$validkeyword = 0;
			$kw = $1;
			$quest = $2 ? 1 : 0;
			if ($kw eq "Platz") {
				$validkeyword = 1;
				if ($line =~ /^(\d+)\b/) {
					$platz = $1;
					$line =~ s/^\d+\b//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Sender") {
				$validkeyword = 1;
				if ($line =~ /^\d+\b/) {
					$line =~ s/^\d+\b//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Geburtsjahr" || $kw eq "Gebjahr") {
				$validkeyword = 1;
				if ($line =~ /^(\d{4})\b/) {
					$gebjahr = $1;
					$line =~ s/^\d+\b//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Zeit") {
				$validkeyword = 1;
				if ($line =~ /^[.:0-9]+\b/) {
					$line =~ s/^[.:0-9]+\b//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Dok") {
				$validkeyword = 1;
				if ($line =~ /^(\S+)/) {
					$dok = uc($1);
					$dok = "---" if ($dok !~ /^[A-Z]\d\d$/);
					$line =~ s/^\S+//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Call" || $kw eq "Rufzeichen") {
				$validkeyword = 1;
				if ($line =~ /^(\S+)/) {
					$call = uc($1);
					$call = "---" if ($call =~ /^[A-Z]+$/ || $call =~ /^-+$/);
					$line =~ s/^\S+//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Egal" || $kw eq "Ignorier" || $kw eq "Ignoriere") {
				$validkeyword = 1;
				if ($line =~ /^\S+/) {
					$line =~ s/^\S+//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Nachname") {
				$validkeyword = 1;
				if ($line =~ /^\"([^"]+)\"/) {
					$nachname = $1;
					$line =~ s/^\"[^"]+\"//;
				}
				elsif ($line =~ /^([-a-zA-ZäöüÄÖÜß]+)/) {
					$nachname = $1;
					$line =~ s/^[-a-zA-ZäöüÄÖÜß]+//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}
			if ($kw eq "Vorname") {
				$validkeyword = 1;
				if ($line =~ /^\"([^"]+)\"/) {
					$vorname = $1;
					$line =~ s/^\"[^"]+\"//;
				}
				elsif ($line =~ /^([-a-zA-ZäöüÄÖÜß]+)/) {
					$vorname = $1;
					$line =~ s/^[-a-zA-ZäöüÄÖÜß]+//;
				}
				elsif ($quest == 0) {
					return (0,$kw); # Fehlschlag
				}
			}

			return (0, $kw." ist kein Schlüsselwort") if ($validkeyword != 1);	 # illegales Wort
			$pattern =~ s/^([A-Z][a-z]+)//;	 # entferne Schluesselwort

			if ($quest == 1) {
				$pattern =~ s/^\?//;
				$line = " ".$line;	# füge Leerzeichen am Anfang hinzu, weil Leerzeichen im Muster sonst
				                     # nicht gefunden werden.
			}

		} # Ende Wortoperation
		elsif ($pattern =~ /^(\w+)/) {
			return (0,$1." ist kein Schlüsselwort");	 # illegales Wort
		}

		if ($pattern =~ /^\s+/) {
			if ($line =~ /^\s+/) {
				$line =~ s/^\s+//;
			}
			else {
				return (0,"Leerzeichen"); # Fehlschlag
			}
			$pattern =~ s/^\s+//;
			next;
		}
		if ($pattern =~ /^(\S+)/) {
			if ($line =~ /^($1)/) {
				$line =~ s/^$1//;
			}
			else {
				return (0,"Sonstige Zeichen"); # Fehlschlag
			}
			$pattern =~ s/^\S+//;
		}
	}
	
	return (1,$platz,$nachname,$vorname,$gebjahr,$call,$dok);
}


#Suche in PM Daten
sub SucheTlnInPM {
	local *FH = shift;
	my ($pmarray,$nachname,$vorname,$gebjahr,$call,$dok,$override_IsInPmvj,$CheckInAktPM,$nicknames) = @_;
	my ($rest,$name);
	my ($nname,$vname);
	my $callmismatch = 0;
	my $arindex;
	my (@mlist,@mlist2,@mlist3,@nicklist,$listelem,$lelem2);
	my $PMJahr = $CheckInAktPM == 0 ? "PMVorjahr" : "akt. PM Daten";
	my $foundbydokgeb;
	my $foundnachname = 0;
	
	if ($override_IsInPmvj == 2)
	{
		RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." durch Override 'NichtInPMVJ' von Suche in ".$PMJahr." ausgeschlossen");
		return (0,"Ausschluss wegen Override 'NichtInPMVJ'");
	}
	
	if ($call ne "---" && $call ne "" && uc($call) ne "SWL")	# Rufzeichen vorhanden
	{
		$callmismatch = 1;	# fuer unten merken
		for ($arindex = 0; $arindex < @$pmarray; $arindex++)
		{# ueber Call gefunden
			#print "Call ".$call." gefunden\n";
			#print "Call ".$pmarray->[$arindex]->[2]."\n";
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
							RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$$nachname.", ".$vname." ueber Rufzeichen und Spitznamen in ".$PMJahr." gefunden, verwende neuen Vornamen");
							$$vorname = $vname;
							return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname
							}
						}
					RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$$nachname.", ".$vname." ueber Rufzeichen in ".$PMJahr." gefunden, verwende neuen Vornamen");
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
	for ($arindex = 0; $arindex < @$pmarray; $arindex++)
	{
		if ($pmarray->[$arindex]->[0] eq $$nachname)
		{
			#print $$nachname.", ".$_."\n";
			$foundnachname = 1;
			push (@mlist,$pmarray->[$arindex]);
		}
		else
		{
			last if ($foundnachname == 1);	# Nachnamen sind zusammenhaengend in PM Datei, verlasse Schleife sobald 
														# nach gefundenen Nachnamen der erste nicht mehr stimmt
		}
	}
	if (@mlist == 0)	# kein Eintrag mit passenden Nachnamen gefunden
	{
		return (0,"",undef);		# Nicht ueber Nachname gefunden, verwerfe Eintrag
	}	
	foreach $listelem (@mlist) {
		#print $listelem."\n";
		if ($nicknames =~ /^(".*?$$vorname.*)$/m)
		{
			$_ = $1;
			tr/\"//d;							# entferne alle Anführungszeichen
			@nicklist = split(/=/);
			foreach $lelem2 (@nicklist) {
				#print $lelem2."\n";
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
	$dok = "" if ($dok eq "---");
	$foundbydokgeb = 0;
	foreach $listelem (@mlist2) {
		if ($listelem->[3] eq $dok)
		{
			push (@mlist3,$listelem);
			$foundbydokgeb = 1;
			next;
		}
		if ($listelem->[4] eq $gebjahr && $gebjahr ne "" && $gebjahr ne "---" && $gebjahr ne "-")
		{
			push (@mlist3,$listelem);
			$foundbydokgeb = 2;
			next;
		}		
	}
	$dok = "---" if ($dok eq "");
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

sub read_pm_file {
	my $filename = shift;
	my $anonarray = [];	# anonymes Array
	my ($pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum);

	my $infile;
	open $infile, '<', $filename
	 or return meldung(FEHLER, "Kann PM-Datei '$filename' nicht finden");

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

#Lesen der Spitznamen Datei
sub get_nicknames {
	my $filename = shift
	 or return meldung(HINWEIS, "Keine Spitznamen-Datei spezifiziert");
	
	my $nicknames = '';
	my $infile;
	open ($infile, '<', $filename) &&
	read $infile, $nicknames, -s $filename
	 or return meldung(FEHLER, "Kann Spitznamen-Datei '$filename' nicht lesen: $!");
	close $infile;
	$nicknames =~ s/\r//g;
	$nicknames =~ s/^#.*?$//mg;
	return $nicknames;
}

#Lesen der Override Datei (falls vorhanden)
#Format: Name,Vorname,Rufzeichen,DOK,Gebjahr,NichtInPMVJ|IstInPMVJ
sub get_overrides {
	my $filename = shift
	 or return meldung(HINWEIS, "Keine Override-Datei spezifiziert");

	return unless (-e $filename);

	my $line = 0;
	my $overrides = undef;
	open (my $infile , '<', $filename)
	 or return meldung(FEHLER, "Kann Override Datei '$filename' nicht lesen: $!");
	while (<$infile>) {
		$line++;
		chomp;
		next if (/^#/);		# Kommentarzeilen ueberspringen
		next if (/^\W+/);		# Zeilen, die nicht mit einem Buchstaben beginnen ueberspringen
		next if ($_ eq "");	# Leerzeilen ueberspringen
		s/\r//;
		if (/^[-a-zA-ZäöüÄÖÜß]+,[-a-zA-ZäöüÄÖÜß]+,(|---|\w+),(|---|\w+),(|\d{4}),(NichtInPMVJ|IstInPMVJ|)\s*$/) {
			$overrides .= $_."\n";
		}
		else {
			meldung(FEHLER, "Formatfehler in Zeile $line der Overridedatei: '$_'");
		}
	}
	#meldung(HINWEIS,"INFO: Override Datei eingelesen");
	close $infile || die "close: $!";
	return $overrides;
}
	
#Auswertung der aktuellen OVFJ
sub eval_ovfj {   # Rueckgabe: 0 = ok, 1 = Fehler, 2 = Fehler mit Abbruch der auesseren Schleife
	my $mode = shift;	# 0 = erster Start, >0 = Aufruf aus Auswertung und Export aller OVFJ heraus
	
	my $general = shift;
	my $tn = shift;
	my $ovfjlist = shift;
	my $ovfjanztlnlist = shift;
	my $ovfj = shift;
	my $ovfjname = shift;
#	my $inputpath = shift;
#	my $reportpath = shift;
#	my $genfilename = shift;
	my $ovfjrepfilename = shift;
	
	# FIXME:
	my $overrides;
	my @pmvjarray = @::pmvjarray;
	my @pmaktarray = @::pmaktarray;
#	my %auswerthash = %::auswerthash;

	my $patmatched;
	my $evermatched = 0;
	my ($platz,$ev_nachname,$ev_vorname,$ev_gebjahr);
	my ($ev_call,$ev_dok);
	my $anztln = 0;
	my $nichtpm = 0;
	my $oldnotpmplatz = 0;
	my $AddedVerant = 0;
	my $Helfermode = 0;
	my $Ignoriermode = 0;
	my $HelferInKopf;
	my $KeineSonderpunkte = 0;
	my $SPunktePlatz = 0;
	my ($IsPM,$tnkey);
	my ($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum,);
	my $tndata = {}; # ein anonymer Hash
	my $match;
	my %ovfjcopy;
	my ($name,$str,$str2);
	my $line = 0;
	my $oldline = 0;
	my ($override_call,$override_dok,$override_gebjahr,$override_IsInPmvj);
	my $SText;
	my $rest;
	my $aktJahr;	# Teilnahme im aktuellen Jahr
	my $matcherrortext;	# Fehlertext bei Pattern nicht matched
	my $TlnIstAusrichter;	# Teilnehmer ist auch Ausrichter
	
	#Auswertung
	if ($general->{Jahr} !~ /^\d{4}$/)
	{
		meldung(FEHLER,"Jahr ist keine gültige Zahl");
		return 2;	# Fehler mit Schleifenabbruch
	}
	
	meldung(HINWEIS,"***************  ".$ovfjname."  ***************");


	$_ = $ovfj->{Auswertungsmuster};
	unless (/Nachname/ && /Vorname/) {
		meldung(FEHLER,"Muster muss 'Nachname' und 'Vorname' beinhalten");
		return 1;	# Fehler
	}


	my $nicknames = get_nicknames($general->{Spitznamen});  	# Spitznamen einlesen
	$overrides = get_overrides($overridefilename);		# Lade die Override-Datei (falls vorhanden)

	unless (-e $reportpath.$sep.$genfilename && -d $reportpath.$sep.$genfilename)
	{
		meldung(HINWEIS,"Erstelle Verzeichnis \'".$genfilename."\' in \'".$reportpath."\'");
		unless (mkdir($reportpath.$sep.$genfilename))
		{
			meldung(FEHLER,"Konnte Verzeichnis \'".$reportpath.$sep.$genfilename."\' nicht erstellen".$!);
			return 1;	# Fehler
		}
	}
	
	if (!open (OUTFILE,">",$reportpath.$sep.$genfilename.$sep.$ovfjrepfilename))
	{
		meldung(FEHLER,"Kann '$ovfjrepfilename' nicht schreiben");
		return 1;	# Fehler
	}	

	# Lese PMVJ Daten
	$general->{PMVorjahr}
	 or return meldung(FEHLER, "Keine PMVorjahr-Datei spezifiziert");
	$general->{PMaktJahr}
	 or return meldung(FEHLER, "Keine PMaktJahr-Datei spezifiziert");
	@pmvjarray = read_pm_file($general->{PMVorjahr})
	 or return;
	@pmaktarray = read_pm_file($general->{PMaktJahr})
	 or return;

	if ($ovfj->{OVFJDatei} eq "")
	{
		RepMeld(*OUTFILE,"FEHLER: Keine OVFJ Datei spezifiziert");
		close (OUTFILE) || die "close: $!";
		return 1;	# Fehler
	}	
	
	unless (-e $inputpath.$sep.$genfilename && -d $inputpath.$sep.$genfilename)
	{
		meldung(FEHLER,"Verzeichnis \'".$inputpath.$sep.$genfilename."\' nicht vorhanden");
		close (OUTFILE) || die "close: $!";
		return 2;	# Fehler mit Schleifenabbruch
	}
	
	if (!open (INFILE,"<",$inputpath.$sep.$genfilename.$sep.$ovfj->{"OVFJDatei"}))
	{
		RepMeld(*OUTFILE,"FEHLER: Kann OVFJ Datei ".$ovfj->{"OVFJDatei"}." nicht lesen");
		close (OUTFILE) || die "close: $!";
		return 1;	# Fehler
	}

#	$auswerthash{$ovfjname} = 1;	# Wert ist egal, nur Vorhandensein des Schlüssels zählt
# FIXME: Move to GUI
#	$OVJ::GUI::ovfj_eval_button->configure(-state => 'disabled');
#	$OVJ::GUI::reset_eval_button->configure(-state => 'normal');
#	$OVJ::GUI::exp_eval_button->configure(-state => 'normal');
	
	$lfdauswert++; # Fortlaufende Numerierung aller OVFJ Auswertungen

	while (<INFILE>)
	{
		s/\r//;
		$HelferInKopf = 0;
		if ($AddedVerant == 1)
		{
			#print $_;
			chomp;						# entferne CR am Zeilenende
			tr/\t/ /;					# ersetze Tabulatoren durch Leerzeichen
			next if /^#/;				# ignoriere Zeilen die mit einem # beginnen
			next if ($_ eq "");		# und leere Zeilen 
			next if /^\s+$/;			# und Zeilen, die nur aus Leerzeichen bestehen
			$line++;
			if (/^<(\/?)([^>]+)>$/)
			{
				if ($2 eq "Ignorier" || $2 eq "Ignoriere")
				{
					if ($1 eq '/')
					{
						$Ignoriermode = 0;
						RepMeldFile(*OUTFILE,"\n<Ende Ignorierabschnitt>");
					}
					else
					{
						$Ignoriermode = 1;
						RepMeldFile(*OUTFILE,"\n<Beginn Ignorierabschnitt>");
					}
				}
				next if ($Ignoriermode == 1);		# Ignoriere alles was sonst sein koennte
				
				if ($2 eq "Helfer")
				{
					if ($1 eq '/')
					{
						$Helfermode = 0;
						RepMeldFile(*OUTFILE,"\n<Ende Helferabschnitt>");
					}
					else
					{
						$Helfermode = 1;
						RepMeldFile(*OUTFILE,"\n<Beginn Helferabschnitt>");
					}
				}
				if ($2 eq "Keine Sonderpunkte")
				{
					if ($1 eq '/')
					{
						$KeineSonderpunkte = 0;
						RepMeldFile(*OUTFILE,"\n<Ende Abschnitt ohne Sonderpunkte>");
					}
					else
					{
						$KeineSonderpunkte = 1;
						RepMeldFile(*OUTFILE,"\n<Beginn Abschnitt ohne Sonderpunkte>");
					}
				}
#				if ($2 eq "TODO")
#				{
#					if ($1 eq '/')
#					{
#						$KeineSonderpunkte = 0;
#						RepMeldFile(*OUTFILE,"\n<Ende Abschnitt ohne Sonderpunkte>");
#					}
#					else
#					{
#						$KeineSonderpunkte = 1;
#						RepMeldFile(*OUTFILE,"\n<Beginn Abschnitt ohne Sonderpunkte>");
#					}
#				}
				next;
			}
			next if ($Ignoriermode == 1);		# Ignoriere alles was sonst sein koennte
			if (/^Helfer:\s*(.+)$/ && $evermatched == 0) # nur am Kopf der Datei matchen, nicht nach Auswertung
			{
				$str2 = $1;
				$str2 =~ s/\s+$//;
				$str2 =~ tr/,/ /;
				($ev_vorname,$ev_nachname,$ev_call,$ev_dok,$ev_gebjahr) = split(/\s+/,$str2);
				$ev_call = uc($ev_call);
				$ev_call = "---" if ($ev_call eq "" || uc($ev_call) eq "SWL");
				$ev_dok = uc($ev_dok);
				$ev_dok = "---" if ($ev_dok eq "");
				($patmatched,$platz) = (1,0);
				$HelferInKopf = 1;
				#print "Vorname: <".$ev_vorname."> Nachname: <".$ev_nachname."> Call: <".$ev_call."> DOK: <".$ev_dok."> Gebjahr: <".$ev_gebjahr.">\n";
			}
		}

		if ($AddedVerant == 1)
		{
			if ($HelferInKopf == 0)
			{
				($patmatched,$platz,$ev_nachname,$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok) = MatchPat($_, $ovfj->{Auswertungsmuster});
				$str2 = "\nTeilnehmer: ";
				$str2 = "\nHelfer: " if ($Helfermode == 1);
				$matcherrortext = $platz if ($patmatched == 0);	# Fehlertext steht in zweitem Rückgabewert
			}
			else
			{
				$str2 = "\nHelfer: ";
			}
		}
		else
		{
			($patmatched,$platz,$ev_nachname,$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok) =
			(1,0,$ovfj->{"Verantw_Name"},$ovfj->{"Verantw_Vorname"},$ovfj->{"Verantw_GebJahr"},$ovfj->{"Verantw_CALL"},$ovfj->{"Verantw_DOK"});
			$ev_call = "---" if ($ev_call eq "" || uc($ev_call) eq "SWL");
			$ev_dok = "---" if ($ev_dok eq "");
			$str2 = "\nAusrichter: ";
			$matcherrortext = $platz if ($patmatched == 0);	# Fehlertext steht in zweitem Rückgabewert
		}
		if ($patmatched)
		{
			$str2 .= $ev_nachname.", ".$ev_vorname.", ".$ev_gebjahr.", ".$ev_call.", ".$ev_dok;
			RepMeldFile(*OUTFILE,$str2);
			$override_call = 0;
			$override_dok = 0;
			$override_gebjahr = 0;
			$override_IsInPmvj = 0;
			if (defined $overrides)
			{
				if ($overrides =~ /^$ev_nachname,$ev_vorname,([^,]*),([^,]*),(\d*),(\w*)$/m)
				{
					RepMeldFile(*OUTFILE,"INFO: Overridedatensatz für ".$ev_nachname.", ".$ev_vorname." gefunden");
					if ($1 ne "")
					{
						$ev_call = $1;		# Override des Rufzeichens
						$override_call = 1;
					}
					if ($2 ne "")
					{
						$ev_dok = $2;		# Override des DOK
						$override_dok = 1;
					}
					if ($3 ne "")
					{
						$ev_gebjahr = $3;		# Override des Geburtsjahres
						$override_gebjahr = 1;
					}
					if ($4 ne "")
					{	# Override des PM Status im Vorjahr
						$override_IsInPmvj = 1 if ($4 eq "IstInPMVJ");
						$override_IsInPmvj = 2 if ($4 eq "NichtInPMVJ");
					}
				}
			}
			if ($AddedVerant == 1 && $HelferInKopf == 0 && $evermatched == 0)
			{
				RepMeld(*OUTFILE,"INFO: Erster Match mit: ".$_);
				$evermatched = 1;
			}
			#print $ev_nachname." ".$ev_vorname."\n";
			$anztln++ if ($AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0);
			
			#Check, ob Teilnehmer identisch mit Verantwortlichem, um Warnung auszugeben
			$TlnIstAusrichter = 0;
			if (($ev_nachname eq $ovfj->{"Verantw_Name"}) &&
				 ($ev_vorname eq $ovfj->{"Verantw_Vorname"}) &&
				 ($AddedVerant == 1) )
				{
				 	RepMeld(*OUTFILE,"WARNUNG: Verantwortlicher ($ev_nachname,$ev_vorname) ist in Teilnehmer Liste");
				 	$TlnIstAusrichter = 1;
				}

			#Suche, ob PM und ob Daten stimmen
			$IsPM = 0;
			$match = 0;

			($match,$SText,$rest) = SucheTlnInPM(*OUTFILE,\@pmvjarray,\$ev_nachname,\$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok,$override_IsInPmvj,0,$nicknames);
			if ($match > 0)
			{
				RepMeldFile(*OUTFILE,"In PMVorjahr gefunden da Übereinstimmung von: ".$SText);
			}
			else
			{
				RepMeldFile(*OUTFILE,"Nicht in PMVorjahr gefunden da nur Übereinstimmung von: ".$SText);
			}
		

			if ($match != 0)
			{
				($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum) = @{$rest}[2..6];

				$IsPM = 1 if ($pmpm eq "FM");

				if ($ev_gebjahr ne "" && ($ev_gebjahr ne $pmgebjahr))
				{
					RepMeld(*OUTFILE,"INFO: Geb.jahr unterschiedlich mit PMVorjahr: ");
					RepMeld(*OUTFILE,$ev_nachname.", ".$ev_vorname." :".$ev_gebjahr." <-> ".$pmgebjahr);
				}
			}

			# Verwaltung der Platzierung fuer Nicht-PMs. $nichtpm wird bei Nicht-PMs erhoeht
			if ($IsPM == 0 && $AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0)
			{
				if ($platz ne "")
				{
					$nichtpm++ if ($platz ne $oldnotpmplatz);	# nur erhoehen, wenn auf verschiedenen Plaetzen
					$oldnotpmplatz = $platz;
				}
				else
				{
					$nichtpm++;
				}
			}
			
			#Jetzt wird geschaut, ob Teilnehmer auch in aktueller Datei gefunden wird
			#oder ob z.B. der Vorname angepasst werden muss
			
			($match,$SText,$rest) = SucheTlnInPM(*OUTFILE,\@pmaktarray,\$ev_nachname,\$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok,$override_IsInPmvj,1,$nicknames);
			

			$aktJahr = 0;							# Default: nicht in aktueller PM Datei gefunden
			if ($match > 0)
			{
				($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum) = @{$rest}[2..6];
				$str2 = "";
				$pmcall = "---" if ($pmcall eq "SWL");
				$pmdok = "---" if ($pmdok eq "");
				if ($ev_call ne "" && $pmcall ne $ev_call)
				{
					$str2 = "  Call: ".$ev_call.($override_call ? " (Override)" : " (OVFJ)")." <-> ".$pmcall." (akt.PMDatei)";
				}
				if ($ev_dok ne "" && $pmdok ne $ev_dok)
				{
					$str2 .= "  DOK: ".$ev_dok.($override_dok ? " (Override)" : " (OVFJ)")." <-> ".$pmdok." (akt.PMDatei)";
				}
				if ($ev_gebjahr ne "" && $pmgebjahr ne $ev_gebjahr)
				{
					$str2 .= "  Geb.jahr: ".$ev_gebjahr.($override_gebjahr ? " (Override)" : " (OVFJ)")." <-> ".$pmgebjahr." (akt.PMDatei)";
				}
				if ($str2 ne "")
				{
					$str2 = "INFO: ".$ev_nachname.", ".$ev_vorname.":".$str2;
					RepMeld(*OUTFILE,$str2);
				}
				$aktJahr = 1;	# zwar gefunden, aber keine Teilnahme im aktuellen Jahr (kann nachfolgend ueberschrieben werden)
				$aktJahr = 2 if ($pmdatum =~ /^$general->{Jahr}\d{4}$/);
			}		
			
			if ($IsPM == 0 && $AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0 && $KeineSonderpunkte == 0)
			{
				$SPunktePlatz = 1;
			}
			else
			{
				$SPunktePlatz = 0;
			}
			
			$tnkey = join(',',$ev_nachname,$ev_vorname);	# key ist Nachname,Vorname
			if (exists($tn->{$tnkey}))
			{
				#print "Found Call: ".$tn->{$tnkey}->{call};
				$str2 = sprintf("%u",$lfdauswert);
				if ($tn->{$tnkey}->{wwbw} =~ /$str2/)
				{
					if ($TlnIstAusrichter == 0)
					{
						RepMeld(*OUTFILE,"FEHLER: ".$ev_nachname.", ".$ev_vorname." ist bereits in laufender Auswertung");
					}
					else
					{
						RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname." ist als Ausrichter bereits in laufender Auswertung, ignoriere Teilnahme als Teilnehmer");
					}
					next;
				}					
				$str2 = $tnkey." ist bereits in Auswertung, Status: ";
				$tn->{$tnkey}->{anzwwbw}++;
				$tn->{$tnkey}->{wwbw} .= ",".sprintf("%u",$lfdauswert);
				$tn->{$tnkey}->{anzausr} += ($AddedVerant == 0 ? 1 : 0);
				if ($SPunktePlatz == 1)
				{
					$tn->{$tnkey}->{anzpl1} += ($nichtpm == 1 ? 1 : 0);
					$tn->{$tnkey}->{anzpl2} += ($nichtpm == 2 ? 1 : 0);
				}
				$tn->{$tnkey}->{anzhelf}++ if ($Helfermode == 1 || $HelferInKopf == 1);

				# Abgleich Rufzeichen
				$tn->{$tnkey}->{call} = $ev_call if (($tn->{$tnkey}->{call} eq "---" || $tn->{$tnkey}->{call} eq "") && ($ev_call ne "---" && $ev_call ne ""));
				if ($tn->{$tnkey}->{call} ne "---" && $tn->{$tnkey}->{call} ne "" && $ev_call ne $tn->{$tnkey}->{call})
				{
					RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": Rufzeichen unterschiedlich: ".$tn->{$tnkey}->{call}." (alt, bleibt)<->(OVFJ) ".$ev_call);
				}

				# Abgleich DOK
				$tn->{$tnkey}->{dok} = $ev_dok if ($tn->{$tnkey}->{dok} eq "" && $ev_dok ne "");
				if ($tn->{$tnkey}->{dok} ne "" && $ev_dok ne "" && $ev_dok ne $tn->{$tnkey}->{dok})
				{
					RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": DOK unterschiedlich: ".$tn->{$tnkey}->{dok}." (alt, bleibt)<->(OVFJ) ".$ev_dok);
				}

				# Abgleich Geburtsjahr
				$tn->{$tnkey}->{gebjahr} = $ev_gebjahr if ($tn->{$tnkey}->{gebjahr} eq "" && $ev_gebjahr ne "");
				if ($tn->{$tnkey}->{gebjahr} ne "" && $ev_gebjahr ne "" && $ev_gebjahr ne $tn->{$tnkey}->{gebjahr})
				{
					RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": Geburtsjahr unterschiedlich: ".$tn->{$tnkey}->{gebjahr}." (alt, bleibt)<->(OVFJ) ".$ev_gebjahr);
				}
				
			}
			else
			{
				$str2 = $tnkey." ist neu in Auswertung, Status: ";
				$tndata = {	"nachname" => $ev_nachname,
								"vorname" => $ev_vorname,
								"call" => $ev_call,
								"dok" => $ev_dok,
								"gebjahr" => $ev_gebjahr,
								"pmvj" => $IsPM,
								"wwbw" => sprintf("%u",$lfdauswert),
								"anzwwbw" => 1,
								"anzpl1" => (($nichtpm == 1 && $SPunktePlatz == 1) ? 1 : 0),
								"anzpl2" => (($nichtpm == 2 && $SPunktePlatz == 1) ? 1 : 0),
								"anzausr" => ($AddedVerant == 0 ? 1 : 0),
								"anzhelf" => (($Helfermode == 1 || $HelferInKopf == 1) ? 1 : 0),
								"aktjahr" => $aktJahr
							};
				$tn->{$tnkey} = $tndata;
			}
			$str2 .= "Helfer" if ($Helfermode == 1 || $HelferInKopf == 1);
			$str2 .= "Ausrichter" if ($AddedVerant == 0);
			$str2 .= "1 Extrapunkt für Platz 2 als Nicht-PM" if ($nichtpm == 2 && $SPunktePlatz == 1);
			$str2 .= "2 Extrapunkte für Platz 1 als Nicht-PM" if ($nichtpm == 1 && $SPunktePlatz == 1);
			$str2 .= "PM im Vorjahr" if ($IsPM && $Helfermode == 0 && $HelferInKopf == 0 && $AddedVerant == 1);
			RepMeldFile(*OUTFILE,$str2);
		}
		else
		{
			if ($evermatched == 1)
			{
				RepMeld(*OUTFILE,"\nINFO: kein Match (Ursache: ".$matcherrortext.") bei:") if ($oldline+1 < $line);
				RepMeld(*OUTFILE,$_);
				$oldline = $line;
			}
		}
		if ($AddedVerant == 0)
		{
			$AddedVerant = 1;
			redo; # Die Schleife noch einmal durchlaufen, diesmal mit der Auswertung des ersten
			      # Datensatzes. Durch das 'redo' wird aus INFILE nichts neues gelesen
		}
	} # Ende von while (<INFILE>)

	RepMeld(*OUTFILE,"INFO: kein einziger Match! Letzte Ursache: ".$matcherrortext) if ($evermatched == 0);

	%ovfjcopy = %$ovfj;
	push (@{$ovfjlist},\%ovfjcopy);
	if ($ovfj->{"TlnManuell"} ne "")
	{# Manuelle Vorgabe hat Vorrang vor automatischer Zaehlung
		push (@{$ovfjanztlnlist},$ovfj->{"TlnManuell"});
	}
	else
	{
		push (@{$ovfjanztlnlist},$anztln);
	}

	meldung(HINWEIS,"");	# Erzeuge Leerzeile zwischen Auswertungen

	close (OUTFILE) || die "close: $!";
	close (INFILE) || die "close: $!";
	return 0;	# kein Fehler
}


#Export der Auswertung(en) im Speicher in die verschiedenen Formate
sub export {
	my $general = shift;
	my $tn = shift;
	my $ovfjlist = shift;
	my $ovfjanztlnlist = shift;
#	my $outputpath = shift;
#	my $genfilename = shift;

	my ($rawresultfilename,$asciiresultfilename,$htmlresultfilename);
	my ($tnkey,$tndatakey);
	my $addoutput = '';
	my $ExcludeTln;
	my $ovfjlistelement;
	my ($i,$str2);
	my %maxlen = ("kombiname",0, #Vorbelegen um Abfrage unten zu sparen
					  "gebjahr",length("GebJahr  "),
					  "wwbw",length("Wettbewerbe"));
	my ($sec,$min,$hour,$mday,$mon,$myear,$wday,$yday,$isdst) = localtime(time);

	$ExcludeTln = $general->{Exclude_Checkmark};

	$rawresultfilename = "OVJ_Ergebnisse_".$general->{"Distriktskenner"}."_".$general->{Jahr}."raw.txt";
	
	unless (-e $outputpath.$sep.$genfilename && -d $outputpath.$sep.$genfilename)
	{
		meldung(HINWEIS,"Erstelle Verzeichnis \'".$genfilename."\' in \'".$outputpath."\'");
		unless (mkdir($outputpath.$sep.$genfilename))
		{
			meldung(FEHLER,"Konnte Verzeichnis \'".$outputpath.$sep.$genfilename."\' nicht erstellen".$!);
			return;
		}
	}	
	
	if (!open (ROUTFILE,">",$outputpath.$sep.$genfilename.$sep.$rawresultfilename))
	{
		meldung(FEHLER,"Kann ".$rawresultfilename." nicht schreiben");
		return;
	}
	$asciiresultfilename = "OVJ".$general->{"Distriktskenner"}.$general->{Jahr}.".txt";
	if (!open (AOUTFILE,">",$outputpath.$sep.$genfilename.$sep.$asciiresultfilename))
	{
		meldung(FEHLER,"Kann ".$asciiresultfilename." nicht schreiben");
		return;
	}
	$htmlresultfilename = "OVJ_Ergebnisse_".$general->{"Distriktskenner"}."_".$general->{Jahr}.".htm";
	if (!open (HOUTFILE,">",$outputpath.$sep.$genfilename.$sep.$htmlresultfilename))
	{
		meldung(FEHLER,"Kann ".$htmlresultfilename." nicht schreiben");
		return;
	}
	
	printf AOUTFILE "             OV Jahresauswertung ".$general->{Jahr}." des Distrikts ".$general->{"Distrikt"}."\n\n";
	printf AOUTFILE "OV-Wettbewerbe des Distriktes   ".$general->{"Distrikt"}."\n";
	printf AOUTFILE "für das Jahr                    ".$general->{Jahr}."\n";
	printf AOUTFILE "Distriktspeilreferent\n";
	printf AOUTFILE "Name, Vorname                   ".$general->{"Name"}.", ".$general->{"Vorname"}."\n";
	printf AOUTFILE "Call                            ".$general->{"Call"}."\n";
	printf AOUTFILE "DOK                             ".$general->{"DOK"}."\n";
	printf AOUTFILE "Telefon                         ".$general->{"Telefon"}."\n";
	printf AOUTFILE "Home-BBS                        ".$general->{"Home-BBS"}."\n";
	printf AOUTFILE "E-Mail                          ".$general->{"E-Mail"}."\n";
	printf AOUTFILE "Auswertung mit                  OVJ (Version ".$ovjvers." vom ".$ovjdate.")\n";
	printf AOUTFILE ("am                              %i.%i.%i\n",$mday,$mon+1,$myear+1900);
	if ($ExcludeTln == 1)
	{
		printf AOUTFILE "Hinweis                         Teilnehmer ohne Teilnahme an offiziellen Wettbewerb in ".$general->{Jahr}."\n";
		printf AOUTFILE "                                wurden von OVJ entfernt\n";
	}

	printf AOUTFILE "\n********************************\n";
	printf AOUTFILE "* Durchgeführte OV-Wettbewerbe *\n";
	printf AOUTFILE "********************************\n";
	printf AOUTFILE "Nr. Ausrichtender OV           DOK  Verantwortlicher          Call    DOK  Datum       Band  Teilnehmer\n";
	printf AOUTFILE "-------------------------------------------------------------------------------------------------------\n";

	printf HOUTFILE "<html>\n<head>\n<title>OV Jahresauswertung ".$general->{Jahr}." des Distrikts ".$general->{"Distrikt"}."</title>\n</head>\n";
	printf HOUTFILE "<body>\n";
	printf HOUTFILE "<h1>Jahresauswertung der OV-Peilveranstaltungen</h1>\n";
	printf HOUTFILE "<table border=\"0\"><tbody align=\"left\">\n";
	printf HOUTFILE "<tr><td>OV-Wettbewerbe des Distriktes&nbsp;&nbsp;&nbsp;</td>\n";
	printf HOUTFILE "<td><b>".$general->{"Distrikt"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>für das Jahr</td>\n";
	printf HOUTFILE "<td><b>".$general->{Jahr}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td><b>Distriktspeilreferent</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Name, Vorname</td>\n";
	printf HOUTFILE "<td><b>".$general->{"Name"}.", ".$general->{"Vorname"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Call</td>\n";
	printf HOUTFILE "<td><b>".$general->{"Call"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>DOK</td>\n";
	printf HOUTFILE "<td><b>".$general->{"DOK"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Telefon</td>\n";
	printf HOUTFILE "<td><b>".$general->{"Telefon"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Home-BBS</td>\n";
	printf HOUTFILE "<td><b>".$general->{"Home-BBS"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>E-Mail</td>\n";
	printf HOUTFILE "<td><b>".$general->{"E-Mail"}."</b></td></tr>\n";
	printf HOUTFILE "</tbody></table><br><br>\n";

	printf HOUTFILE "<table border=\"1\">\n";
	printf HOUTFILE "<thead><tr><th colspan=\"9\">Durchgeführte OV-Wettbewerbe</b></th></tr>\n";
	printf HOUTFILE "<tr><th>Nr.</th><th>Ausrichtender OV</th><th>DOK</th><th>Verantwortlicher</th>";
	printf HOUTFILE "<th>Call</th><th>DOK</th><th>Datum</th><th>Band</th><th>Teilnehmer</th></tr>\n";
	printf HOUTFILE "</thead><tbody>\n";

	$i = 1;
	foreach $ovfjlistelement (@$ovfjlist)
	{
		printf AOUTFILE substr(" ".$i."  ",0,4).substr($ovfjlistelement->{"AusrichtOV"}." "x27,0,27).substr($ovfjlistelement->{"AusrichtDOK"}."     ",0,5);
		printf AOUTFILE substr($ovfjlistelement->{"Verantw_Name"}.", ".$ovfjlistelement->{"Verantw_Vorname"}." "x26,0,26);
		printf AOUTFILE substr($ovfjlistelement->{"Verantw_CALL"}." "x8,0,8).substr($ovfjlistelement->{"Verantw_DOK"}." "x5,0,5);
		printf AOUTFILE substr($ovfjlistelement->{"Datum"}." "x13,0,13).substr($ovfjlistelement->{"Band"}." "x9,0,9).@$ovfjanztlnlist[$i-1]."\n";

		printf HOUTFILE "<tr><td>".$i."</td><td>".$ovfjlistelement->{"AusrichtOV"}."</td><td>".$ovfjlistelement->{"AusrichtDOK"}."</td>";
		printf HOUTFILE "<td>".$ovfjlistelement->{"Verantw_Name"}.", ".$ovfjlistelement->{"Verantw_Vorname"}."</td>\n";
		printf HOUTFILE "<td>".($ovfjlistelement->{"Verantw_CALL"} eq "" ? "&nbsp;" : $ovfjlistelement->{"Verantw_CALL"})."</td>";
		printf HOUTFILE "<td>".($ovfjlistelement->{"Verantw_DOK"} eq "" ? "&nbsp;" : $ovfjlistelement->{"Verantw_DOK"})."</td>";
		printf HOUTFILE "<td>".$ovfjlistelement->{"Datum"}."</td><td>".$ovfjlistelement->{"Band"}."</td>";
		printf HOUTFILE "<td>".@$ovfjanztlnlist[$i-1]."</td></tr>\n";
		$i++;
	}

	printf HOUTFILE "</tbody></table><br>\n";

	printf HOUTFILE "<br><table border=\"1\">\n";
	printf HOUTFILE "<thead><tr><th colspan=\"11\">Teilnehmer der OV-Wettbewerbe</b></th></tr>\n";
	printf HOUTFILE "<tr><th>Name, Vorname</th><th>Call</th><th>DOK</th><th>Geburtsjahr</th>";
	printf HOUTFILE "<th>PM im Vorjahr</th><th>Wettbewerbe</th><th>Anzahl OV FJ</th>";
	printf HOUTFILE "<th>Anz. Platz 1</th><th>Anz. Platz 2</th><th>Anz. Ausrichter</th><th>Anz. Helfer</th></tr></thead>\n<tbody>\n";

	foreach $tnkey (sort keys %$tn)
	{
		foreach $tndatakey (keys %{$tn->{$tnkey}})
		{
			if (exists($maxlen{$tndatakey}))
			{
				if (length($tn->{$tnkey}->{$tndatakey})>$maxlen{$tndatakey})
				{
					$maxlen{$tndatakey} = length($tn->{$tnkey}->{$tndatakey});
				}
			}
			else
			{
				$maxlen{$tndatakey} = length($tn->{$tnkey}->{$tndatakey});
			}
		}
		# die Längeninfo für die Kombination beider Namen muss speziell erzeugt werden
		if (length($tn->{$tnkey}->{nachname}.$tn->{$tnkey}->{vorname})>$maxlen{kombiname})
		{
			$maxlen{kombiname} = length($tn->{$tnkey}->{nachname}.$tn->{$tnkey}->{vorname});
		}
	}

	printf AOUTFILE "\n*********************************\n";
	printf AOUTFILE "* Teilnehmer der OV-Wettbewerbe *\n";
	printf AOUTFILE "*********************************\n";

	my $str = "Name, Vorname"." "x($maxlen{kombiname}-length("Name, Vorname")+4)."Call"." "x($maxlen{call}-length("Call")+2);
	$str .= "DOK"." "x($maxlen{dok}-length("DOK")+2)."GebJahr  "."PMVJ?  "."Wettbewerbe"." "x($maxlen{wwbw}-length("Wettbewerbe")+1);
	$str .= "AnzFJ  "."Platz1  "."Platz2  "."Ausrichter  "."Helfer";
	$str2 = $str;
	$str .= "  akt.Jahr" if ($ExcludeTln == 0);

	printf ROUTFILE $str."\n";
	printf ROUTFILE "-"x(length($str))."\n";
	printf AOUTFILE $str2."\n";
	printf AOUTFILE "-"x(length($str2))."\n";
	foreach $tnkey (sort keys %$tn) {

		if ($ExcludeTln == 1 && $tn->{$tnkey}->{aktjahr} == 1)
		{
			$addoutput .= "Schliesse ".$tn->{$tnkey}->{nachname}.", ".$tn->{$tnkey}->{vorname}." aus, da kein offizieller Wettbewerb in ".$general->{Jahr}."\n";
			next;
		}

		if ($ExcludeTln == 1 && $tn->{$tnkey}->{aktjahr} == 0)
		{
			$addoutput .= "Schliesse ".$tn->{$tnkey}->{nachname}.", ".$tn->{$tnkey}->{vorname}." aus, da Name nicht in aktueller PM Datei\n";
			next;
		}

		$str = $tn->{$tnkey}->{nachname}.", ".
		$tn->{$tnkey}->{vorname}." "x($maxlen{kombiname}-length($tn->{$tnkey}->{nachname}.$tn->{$tnkey}->{vorname})+2).
		$tn->{$tnkey}->{call}." "x($maxlen{call}-length($tn->{$tnkey}->{call})+2).
		$tn->{$tnkey}->{dok}." "x($maxlen{dok}-length($tn->{$tnkey}->{dok})+2).
		$tn->{$tnkey}->{gebjahr}." "x($maxlen{gebjahr}-length($tn->{$tnkey}->{gebjahr})+1).
		($tn->{$tnkey}->{pmvj} ? "JA" : "--")."    ".
		$tn->{$tnkey}->{wwbw}." "x($maxlen{wwbw}-length($tn->{$tnkey}->{wwbw})+3).
		$tn->{$tnkey}->{anzwwbw}."      ".($tn->{$tnkey}->{anzwwbw}<10 ? " " : "").
		$tn->{$tnkey}->{anzpl1}."       ".
		$tn->{$tnkey}->{anzpl2}."        ".
		$tn->{$tnkey}->{anzausr}."         ".
		$tn->{$tnkey}->{anzhelf};
		$str2 = $str;
		$str .= ($tn->{$tnkey}->{aktjahr} != 2 ? "       Nein" : "");
		
		printf ROUTFILE $str."\n";
		printf AOUTFILE $str2."\n";
		
		printf HOUTFILE "<tr><td>".$tn->{$tnkey}->{nachname}.", ".$tn->{$tnkey}->{vorname}."</td>";
		printf HOUTFILE "<td>".($tn->{$tnkey}->{call} eq "" ? "&nbsp;" : $tn->{$tnkey}->{call})."</td><td>".($tn->{$tnkey}->{dok} eq "" ? "&nbsp;" : $tn->{$tnkey}->{dok})."</td>\n";
		printf HOUTFILE "<td>".($tn->{$tnkey}->{gebjahr} eq "" ? "&nbsp;" : $tn->{$tnkey}->{gebjahr})."</td><td>".($tn->{$tnkey}->{pmvj} ? "JA" : "--")."</td>";
		printf HOUTFILE "<td>".$tn->{$tnkey}->{wwbw}."</td><td>".$tn->{$tnkey}->{anzwwbw}."</td>\n";
		printf HOUTFILE "<td>".$tn->{$tnkey}->{anzpl1}."</td><td>".$tn->{$tnkey}->{anzpl2}."</td><td>".$tn->{$tnkey}->{anzausr}."</td><td>".$tn->{$tnkey}->{anzhelf}."</td></tr>\n";
	}
	
	if ($addoutput ne "")
	{
		printf ROUTFILE "\n".$addoutput."\n";
	}
	
	printf HOUTFILE "</tbody></table>\n";
	printf HOUTFILE "<h5>erzeugt durch OVJ  (Version ".$ovjvers." vom ".$ovjdate.")</h5>\n";
	printf HOUTFILE "</body>\n</html>\n";
	
	close (ROUTFILE) || die "close: $!";
	close (AOUTFILE) || die "close: $!";
	close (HOUTFILE) || die "close: $!";
}

#Ausgabe einer Meldung im Meldungsfenster und der Report-Datei
sub RepMeld {
	local *FH = shift;
	printf FH $_[0]."\n";
	local $_ = $_[0];
	tr/\n//d;							# entferne alle CRs
	meldung(HINWEIS, $_);
}

#Ausgabe einer Meldung in der Report-Datei
sub RepMeldFile {
	local *FH = shift;
	printf FH $_[0]."\n";
}


#Speichern der Pattern Datei
sub save_patterns {
	my $patterns = shift;
	open (my $patternfile, '>', $patternfilename)
	  or return meldung(FEHLER, "Kann Datei '$patternfilename' nicht schreiben: $!");
	print $patternfile $patterns;
	close $patternfile
	  or return meldung(FEHLER, "Kann Datei '$patternfilename' nicht schließen: $!");
}

#Lesen der Pattern Datei
sub read_patterns {
	my $patterns = '';
	if (-e $patternfilename) {
		if (open (my $patternfile, '<', $patternfilename)) {
			read $patternfile, $patterns, -s $patternfilename;
			close $patternfile
			  or meldung(FEHLER, "Kann Datei '$patternfilename' nicht schließen: $!");
			$patterns =~ s/\r//g;
		} else {
			return meldung(FEHLER, "Kann Datei '$patternfilename' nicht öffnen: $!");
		}
	}
	return $patterns;
}

#=new

#Lesen der Generellen Daten aus der Genfile Datei
sub read_genfile {
#my ($choice,$filename) = @_;	# 0 = Laden, 1 = Importieren
	my $filename = shift;
	defined $filename or carp "filename required";
	if ($filename !~ /\/|\\/) {
		defined $configpath or carp "'configpath' required for '$filename'";
		$filename = $configpath.$sep.$filename.$sep.$filename.'.txt';
	}

	open (INFILE, '<', $filename)
	  or return meldung(FEHLER,"Kann '$filename' nicht öffnen: $!");

	my %general;
#	my @fjlist;
	while (<INFILE>)
	{
		next if /^#/;
		next if /^\s/;
		s/\r//;
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s*$/)
		{
#			if ($1 eq "ovfj_link") { push(@fjlist,$2) }
			if ($1 eq "ovfj_link") { push(@{$general{$1}},$2) }
			else                   { $general{$1} = $2 }
		}
	}
	close (INFILE) || die "close: $!";
	return %general;
}

#Schreiben der Generellen Daten in die Genfile Datei
sub write_genfile {
	my ($filename, %general) = @_;

	defined $filename or carp "filename required";
	if ($filename !~ /\/|\\/) {
		defined $configpath or carp "'configpath' required for '$filename'";
		unless (-d $configpath.$sep.$filename) {
			meldung(HINWEIS,"Erstelle Verzeichnis '$configpath$sep$filename'");
			mkdir($configpath.$sep.$filename)
			  or return meldung(FEHLER,"Konnte Verzeichnis '$configpath$sep$filename' nicht erstellen: $!");
		}
		$filename = $configpath.$sep.$filename.$sep.$filename.'.txt';
	}

=pointless here

	unless (-e $inputpath.$sep.$genfilename && -d $inputpath.$sep.$genfilename)
	{
		meldung(HINWEIS,"Erstelle Verzeichnis \'".$genfilename."\' in \'".$inputpath."\'");
		unless (mkdir($inputpath.$sep.$genfilename))
		{
			meldung(FEHLER,"Konnte Verzeichnis \'".$inputpath.$sep.$genfilename."\' nicht erstellen".$!);
			return 1;	# Fehler
		}
	}
	
=cut
	
	open (OUTFILE, '>', $filename)
	  or return meldung(FEHLER,"Kann ".$filename." nicht schreiben");
	print OUTFILE "#OVJ Toplevel-Datei für $general{Jahr}\n\n";
	my $key;
	foreach my $key (keys %general) {
		next if ($key eq 'ovfj_link');
		print OUTFILE "$key = $general{$key}\n";
	}
	print OUTFILE "\n";
	map { print OUTFILE "ovfj_link = $_\n" } @{$general{ovfj_link}};
	close (OUTFILE) || die "close: $!";
}


sub meldung { 
	my $level = shift;
	my $message = shift;
	carp "$level: $message" if ($level eq WARNUNG || $level eq FEHLER);
	foreach (@meldung_callback) {
		&$_($level, $message);
	}
	return if ($level eq FEHLER); 
	return 1;
}

sub meldung_callback_add {
	my $callback = shift;
	if (ref $callback) {
		push @meldung_callback, $callback;
	}
	else {
		carp "Callback must be a reference";
	}
}

sub meldung_callback_remove {
	my $callback = shift;
	if (ref $callback) {
		@meldung_callback = grep { $_ != $callback } @meldung_callback;
	}
	else {
		carp "Callback must be a reference";
	}
}


#Lesen einer Input-Datei
sub read_ovfj_infile {
	my $filename = $inputpath.$sep.$genfilename.$sep.(shift);
	open my $infile, '<', $filename
	 or return meldung(FEHLER, "Kann '$filename' nicht lesen: $!");
	my @data = <$infile>;
	close $infile
	 or die "close: $!";
	return wantarray ? @data : join('', @data);
}

#Lesen der Daten aus einer OVFJ Datei
sub read_ovfjfile {
	my $ovfjfilename = (shift) . "_ovj.txt";
	open my $infile, '<', $configpath.$sep.$genfilename.$sep.$ovfjfilename
	 or return meldung(FEHLER, "Kann '$ovfjfilename' nicht lesen: $!");

	my %ovfj;
	my $ovfj = '';
	while (<$infile>) {
		$ovfj .= $_;
		next if /^#/;
		next if /^\s/;
		s/\r//;
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s*$/) {
			$ovfj{$1} = $2;
		}
	}
	close $infile
	 or die "close: $!";
	return %ovfj
}


#Schreiben der aktuellen OVFJ Daten
sub write_ovfjfile {
	my $ovfjfilename = (shift) . "_ovj.txt";;
	my $ovfj = shift; # Referenz auf %ovfj
	open my $outfile, '>', $configpath.$sep.$genfilename.$sep.$ovfjfilename
	 or return meldung(FEHLER, "Kann '$ovfjfilename' nicht schreiben: $!");
	print $outfile "#OVFJ Datei\n";
	foreach my $key (keys %$ovfj) {
		print $outfile "$key = $ovfj->{$key}\n";
	}
	close $outfile
	 or die "close: $!";
}


# FIXME: Patterns zusammenfassen
sub import_fjfile {
	my $filename = shift;
	my %ovfj = ( OVFJDatei => $filename );
	open my $infile, '<', $inputpath.$sep.$genfilename.$sep.$filename
	 or return OVJ_meldung(FEHLER, "Kann OVFJ Datei '$filename' nicht lesen: $!");
	my $tp;
	while (<$infile>) {
		s/\r//;
		if (/^Organisation:\s*(.+)$/) {
			$tp = $1;
			$tp =~ s/^OV\s+//;
			$tp =~ s/\s+$//;
			$ovfj{AusrichtOV} = $tp;
			next;
		}
		if (/^DOK:\s*([A-Z]\d{2})$/i) { # Case insensitive
			$tp = uc($1);
			$tp =~ s/\s+$//;
			$ovfj{AusrichtDOK} = $tp;
			next;
		}
		if (/^Datum:\s*(\d{1,2}\.\d{1,2}\.\d{2,4})$/) {
			$tp = $1;
			$tp =~ s/\s+$//;
			$ovfj{Datum} = $tp;
			next;
		}
		if (/^Verantwortlich:\s*(.+)$/)	{
			$tp = $1;
			$tp =~ s/\s+$//;
			$tp =~ tr/,/ /;
			my @fi = split(/\s+/, $tp);
			$ovfj{Verantw_Vorname} = $fi[0] if (@fi >= 1);
			$ovfj{Verantw_Name} = $fi[0] if (@fi >= 2);
			$ovfj{Verantw_CALL} = $fi[0] if (@fi >= 3);
			$ovfj{Verantw_DOK} = $fi[0] if (@fi >= 4);
			$ovfj{Verantw_GebJahr} = $fi[0] if (@fi >= 5);
			next;
		}
		if (/^Teilnehmerzahl:\s*(\d+)/) {
			$ovfj{TlnManuell} = $1;
			next;
		}
		if (/^Band:\s*(\d{1,2})/) {
			$ovfj{Band} = $1;
			next;
		}
		last if (/^---/);		# Breche bei --- ab 
	}
	close $infile
	 or die "close: $!";
	return %ovfj;
}


1;
