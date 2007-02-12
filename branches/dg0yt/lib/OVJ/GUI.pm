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
use OVJ;

my $mw;
my %gui_general;
my $gui_general_label;
my %gui_ovfj;
my $gui_patterns;
my $meldung;
my $check_ExcludeTln;

my $orig_patterns;
my %orig_ovfj;
my %orig_general;

# my %auswerthash;		# Hash zur Kontrolle, welche OVFJ schon ausgewertet sind

use vars qw(
	$fjlistbox 
	$reset_eval_button
	$exp_eval_button
	$ovfj_eval_button
	$ovfj_fileset_button
	$ovfj_save_button
	$copy_pattern_button
	$ovfjnamelabel
);

sub run {
	MainLoop();
}

sub init {
	my %config = @_;
	
	$mw = MainWindow->new;
	$mw->OnDestroy(sub { Leave(); warn "Fixxxme" });
	make_menu($mw);
	make_general($mw);
	make_ovfj_list($mw);
	make_muster($mw);
	make_ovfj_detail($mw);
	make_meldungen($mw);
	return $mw;
}


# Menü
sub make_menu {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	my $menu_bar = $parent->Frame(-relief => 'raised', -borderwidth => 2)->pack(-side => 'top', -anchor => "nw", -fill => "x");
	$menu_bar->Menubutton(-text => 'Datei', -menuitems => [
				[ Button => "Exit",-command => \&Leave]])
								->pack(-side => 'left');
	$menu_bar->Menubutton(-text => 'Hilfe', , -menuitems => [
				[ Button => "Über",-command => \&About]])
								->pack(-side => 'left');
	$menu_bar->Button(
	        -text    => 'Exit',
	        -command => \&Leave)->pack(-side => 'right');
	$menu_bar->Label(-text => "OVJ $OVJ::ovjvers by DL3SDO, $OVJ::ovjdate")->pack();
}
    
