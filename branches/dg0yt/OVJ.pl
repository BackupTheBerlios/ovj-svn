#!/usr/bin/perl -w
#
# Branch DG0YT $Id$
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

use strict qw(vars);		# Deklarationen erzwingen
use lib "lib";	# FIXME: relativ zum Programverzeichnis ermitteln

use OVJ::Inifile;
use OVJ::GUI;
use OVJ;

use constant {
	INFO    => 'Information',
	HINWEIS => 'Hinweis',
	WARNUNG => 'Warnung',
	FEHLER  => 'Fehler',
};

my %config  = ();		# Konfigurationsdaten
my %general = ();	# Generelle Einstellungen
my %ovfj;				# Hash für eine OV Veranstaltung, Kopfdaten
my $ovfjname;			# Name der aktiven OV Veranstaltung

my $patternfilename = "OVFJ_Muster.txt";
my $overridefilename = "Override.txt";
my $inifilename = "OVJini.txt";
my $inputpath = "input";		# Pfad für die Eingangsdaten
my $outputpath = "output";		# Pfad für die Ergebnisdaten
my $reportpath = "report";		# Pfad für die Reportdaten
my $configpath = "config";		# Pfad für die Konfigurationsdaten
										# Generelle Daten, sowie die OVFJ Dateien (*_ovj.txt))
my $sep = ($^O =~ /Win/i) ? '\\' : '/';	# Kai, fuer Linux und Win32 Portabilitaet

my ($genfilename,$ovfjfilename,$ovfjrepfilename);
my @fjlist;				# Liste der OV Veranstaltungen, nur die Namen, keine Details
my $fjlistsaved;		# gespeicherte Liste der OV Veranstaltungen, auf Basis des Eingabefeldes, daher
                     # keine Liste
my %tn;					# Hash für die Teilnehmer, Elemente sind wiederum Hashes
my %auswerthash;		# Hash zur Kontrolle, welche OVFJ schon ausgewertet sind
my $lfdauswert=0;		# Nummer der lfd. OVFJ Auswertung
my $nicknames;			# Inhalt der Spitznamen Datei
my ($i,$str);			# temp. Variablen
my $pattern;			# Das 'richtige' Pattern, das aus dem textuellen erzeugt wird
my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
                  	# Elemente sind die %ovfj Daten
my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info über die Anzahl 
                     # der Teilnehmer, wird parallel zur @ovfjlist Liste geführt
my $overrides=undef;	# Overrides
my @pmvjarray;			# Array mit PMVJ Daten
my @pmaktarray;		# Array mit aktuellen PM Daten

my $gui;



intro();
$gui = OVJ::GUI::init();
init();
OVJ::GUI::run;
exit 0;



sub intro {
	my $str = "*  OVJ $OVJ::ovjvers by DL3SDO, $OVJ::ovjdate  *";
	my $sep = '*' x length($str);
	print "$sep\n$str\n$sep\n";
}


sub init {
# FIXME: local var
	%config = OVJ::Inifile::read($inifilename)
	  or OVJ_meldung(OVJ::WARNUNG,"Kann INI-Datei '$inifilename' nicht lesen: $!");
#	do_file_general(2);	# Lade Generelle Daten Datei falls vorhanden
	init_general();	# Lade Generelle Daten Datei falls vorhanden
	OVJ::GUI::set_patterns(OVJ::read_patterns());
	
	# FIXME: use loop
	unless (-e $configpath && -d $configpath)
	{
		OVJ_meldung(HINWEIS,"Erzeuge Verzeichnis \'".$configpath."\'");
		unless (mkdir($configpath))
		{
			OVJ_meldung(FEHLER,"Konnte Verzeichnis \'".$configpath."\' nicht erstellen".$!);
			return;
		}
	}
	unless (-e $reportpath && -d $reportpath)
	{
		OVJ_meldung(HINWEIS,"Erzeuge Verzeichnis \'".$reportpath."\'");
		unless (mkdir($reportpath))
		{
			OVJ_meldung(FEHLER,"Konnte Verzeichnis \'".$reportpath."\' nicht erstellen".$!);
			return;
		}
	}
	unless (-e $outputpath && -d $outputpath)
	{
		OVJ_meldung(HINWEIS,"Erzeuge Verzeichnis \'".$outputpath."\'");
		unless (mkdir($outputpath))
			{
			OVJ_meldung(FEHLER,"Konnte Verzeichnis \'".$outputpath."\' nicht erstellen".$!);
			return;
		}
	}
	unless (-e $inputpath && -d $inputpath)
	{
		OVJ_meldung(HINWEIS,"Warnung: Verzeichnis \'".$inputpath."\' nicht vorhanden");
	}
	
	$fjlistsaved = $OVJ::GUI::fjlistbox->Contents();
}



#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	unless (-e $inputpath.$sep.$genfilename && -d $inputpath.$sep.$genfilename)
	{
		OVJ_meldung(FEHLER,"Verzeichnis \'".$inputpath.$sep.$genfilename."\' nicht vorhanden");
		return;
	}
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $gui->getOpenFile(-initialdir => $inputpath.$sep.$genfilename, -filetypes => $types, -title => "FJ Datei auswählen");
	return if (!defined($selfile) || $selfile eq "");
	my $tp;
	my @fi;
	$selfile =~ s/^.*\///;
	my %ovfj_temp = OVJ::GUI::get_ovfj();
	$ovfj_temp{OVFJDatei} = $selfile;

	if (!open (INFILE,"<",$inputpath.$sep.$genfilename.$sep.$selfile))
	{
		OVJ_meldung(FEHLER,"Kann OVFJ Datei ".$selfile." nicht lesen");
		return;
	}
	while (<INFILE>)
	{
		s/\r//;
		if (/^Organisation:\s*(.+)$/)
		{
			$tp = $1;
			$tp =~ s/^OV\s+//;
			$tp =~ s/\s+$//;
			$ovfj_temp{AusrichtOV} = $tp;
			next;
		}
		if (/^DOK:\s*([A-Z]\d{2})$/i) # Case insensitive
		{
			$tp = uc($1);
			$tp =~ s/\s+$//;
			$ovfj_temp{AusrichtDOK} = $tp;
			next;
		}
		if (/^Datum:\s*(\d{1,2}\.\d{1,2}\.\d{2,4})$/)
		{
			$tp = $1;
			$tp =~ s/\s+$//;
			$ovfj_temp{Datum} = $tp;
			next;
		}
		if (/^Verantwortlich:\s*(.+)$/)
		{
			$tp = $1;
			$tp =~ s/\s+$//;
			$tp =~ tr/,/ /;
			@fi = split(/\s+/,$tp);
			$ovfj_temp{Verantw_Vorname} = $fi[0] if (@fi >= 1);
			$ovfj_temp{Verantw_Name} = $fi[0] if (@fi >= 2);
			$ovfj_temp{Verantw_CALL} = $fi[0] if (@fi >= 3);
			$ovfj_temp{Verantw_DOK} = $fi[0] if (@fi >= 4);
			$ovfj_temp{Verantw_GebJahr} = $fi[0] if (@fi >= 5);
			next;
		}
		if (/^Teilnehmerzahl:\s*(\d+)/)
		{
			$ovfj_temp{TlnManuell} = $1;
			next;
		}
		if (/^Band:\s*(\d{1,2})/)
		{
			$ovfj_temp{Band} = $1;
			next;
		}
		last if (/^---/);		# Breche bei --- ab 
	}
	close (INFILE) || die "close: $!";
	OVJ::GUI::set_ovfj(%ovfj_temp);
}


