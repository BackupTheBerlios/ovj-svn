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

my %config  = ();		# Konfigurationsdaten
my %general = ();	# Generelle Einstellungen
my %ovfj;				# Hash für eine OV Veranstaltung, Kopfdaten
my $ovfjname;			# Name der aktiven OV Veranstaltung

my $inifilename = "OVJini.txt";
my $inputpath = "input";		# Pfad für die Eingangsdaten
my $outputpath = "output";		# Pfad für die Ergebnisdaten
my $reportpath = "report";		# Pfad für die Reportdaten
#my $configpath = "config";		# Pfad für die Konfigurationsdaten
										# Generelle Daten, sowie die OVFJ Dateien (*_ovj.txt))
my $sep = ($^O =~ /Win/i) ? '\\' : '/';	# Kai, fuer Linux und Win32 Portabilitaet

#my ($genfilename,$ovfjfilename,$ovfjrepfilename);
my ($ovfjrepfilename);

my $nicknames;			# Inhalt der Spitznamen Datei
my ($i,$str);			# temp. Variablen
my $overrides=undef;	# Overrides
my @pmvjarray;			# Array mit PMVJ Daten
my @pmaktarray;		# Array mit aktuellen PM Daten

my $gui;



intro();
%config = OVJ::Inifile::read($inifilename)
 or OVJ::meldung(OVJ::WARNUNG, "Kann INI-Datei '$inifilename' nicht lesen: $!");
$gui = OVJ::GUI::init(%config);
init();
OVJ::GUI::run();
exit 0;



sub intro {
	my $str = "*  OVJ $OVJ::ovjvers by DL3SDO, $OVJ::ovjdate  *";
	my $sep = '*' x length($str);
	print "$sep\n$str\n$sep\n";
}


sub init {
# FIXME: local var
#	do_file_general(2);	# Lade Generelle Daten Datei falls vorhanden
	init_general();	# Lade Generelle Daten Datei falls vorhanden
	OVJ::GUI::set_patterns(OVJ::read_patterns());
	
	# FIXME: use loop

=disabled

	unless (-e $configpath && -d $configpath)
	{
		OVJ_meldung(HINWEIS,"Erzeuge Verzeichnis \'".$configpath."\'");
		unless (mkdir($configpath))
		{
			OVJ_meldung(FEHLER,"Konnte Verzeichnis \'".$configpath."\' nicht erstellen".$!);
			return;
		}
	}

=cut

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
}



#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	unless (-e $inputpath.$sep.$OVJ::genfilename && -d $inputpath.$sep.$OVJ::genfilename)
	{
		OVJ_meldung(FEHLER,"Verzeichnis \'".$inputpath.$sep.$OVJ::genfilename."\' nicht vorhanden");
		return;
	}
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $gui->getOpenFile(-initialdir => $inputpath.$sep.$OVJ::genfilename, -filetypes => $types, -title => "FJ Datei auswählen");
	return if (!defined($selfile) || $selfile eq "");
	my $tp;
	my @fi;
	$selfile =~ s/^.*\///;
	my %ovfj_temp = OVJ::GUI::get_ovfj();
	$ovfj_temp{OVFJDatei} = $selfile;

	if (!open (INFILE,"<",$inputpath.$sep.$OVJ::genfilename.$sep.$selfile))
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
		$OVJ::genfilename = $config{LastGenFile};
		OVJ_meldung(HINWEIS,"Lade $OVJ::genfilename...");
		return read_genfile(0, $OVJ::genfilename);
	}
	else {
		return 1;	# KEIN Fehler
	}
}
		