# Allgemeine Daten
sub make_general {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr1 = $parent->Frame(-borderwidth => 5, -relief => 'raised');
	$fr1->pack;
	$gui_general_label = $fr1->Label(-text => 'Generelle Daten:')->pack;
	
	my $fr11 = $fr1->Frame->pack(-side => 'left');
	my $fr111 = $fr11->Frame->pack;
	$fr111->Button(
	        -text => 'Importieren',
	        -command => sub{import_file_general()}
	    )->pack(-side => 'right',-padx => 1);
	$fr111->Button(
	        -text => 'Speichern als',
	        -command => sub{save_file_general()}
	    )->pack(-side => 'right',-padx => 1);
	$fr111->Button(
	        -text => 'Speichern',
	        -command => sub{save_file_general($OVJ::genfilename)}
	    )->pack(-side => 'right',-padx => 1);
	$fr111->Button(
	        -text => 'Laden',
	        -command => sub{open_file_general(1)}
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

# Liste der OV-Wettbewerbe
sub make_ovfj_list {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr2 = $parent->Frame(-borderwidth => 5, -relief => 'raised');
	$fr2->pack;
	$fr2->Label(-text => 'Liste der OV Wettbewerbe')->pack;
	my $fr21 = $fr2->Frame->pack();
	$fjlistbox = $fr21->Scrolled('Text',-scrollbars =>'oe',width => 40, height => 4)->pack(-side => 'left');
	my $fr21b = $fr21->Frame->pack(-side => 'right');
	$fr21b->Button(
	        -text => 'Editieren/Erzeugen',
	        -command => sub{do_edit_ovfj(0)}
	    )->pack();
	$fr21b->Button(
	        -text => 'Erzeugen aus aktuellem OV Wettbewerb',
	        -command => sub{do_edit_ovfj(1)}
	    )->pack();
	my $fr22 = $fr2->Frame->pack();
	$fr22->Button(
	        -text => 'Alle OV Wettbewerbe auswerten und exportieren',
	        -command => sub{ 
				my %general = get_general();
				do_eval_ovfj(@{$general{ovfj_link}})}
	    )->pack(-side => 'left');
	$reset_eval_button = $fr22->Button(
	        -text => 'Auswertung im Speicher löschen',
	        -command => sub{do_reset_eval()},
	        -state => 'disabled'
	    )->pack(-side => 'left');
	my $fr23 = $fr2->Frame->pack();
	$exp_eval_button = $fr23->Button(
	        -text => 'Auswertung exportieren',
	        -command => sub{::Export()},
	        -state => 'disabled'
	    )->pack(-side => 'left');
	
	$fr23->Label(-text => 'Beim Export Teilnehmer ohne offizielle Veranstaltung im akt. Jahr ausschliessen')->pack(-side => 'left');
	$check_ExcludeTln = $fr23->Checkbutton()->pack(-side => 'left');
}

# Liste der Auswertungsmuster
sub make_muster {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr4 = $parent->Frame(-borderwidth => 5, -relief => 'raised');
	$fr4->pack;
	$fr4->Label(-text => 'Liste der Auswertungsmuster')->pack;
	my $fr41 = $fr4->Frame->pack(-side => 'left');
	$gui_patterns = $fr41->Scrolled('Text',-scrollbars =>'oe',-width => 91, -height => 4)->pack();
	my $fr42 = $fr4->Frame->pack(-side => 'right');
	$fr42->Button(
	        -text => 'Speichern',
	        -command => sub{OVJ::save_patterns(get_patterns())}
	    )->pack();
	$copy_pattern_button = $fr42->Button(
	        -text => 'Kopiere',
	        -command => sub{do_copy_pattern()},
	        -state => 'disabled'
	    )->pack();
}

# Wettbewerbsdaten
sub make_ovfj_detail {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr3 = $parent->Frame(-borderwidth => 5, -relief => 'raised');
	$fr3->pack;
	$ovfjnamelabel = $fr3->Label(-text => 'OV Wettbewerb:')->pack();
	my $fr30 = $fr3->Frame->pack(-side => 'top');
	$ovfj_save_button = $fr30->Button(
	        -text => 'Speichern',
	        -command => sub {
				my %ovfj = get_ovfj();
				OVJ::write_ovfjfile(get_selected_ovfj(), \%ovfj ) 
			},
	        -state => 'disabled'
	        )
			->pack(-side => 'left',-padx => 2);
	$ovfj_eval_button = $fr30->Button(
	        -text => 'Auswertung',
	        -command => sub{do_eval_ovfj(get_selected_ovfj())},
	        -state => 'disabled'
	        )
			->pack(-side => 'left',-padx => 2);
	
	
	my $fr3b = $fr3->Frame->pack();
	
	my $fr31 = $fr3b->Frame->pack(-side => 'left');
	my $fr311 = $fr31->Frame->pack;
	$fr311->Label(-text => 'Ausricht. OV')->pack(-side => 'left');
	$gui_ovfj{AusrichtOV} = $fr311->Entry()->pack(-side => 'left');
	$gui_ovfj{AusrichtDOK} = $fr311->Entry(-width => 4)->pack(-side => 'right');
	$fr311->Label(-text => 'DOK')->pack(-side => 'left');
	my $fr313 = $fr31->Frame->pack;
	$fr313->Label(-text => 'Datum')->pack(-side => 'left');
	$gui_ovfj{Datum} = $fr313->Entry(-width => 10)->pack(-side => 'left');
	$fr313->Label(-text => 'Band')->pack(-side => 'left');
	$gui_ovfj{Band} = $fr313->Entry(-width => 2)->pack(-side => 'left');
	$fr313->Label(-text => 'Anz. Teilnehmer manuell')->pack(-side => 'left');
	$gui_ovfj{TlnManuell} = $fr313->Entry(-width => 2)->pack(-side => 'left');
	my $fr315 = $fr31->Frame->pack;
	$ovfj_fileset_button = $fr315->Button(
	        -text => 'OVFJ Auswertungsdatei',
	        -state => 'disabled',
	        -command => sub{ do_select_fjfile() }
	    )->pack(-side => 'left');
	$gui_ovfj{OVFJDatei} = $fr315->Entry(-width => 27)->pack(-side => 'right');
	
	my $fr32 = $fr3b->Frame->pack(-side => 'left');
	my $fr321 = $fr32->Frame->pack;
	$gui_ovfj{Verantw_Name} = $fr321->Entry()->pack(-side => 'right');
	$fr321->Label(-text => 'Name')->pack(-side => 'left');
	my $fr325 = $fr32->Frame->pack;
	$gui_ovfj{Verantw_Vorname} = $fr325->Entry()->pack(-side => 'right');
	$fr325->Label(-text => 'Vorname')->pack(-side => 'left');
	my $fr322 = $fr32->Frame->pack;
	$fr322->Label(-text => 'CALL')->pack(-side => 'left');
	$gui_ovfj{Verantw_CALL} = $fr322->Entry(-width => 8)->pack(-side => 'left');
	$fr322->Label(-text => 'DOK')->pack(-side => 'left');
	$gui_ovfj{Verantw_DOK} = $fr322->Entry(-width => 4)->pack(-side => 'left');
	$gui_ovfj{Verantw_GebJahr} = $fr322->Entry(-width => 4)->pack(-side => 'right');
	$fr322->Label(-text => 'Geburtsjahr')->pack(-side => 'left');
	
	my $fr33 = $fr3->Frame->pack();
	#$fr33->Button(
	#        -text => 'Teste Muster',
	#        -state => 'disabled',
	#        -command => sub{do_test_pattern()}
	#    )->pack(-side => 'left');
	$fr33->Label(-text => 'Muster')->pack(-side => 'left');
	$gui_ovfj{Auswertungsmuster} = $fr33->Entry(-width => 70)->pack(-side => 'right');
}

# Statusmeldungen
sub make_meldungen {
	my $parent = shift
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr5 = $parent->Frame(-borderwidth => 5, -relief => 'raised');
	$fr5->pack;
	$fr5->Label(-text => 'Meldungen')->pack;
	$meldung = $fr5->Scrolled('Listbox',-scrollbars =>'e',-width => 116, -height => 12)->pack();
}

sub set_general {
	return unless @_;
	%orig_general = @_;
	$check_ExcludeTln->{Value} = $orig_general{Exclude_Checkmark}; 
	$fjlistbox->selectAll();
	$fjlistbox->deleteSelected();
	$fjlistbox->insert('end', join("\n", @{$orig_general{ovfj_link}}));
#	map { $fjlistbox->insert('end', "$_\n") } @{$general{ovfj_link}};
	map {
		$gui_general{$_}->delete(0, "end");
		$gui_general{$_}->insert(0, $orig_general{$_});
	} keys %gui_general;
	do_reset_eval();
	$ovfj_eval_button->configure(-state => 'disabled');
	$ovfj_fileset_button->configure(-state => 'disabled');
	$ovfj_save_button->configure(-state => 'disabled');
	$copy_pattern_button->configure(-state => 'disabled');
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

# Test auf Änderungen
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

# Test auf Änderungen
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
	my $selfile = $mw->getOpenFile(-initialdir => '.', -filetypes => $types, -title => "Spitznamen Datei auswählen");
	return if (!defined($selfile) || $selfile eq "");
	$selfile =~ s/^.*\///;
	$gui_general{Spitznamen}->delete(0,"end");
	$gui_general{Spitznamen}->insert(0,$selfile);
}

#Auswahl der PMVorjahr (0) oder aktuellen (else) PM Datei per Button
sub do_select_pmfile {
	my ($choice) = @_;
	my $types = [['Text Files','.txt'],['All Files','*',]];
	my $selfile = $mw->getOpenFile(-initialdir => '.', -filetypes => $types, -title => ($choice == 0 ? "PM Vorjahr Datei auswählen" : "aktuelle PM Datei auswählen"));
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

#Über Box aus dem 'Hilfe' Menu
sub About {
	$mw->messageBox(-icon => 'info', 
						-message => "OV Jahresauswertung\n\n".
						"by Matthias Kühlewein, DL3SDO\n".
						"Version: $OVJ::ovjvers - Datum: $OVJ::ovjdate",
						-title => 'Über', -type => 'Ok');
}


sub get_patterns {
	return $gui_patterns->Contents();
}

sub set_patterns {
	$orig_patterns = shift;
	$gui_patterns->Contents($orig_patterns);
}

sub patterns_modified {
	return $orig_patterns ne $gui_patterns->Contents();
}


#Ueberpruefen beim Beenden des Programms, ob aktuelle Auswertungsmuster
#gespeichert wurden, und falls nicht, was passieren soll
sub CheckForUnsavedPatterns {
	if (patterns_modified()) {
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => 'Auswertungsmuster speichern?', 
			-message => "Liste der Auswertungsmuster wurden geändert\n".
			            "und noch nicht gespeichert.\n\n".
						"Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 1 }
		elsif ($response eq 'Yes')    { return OVJ::save_patterns(get_patterns()) }
	}
	
	return 0;
}


#Prüfen, ob OVFJ Veranstaltung verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForOverwriteOVFJ {
	if (ovfj_modified()) {
		my $ovfjname = get_selected_ovfj();
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => 'OVFJ Daten speichern?', 
			-message => "Kopfdaten zum OV Wettbewerb '$ovfjname' wurden geändert\n".
			            "und noch nicht gespeichert.\n\n".
			            "Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 1 }
		elsif ($response eq 'Yes')    { return OVJ::write_ovfjfile($ovfjname) }
	}
	
	return 0;
}


#Prüfen, ob Generelle Daten verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForSaveGenfile {
	if (general_modified()) {
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => "Generelle Daten '$OVJ::genfilename' speichern?", 
			-message => "Generelle Daten '$OVJ::genfilename' wurden geändert\n".
			            "und noch nicht gespeichert.\n\n".
						"Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 1 }
		elsif ($response eq 'Yes')    { return ! open_file_general(0) }
	}
	
	return 0;
}


#Exit Box aus dem 'Datei' Menu und 'Exit' Button
sub Leave {
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	return if (CheckForUnsavedPatterns());	# Abbruch durch Benutzer
	return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
	::Leave();
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
# Rückgabe: FALSE bei Fehlermeldung, WAHR sonst
sub meldung {
	my ($type, $message) = @_;

	OVJ::meldung($type, $message);
	$meldung->insert('end', "$type: $message");

	my $err_icon;
	if    ($type eq OVJ::FEHLER)  { $err_icon = 'error' }
	elsif ($type eq OVJ::WARNUNG) { $err_icon = 'warning' }

	if ($err_icon) {
		$mw->messageBox(
			-icon    => $err_icon, 
			-title   => $type, 
			-message => $message,
			-type    => 'Ok' );
	}
	return ($type eq OVJ::FEHLER) ? 0 : 1 ; # 0: Fehler, 1: okay 
}

# Bestimmt einzelne ausgewählte Zeile aus Tk::Text
# Rückgabe: FALSE bei Fehler, ausgewählte Zeile sonst
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

#Löschen aller Auswertungen im Speicher
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
	$copy_pattern_button->configure(-state => 'normal');
	$ovfj_eval_button->configure(-state => 'normal');
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
		-title      => "FJ Datei auswählen");
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
	OVJ::GUI::set_general(%general);
	$OVJ::genfilename = "";
	set_general_data_label($OVJ::genfilename);
# FIXME:	$config{"LastGenFile"} = $OVJ::genfilename;
	return 1;
}

sub save_file_general {
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
	my %tn;					# Hash für die Teilnehmer, Elemente sind wiederum Hashes
	my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
	                  	# Elemente sind die %ovfj Daten
	my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info über die Anzahl 
	                     # der Teilnehmer, wird parallel zur @ovfjlist Liste geführt
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
#		  $inputpath,
#		  $reportpath,
#		  $OVJ::genfilename,
		  $ovfjrepfilename
		);
		$success = 1 if ($retval == 0);	# Stelle fest, ob wenigstens eine Auswertung erfolgreich war
		last if ($retval == 2);	# systematischer Fehler, Abbruch der Schleife
	}
	OVJ::export(\%general,\%tn,\@ovfjlist,\@ovfjanztlnlist) if ($success);
}

	

1;
