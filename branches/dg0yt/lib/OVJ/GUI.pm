# $Id$
#
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

package OVJ::GUI;

use strict;
use Carp;

use Tk;
use Tk::DialogBox;
use OVJ;

my $mw;
my %gui_general;
my $gui_general_label;
my %gui_ovfj;
my $gui_patterns;
my $meldung;
my $check_ExcludeTln;

my $curr_patterns;
my $orig_patterns;
my %orig_ovfj;
my %orig_general;

# my %auswerthash;		# Hash zur Kontrolle, welche OVFJ schon ausgewertet sind

# use vars qw(
my $fjlistbox;
my $reset_eval_button;
my $exp_eval_button;
my $ovfj_eval_button;
my $ovfj_fileset_button;
my $ovfj_save_button;
my $copy_pattern_button;
my $select_pattern_button;
my $ovfjnamelabel;
#);

sub run {
	# Warnungen abfangen
	$SIG{'__WARN__'} = sub {
		my $error = shift;
		chomp $error;
		meldung(OVJ::WARNUNG, $error);
	};
	
	MainLoop();
	
	# GUI beendet, Warnungen nicht mehr abfangen
	delete $SIG{'__WARN__'};
}

sub init {
	my %config = @_;
	
	$mw = MainWindow->new;
	$mw->OnDestroy(\&Leave);
	$mw->gridColumnconfigure(0, -weight => 1);
	$mw->gridRowconfigure([1,3], -weight => 3);

	make_menu($mw)->grid(-row => 0,-sticky => 'nswe');
	make_general($mw)->grid(-row => 1, -sticky => 'nswe');
	make_ovfj_detail($mw)->grid(-row => 2, -sticky => 'nswe');
	make_meldungen($mw)->grid(-row => 3, -sticky => 'nswe');

	set_patterns(OVJ::read_patterns());

	return $mw;
}


# Men�
sub make_menu {
	my $parent = shift
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $menu_bar = $parent->Frame(-relief => 'raised', -borderwidth => 1);
	$menu_bar->Menubutton(-text => 'Datei', -underline => 0, -menuitems => [
				[ Button => "Neu", -underline => 0, -command => \&set_general],
				[ Button => "�ffnen", -underline => 1, -command => \&open_file_general],
				[ Button => "Importieren", -underline => 0, -command => \&import_file_general],
				[ Button => "Speichern", -underline => 0, -command => \&save_file_general],
				[ Separator => "--" ],
				[ Button => "Beenden", -underline => 0, -command => \&Leave]])
								->pack(-side => 'left');
	$menu_bar->Menubutton(-text => 'Hilfe', -underline => 0, , -menuitems => [
				[ Button => "�ber", -underline => 1,-command => \&About]])
								->pack(-side => 'left');
#	$menu_bar->Button(
#	        -text    => 'Exit', -underline => 1,
#	        -command => \&Leave)->pack(-side => 'right');
	$menu_bar->Label(-text => $OVJ::ovjinfo)->pack();
	return $menu_bar;
}
    
