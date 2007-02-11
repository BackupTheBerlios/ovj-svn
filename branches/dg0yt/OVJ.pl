#!/usr/bin/perl -w
#
# Branch DG0YT $Id$
# Some portions (C) 2007 Kai Pastor, DG0YT <dg0yt AT darc DOT de>
#
# Based on / major work:
#
# Script zum Erzeugen der OV Jahresauswertung f�r
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
my %ovfj;				# Hash f�r eine OV Veranstaltung, Kopfdaten
my $ovfjname;			# Name der aktiven OV Veranstaltung

my $inifilename = "OVJini.txt";
my $inputpath = "input";		# Pfad f�r die Eingangsdaten
my $outputpath = "output";		# Pfad f�r die Ergebnisdaten
my $reportpath = "report";		# Pfad f�r die Reportdaten
#my $configpath = "config";		# Pfad f�r die Konfigurationsdaten
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
Leave();



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

	if ($choice == 2)	# Laden der im Inifile angegebenen Datei, wird beim Programmstart ausgef�hrt
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
#													-message => "Datei ".$OVJ::genfilename.".txt existiert bereits\n\n�berschreiben?", 
#													-title => 'Generelle Daten Datei �berschreiben?', 
#													-type => 'YesNo', 
#													-default => 'Yes');
#			return 1 if ($response eq "No");
#			OVJ_meldung(HINWEIS,"Speichere ".$OVJ::genfilename);
#		}
#		else
#		{
		if (-e $OVJ::configpath.$sep.$OVJ::genfilename.$sep.$OVJ::genfilename.".txt")
		{ OVJ_meldung(HINWEIS,"�berschreibe ".$OVJ::genfilename); }
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
	
	# %general = OVJ::GUI::get_general() if ($choice == 1);	# einige Hashwerte l�schen
	OVJ::GUI::do_reset_eval();	# evtl. vorhandene Auswertungen l�schen
	undef %ovfj;	# OVFJ Daten l�schen
	OVJ::GUI::clear_ovfj();	# und anzeigen
	$OVJ::GUI::ovfj_eval_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfj_fileset_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfj_save_button->configure(-state => 'disabled');
	$OVJ::GUI::copy_pattern_button->configure(-state => 'disabled');
	$OVJ::GUI::ovfjnamelabel->configure(-text => "OV Wettbewerb: ");
	return 0;	# kein Fehler
}



# Auswertung und Export von OVFJ
# Parameter: Liste der OVFJ
sub do_eval_ovfj {
	my $i = 0;
	my $success = 0;
	my $retval;
	
	OVJ::GUI::do_reset_eval();
	my %general = OVJ::GUI::get_general();
	my %tn;					# Hash f�r die Teilnehmer, Elemente sind wiederum Hashes
	my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
	                  	# Elemente sind die %ovfj Daten
	my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info �ber die Anzahl 
	                     # der Teilnehmer, wird parallel zur @ovfjlist Liste gef�hrt
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