sub init_general {
	if (exists $config{LastGenFile}) {
		$genfilename = $config{LastGenFile};
		OVJ_meldung(HINWEIS,"Lade $genfilename...");
		return read_genfile(0, $genfilename);
	}
	else {
		return 1;	# KEIN Fehler
	}
}
		
=obsolete	
		if (-e $configpath.$sep.$config{LastGenFile}.$sep.$config{LastGenFile}.".txt") {
			$genfilename = $config{"LastGenFile"};
			OVJ_meldung(HINWEIS,"Lade $genfilename");
			OVJ::GUI::set_general_data_label($genfilename);
			return(read_genfile(0,$genfilename));
		}
		else {
			unless (-e $configpath.$sep.$config{"LastGenFile"} && -d $configpath.$sep.$config{"LastGenFile"})
			{
				OVJ_meldung(HINWEIS,"Kann ".$config{"LastGenFile"}." nicht laden, da Verzeichnis \'".$config{"LastGenFile"}."\' nicht existiert!");
			}
			else
			{
				OVJ_meldung(HINWEIS,"Kann ".$config{"LastGenFile"}." nicht laden! Datei existiert nicht");
			}
			return 1;	# Fehler
		}
}
=cut

#Speichern, Laden bzw. Erzeugen der Generellen Daten Datei
sub do_file_general {
	my ($choice) = @_;	# 0 = Speichern, 1 = Laden, 2 = Laden der im Inifile angegebenen, 3 = Importieren, 4 = Speichern als
	my $retstate;
	#my $tempname;
	
	if ($choice == 1)	# Laden
	{	
		return 1 if (CheckForSaveGenfile());		# Abbruch durch Benutzer
		return 1 if (CheckForOVFJList());			# Abbruch durch Benutzer
		my $types = [['Text Files','.txt'],['All Files','*',]];
		my $filename = $gui->getOpenFile(-initialdir => $configpath, -filetypes => $types, -title => "Generelle Daten laden");
		return 1 if (!defined($filename) || $filename eq "");
		#my $FSref = $gui->FileSelect(-directory => $configpath);
		#$tempname = $FSref->Show;
		$filename =~ s/^.*\///;		# Pfadangaben entfernen
		$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
		OVJ_meldung(HINWEIS,"Lade ".$filename);
		$retstate = read_genfile(0,$filename);
		if ($retstate == 0)	# Erfolgreich geladen
		{
			$genfilename = $filename;
			OVJ::GUI::set_general_data_label($genfilename);
			$config{"LastGenFile"} = $genfilename;
		}
		return($retstate);
	}

	if ($choice == 3)	# Importieren
	{	
		return 1 if (CheckForSaveGenfile());		# Abbruch durch Benutzer
		return 1 if (CheckForOVFJList());			# Abbruch durch Benutzer
		my $types = [['Text Files','.txt'],['All Files','*',]];
		my $filename = $gui->getOpenFile(-initialdir => $configpath, -filetypes => $types, -title => "Generelle Daten importieren");
		return 1 if (!defined($filename) || $filename eq "");
		#my $FSref = $gui->FileSelect(-directory => $configpath);
		#$genfilename = $FSref->Show;
		OVJ_meldung(HINWEIS,"Importiere ".$filename);
		$retstate = read_genfile(1,$filename);
		if ($retstate == 0)	# Erfolgreich geladen
		{
			$genfilename = "";	# Beim Importieren wird kein Name festgelegt
			OVJ::GUI::set_general_data_label();
			$config{"LastGenFile"} = $genfilename;
		}
		return($retstate);
	}

	if ($choice == 2)	# Laden der im Inifile angegebenen Datei, wird beim Programmstart ausgeführt
	{	
		die "Refactored: use init_general";
	}

	if ($choice == 0)	# Speichern
	{
		if ($genfilename ne "")
		{
			if (-e $configpath.$sep.$genfilename.$sep.$genfilename.".txt")
			{
				OVJ_meldung(HINWEIS,"Speichere ".$genfilename);
			}
			else
			{
				OVJ_meldung(HINWEIS,"Erzeuge ".$genfilename);
			}
			return(write_genfile());
		}
		else
		{
			$choice = 4;	# gehe zu Speichern als
		}
	}

	if ($choice == 4)	# Speichern als
	{
		my $types = [['Text Files','.txt'],['All Files','*',]];
		my $filename = $gui->getSaveFile(-initialdir => $configpath, -filetypes => $types, -title => "Generelle Daten laden");
		#my $FSref = $gui->FileSelect(-directory => $configpath);
		#$tempname = $FSref->Show;
		return 1 if (!defined($filename) || $filename eq "");
		$filename =~ s/^.*\///;		# Pfadangaben entfernen
		$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
		$genfilename = $filename;
#		if (-e $configpath.$sep.$genfilename.".txt")
#		{
#			my $response = $gui->messageBox(-icon => 'question', 
#													-message => "Datei ".$genfilename.".txt existiert bereits\n\nÜberschreiben?", 
#													-title => 'Generelle Daten Datei überschreiben?', 
#													-type => 'YesNo', 
#													-default => 'Yes');
#			return 1 if ($response eq "No");
#			OVJ_meldung(HINWEIS,"Speichere ".$genfilename);
#		}
#		else
#		{
		if (-e $configpath.$sep.$genfilename.$sep.$genfilename.".txt")
		{ OVJ_meldung(HINWEIS,"Überschreibe ".$genfilename); }
		else { OVJ_meldung(HINWEIS,"Erzeuge ".$genfilename); }
#		}
		OVJ::GUI::set_general_data_label($genfilename);
		$config{"LastGenFile"} = $genfilename;
		return(write_genfile());
	}
}