# Allgemeine Daten
sub make_general {
	my $parent = shift
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";

	my $fr0 = $parent->Frame(-borderwidth => 1, -relief => 'raised');

#	$fr0->pack;

	$fr0->gridColumnconfigure([1,4,7], -weight => 1);
	$fr0->gridColumnconfigure([2,5,8], -minsize => 15);
#	$fr0->gridRowconfigure([1,4], -pad => 15);

	my ($row, $col) = (0, 0);
	$gui_general_label = $fr0->Label(-text => 'OV-Jahresauswertung')
	  ->grid(-row => $row, -column => $col++, -sticky => 'nw', -columnspan => 6);
	
	($row, $col) = ($row+1, 0);
	$fr0->Label(-text => 'Distrikt')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Distrikt} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'Distriktskenner')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Distriktskenner} = $fr0->Entry(-width => 1)
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	
	$col++;
	$fr0->Label(-text => 'Jahr')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Jahr} = $fr0->Entry(-width => 4)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	($row, $col) = ($row+1, 0);
	$fr0->Label(-text => 'Name')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Name} = $fr0->Entry(-width => 16)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	$col++;
	$fr0->Label(-text => 'Vorname')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Vorname} = $fr0->Entry(-width => 16)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	$col++;
	$fr0->Label(-text => 'Call')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Call} = $fr0->Entry(-width => 8)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	$col++;
	$fr0->Label(-text => 'DOK')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{DOK} = $fr0->Entry(-width => 4)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	($row, $col) = ($row+1, 0);
	$fr0->Label(-text => 'Telefon')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{Telefon} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'Home-BBS')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{"Home-BBS"} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'E-Mail')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_general{"E-Mail"} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	($row, $col) = ($row+1, 0);
	$fr0->Button(
	        -text => 'PM Vorjahr',
	        -command => sub{do_select_pmfile(0)} )
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	$gui_general{PMVorjahr} = $fr0->Entry(-width => 15)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Button(
	        -text => 'PM akt. Jahr',
	        -command => sub{do_select_pmfile(1)} )
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	$gui_general{PMaktJahr} = $fr0->Entry(-width => 15)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Button(
	        -text => 'Spitznamen',
	        -command => sub{do_get_nickfile()} )
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	$gui_general{Spitznamen} = $fr0->Entry(-width => 15)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	($row, $col) = ($row+1, 0);
	make_ovfj_list($fr0)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we',
	         -padx => 5, -pady => 5, -columnspan=>11);

	return $fr0;
}

