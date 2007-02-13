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


my $inifilename = "OVJini.txt";
my %config  = ();		# Konfigurationsdaten
my $gui;


intro();
%config = OVJ::Inifile::read($inifilename)
 or warn "Kann INI-Datei '$inifilename' nicht lesen: $!";
$gui = OVJ::GUI::init(%config);
init() or exit 1;
OVJ::GUI::run();
OVJ::Inifile::write($inifilename,%config)		# Speichern der Inidaten
 or warn "Kann INI-Datei '$inifilename' nicht schreiben: $!";
exit 0;



sub intro {
	my $str = "*  OVJ $OVJ::ovjvers by DL3SDO, $OVJ::ovjdate  *";
	my $sep = '*' x length($str);
	print "$sep\n$str\n$sep\n";
}


sub init {
	init_general();	# Lade Generelle Daten Datei falls vorhanden
	OVJ::GUI::set_patterns(OVJ::read_patterns());
	
	foreach my $dir ($OVJ::configpath, $OVJ::reportpath,
	                 $OVJ::outputpath, $OVJ::inputpath) {
		next if -d $dir;
		OVJ::GUI::meldung(HINWEIS, "Erzeuge Verzeichnis '$dir'");
		mkdir $dir
		 or return OVJ_meldung(FEHLER, 
		   "Konnte Verzeichnis '$dir' nicht erstellen: $!");
	}
	return 1;
}


sub init_general {
	if (exists $config{LastGenFile}) {
		$OVJ::genfilename = $config{LastGenFile};
		OVJ_meldung(HINWEIS,"Lade $OVJ::genfilename...");
		OVJ::GUI::set_general(OVJ::read_genfile($OVJ::genfilename));
	}
}


sub OVJ_meldung {
	my $level = shift;
	my $message = "$level: " . shift;
	OVJ::GUI::meldung($level, $message) if $gui;
	return 0;
}

