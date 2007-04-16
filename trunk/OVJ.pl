#!/usr/bin/perl --
#
# $Id$
#
# Script zum Erzeugen der OV Jahresauswertung für
# OV Peilwettbewerbe
#
# Copyright (C) 2007  Matthias Kuehlewein, DL3SDO,
#                     Kai Pastor, DG0YT, <dg0yt AT darc DOT de>
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

use warnings;
use strict qw(vars);		# Deklarationen erzwingen

use lib "lib";	# FIXME: relativ zum Programverzeichnis ermitteln

use OVJ;
BEGIN { print STDERR OVJ::ovjinfo() . "\n" }

use Config::IniFiles;
use OVJ::GUI;

my $inifilename = "ovj.ini";
my $inifile = Config::IniFiles->new();
$inifile->SetFileName($inifilename);
$inifile->ReadConfig() if (-r $inifilename);
 ;# or warn "Kann INI-Datei '$inifilename' nicht lesen: $!";
my %config;
if ($inifile->val('LastSession','ProjectFile')) {
	$config{LastGenFile} = $inifile->val('LastSession','ProjectFile');
}
OVJ::GUI::init(%config);
init() or exit 1;

OVJ::GUI::run();

$inifile->setval('LastSession','ProjectFile', $OVJ::genfilename)
 or $inifile->newval('LastSession','ProjectFile', $OVJ::genfilename);
$inifile->RewriteConfig()		# Speichern der Inidaten
 or warn "Kann INI-Datei '$inifilename' nicht schreiben: $!";

exit 0;



sub init {
	if ($config{LastGenFile} && $config{LastGenFile} ne OVJ::GUI::UNNAMED) {
		OVJ::GUI::open_file_general($config{LastGenFile});
	}
	return 1;
}