# Liste der OV-Wettbewerbe
sub make_ovfj_list {
	my $parent = shift
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $fr0 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
#	$fr2->pack;
	$fr0->gridColumnconfigure(1, -weight => 2);
	$fr0->gridColumnconfigure(3, -weight => 1);
	$fr0->gridColumnconfigure(2, -minsize => 15);
#	$fr0->gridRowconfigure(6, -pad => 15);

	my ($row, $col) = (0, 0);
	$fr0->Label(-text => 'Liste der OV-Wettbewerbe')
	  ->grid(-row => $row, -column => $col++, -sticky => 'nw', -columnspan => 3);
	
	($row, $col) = ($row+1, 0);
	$fjlistbox = $fr0->Scrolled('Text',
		-scrollbars =>'oe',width => 40, height => 4)
	  ->grid(-row => $row, -column => $col++, -sticky => 'wens', -columnspan => 2, -rowspan => 4);
	
	$col += 2;
	$fr0->Button(
	        -text => 'Editieren/Erzeugen',
	        -command => sub{do_edit_ovfj(0)})
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$fr0->Button(
	        -text => 'Erzeugen aus aktuellem OV-Wettbewerb',
	        -command => sub{do_edit_ovfj(1)})
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$fr0->Button(
	        -text => 'Alle OV-Wettbewerbe auswerten und exportieren',
	        -command => sub{ 
				my %general = get_general();
				do_eval_ovfj(@{$general{ovfj_link}})})
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$reset_eval_button = $fr0->Button(
	        -text => 'Auswertung im Speicher l�schen',
	        -command => \&do_reset_eval,
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$exp_eval_button = $fr0->Button(
	        -text => 'Auswertung exportieren',
	        -command => \&Export,
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	
	($row, $col) = ($row-1, 0);
	$check_ExcludeTln = $fr0->Checkbutton()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	$fr0->Label(-text => "Beim Export Teilnehmer ohne offizielle Veranstaltung\nim akt. Jahr ausschliessen")
	  ->grid(-row => $row++, -column => $col, -sticky => 'w');
	return $fr0;
}


# Wettbewerbsdaten
sub make_ovfj_detail {
	my $parent = shift
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $fr0 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
#	$fr3->pack;
	$fr0->gridColumnconfigure([1,4,7], -weight => 1);
	$fr0->gridColumnconfigure([2,5,8], -minsize => 15);
#	$fr0->gridRowconfigure(6, -pad => 15);

	my ($row, $col) = (0, 0);
	$ovfjnamelabel = $fr0->Label(-text => 'OV-Wettbewerb')
	  ->grid(-row => $row, -column => $col++, -sticky => 'nw', -columnspan => 3);
	
	($row, $col) = ($row+1, 0);
	$ovfj_fileset_button = $fr0->Button(
	        -text => 'OVFJ-Auswertungsdatei',
	        -state => 'disabled',
	        -command => sub{ do_select_fjfile() } )
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{OVFJDatei} = $fr0->Entry(-width => 27)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	$col++;
	$fr0->Label(-text => 'Ausricht. OV')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{AusrichtOV} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'DOK')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{AusrichtDOK} = $fr0->Entry(-width => 4)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	($row, $col) = ($row+1, 0);
	$fr0->Label(-text => 'Datum')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Datum} = $fr0->Entry(-width => 10)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'Band')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Band} = $fr0->Entry(-width => 2)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	$col++;
	$fr0->Label(-text => 'Anz. Teilnehmer manuell')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w', -columnspan => 4);
	$col += 3;
	$gui_ovfj{TlnManuell} = $fr0->Entry(-width => 2)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	($row, $col) = ($row+1, 0);
	$fr0->Label(-text => 'Name')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Verantw_Name} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'Vorname')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Verantw_Vorname} = $fr0->Entry()
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'Call')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Verantw_CALL} = $fr0->Entry(-width => 8)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	$col++;
	$fr0->Label(-text => 'DOK')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Verantw_DOK} = $fr0->Entry(-width => 4)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	
	($row, $col) = ($row+1, 0);
	$fr0->Label(-text => 'Geburtsjahr')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$gui_ovfj{Verantw_GebJahr} = $fr0->Entry(-width => 4)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');

	($row, $col) = ($row+1, 0);
	$select_pattern_button = $fr0->Button(
		-text    => 'Muster', 
		-state   => 'disabled',
		-command => \&do_pattern_dialog,)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we');
	$gui_ovfj{Auswertungsmuster} = $fr0->Entry(-width => 70)
	  ->grid(-row => $row, -column => $col++, -sticky => 'we', -columnspan => 10);

	($row, $col) = ($row+1, 1);
	$ovfj_save_button = $fr0->Button(
	        -text => 'Speichern',
	        -command => sub {
				my %ovfj = get_ovfj();
				OVJ::write_ovfjfile(get_selected_ovfj(), \%ovfj ) 
			},
	        -state => 'disabled')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	$col+=2;
	$ovfj_eval_button = $fr0->Button(
	        -text => 'Auswertung',
	        -command => sub{do_eval_ovfj(get_selected_ovfj())},
	        -state => 'disabled')
	  ->grid(-row => $row, -column => $col++, -sticky => 'w');
	
	
	return $fr0;
}

# Statusmeldungen
sub make_meldungen {
	my $parent = shift
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $fr5 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
#	$fr5->pack;
	$fr5->gridColumnconfigure(0, -weight => 1);
	$fr5->gridRowconfigure(1, -weight => 1);
	$fr5->Label(-text => 'Meldungen')->grid(-stick => "w");
	$meldung = $fr5->Scrolled('Listbox',-scrollbars =>'e',-width => 80, -height => 6)
	  ->grid(-stick => "nswe", -row => 1);
	return $fr5;
}