#Schreiben der Generellen Daten in die Genfile Datei
sub write_genfile {
# FIXME: has side-effects
	%general = OVJ::GUI::get_general();	# Hash aktualisieren auf Basis der Felder
	OVJ::write_genfile($genfilename, $configpath, %general) or return 1; # FIXME:
	$fjlistsaved = $OVJ::GUI::fjlistbox->Contents(); # FIXME: Remove if obsolete
	return 0;	# kein Fehler
}


#Lesen der Generellen Daten aus der Genfile Datei
sub read_genfile {
# FIXME: has side-effects, access TK
	my ($choice,$filename) = @_;	# 0 = Laden, 1 = Importieren
	%general = OVJ::read_genfile($filename, $configpath);
	if ($choice == 0) {
		foreach (@{$general{ovfj_link}}) {
			push(@fjlist,$_); # FIXME: Remove if obsolete
		}
	}
	else {
		my %general_alt = OVJ::GUI::get_general();
		@{$general{ovfj_link}} = @{$general_alt{ovfj_link}};
		$general{PMVorjahr} = $general_alt{PMVorjahr};
		$general{PMaktJahr} = $general_alt{PMaktJahr};
	}
	OVJ::GUI::set_general(%general);
	
	$fjlistsaved = $OVJ::GUI::fjlistbox->Contents(); # FIXME: Remove if obsolete
	# %general = OVJ::GUI::get_general() if ($choice == 1);	# einige Hashwerte löschen
	do_reset_eval();	# evtl. vorhandene Auswertungen löschen
	undef %ovfj;	# OVFJ Daten löschen
	OVJ::GUI::clear_ovfj();	# und anzeigen
	$OVJ::GUI::ovfj_eval_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfj_fileset_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfj_save_button->configure(-state => 'disabled');
	$OVJ::GUI::copy_pattern_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfjnamelabel->configure(-text => "OV Wettbewerb: ");
	return 0;	# kein Fehler
}

#Prüfen, ob Generelle Daten verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForSaveGenfile {
	return 0 if ! OVJ::GUI::general_modified(%general);
warn "Fixme: Direct Tk access";
	my $response = $gui->messageBox(-icon => 'question', 
											-message => "Generelle Daten \'$genfilename\' wurden geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => "Generelle Daten \'$genfilename\' speichern?", 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	return(do_file_general(0)) if ($response eq "Yes");
	return 0;
}

