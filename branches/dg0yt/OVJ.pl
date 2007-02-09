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

my $inifilename = "OVJini.txt";
my $inputpath = "input";		# Pfad für die Eingangsdaten
my $outputpath = "output";		# Pfad für die Ergebnisdaten
my $reportpath = "report";		# Pfad für die Reportdaten
my $configpath = "config";		# Pfad für die Konfigurationsdaten
										# Generelle Daten, sowie die OVFJ Dateien (*_ovj.txt))
my $sep = ($^O =~ /Win/i) ? '\\' : '/';	# Kai, fuer Linux und Win32 Portabilitaet

my ($genfilename,$ovfjfilename,$ovfjrepfilename);

my %tn;					# Hash für die Teilnehmer, Elemente sind wiederum Hashes
my %auswerthash;		# Hash zur Kontrolle, welche OVFJ schon ausgewertet sind
my $nicknames;			# Inhalt der Spitznamen Datei
my ($i,$str);			# temp. Variablen
my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
                  	# Elemente sind die %ovfj Daten
my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info über die Anzahl 
                     # der Teilnehmer, wird parallel zur @ovfjlist Liste geführt
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
	return 0;	# kein Fehler
}


#Lesen der Generellen Daten aus der Genfile Datei
sub read_genfile {
# FIXME: has side-effects, access TK
	my ($choice,$filename) = @_;	# 0 = Laden, 1 = Importieren
	%general = OVJ::read_genfile($filename, $configpath);
	if ($choice != 0) {
		my %general_alt = OVJ::GUI::get_general();
		@{$general{ovfj_link}} = @{$general_alt{ovfj_link}};
		$general{PMVorjahr} = $general_alt{PMVorjahr};
		$general{PMaktJahr} = $general_alt{PMaktJahr};
	}
	OVJ::GUI::set_general(%general);
	
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


#Auswahl einer Veranstaltung durch den Anwender
sub do_edit_ovfj {
	my ($choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb. Wird durchgereicht.
	$ovfjname = OVJ::GUI::get_selected_ovfj();
	CreateEdit_ovfj($ovfjname, $choice);
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
	$OVJ::lfdauswert = 0;
#	$meldung->delete(0,"end");
}



#Auswertung und Export aller OVFJ
sub do_eval_ovfj {
	$ovfjname = shift
	 or return;
	$ovfjname =~ /\S+/
	 or return;
	my $i = 0;
	my $success = 0;
	my $retval;
	
	do_reset_eval();
	my %general = OVJ::GUI::get_general();
	next if (CreateEdit_ovfj($ovfjname,2)==1); # FIXME: ?
	$retval = OVJ::eval_ovfj($i++,
	  \%general,
	  \%tn,
	  \@ovfjlist,
	  \@ovfjanztlnlist,
	  \%ovfj,
	  $ovfjname,
	  $inputpath,
	  $reportpath,
	  $genfilename,
	  $ovfjrepfilename
	);
	OVJ::export(\%general,\%tn,\@ovfjlist,\@ovfjanztlnlist,$outputpath,$genfilename) if (! $retval);
}

#Auswertung und Export aller OVFJ
sub do_eval_allovfj {
	my $i = 0;
	my $success = 0;
	my $retval;
	
	do_reset_eval();
	my %general = OVJ::GUI::get_general();
	foreach $str (@{$general{ovfj_link}})
	{
		$ovfjname = $str;
		next if ($ovfjname !~ /\S+/);
		next if (CreateEdit_ovfj($ovfjname,2)==1);
		$retval = OVJ::eval_ovfj($i++,
		  \%general,
		  \%tn,
		  \@ovfjlist,
		  \@ovfjanztlnlist,
		  \%ovfj,
		  $ovfjname,
		  $inputpath,
		  $reportpath,
		  $genfilename,
		  $ovfjrepfilename
		);
		$success = 1 if ($retval == 0);	# Stelle fest, ob wenigstens eine Auswertung erfolgreich war
		last if ($retval == 2);	# systematischer Fehler, Abbruch der Schleife
	}
	OVJ::export(\%general,\%tn,\@ovfjlist,\@ovfjanztlnlist,$outputpath,$genfilename) if ($success);
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
	OVJ::GUI::add_meldung($message) if $gui;
	return 0;
}