sub do_pattern_dialog {
	my $dlg = $mw->DialogBox(
	  -title          => 'Musterkatalog',
	  -buttons        => ['�bernehmen', 'Speichern', 'Abbrechen'],
	);
	my $textbox = $dlg->add('Scrolled','Text',-wrap=>'none',-scrollbars =>'osoe',-width => 80, -height => 6)
	  ->pack(-fill => 'both', -expand => 1);
	$textbox->Contents($curr_patterns);
	while (1) {
		my $sel = $dlg->Show;
		my $curr_patterns = $textbox->Contents;
		if ($sel eq '�bernehmen') {
			if ( my $pattern = get_selected($textbox) ) {
				$pattern =~ s/\/\/.*$//;	# Entferne Kommentare beim Kopieren
				$pattern =~ s/\s+$//;		# Entferne immer Leerzeichen nach dem Muster
				my %ovfj_tmp = get_ovfj();
				$gui_ovfj{Auswertungsmuster}->delete(0, "end");
				$gui_ovfj{Auswertungsmuster}->insert(0, $pattern);
				last;
			}
		}
		elsif ($sel eq 'Speichern') {
			if ( OVJ::save_patterns($curr_patterns) ) {
				$orig_patterns = $curr_patterns;
				last;
			}
		}
		else {
			last;
		}
	}
}

sub set_general {
#	return unless @_;
	%orig_general = @_;
	$orig_general{Exclude_Checkmark} ||= '';
	$check_ExcludeTln->{Value} = $orig_general{Exclude_Checkmark}; 
	$orig_general{ovfj_link} ||= [];
	$fjlistbox->selectAll();
	$fjlistbox->deleteSelected();
	$fjlistbox->insert('end', join("\n", @{$orig_general{ovfj_link}}));
#	map { $fjlistbox->insert('end', "$_\n") } @{$general{ovfj_link}};
	map {
		$orig_general{$_} ||= '';
		$gui_general{$_}->delete(0, "end");
		$gui_general{$_}->insert(0, $orig_general{$_});
	} keys %gui_general;
	do_reset_eval();
	$ovfj_eval_button->configure(-state => 'disabled');
	$ovfj_fileset_button->configure(-state => 'disabled');
	$ovfj_save_button->configure(-state => 'disabled');
#	$copy_pattern_button->configure(-state => 'disabled');
	$select_pattern_button->configure(-state => 'disabled');
	$ovfjnamelabel->configure(-text => "OV Wettbewerb: ");
}

#Aktualisieren der aktuellen Generellen Daten im Hash
sub get_general {
	my %general;
	while (my ($key,$value) = each(%gui_general)) {
		$general{$key} = $value->get();
	}
	$general{Exclude_Checkmark} = $check_ExcludeTln->{Value};
	@{$general{ovfj_link}} = split "\n", $fjlistbox->Contents();
	return %general;
}

# Test auf �nderungen
sub general_modified {
	$orig_general{Exclude_Checkmark} ne $check_ExcludeTln->{Value}
	or grep {
		$gui_general{$_}->get() ne ($orig_general{$_} || "");
	} keys %gui_general
	or join("\n", @{$orig_general{ovfj_link}}) ne $fjlistbox->Contents();
}


sub get_selected_ovfj {
	return get_selected($fjlistbox);
}


sub set_ovfj {
	%orig_ovfj = @_;
	map {
		$gui_ovfj{$_}->delete(0, "end");
		$gui_ovfj{$_}->insert(0, $orig_ovfj{$_});
	} keys %gui_ovfj;
}

sub get_ovfj {
	my %ovfj;
	while (my ($key,$value) = each(%gui_ovfj)) {
		$ovfj{$key} = $value->get();
	}
	foreach my $key (qw(AusrichtDOK Verantw_CALL Verantw_DOK)) {
		$ovfj{$key} = uc $ovfj{$key};
	}
	return %ovfj;
}

# Test auf �nderungen
sub ovfj_modified {
	grep {
		$gui_ovfj{$_}->get ne ($orig_ovfj{$_} || "");
	} keys %gui_ovfj;
}

sub clear_ovfj {
	while (my ($key,$value) = each(%gui_ovfj)) {
		$value->delete(0, 'end');
	}
	%orig_ovfj = ();
}

# FIXME: Unify file selection code