#Prüfen, ob OV Wettbewerbsliste (Teil der Generellen Daten) verändert wurde, 
#ohne gespeichert worden zu sein
sub CheckForOVFJList {
	return 0 if ($fjlistsaved eq $OVJ::GUI::fjlistbox->Contents());
warn "Fixme: Direct Tk access";
	my $response = $gui->messageBox(-icon => 'question', 
											-message => "Liste der OV Wettbewerbe wurde geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => "Generelle Daten \'$genfilename\' speichern?", 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	return(do_file_general(0)) if ($response eq "Yes");
	return 0;
}

#Auswahl einer Veranstaltung durch den Anwender
sub do_edit_ovfj {
	my ($choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb. Wird durchgereicht.
	$_ = $OVJ::GUI::fjlistbox->Contents(); # erstmal
	@fjlist = split(/\n/); # die Daten im Speicher aktualisieren
	#print @fjlist."\n".$OVJ::GUI::fjlistbox->Contents()."\n";
	$_ = $OVJ::GUI::fjlistbox->getSelected();
	my @fjlines = split(/\n/);
	if ($#fjlines > 0)
		{
			OVJ_meldung(FEHLER,"Nur eine Veranstaltung markieren !");
			return;
		}
	if (!grep {$_ eq $fjlines[0]} @fjlist)
	{
			OVJ_meldung(FEHLER,"Ganze Veranstaltung markieren !");
			return;
	}
	CreateEdit_ovfj($fjlines[0],$choice);
	$ovfjname = $fjlines[0];
}

#Prüfen, ob OVFJ Veranstaltung verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForOverwriteOVFJ {
	return 0 unless (%ovfj);		# wenn Hash leer ist
	return 0 if (! OVJ::GUI::ovfj_modified(%ovfj));
warn "Fixme: Direct Tk access";
	my $response = $gui->messageBox(-icon => 'question', 
											-message => "Kopfdaten zum OV Wettbewerb ".$ovfjname." wurden geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => 'OVFJ Daten speichern?', 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	do_write_ovfjfile() if ($response eq "Yes");
	return 0;
}

#Anlegen bzw. Editieren einer OVFJ Veranstaltung
sub CreateEdit_ovfj { # Rueckgabewert: 0 = Erfolg, 1 = Misserfolg
	my ($ovfjf_name,$choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb, 
												# 2 = explizites Laden aus Auswertungsschleife heraus
	
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	
	$OVJ::GUI::ovfjnamelabel->configure(-text => "OV Wettbewerb: ".$ovfjf_name);
	$ovfjfilename = $ovfjf_name."_ovj.txt";
	$ovfjrepfilename = $ovfjf_name."_report_ovj.txt";
	if (-e $configpath.$sep.$genfilename.$sep.$ovfjfilename)
	{
		if (read_ovfjfile()==1)	# Rueckgabe bei Fehler
		{
			OVJ_meldung(FEHLER,"Kann ".$ovfjfilename." nicht lesen");
			return 1;
		}
	}
	else
	{
		if ($choice == 2)	# kann nicht geladen werden
		{
			OVJ_meldung(FEHLER,"Finde ".$ovfjfilename." nicht");
			return 1;
		}
		if ($choice == 0)
		{
			OVJ::GUI::clear_ovfj();
		}
		else
		{
#			$datum->delete(0,"end");
#			$fjfile->delete(0,"end");
			warn "Inactive code";
		}
		%ovfj = OVJ::GUI::get_ovfj(); # FIXME: redundant code
		OVJ::GUI::set_ovfj(%ovfj);
	}
	$OVJ::GUI::ovfj_fileset_button->configure(-state => 'normal');
	$OVJ::GUI::ovfj_save_button->configure(-state => 'normal');
	$OVJ::GUI::copy_pattern_button->configure(-state => 'normal');
	if (exists($auswerthash{$ovfjf_name}))
	{
		$OVJ::GUI::ovfj_eval_button->configure(-state => 'disabled');
	}
	else
	{
		$OVJ::GUI::ovfj_eval_button->configure(-state => 'normal');
	}
}

#Lesen der Daten aus einer OVFJ Datei
sub read_ovfjfile { # Rueckgabewert: 0 = Erfolg, 1 = Misserfolg
	if (!open (INFILE,"<",$configpath.$sep.$genfilename.$sep.$ovfjfilename))
	{
		OVJ_meldung(FEHLER,"Kann ".$ovfjfilename." nicht lesen");
		return 1;	# Fehler
	}

	while (<INFILE>)
	{
		next if /^#/;
		next if /^\s/;
		s/\r//;
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s*$/)
		{
			$ovfj{$1} = $2;
			#print $1."=".$2;
		}
	}
	close (INFILE) || die "close: $!";
	OVJ::GUI::set_ovfj(%ovfj);
	return 0; # Erfolg
}


#Schreiben der aktuellen OVFJ Daten
sub do_write_ovfjfile {
	if (!open (OUTFILE,">",$configpath.$sep.$genfilename.$sep.$ovfjfilename))
	{
		OVJ_meldung(FEHLER,"Kann ".$ovfjfilename." nicht schreiben");
		return;
	}
	%ovfj = OVJ::GUI::get_ovfj();
	printf OUTFILE "#OVFJ Datei\n";
	my $key;
	foreach $key (keys %ovfj) {
		printf OUTFILE $key." = ".$ovfj{$key}."\n";
	}
	close (OUTFILE) || die "close: $!";
}

#Löschen aller Auswertungen im Speicher
sub do_reset_eval {
	undef %tn;
	undef %auswerthash;
	undef @ovfjlist;
	undef @ovfjanztlnlist;
	$OVJ::GUI::reset_eval_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfj_eval_button->configure(-state => 'normal');
	$OVJ::GUI::exp_eval_button->configure(-state => 'disabled');
	$lfdauswert=0;
#	$meldung->delete(0,"end");
}

#Lesen der Spitznamen Datei
sub get_nicknames {
	if ($general{"Spitznamen"} eq "")
	{
		OVJ_meldung(HINWEIS,"Keine Spitznamen Datei spezifiziert");
		return;
	}	
	
	if (!open (INFILE,"<",$general{"Spitznamen"}))
	{
		OVJ_meldung(FEHLER,"Kann Spitznamen Datei ".$general{"Spitznamen"}." nicht lesen");
		return;
	}
	else
	{
		local $/ = undef;
		$_ = <INFILE>;										# alles einlesen
		s/\r//g;
		close (INFILE) || die "close: $!";
	}
	s/^#.*?$//mg;
	$nicknames = $_;
}

#Lesen der Override Datei (falls vorhanden)
#Format: Name,Vorname,Rufzeichen,DOK,Gebjahr,NichtInPMVJ|IstInPMVJ
sub get_overrides {
	my $line = 0;
	$overrides = undef;
	return unless (-e $overridefilename);
	if (!open (INFILE,"<",$overridefilename))
	{
		OVJ_meldung(FEHLER,"Kann Override Datei ".$overridefilename." nicht lesen");
		return;
	}
	while (<INFILE>)
	{
		$line++;
		chomp;
		next if (/^#/);		# Kommentarzeilen ueberspringen
		next if (/^\W+/);		# Zeilen, die nicht mit einem Buchstaben beginnen ueberspringen
		next if ($_ eq "");	# Leerzeilen ueberspringen
		s/\r//;
		unless (/^[-a-zA-ZäöüÄÖÜß]+,[-a-zA-ZäöüÄÖÜß]+,(|---|\w+),(|---|\w+),(|\d{4}),(NichtInPMVJ|IstInPMVJ|)\s*$/)
		{
			OVJ_meldung(FEHLER,"Formatfehler in Zeile ".$line." der Overridedatei: ".$_);
			next;
		}
		$overrides .= $_."\n";
	}
	#OVJ_meldung(HINWEIS,"INFO: Override Datei eingelesen");
	close (INFILE) || die "close: $!";
}
	
#Vergleiche Zeile aus Auswertungsdatei mit Pattern
sub MatchPat {
	my ($line) = @_;
	
	my $patmatched = 0;
	my $platz = "";
	my ($nachname,$vorname,$gebjahr) = ("","","");
	my ($call,$dok) = ("","");
	my ($quest,$kw);
	my $validkeyword;
	
	my %ovfj_temp = OVJ::GUI::get_ovfj();
	local $_ = $ovfj_temp{Auswertungsmuster};
	s/^\s+//; # entferne evtl. vorhandene Leerzeichen am Anfang
	s/\s+$//; # und am Ende
	
	$line =~ s/^\s+//; # entferne evtl. vorhandene Leerzeichen am Anfang
	$line .= ' ';	# fuer den Sonderfall, dass am Ende optionale Elemente (d.h. mit Schlüsselwort?) kommen
						# wenn das Schlüsselwort? nach einem Leerzeichen folgt, so wuerden normale Matches das Leerzeichen
						# am Ende erwarten.
	
	while ($_ ne "")
	{
		if (/^([A-Z][a-z]+\??)/)
		{
			$quest = 0;
			$validkeyword = 0;
			$kw = $1;
			if ($kw =~ /\?$/)
			{
				$quest = 1;
				$kw =~ s/\?$//;
			}
			if ($kw eq "Platz")
			{
				$validkeyword = 1;
				if ($line =~ /^(\d+)\b/)
				{
					$platz = $1;
					$line =~ s/^\d+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Sender")
			{
				$validkeyword = 1;
				if ($line =~ /^\d+\b/)
				{
					$line =~ s/^\d+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Geburtsjahr" || $kw eq "Gebjahr")
			{
				$validkeyword = 1;
				if ($line =~ /^(\d{4})\b/)
				{
					$gebjahr = $1;
					$line =~ s/^\d+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Zeit")
			{
				$validkeyword = 1;
				if ($line =~ /^[.:0-9]+\b/)
				{
					$line =~ s/^[.:0-9]+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Dok")
			{
				$validkeyword = 1;
				if ($line =~ /^(\S+)/)
				{
					$dok = uc($1);
					$dok = "---" if ($dok !~ /^[A-Z]\d\d$/);
					$line =~ s/^\S+//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Call" || $kw eq "Rufzeichen")
			{
				$validkeyword = 1;
				if ($line =~ /^(\S+)/)
				{
					$call = uc($1);
					$call = "---" if ($call =~ /^[A-Z]+$/ || $call =~ /^-+$/);
					$line =~ s/^\S+//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Egal" || $kw eq "Ignorier" || $kw eq "Ignoriere")
			{
				$validkeyword = 1;
				if ($line =~ /^\S+/)
				{
					$line =~ s/^\S+//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Nachname")
			{
				$validkeyword = 1;
				if ($line =~ /^\"([^"]+)\"/)
				{
					$nachname = $1;
					$line =~ s/^\"[^"]+\"//;
				}
				else
				{
					if ($line =~ /^([-a-zA-ZäöüÄÖÜß]+)/)
					{
						$nachname = $1;
						$line =~ s/^[-a-zA-ZäöüÄÖÜß]+//;
					}
					else
					{
						if ($quest == 0) {return 0;} # Fehlschlag
					}
				}
			}
			if ($kw eq "Vorname")
			{
				$validkeyword = 1;
				if ($line =~ /^\"([^"]+)\"/)
				{
					$vorname = $1;
					$line =~ s/^\"[^"]+\"//;
				}
				else
				{
					if ($line =~ /^([-a-zA-ZäöüÄÖÜß]+)/)
					{
						$vorname = $1;
						$line =~ s/^[-a-zA-ZäöüÄÖÜß]+//;
					}
					else
					{
						if ($quest == 0) {return (0,$kw);} # Fehlschlag
					}
				}
			}

			return (0,$kw." ist kein Schlüsselwort") if ($validkeyword != 1);	 # illegales Wort
			s/^([A-Z][a-z]+)//;	 # entferne Schluesselwort

			if ($quest == 1)
			{
				s/^\?//;
				$line = " ".$line;	# füge Leerzeichen am Anfang hinzu, weil Leerzeichen im Muster sonst
				                     # nicht gefunden werden.
			}

		} # Ende Wortoperation
		else {
		if (/^(\w+)/)
			{
				return (0,$1." ist kein Schlüsselwort");	 # illegales Wort
			}
		}
		if (/^\s+/)
		{
			if ($line =~ /^\s+/)
			{
				$line =~ s/^\s+//;
			}
			else
			{
				return (0,"Leerzeichen"); # Fehlschlag
			}
			s/^\s+//;
			next;
		}
		if (/^(\S+)/)
		{
			if ($line =~ /^($1)/)
			{
				$line =~ s/^$1//;
			}
			else
			{
				return (0,"Sonstige Zeichen"); # Fehlschlag
			}
			s/^\S+//;
		}
	}
	
	return (1,$platz,$nachname,$vorname,$gebjahr,$call,$dok);
}


#Auswertung und Export aller OVFJ
sub do_eval_allovfj {
	my $i = 0;
	my $success = 0;
	my $retval;
	
	do_reset_eval();
	$_ = $OVJ::GUI::fjlistbox->Contents();
	my @fjlines = split(/\n/);
	foreach $str (@fjlines)
	{
		$ovfjname = $str;
		next if ($ovfjname !~ /\S+/);
		next if (CreateEdit_ovfj($ovfjname,2)==1);
		$retval = do_eval_ovfj($i++);
		$success = 1 if ($retval == 0);	# Stelle fest, ob wenigstens eine Auswertung erfolgreich war
		last if ($retval == 2);	# systematischer Fehler, Abbruch der Schleife
	}
	OVJ::export(\%general,\%tn,\@ovfjlist,\@ovfjanztlnlist,$outputpath,$genfilename) if ($success);
}

#Suche in PM Daten
sub SucheTlnInPM {
	local *FH = shift;
	my ($pmarray,$nachname,$vorname,$gebjahr,$call,$dok,$override_IsInPmvj,$CheckInAktPM) = @_;
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
		OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." durch Override 'NichtInPMVJ' von Suche in ".$PMJahr." ausgeschlossen");
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
							OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$$nachname.", ".$vname." ueber Rufzeichen und Spitznamen in ".$PMJahr." gefunden, verwende neuen Vornamen");
							$$vorname = $vname;
							return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname
							}
						}
					OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$$nachname.", ".$vname." ueber Rufzeichen in ".$PMJahr." gefunden, verwende neuen Vornamen");
					$$vorname = $vname;
					return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname				
				}
			
				if ($vname eq $$vorname)
				{ # Vorname stimmt, aber nicht der Nachname
					OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$$vorname." ueber Rufzeichen in ".$PMJahr." gefunden, verwende neuen Nachnamen");
					$$nachname = $nname;
					return (11,"Call,Vorname;Nachname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Vorname; Nachname passt nicht
				}
			
				if ($dok ne "---" && $dok ne "") # jetzt zusaetzlich Abgleich ueber DOK 
				{
					if ($rest =~ /^\"$call\",\"$dok\"/)
					{# Vorname und Nachname stimmen nicht, aber DOK !
						OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen und DOK in ".$PMJahr." gefunden, verwende neue Namen");
						$$nachname = $nname;
						$$vorname = $vname;
						return (12,"Call,DOK",$rest);		# Gefunden ueber Rufzeichen, DOK; Vorname, Nachname passen nicht
					}
					else
					{# Vorname und Nachname und DOK stimmen nicht
						OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen aber mit falschem DOK in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
						return (0,"Call",$rest);		# Gefunden ueber Rufzeichen; DOK, Vorname, Nachname passen nicht
					}
				}
				else
				{
					OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen (kein DOK in OVFJ) in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
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
				OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit passendem DOK in PMVorjahr gefunden, aber Call: ".$call." stimmt nicht, verwende trotzdem PM Eintrag") if ($CheckInAktPM == 0);
				OVJ::RepMeld(*FH,"INFO: ".join(',',@{$mlist3[0]})) if ($CheckInAktPM == 0);
				return (1,"Nachname,Vorname,DOK;Call stimmt nicht",$rest) 		# Gefunden ueber Nachname, Vorname und DOK; Call stimmt nicht!
			}
			if ($foundbydokgeb == 2)
			{
				OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit passendem Geb.jahr in PMVorjahr gefunden, aber Call: ".$call." stimmt nicht, verwende trotzdem PM Eintrag") if ($CheckInAktPM == 0);
				OVJ::RepMeld(*FH,"INFO: ".join(',',@{$mlist3[0]})) if ($CheckInAktPM == 0);
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
				OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." und Call: ".$call." stimmen nicht, verwende Daten aufgrund von 'IstInPMVJ Override'") if ($CheckInAktPM == 0);
			}
			else
			{
				OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." stimmt nicht, verwende Daten aufgrund von 'IstInPMVJ Override'") if ($CheckInAktPM == 0);
			}
			$rest = $mlist2[0];
			return (1,"Nachname,Vorname,! 'IstInPMVJ' Override !",$rest);		# Gefunden ueber Nachname, Vorname und 'IstInPMVJ' Override
		}
		
		if ($callmismatch == 1)
		{
			OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." und Call: ".$call." stimmen nicht, verwende Daten nicht") if ($CheckInAktPM == 0);
		}
		else
		{
			OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." stimmt nicht, verwende Daten nicht") if ($CheckInAktPM == 0);
		}
		OVJ::RepMeld(*FH,"INFO: mögliche Teilnehmer: ") if ($CheckInAktPM == 0);
		foreach $listelem (@mlist2) {
			OVJ::RepMeld(*FH,join(',',@$listelem)) if ($CheckInAktPM == 0);
		}
		return (0,"Nachname,Vorname",undef);		# Gefunden ueber Nachname, Vorname, aber DOK stimmt nicht, verwerfe Eintrag
	}
	OVJ::RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit DOK ".$dok." bzw. Geb.jahr ".$gebjahr." mehrmals in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
	foreach $listelem (@mlist3) {
		OVJ::RepMeld(*FH,join(',',@$listelem)) if ($CheckInAktPM == 0);
	}
	return (0,"Nachname,Vorname,DOK",undef);		# Gefunden ueber Nachname, Vorname, DOK, aber mehrmals vorhanden, verwerfe Eintrag
}

#Lesen der Vorjahr (mode == 0) oder der aktuellen (mode == 1) PM Daten
#Rückgabewerte: 0 = ok, 1 = Fehler
sub ReadPMDaten {
	my $OUTFILE = shift;
	my ($mode,$pmarray) = @_;	#mode: 0 = PMVJ Daten, 1 = akt. PM Daten
	my $anonarray = [];	# anonymes Array
	my ($pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum);
	if ($mode == 0)
	{
		if ($general{"PMVorjahr"} eq "")
		{
			OVJ::RepMeld($OUTFILE,"FEHLER: Keine PMVorjahr Datei spezifiziert");
			close ($OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}

		if (!open (INFILE2,"<",$general{"PMVorjahr"}))
		{
			OVJ::RepMeld($OUTFILE,"FEHLER: Kann PMVorjahr Datei ".$general{"PMVorjahr"}." nicht lesen");
			close ($OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}
	}
	else
	{
		if ($general{"PMaktJahr"} eq "")
		{
			OVJ::RepMeld($OUTFILE,"FEHLER: Keine aktuelle PM Datei spezifiziert");
			close ($OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}

		if (!open (INFILE2,"<",$general{"PMaktJahr"}))
		{
			OVJ::RepMeld($OUTFILE,"FEHLER: Kann aktuelle PM Datei ".$general{"PMaktJahr"}." nicht lesen");
			close ($OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}
	}

	undef @$pmarray;
	while (<INFILE2>)
	{
		next unless (/^\"/);	# Zeile muss mit Anfuehrungszeichen beginnen
		s/\r//;
		tr/\"//d;				# entferne alle Anführungszeichen
		($pmname,$pmvorname,$pmcall,$pmdok,undef,undef,$pmgebjahr,undef,$pmpm,undef,$pmdatum,undef) = split(/,/);
		$anonarray = [$pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum];
		push (@$pmarray,$anonarray);
	}
	close (INFILE2) || die "close: $!";
	return 0;	# ok
}

#Auswertung der aktuellen OVFJ
sub do_eval_ovfj {   # Rueckgabe: 0 = ok, 1 = Fehler, 2 = Fehler mit Abbruch der auesseren Schleife
	my ($mode) = @_;	# 0 = erster Start, >0 = Aufruf aus Auswertung und Export aller OVFJ heraus
	
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
	%general = OVJ::GUI::get_general() if ($mode == 0);	# Generelle Hashdaten aktualisieren auf Basis der Felder
	%ovfj = OVJ::GUI::get_ovfj() if ($mode == 0);	# Hashdaten aktualisieren
	
	if ($general{Jahr} !~ /^\d{4}$/)
	{
		OVJ_meldung(FEHLER,"Jahr ist keine gültige Zahl");
		return 2;	# Fehler mit Schleifenabbruch
	}
	
	OVJ_meldung(HINWEIS,"***************  ".$ovfjname."  ***************");
	
	my %ovfj_temp = OVJ::GUI::get_ovfj();
	$_ = $ovfj_temp{Auswertungsmuster};
	unless (/Nachname/ && /Vorname/)
	{
		OVJ_meldung(FEHLER,"Muster muss 'Nachname' und 'Vorname' beinhalten");
		return 1;	# Fehler
	}

	if ($mode == 0)
	{
		get_nicknames();  	# Spitznamen einlesen
		get_overrides();		# Lade die Override-Datei (falls vorhanden)
	}

	unless (-e $reportpath.$sep.$genfilename && -d $reportpath.$sep.$genfilename)
	{
		OVJ_meldung(HINWEIS,"Erstelle Verzeichnis \'".$genfilename."\' in \'".$reportpath."\'");
		unless (mkdir($reportpath.$sep.$genfilename))
		{
			OVJ_meldung(FEHLER,"Konnte Verzeichnis \'".$reportpath.$sep.$genfilename."\' nicht erstellen".$!);
			return 1;	# Fehler
		}
	}
	
	if (!open (OUTFILE,">",$reportpath.$sep.$genfilename.$sep.$ovfjrepfilename))
	{
		OVJ_meldung(FEHLER,"Kann ".$ovfjrepfilename." nicht schreiben");
		return 1;	# Fehler
	}	

	if ($mode == 0)
	{# Lese PMVJ Daten
		return 2 if (ReadPMDaten(*OUTFILE,0,\@pmvjarray) == 1);	# Fehler mit Schleifenabbruch
	 # Lese aktuelle PM Daten
		return 2 if (ReadPMDaten(*OUTFILE,1,\@pmaktarray) == 1);	# Fehler mit Schleifenabbruch
	}

	if ($ovfj{"OVFJDatei"} eq "")
	{
		OVJ::RepMeld(*OUTFILE,"FEHLER: Keine OVFJ Datei spezifiziert");
		close (OUTFILE) || die "close: $!";
		return 1;	# Fehler
	}	
	
	unless (-e $inputpath.$sep.$genfilename && -d $inputpath.$sep.$genfilename)
	{
		OVJ_meldung(FEHLER,"Verzeichnis \'".$inputpath.$sep.$genfilename."\' nicht vorhanden");
		close (OUTFILE) || die "close: $!";
		return 2;	# Fehler mit Schleifenabbruch
	}
	
	if (!open (INFILE,"<",$inputpath.$sep.$genfilename.$sep.$ovfj{"OVFJDatei"}))
	{
		OVJ::RepMeld(*OUTFILE,"FEHLER: Kann OVFJ Datei ".$ovfj{"OVFJDatei"}." nicht lesen");
		close (OUTFILE) || die "close: $!";
		return 1;	# Fehler
	}

	$auswerthash{$ovfjname} = 1;	# Wert ist egal, nur Vorhandensein des Schlüssels zählt
	$OVJ::GUI::ovfj_eval_button->configure(-state => 'disabled');
	$OVJ::GUI::reset_eval_button->configure(-state => 'normal');
	$OVJ::GUI::exp_eval_button->configure(-state => 'normal');
	
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
						OVJ::RepMeldFile(*OUTFILE,"\n<Ende Ignorierabschnitt>");
					}
					else
					{
						$Ignoriermode = 1;
						OVJ::RepMeldFile(*OUTFILE,"\n<Beginn Ignorierabschnitt>");
					}
				}
				next if ($Ignoriermode == 1);		# Ignoriere alles was sonst sein koennte
				
				if ($2 eq "Helfer")
				{
					if ($1 eq '/')
					{
						$Helfermode = 0;
						OVJ::RepMeldFile(*OUTFILE,"\n<Ende Helferabschnitt>");
					}
					else
					{
						$Helfermode = 1;
						OVJ::RepMeldFile(*OUTFILE,"\n<Beginn Helferabschnitt>");
					}
				}
				if ($2 eq "Keine Sonderpunkte")
				{
					if ($1 eq '/')
					{
						$KeineSonderpunkte = 0;
						OVJ::RepMeldFile(*OUTFILE,"\n<Ende Abschnitt ohne Sonderpunkte>");
					}
					else
					{
						$KeineSonderpunkte = 1;
						OVJ::RepMeldFile(*OUTFILE,"\n<Beginn Abschnitt ohne Sonderpunkte>");
					}
				}
#				if ($2 eq "TODO")
#				{
#					if ($1 eq '/')
#					{
#						$KeineSonderpunkte = 0;
#						OVJ::RepMeldFile(*OUTFILE,"\n<Ende Abschnitt ohne Sonderpunkte>");
#					}
#					else
#					{
#						$KeineSonderpunkte = 1;
#						OVJ::RepMeldFile(*OUTFILE,"\n<Beginn Abschnitt ohne Sonderpunkte>");
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
				($patmatched,$platz,$ev_nachname,$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok) = MatchPat($_);
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
			(1,0,$ovfj{"Verantw_Name"},$ovfj{"Verantw_Vorname"},$ovfj{"Verantw_GebJahr"},$ovfj{"Verantw_CALL"},$ovfj{"Verantw_DOK"});
			$ev_call = "---" if ($ev_call eq "" || uc($ev_call) eq "SWL");
			$ev_dok = "---" if ($ev_dok eq "");
			$str2 = "\nAusrichter: ";
			$matcherrortext = $platz if ($patmatched == 0);	# Fehlertext steht in zweitem Rückgabewert
		}
		if ($patmatched)
		{
			$str2 .= $ev_nachname.", ".$ev_vorname.", ".$ev_gebjahr.", ".$ev_call.", ".$ev_dok;
			OVJ::RepMeldFile(*OUTFILE,$str2);
			$override_call = 0;
			$override_dok = 0;
			$override_gebjahr = 0;
			$override_IsInPmvj = 0;
			if (defined $overrides)
			{
				if ($overrides =~ /^$ev_nachname,$ev_vorname,([^,]*),([^,]*),(\d*),(\w*)$/m)
				{
					OVJ::RepMeldFile(*OUTFILE,"INFO: Overridedatensatz für ".$ev_nachname.", ".$ev_vorname." gefunden");
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
				OVJ::RepMeld(*OUTFILE,"INFO: Erster Match mit: ".$_);
				$evermatched = 1;
			}
			#print $ev_nachname." ".$ev_vorname."\n";
			$anztln++ if ($AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0);
			
			#Check, ob Teilnehmer identisch mit Verantwortlichem, um Warnung auszugeben
			$TlnIstAusrichter = 0;
			if (($ev_nachname eq $ovfj{"Verantw_Name"}) &&
				 ($ev_vorname eq $ovfj{"Verantw_Vorname"}) &&
				 ($AddedVerant == 1) )
				{
				 	OVJ::RepMeld(*OUTFILE,"WARNUNG: Verantwortlicher ($ev_nachname,$ev_vorname) ist in Teilnehmer Liste");
				 	$TlnIstAusrichter = 1;
				}

			#Suche, ob PM und ob Daten stimmen
			$IsPM = 0;
			$match = 0;

			($match,$SText,$rest) = SucheTlnInPM(*OUTFILE,\@pmvjarray,\$ev_nachname,\$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok,$override_IsInPmvj,0);
			if ($match > 0)
			{
				OVJ::RepMeldFile(*OUTFILE,"In PMVorjahr gefunden da Übereinstimmung von: ".$SText);
			}
			else
			{
				OVJ::RepMeldFile(*OUTFILE,"Nicht in PMVorjahr gefunden da nur Übereinstimmung von: ".$SText);
			}
		

			if ($match != 0)
			{
				($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum) = @{$rest}[2..6];

				$IsPM = 1 if ($pmpm eq "FM");

				if ($ev_gebjahr ne "" && ($ev_gebjahr ne $pmgebjahr))
				{
					OVJ::RepMeld(*OUTFILE,"INFO: Geb.jahr unterschiedlich mit PMVorjahr: ");
					OVJ::RepMeld(*OUTFILE,$ev_nachname.", ".$ev_vorname." :".$ev_gebjahr." <-> ".$pmgebjahr);
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
			
			($match,$SText,$rest) = SucheTlnInPM(*OUTFILE,\@pmaktarray,\$ev_nachname,\$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok,$override_IsInPmvj,1);
			

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
					OVJ::RepMeld(*OUTFILE,$str2);
				}
				$aktJahr = 1;	# zwar gefunden, aber keine Teilnahme im aktuellen Jahr (kann nachfolgend ueberschrieben werden)
				$aktJahr = 2 if ($pmdatum =~ /^$general{Jahr}\d{4}$/);
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
			if (exists($tn{$tnkey}))
			{
				#print "Found Call: ".$tn{$tnkey}->{call};
				$str2 = sprintf("%u",$lfdauswert);
				if ($tn{$tnkey}->{wwbw} =~ /$str2/)
				{
					if ($TlnIstAusrichter == 0)
					{
						OVJ::RepMeld(*OUTFILE,"FEHLER: ".$ev_nachname.", ".$ev_vorname." ist bereits in laufender Auswertung");
					}
					else
					{
						OVJ::RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname." ist als Ausrichter bereits in laufender Auswertung, ignoriere Teilnahme als Teilnehmer");
					}
					next;
				}					
				$str2 = $tnkey." ist bereits in Auswertung, Status: ";
				$tn{$tnkey}->{anzwwbw}++;
				$tn{$tnkey}->{wwbw} .= ",".sprintf("%u",$lfdauswert);
				$tn{$tnkey}->{anzausr} += ($AddedVerant == 0 ? 1 : 0);
				if ($SPunktePlatz == 1)
				{
					$tn{$tnkey}->{anzpl1} += ($nichtpm == 1 ? 1 : 0);
					$tn{$tnkey}->{anzpl2} += ($nichtpm == 2 ? 1 : 0);
				}
				$tn{$tnkey}->{anzhelf}++ if ($Helfermode == 1 || $HelferInKopf == 1);

				# Abgleich Rufzeichen
				$tn{$tnkey}->{call} = $ev_call if (($tn{$tnkey}->{call} eq "---" || $tn{$tnkey}->{call} eq "") && ($ev_call ne "---" && $ev_call ne ""));
				if ($tn{$tnkey}->{call} ne "---" && $tn{$tnkey}->{call} ne "" && $ev_call ne $tn{$tnkey}->{call})
				{
					OVJ::RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": Rufzeichen unterschiedlich: ".$tn{$tnkey}->{call}." (alt, bleibt)<->(OVFJ) ".$ev_call);
				}

				# Abgleich DOK
				$tn{$tnkey}->{dok} = $ev_dok if ($tn{$tnkey}->{dok} eq "" && $ev_dok ne "");
				if ($tn{$tnkey}->{dok} ne "" && $ev_dok ne "" && $ev_dok ne $tn{$tnkey}->{dok})
				{
					OVJ::RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": DOK unterschiedlich: ".$tn{$tnkey}->{dok}." (alt, bleibt)<->(OVFJ) ".$ev_dok);
				}

				# Abgleich Geburtsjahr
				$tn{$tnkey}->{gebjahr} = $ev_gebjahr if ($tn{$tnkey}->{gebjahr} eq "" && $ev_gebjahr ne "");
				if ($tn{$tnkey}->{gebjahr} ne "" && $ev_gebjahr ne "" && $ev_gebjahr ne $tn{$tnkey}->{gebjahr})
				{
					OVJ::RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": Geburtsjahr unterschiedlich: ".$tn{$tnkey}->{gebjahr}." (alt, bleibt)<->(OVFJ) ".$ev_gebjahr);
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
				$tn{$tnkey} = $tndata;
			}
			$str2 .= "Helfer" if ($Helfermode == 1 || $HelferInKopf == 1);
			$str2 .= "Ausrichter" if ($AddedVerant == 0);
			$str2 .= "1 Extrapunkt für Platz 2 als Nicht-PM" if ($nichtpm == 2 && $SPunktePlatz == 1);
			$str2 .= "2 Extrapunkte für Platz 1 als Nicht-PM" if ($nichtpm == 1 && $SPunktePlatz == 1);
			$str2 .= "PM im Vorjahr" if ($IsPM && $Helfermode == 0 && $HelferInKopf == 0 && $AddedVerant == 1);
			OVJ::RepMeldFile(*OUTFILE,$str2);
		}
		else
		{
			if ($evermatched == 1)
			{
				OVJ::RepMeld(*OUTFILE,"\nINFO: kein Match (Ursache: ".$matcherrortext.") bei:") if ($oldline+1 < $line);
				OVJ::RepMeld(*OUTFILE,$_);
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

	OVJ::RepMeld(*OUTFILE,"INFO: kein einziger Match! Letzte Ursache: ".$matcherrortext) if ($evermatched == 0);

	%ovfjcopy = %ovfj;
	push (@ovfjlist,\%ovfjcopy);
	if ($ovfj{"TlnManuell"} ne "")
	{# Manuelle Vorgabe hat Vorrang vor automatischer Zaehlung
		push (@ovfjanztlnlist,$ovfj{"TlnManuell"});
	}
	else
	{
		push (@ovfjanztlnlist,$anztln);
	}

	OVJ_meldung(HINWEIS,"");	# Erzeuge Leerzeile zwischen Auswertungen

	close (OUTFILE) || die "close: $!";
	close (INFILE) || die "close: $!";
	return 0;	# kein Fehler
}

#Exit Box aus dem 'Datei' Menu und 'Exit' Button
sub Leave {
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	return if (OVJ::GUI::CheckForUnsavedPatterns());	# Abbruch durch Benutzer
	return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
	return if (CheckForOVFJList());			# Abbruch durch Benutzer
	OVJ::Inifile::write($inifilename,%config)		# Speichern der Inidaten
	  or warn "Kann INI-Datei '$inifilename' nicht schreiben: $!";
	exit 0;
}

sub OVJ_meldung {
	my $level = shift;
	my $message = "$level: " . shift;
	warn $message if ($level eq WARNUNG || $level eq FEHLER);
	OVJ::GUI::add_meldung($message) if $gui;
	return 0;
}