=obsolete	
		if (-e $configpath.$sep.$config{LastGenFile}.$sep.$config{LastGenFile}.".txt") {
			$OVJ::genfilename = $config{"LastGenFile"};
			OVJ_meldung(HINWEIS,"Lade $OVJ::genfilename");
			OVJ::GUI::set_general_data_label($OVJ::genfilename);
			return(read_genfile(0,$OVJ::genfilename));
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
		my $types = [['Text Files','.txt'],['All Files','*',]];
		my $filename = $gui->getOpenFile(-initialdir => $OVJ::configpath, -filetypes => $types, -title => "Generelle Daten laden");
		return 1 if (!defined($filename) || $filename eq "");
		#my $FSref = $gui->FileSelect(-directory => $configpath);
		#$tempname = $FSref->Show;
		$filename =~ s/^.*\///;		# Pfadangaben entfernen
		$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
		OVJ_meldung(HINWEIS,"Lade ".$filename);
		$retstate = read_genfile(0,$filename);
		if ($retstate == 0)	# Erfolgreich geladen
		{
			$OVJ::genfilename = $filename;
			OVJ::GUI::set_general_data_label($OVJ::genfilename);
			$config{"LastGenFile"} = $OVJ::genfilename;
		}
		return($retstate);
	}

	if ($choice == 3)	# Importieren
	{	
		return 1 if (CheckForSaveGenfile());		# Abbruch durch Benutzer
		my $types = [['Text Files','.txt'],['All Files','*',]];
		my $filename = $gui->getOpenFile(-initialdir => $OVJ::configpath, -filetypes => $types, -title => "Generelle Daten importieren");
		return 1 if (!defined($filename) || $filename eq "");
		#my $FSref = $gui->FileSelect(-directory => $configpath);
		#$OVJ::genfilename = $FSref->Show;
		OVJ_meldung(HINWEIS,"Importiere ".$filename);
		$retstate = read_genfile(1,$filename);
		if ($retstate == 0)	# Erfolgreich geladen
		{
			$OVJ::genfilename = "";	# Beim Importieren wird kein Name festgelegt
			OVJ::GUI::set_general_data_label();
			$config{"LastGenFile"} = $OVJ::genfilename;
		}
		return($retstate);
	}

	if ($choice == 2)	# Laden der im Inifile angegebenen Datei, wird beim Programmstart ausgeführt
	{	
		die "Refactored: use init_general";
	}

	if ($choice == 0)	# Speichern
	{
		if ($OVJ::genfilename ne "")
		{
			if (-e $OVJ::configpath.$sep.$OVJ::genfilename.$sep.$OVJ::genfilename.".txt")
			{
				OVJ_meldung(HINWEIS,"Speichere ".$OVJ::genfilename);
			}
			else
			{
				OVJ_meldung(HINWEIS,"Erzeuge ".$OVJ::genfilename);
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
		my $filename = $gui->getSaveFile(-initialdir => $OVJ::configpath, -filetypes => $types, -title => "Generelle Daten laden");
		#my $FSref = $gui->FileSelect(-directory => $configpath);
		#$tempname = $FSref->Show;
		return 1 if (!defined($filename) || $filename eq "");
		$filename =~ s/^.*\///;		# Pfadangaben entfernen
		$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
		$OVJ::genfilename = $filename;
#		if (-e $configpath.$sep.$OVJ::genfilename.".txt")
#		{
#			my $response = $gui->messageBox(-icon => 'question', 
#													-message => "Datei ".$OVJ::genfilename.".txt existiert bereits\n\nÜberschreiben?", 
#													-title => 'Generelle Daten Datei überschreiben?', 
#													-type => 'YesNo', 
#													-default => 'Yes');
#			return 1 if ($response eq "No");
#			OVJ_meldung(HINWEIS,"Speichere ".$OVJ::genfilename);
#		}
#		else
#		{
		if (-e $OVJ::configpath.$sep.$OVJ::genfilename.$sep.$OVJ::genfilename.".txt")
		{ OVJ_meldung(HINWEIS,"Überschreibe ".$OVJ::genfilename); }
		else { OVJ_meldung(HINWEIS,"Erzeuge ".$OVJ::genfilename); }
#		}
		OVJ::GUI::set_general_data_label($OVJ::genfilename);
		$config{"LastGenFile"} = $OVJ::genfilename;
		return(write_genfile());
	}
}

#Schreiben der Generellen Daten in die Genfile Datei
sub write_genfile {
# FIXME: has side-effects
	%general = OVJ::GUI::get_general();	# Hash aktualisieren auf Basis der Felder
	OVJ::write_genfile($OVJ::genfilename, $OVJ::configpath, %general) or return 1; # FIXME:
	return 0;	# kein Fehler
}


#Lesen der Generellen Daten aus der Genfile Datei
sub read_genfile {
# FIXME: has side-effects, access TK
	my ($choice,$filename) = @_;	# 0 = Laden, 1 = Importieren
	%general = OVJ::read_genfile($filename);
	if ($choice != 0) {
		my %general_alt = OVJ::GUI::get_general();
		@{$general{ovfj_link}} = @{$general_alt{ovfj_link}};
		$general{PMVorjahr} = $general_alt{PMVorjahr};
		$general{PMaktJahr} = $general_alt{PMaktJahr};
	}
	OVJ::GUI::set_general(%general);
	
	# %general = OVJ::GUI::get_general() if ($choice == 1);	# einige Hashwerte löschen
	OVJ::GUI::do_reset_eval();	# evtl. vorhandene Auswertungen löschen
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
											-message => "Generelle Daten \'$OVJ::genfilename\' wurden geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => "Generelle Daten \'$OVJ::genfilename\' speichern?", 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	return(do_file_general(0)) if ($response eq "Yes");
	return 0;
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
	write_ovfjfile(OVJ::GUI::get_selected_ovfj()) if ($response eq "Yes");
	return 0;
}


# Auswertung und Export von OVFJ
# Parameter: Liste der OVFJ
sub do_eval_ovfj {
	my $i = 0;
	my $success = 0;
	my $retval;
	
	OVJ::GUI::do_reset_eval();
	my %general = OVJ::GUI::get_general();
	my %tn;					# Hash für die Teilnehmer, Elemente sind wiederum Hashes
	my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
	                  	# Elemente sind die %ovfj Daten
	my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info über die Anzahl 
	                     # der Teilnehmer, wird parallel zur @ovfjlist Liste geführt
	foreach $str (@_)
	{
		$ovfjname = $str;
		$ovfjrepfilename = $str . "_report_ovj.txt";
		next if ($ovfjname !~ /\S+/);
#		next if (OVJ::GUI::CreateEdit_ovfj($ovfjname,2)==1);
		%ovfj = OVJ::read_ovfjfile($ovfjname)
		 or next;
		OVJ::GUI::set_ovfj(%ovfj);
		$retval = OVJ::eval_ovfj($i++,
		  \%general,
		  \%tn,
		  \@ovfjlist,
		  \@ovfjanztlnlist,
		  \%ovfj,
		  $ovfjname,
		  $inputpath,
		  $reportpath,
#		  $OVJ::genfilename,
		  $ovfjrepfilename
		);
		$success = 1 if ($retval == 0);	# Stelle fest, ob wenigstens eine Auswertung erfolgreich war
		last if ($retval == 2);	# systematischer Fehler, Abbruch der Schleife
	}
	OVJ::export(\%general,\%tn,\@ovfjlist,\@ovfjanztlnlist,$outputpath) if ($success);
}


#Exit Box aus dem 'Datei' Menu und 'Exit' Button
sub Leave {
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	return if (OVJ::GUI::CheckForUnsavedPatterns());	# Abbruch durch Benutzer
	return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
	OVJ::Inifile::write($inifilename,%config)		# Speichern der Inidaten
	  or warn "Kann INI-Datei '$inifilename' nicht schreiben: $!";
	exit 0;
}

sub OVJ_meldung {
	my $level = shift;
	my $message = "$level: " . shift;
	OVJ::GUI::meldung($level, $message) if $gui;
	return 0;
}