#Auswahl der Spitznamen Datei per Button
sub do_get_nickfile {
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $mw->getOpenFile(-initialdir => '.', -filetypes => $types, -title => "Spitznamen Datei ausw�hlen");
	return if (!defined($selfile) || $selfile eq "");
	$selfile =~ s/^.*\///;
	$gui_general{Spitznamen}->delete(0,"end");
	$gui_general{Spitznamen}->insert(0,$selfile);
}

#Auswahl der PMVorjahr (0) oder aktuellen (else) PM Datei per Button
sub do_select_pmfile {
	my ($choice) = @_;
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $mw->getOpenFile(-initialdir => '.', -filetypes => $types, -title => ($choice == 0 ? "PM Vorjahr Datei ausw�hlen" : "aktuelle PM Datei ausw�hlen"));
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

#�ber Box aus dem 'Hilfe' Menu
sub About {
	$mw->messageBox(-icon => 'info', 
						-message => << "END_ABOUT",
OV Jahresauswertung
by Matthias K�hlewein, DL3SDO

Stark modifiziert von/
Fehlerberichte an:
Kai Pastor, DG0YT

$OVJ::ovjinfo
END_ABOUT
						-title => '�ber', -type => 'Ok');
}


sub get_patterns {
	return $curr_patterns;
}

sub set_patterns {
	$curr_patterns = $orig_patterns = shift;
}

sub patterns_modified {
	return $orig_patterns ne $curr_patterns;
}


#Ueberpruefen beim Beenden des Programms, ob aktuelle Auswertungsmuster
#gespeichert wurden, und falls nicht, was passieren soll
sub CheckForUnsavedPatterns {
	if (patterns_modified()) {
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => 'Auswertungsmuster speichern?', 
			-message => "Liste der Auswertungsmuster wurden ge�ndert\n".
			            "und noch nicht gespeichert.\n\n".
						"Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 1 }
		elsif ($response eq 'Yes')    { return OVJ::save_patterns(get_patterns()) }
	}
	
	return 0;
}


#Pr�fen, ob OVFJ Veranstaltung ver�ndert wurde, ohne gespeichert worden zu
#sein
sub CheckForOverwriteOVFJ {
	if (ovfj_modified()) {
		my $ovfjname = get_selected_ovfj();
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => 'OVFJ Daten speichern?', 
			-message => "Kopfdaten zum OV Wettbewerb '$ovfjname' wurden ge�ndert\n".
			            "und noch nicht gespeichert.\n\n".
			            "Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 1 }
		elsif ($response eq 'Yes')    { return OVJ::write_ovfjfile($ovfjname) }
	}
	
	return 0;
}


#Pr�fen, ob Generelle Daten ver�ndert wurde, ohne gespeichert worden zu
#sein
sub CheckForSaveGenfile {
	if (general_modified()) {
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => "Generelle Daten '$OVJ::genfilename' speichern?", 
			-message => "Generelle Daten '$OVJ::genfilename' wurden ge�ndert\n".
			            "und noch nicht gespeichert.\n\n".
						"Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 1 }
		elsif ($response eq 'Yes')    { return ! save_file_general() }
	}
	
	return 0;
}


#Exit Box aus dem 'Datei' Menu und 'Exit' Button
sub Leave {
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	return if (CheckForUnsavedPatterns());	# Abbruch durch Benutzer
	return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
	$mw->destroy();
}

#Kopieren des markierten Patterns in die Patternzeile des OV Wettbewerbs
sub do_copy_pattern {
	my $pattern = get_selected($gui_patterns)
	 or return;
	$pattern =~ s/\/\/.*$//;	# Entferne Kommentare beim Kopieren
	$pattern =~ s/\s+$//;		# Entferne immer Leerzeichen nach dem Muster
	my %ovfj_tmp = get_ovfj();
	$gui_ovfj{Auswertungsmuster}->delete(0, "end");
	$gui_ovfj{Auswertungsmuster}->insert(0, $pattern);
}

# Meldung anzeigen.
# Parameter: Typ, Meldung
# R�ckgabe: FALSE bei Fehlermeldung, WAHR sonst
sub meldung {
	my ($type, $message) = @_;

	OVJ::meldung($type, $message);

	my $err_icon;
	if    ($type eq OVJ::FEHLER)  { $err_icon = 'error' }
	elsif ($type eq OVJ::WARNUNG) { $err_icon = 'warning' }

	if ($err_icon) {
		$meldung->insert('end', "$type: $message");
		$mw->messageBox(
			-icon    => $err_icon, 
			-title   => $type, 
			-message => $message,
			-type    => 'Ok' );
	}
	else {
		# Einfache Meldung
		$meldung->insert('end', "$message");
	}

	return if ($type eq OVJ::FEHLER);
	return 1;
}

# Bestimmt einzelne ausgew�hlte Zeile aus Tk::Text
# R�ckgabe: FALSE bei Fehler, ausgew�hlte Zeile sonst
sub get_selected {
	my $listbox = shift;

	my $selected = $listbox->getSelected();
	chomp $selected;
	$selected !~ /\n/
	 or return meldung(OVJ::FEHLER, 'Nur eine Zeile markieren!');
	grep {$_ eq $selected} split(/\n/, $listbox->Contents())
	 or return meldung(OVJ::FEHLER, 'Ganze Zeile markieren!');
	return $selected;
}

#L�schen aller Auswertungen im Speicher
sub do_reset_eval {
#	undef %auswerthash;
	clear_ovfj();
	$ovfj_eval_button->configure(-state => 'normal');
	$exp_eval_button->configure(-state => 'disabled');
	$OVJ::lfdauswert = 0; # FIXME
	$meldung->delete(0,"end");
}

#Auswahl einer Veranstaltung durch den Anwender
sub do_edit_ovfj {
	my ($choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb. Wird durchgereicht.
	my $ovfjname = get_selected_ovfj()
	 or return;
	CreateEdit_ovfj($ovfjname, $choice);
}

#Anlegen bzw. Editieren einer OVFJ Veranstaltung
sub CreateEdit_ovfj { # Rueckgabewert: 0 = Erfolg, 1 = Misserfolg
	my ($ovfjf_name,$choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb, 
												# 2 = explizites Laden aus Auswertungsschleife heraus
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	$ovfjnamelabel->configure(-text => "OV Wettbewerb: ".$ovfjf_name);
	my $ovfjfilename = $ovfjf_name;
#	$::ovfjrepfilename = $ovfjf_name."_report_ovj.txt";
#	if (-e $configpath.$sep.$OVJ::genfilename.$sep.$ovfjfilename) {
		if (my %ovfj = OVJ::read_ovfjfile($ovfjfilename)) {
			set_ovfj(%ovfj);
		}
		elsif ($choice == 0) {
			clear_ovfj();
		}
		else {
			# FIXME: Meldung aus OVJ.pm umleiten
			meldung(OVJ::FEHLER, "Kann '$ovfjfilename' nicht lesen: $!");
			return 1;
		}
	$ovfj_fileset_button->configure(-state => 'normal');
	$ovfj_save_button->configure(-state => 'normal');
#	$copy_pattern_button->configure(-state => 'normal');
	$select_pattern_button->configure(-state => 'normal');
	$ovfj_eval_button->configure(-state => 'normal');
	$exp_eval_button->configure(-state => 'normal');
#		exists($auswerthash{$ovfjf_name}) ? 'disabled' : 'normal' );
}


#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	my $fjdir = $OVJ::inputpath.$OVJ::sep.$OVJ::genfilename;
	(-e $fjdir && -d $fjdir)
	 or return meldung(OVJ::FEHLER, "Verzeichnis '$fjdir' nicht vorhanden");
	
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $mw->getOpenFile(
		-initialdir => $fjdir,
		-filetypes  => $types,
		-title      => "FJ Datei ausw�hlen");
	return unless ($selfile && $selfile ne "");

	$selfile =~ s/^.*\///;
	my %ovfj = OVJ::import_fjfile($selfile)
	 or return;
	set_ovfj(%ovfj);
}

sub open_file_general {
	return if CheckForSaveGenfile();		# Abbruch durch Benutzer

	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $filename = $mw->getOpenFile(
		-initialdir => $OVJ::configpath,
		-filetypes  => $types,
		-title      => "Generelle Daten laden");
	return unless $filename;
	$filename =~ s/^.*\///;		# Pfadangaben entfernen
	$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
	meldung(OVJ::HINWEIS,"Lade '$filename'");
	set_general(OVJ::read_genfile($filename))
	 or return;
	$OVJ::genfilename = $filename;
	set_general_data_label($OVJ::genfilename);
# FIXME:	$config{"LastGenFile"} = $OVJ::genfilename;
	return 1;
}

sub import_file_general {
	return if CheckForSaveGenfile();		# Abbruch durch Benutzer

	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $filename = $mw->getOpenFile(
		-initialdir => $OVJ::configpath,
		-filetypes  => $types,
		-title      => "Generelle Daten importieren");
	return unless $filename;
	$filename =~ s/^.*\///;		# Pfadangaben entfernen
	$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
	meldung(OVJ::HINWEIS,"Importiere '$filename'");
	my %general = OVJ::read_genfile($filename)
	 or return;
	my %general_alt = OVJ::GUI::get_general();
	@{$general{ovfj_link}} = @{$general_alt{ovfj_link}};
	$general{PMVorjahr} = $general_alt{PMVorjahr};
	$general{PMaktJahr} = $general_alt{PMaktJahr};
	set_general(%general);
	$OVJ::genfilename = "";
	set_general_data_label($OVJ::genfilename);
# FIXME:	$config{"LastGenFile"} = $OVJ::genfilename;
	return 1;
}

sub save_file_general {
	return save_as_file_general($OVJ::genfilename);
}

sub save_as_file_general {
	my $filename = shift;
	if (! $filename) {
		my $types = [['Text Files','.txt'],['All Files','*',]];
		$filename = $mw->getSaveFile(
			-initialdir => $OVJ::configpath,
			-filetypes  => $types,
			-title      => "Generelle Daten speichern");
		return unless $filename;
		$filename =~ s/^.*\///;		# Pfadangaben entfernen
		$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
		set_general_data_label($filename);
	}
	meldung(OVJ::HINWEIS, "Speichere '$filename'");
	$OVJ::genfilename = $filename;
	OVJ::write_genfile($OVJ::genfilename, get_general());
}

# Auswertung und Export von OVFJ
# Parameter: Liste der OVFJ
sub do_eval_ovfj {
	my $i = 0;
	my $success = 0;
	my $retval;
	
	do_reset_eval();
	my %general = get_general();
	my %tn;					# Hash f�r die Teilnehmer, Elemente sind wiederum Hashes
	my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
	                  	# Elemente sind die %ovfj Daten
	my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info �ber die Anzahl 
	                     # der Teilnehmer, wird parallel zur @ovfjlist Liste gef�hrt
	foreach my $str (@_)
	{
		my $ovfjname = $str;
		my $ovfjrepfilename = $str . "_report_ovj.txt";
		next if ($ovfjname !~ /\S+/);
#		next if (OVJ::GUI::CreateEdit_ovfj($ovfjname,2)==1);
		my %ovfj = OVJ::read_ovfjfile($ovfjname)
		 or next;
		set_ovfj(%ovfj);
		$retval = OVJ::eval_ovfj($i++,
		  \%general,
		  \%tn,
		  \@ovfjlist,
		  \@ovfjanztlnlist,
		  \%ovfj,
		  $ovfjname,
		  $ovfjrepfilename
		);
		$success = 1 if ($retval == 0);	# Stelle fest, ob wenigstens eine Auswertung erfolgreich war
		last if ($retval == 2);	# systematischer Fehler, Abbruch der Schleife
	}
	OVJ::export(\%general,\%tn,\@ovfjlist,\@ovfjanztlnlist) if ($success);
}


1;
