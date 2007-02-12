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
my $ovfjname;			# Name der aktiven OV Veranstaltung

my $inifilename = "OVJini.txt";
my $inputpath = "input";		# Pfad für die Eingangsdaten
my $outputpath = "output";		# Pfad für die Ergebnisdaten
my $reportpath = "report";		# Pfad für die Reportdaten
#my $configpath = "config";		# Pfad für die Konfigurationsdaten
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
		OVJ::GUI::set_general(OVJ::read_genfile($OVJ::genfilename));
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

