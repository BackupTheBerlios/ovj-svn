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

package OVJ::GUI;

use strict;
use Carp;

use Tk;

my $root;
my %gui_general;
my $gui_general_label;

sub make_window {
	my $root = MainWindow->new;
	croak "FIXME: Not implemented";
}

sub make_general {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	$root ||= $parent;
	
	my $fr1 = $parent->Frame(-borderwidth => 5, -relief => 'raised');
	$fr1->pack;
	$gui_general_label = $fr1->Label(-text => 'Generelle Daten:')->pack;
	
	my $fr11 = $fr1->Frame->pack(-side => 'left');
	my $fr111 = $fr11->Frame->pack;
	$fr111->Button(
	        -text => 'Importieren',
	        -command => sub{::do_file_general(3)}
	    )->pack(-side => 'right',-padx => 1);
	$fr111->Button(
	        -text => 'Speichern als',
	        -command => sub{::do_file_general(4)}
	    )->pack(-side => 'right',-padx => 1);
	$fr111->Button(
	        -text => 'Speichern',
	        -command => sub{::do_file_general(0)}
	    )->pack(-side => 'right',-padx => 1);
	$fr111->Button(
	        -text => 'Laden',
	        -command => sub{::do_file_general(1)}
	    )->pack(-side => 'right',-padx => 1);
	
	my $fr112 = $fr11->Frame->pack;
	$fr112->Label(-text => 'Distrikt')->pack(-side => 'left');
	$gui_general{Distrikt} = $fr112->Entry()->pack(-side => 'left');
	
	my $fr113 = $fr11->Frame->pack;
	$fr113->Label(-text => 'Distriktskenner')->pack(-side => 'left');
	$gui_general{Distriktskenner} = $fr113->Entry(-width => 1)->pack(-side => 'left');
	
	$fr113->Label(-text => 'Jahr')->pack(-side => 'left');
	$gui_general{Jahr} = $fr113->Entry(-width => 4)->pack(-side => 'left');
	
	my $fr12 = $fr1->Frame->pack(-side => 'left');
	my $fr121 = $fr12->Frame->pack;
	$gui_general{Name} = $fr121->Entry(-width => 16)->pack(-side => 'right');
	$fr121->Label(-text => 'Name')->pack(-side => 'left');
	my $fr122 = $fr12->Frame->pack;
	$gui_general{Vorname} = $fr122->Entry(-width => 16)->pack(-side => 'right');
	$fr122->Label(-text => 'Vorname')->pack(-side => 'left');
	my $fr123 = $fr12->Frame->pack;
	$fr123->Label(-text => 'CALL')->pack(-side => 'left');
	$gui_general{Call} = $fr123->Entry(-width => 8)->pack(-side => 'left');
	$gui_general{DOK} = $fr123->Entry(-width => 4)->pack(-side => 'right');
	$fr123->Label(-text => 'DOK')->pack(-side => 'left');
	
	my $fr13 = $fr1->Frame->pack(-side => 'left');
	my $fr131 = $fr13->Frame->pack;
	$gui_general{Telefon} = $fr131->Entry()->pack(-side => 'right');
	$fr131->Label(-text => 'Telefon')->pack(-side => 'left');
	my $fr132 = $fr13->Frame->pack;
	$gui_general{"Home-BBS"} = $fr132->Entry()->pack(-side => 'right');
	$fr132->Label(-text => 'Home-BBS')->pack(-side => 'left');
	my $fr133 = $fr13->Frame->pack;
	$gui_general{"E-Mail"} = $fr133->Entry()->pack(-side => 'right');
	$fr133->Label(-text => 'E-Mail')->pack(-side => 'left');
	
	my $fr14 = $fr1->Frame->pack(-side => 'left');
	my $fr141 = $fr14->Frame->pack;
	$gui_general{PMVorjahr} = $fr141->Entry(-width => 15)->pack(-side => 'right');
	$fr141->Button(
	        -text => 'PM Vorjahr',
	        -command => sub{do_select_pmfile(0)}
	    )->pack(-side => 'left');
	my $fr142 = $fr14->Frame->pack;
	$gui_general{PMaktJahr} = $fr142->Entry(-width => 15)->pack(-side => 'right');
	$fr142->Button(
	        -text => 'PM akt. Jahr',
	        -command => sub{do_select_pmfile(1)}
	    )->pack(-side => 'left');
	my $fr143 = $fr14->Frame->pack;
	$gui_general{Spitznamen} = $fr143->Entry(-width => 15)->pack(-side => 'right');
	$fr143->Button(
	        -text => 'Spitznamen',
	        -command => sub{do_get_nickfile()}
	    )->pack(-side => 'left');
	     
}

sub set_general {
	my %general = @_;
	map {
		$gui_general{$_}->delete(0, "end");
		$gui_general{$_}->insert(0, $general{$_});
	} keys %gui_general;
}

#Aktualisieren der aktuellen Generellen Daten im Hash
sub get_general {
	my %general;
	while (my ($key,$value) = each(%gui_general)) {
		$general{$key} = $value->get();
	}
	return %general;
}

sub general_modified {
	my %general = @_;
	grep {
		$gui_general{$_}->get ne ($general{$_} || "");
	} keys %gui_general;
}

# FIXME: Unify file selection code

#Auswahl der Spitznamen Datei per Button
sub do_get_nickfile {
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $root->getOpenFile(-initialdir => '.', -filetypes => $types, -title => "Spitznamen Datei auswählen");
	return if (!defined($selfile) || $selfile eq "");
	$selfile =~ s/^.*\///;
	$gui_general{Spitznamen}->delete(0,"end");
	$gui_general{Spitznamen}->insert(0,$selfile);
}

#Auswahl der PMVorjahr (0) oder aktuellen (else) PM Datei per Button
sub do_select_pmfile {
	my ($choice) = @_;
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $root->getOpenFile(-initialdir => '.', -filetypes => $types, -title => ($choice == 0 ? "PM Vorjahr Datei auswählen" : "aktuelle PM Datei auswählen"));
	return if (!defined($selfile) || $selfile eq "");
	$selfile =~ s/^.*\///;
	if ($choice == 0)
	{
		$gui_general{PMVorjahr}->delete(0,"end");
		$gui_general{PMVorjahr}->insert(0,$selfile);
	}
	else
	{
		$gui_general{PMaktJahr}->delete(0,"end");
		$gui_general{PMaktJahr}->insert(0,$selfile);
	}
}

sub set_general_data_label {
	my $label = "Generelle Daten";
	$label .= ": $_[0]" if $_[0];
	$gui_general_label->configure(-text => $label);
}

1;
