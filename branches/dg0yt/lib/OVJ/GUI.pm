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
use Tk::DialogBox;
use Tk::FBox;

use OVJ 0.97;
use OVJ::Browser 0.1;

use vars qw(
	$REVISION
	$REVDATE
	$VERSION
);

BEGIN {
	$VERSION = $OVJ::VERSION;
	'$Id$' =~ 
	 /Id: [^ ]+ (\d+) (\d{4})-(\d{2})-(\d{2}) /
	 or die "Revision format has changed";
	$REVISION = $1;
	$REVDATE = "$4.$3.$2";
}

use constant UNNAMED => 'Unbenannt';

my $help_dir = "doku";

my $mw;
my $gui_general_label;
my %gui_general;
my $gui_ExcludeTln;
my $gui_fjlist;
my $gui_meldung;

my $edit_ovfj_button;
my $eval_ovfj_button;
my $eval_all_button;

my %gui_ovfj;
my $gui_ovfj_view;

my $gui_patterns;

my $curr_patterns;
my $orig_patterns;
my %orig_ovfj;
my $orig_ovfj_link;
my %orig_general;

=head2 sub run

Kontrollfluss an GUI übergeben.

=cut
sub run {
	# Warnungen abfangen
	$SIG{'__WARN__'} = sub {
		my $error = shift;
		chomp $error;
		meldung(OVJ::WARNUNG, $error);
	};
	# OVJ-Meldungen abfangen
	OVJ::meldung_callback_add(\&meldung);
	
	MainLoop();
	
	# GUI beendet, Meldungen und Warnungen nicht mehr abfangen
	OVJ::meldung_callback_remove(\&meldung);
	delete $SIG{'__WARN__'};
}

=head2 sub init(parameter => wert, ...)

GUI initialisieren.

Parameter:	Parameterliste (derzeit unbenutzt)

Rückgabe: ein Tk::MainWindow

=cut
sub init {
	my %config = @_;
	
	$mw = MainWindow->new;
	$mw->protocol(WM_DELETE_WINDOW => \&Leave); 
	$mw->gridColumnconfigure(0, -weight => 1);
	$mw->gridRowconfigure(2, -weight => 1);

	$mw->configure(-menu => make_menu($mw));
	make_general($mw)->grid(-sticky => 'nswe');
	make_ovfj_list($mw)->grid(-sticky => 'nswe');
	make_meldungen($mw)->grid(-sticky => 'nswe');

	set_patterns(OVJ::read_patterns());
	reset_general();

	return $mw;
}


# Menü aufbauen
sub make_menu {
	my $parent = shift
	  or croak "Parameter für übergeordnetes Fenster fehlt";
	
	my $menu_bar = $parent->Menu( -type=>'menubar' );
	$menu_bar->add('cascade', -label => 'Datei', -underline => 0, -menu => 
		$menu_bar->Menu( -tearoff => 0, -menuitems => [
			[ Button => "Neu", -underline => 0, -command => \&reset_general],
			[ Button => "Öffnen...", -underline => 1, -command => \&open_file_general],
			[ Button => "Importieren...", -underline => 0, -command => \&import_file_general],
			[ Button => "Speichern", -underline => 0, -command => \&save_file_general],
			# "Speichern unter" müsste Input-/Config-Verzeichnisse kopieren
			# [ Button => "Speichern unter...", -underline => 0, -command => \&save_as_file_general],
			[ Separator => "--" ],
			[ Button => "Beenden", -underline => 0, -command => \&Leave] 
		] )
	);
	$menu_bar->add('cascade', -label => 'Hilfe', -underline => 0, -menu => 
		$menu_bar->Menu( -tearoff => 0, -menuitems => [
			[ Button => "Hilfethemen", -underline => 0,-command => \&show_help],
			[ Separator => "--" ],
			[ Button => "Über OVJ", -underline => 1,-command => \&About] 
		] )
	);
	return $menu_bar;
}
    
# Allgemeine Daten
sub make_general {
	my $parent = shift
	  or croak "Parameter für übergeordnetes Fenster fehlt";

	my $fr00 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
	my $fr0 = $fr00->Frame()->pack(-fill => 'both', -padx => 5, -pady => 5);

	$fr0->gridColumnconfigure([1,4,7], -weight => 1);
	$fr0->gridColumnconfigure([2,5,8], -minsize => 15);
	my $all_columns = 11;

	$gui_general_label = $fr0->Label(-text => 'OV-Jahresauswertung', -anchor => 'w')->grid(
	'-','-','-','-','-','-','-','-',
	$fr0->Button(
	        -text => 'Hilfe',
	        -command => sub { show_help('schritt1.htm') }),
	'-',
	-sticky => 'we', -pady => 3);
	
	$fr0->Label(-text => 'Distrikt', -anchor => 'w')->grid(
	$gui_general{Distrikt} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'Distriktskenner', -anchor => 'w'),
	$gui_general{Distriktskenner} = $fr0->Entry(-width => 1),
	'x',
	$fr0->Label(-text => 'Jahr', -anchor => 'w'),
	$gui_general{Jahr} = $fr0->Entry(-width => 4),
	-sticky => 'we');
		
	$fr0->Label(-text => 'Name', -anchor => 'w')->grid(
	$gui_general{Name} = $fr0->Entry(-width => 16),
	'x',
	$fr0->Label(-text => 'Vorname', -anchor => 'w'),
	$gui_general{Vorname} = $fr0->Entry(-width => 16),
	'x',
	$fr0->Label(-text => 'Call', -anchor => 'w'),
	$gui_general{Call} = $fr0->Entry(-width => 8),
	'x',
	$fr0->Label(-text => 'DOK', -anchor => 'w'),
	$gui_general{DOK} = $fr0->Entry(-width => 4),
	-sticky => 'we');

	$fr0->Label(-text => 'Telefon', -anchor => 'w')->grid(
	$gui_general{Telefon} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'Home-BBS', -anchor => 'w'),
	$gui_general{"Home-BBS"} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'E-Mail', -anchor => 'w'),
	$gui_general{"E-Mail"} = $fr0->Entry(),
	-sticky => 'we');

	$fr0->Button(-text => 'PM Vorjahr', -command => sub{do_select_pmfile(0)} )->grid(
	$gui_general{PMVorjahr} = $fr0->Entry(-width => 15),
	'x',
	$fr0->Button(-text => 'PM akt. Jahr', -command => sub{do_select_pmfile(1)} ),
	$gui_general{PMaktJahr} = $fr0->Entry(-width => 15),
	'x',
	$fr0->Button(-text => 'Spitznamen', -command => sub{do_get_nickfile()} ),
	$gui_general{Spitznamen} = $fr0->Entry(-width => 15),
	-sticky => 'we');

	$gui_ExcludeTln = $fr0->Checkbutton(
		-text => "Beim Export Teilnehmer ohne offizielle Veranstaltung im akt. Jahr ausschliessen")
	  ->grid('-','-','-','-','-','-','-','-','-','-',-sticky => 'w');
	
	return $fr00;
}

# Liste der OV-Wettbewerbe
sub make_ovfj_list {
	my $parent = shift
	  or croak "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr00 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
	my $fr0 = $fr00->Frame()->pack(-fill => 'both', -padx => 5, -pady => 5);

	$fr0->gridColumnconfigure(1, -weight => 2);
	$fr0->gridColumnconfigure(2, -minsize => 15);
	$fr0->gridColumnconfigure(3, -weight => 1);
	$fr0->gridRowconfigure(3, -weight => 1, -minsize => 5);

	$fr0->Label(-text => 'Liste der OV-Wettbewerbe')
	  ->grid(-sticky => 'nw', -columnspan => 3);
	
	$gui_fjlist = $fr0->Scrolled('Text',
		-scrollbars =>'oe',width => 30, height => 7)
	  ->grid(-row => 1, -column => 1, -sticky => 'wens', -rowspan => 4);
	
	my ($col, $row) = (3, 1);
	$edit_ovfj_button = $fr0->Button(
	        -text => 'OV-Wettbewerb bearbeiten',
	        -command => \&do_edit_ovfj,
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$eval_ovfj_button = $fr0->Button(
	        -text => 'OV-Wettbewerb auswerten',
	        -command => sub {
				my $ovfjname = get_selected_ovfj()
				 or return;
				do_eval_ovfj($ovfjname);
			},
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$row++;
	$eval_all_button = $fr0->Button(
	        -text => 'Jahresauswertung erstellen',
	        -command => sub{ 
				my %general = get_general();
				do_eval_ovfj( @{$general{ovfj_link}} )
			},
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	
	return $fr00;
}


# Wettbewerbsdaten
sub make_ovfj_detail {
	my $parent = shift
	  or croak "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr0 = $parent->Frame();
	$fr0->gridColumnconfigure([1,4,7], -weight => 1);
	$fr0->gridColumnconfigure([2,5,8], -minsize => 15);
	$fr0->gridRowconfigure([5], -weight => 1);

	$fr0->Button(
	        -text => 'Ergebnisliste',
	        -state => 'normal',
	        -command => sub{ do_select_fjfile($parent) } ) ->grid(
	$gui_ovfj{OVFJDatei} = $fr0->Entry(-width => 20),
	'x',
	$fr0->Label(-text => 'Ausricht. OV', -anchor => 'w'),
	$gui_ovfj{AusrichtOV} = $fr0->Entry(-width => 3),
	'x',
	$fr0->Label(-text => 'DOK', -anchor => 'w'),
	$gui_ovfj{AusrichtDOK} = $fr0->Entry(-width => 4),
	-sticky => 'we');

	$fr0->Label(-text => 'Datum', -anchor => 'w') ->grid(
	$gui_ovfj{Datum} = $fr0->Entry(-width => 10),
	'x',
	$fr0->Label(-text => 'Band', -anchor => 'w'),
	$gui_ovfj{Band} = $fr0->Entry(-width => 2),
	'x',
	$fr0->Label(-text => 'Anz. Teilnehmer manuell', -anchor => 'w'),
	'-','-','-',
	$gui_ovfj{TlnManuell} = $fr0->Entry(-width => 2),
	-sticky => 'we');

	$fr0->Label(-text => 'Name', -anchor => 'w') ->grid(
	$gui_ovfj{Verantw_Name} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'Vorname', -anchor => 'w'),
	$gui_ovfj{Verantw_Vorname} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'Call', -anchor => 'w'),
	$gui_ovfj{Verantw_CALL} = $fr0->Entry(-width => 8),
	'x',
	$fr0->Label(-text => 'DOK', -anchor => 'w'),
	$gui_ovfj{Verantw_DOK} = $fr0->Entry(-width => 4),
	-sticky => 'we');
	
	$fr0->Label(-text => 'Geburtsjahr', -anchor => 'w') ->grid(
	$gui_ovfj{Verantw_GebJahr} = $fr0->Entry(-width => 4),
	-sticky => 'we');

	$fr0->Button(
		-text    => 'Muster', 
		-state   => 'normal',
		-command => sub { do_pattern_dialog($parent) } ) ->grid(
	$gui_ovfj{Auswertungsmuster} = $fr0->Entry(-width => 70),
	'-','-','-','-','-','-','-','-','-',
	-sticky => 'we');

	$fr0->Label(-text => "Datei-Inhalt", -anchor => 'nw') ->grid(
	$gui_ovfj_view = $fr0->Scrolled('Text',-scrollbars =>'e',-width => 70, -height => 10, -state => 'disabled'),
	'-','-','-','-','-','-','-','-','-',
	-sticky => "nswe");

	return $fr0;
}

# Statusmeldungen
sub make_meldungen {
	my $parent = shift
	  or croak "Parameter für übergeordnetes Fenster fehlt";
	
	my $fr5 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
	$fr5->gridColumnconfigure(0, -weight => 1);
	$fr5->gridRowconfigure(1, -weight => 1);
	$fr5->Label(-text => 'Meldungen')->grid(-stick => "w");
	$gui_meldung = $fr5->Scrolled('Listbox',-scrollbars =>'e',-width => 80, -height => 6)
	  ->grid(-stick => "nswe");
	return $fr5;
}

sub do_pattern_dialog { 
	my $parent = shift || $mw;
	my $dlg = $parent->DialogBox(
	  -title          => 'Musterkatalog',
	  -buttons        => ['Übernehmen', 'Speichern', 'Hilfe', 'Abbrechen'],
	  -default_button => 'Abbrechen',
	);
	# http://www.annocpan.org/~NI-S/Tk-804.027/pod/DialogBox.pod
	$dlg->protocol( WM_DELETE_WINDOW => sub { 
		$dlg->{selected_button} = 'Abbrechen' } );
	my $textbox = $dlg->add('Scrolled', 'Text', 
		-wrap => 'none',
		-scrollbars => 'osoe',
		-width => 80, 
		-height => 6)
	  ->pack(-fill => 'both', -expand => 1);
	$textbox->Contents($orig_patterns);
	while (1) {
		my $sel = $dlg->Show;
		$curr_patterns = $textbox->Contents;
		chomp $curr_patterns;
		if ($sel eq 'Übernehmen') {
			if ( my $pattern = get_selected($textbox) ) {
				next unless CheckForUnsavedPatterns();
				$pattern =~ s/\/\/.*$//;	# Entferne Kommentare beim Kopieren
				$pattern =~ s/\s+$//;		# Entferne immer Leerzeichen nach dem Muster
				my %ovfj_tmp = get_ovfj();
				$ovfj_tmp{Auswertungsmuster} = $pattern;
				modify_ovfj(%ovfj_tmp);
			}
		}
		elsif ($sel eq 'Speichern') {
			if ( OVJ::save_patterns($curr_patterns) ) {
				$orig_patterns = $curr_patterns;
				last;
			}
		}
		elsif ($sel eq 'Hilfe') {
			show_help('auswertungsmuster.htm');
		}
		else {
			last if CheckForUnsavedPatterns();
		}
	}
}

sub do_ovfj_dialog {
	my $ovfjname = shift
	 or carp "OV-Wettbewerb?";
	my $dlg = $mw->DialogBox(
	  -title          => "'$ovfjname' bearbeiten",
	  -buttons        => ['Speichern', 'Importieren...', 'Auswerten', 'Hilfe', 'Abbrechen'],
	  -default_button => 'Abbrechen',
	);
	# http://www.annocpan.org/~NI-S/Tk-804.027/pod/DialogBox.pod
	$dlg->protocol( WM_DELETE_WINDOW => sub { 
		$dlg->{selected_button} = 'Abbrechen' } );
	my $fr = $dlg->add('Frame', -relief => 'flat')
	  ->pack(-fill => 'both', -expand => 1);
	make_ovfj_detail($fr)
	  ->pack(-fill => 'both', -expand => 1);
	
	if (OVJ::exist_ovfjfile($ovfjname)) {
		set_ovfj($ovfjname, OVJ::read_ovfjfile($ovfjname));
	}
	else {
		meldung(OVJ::INFO, "Noch keine Daten für '$ovfjname' gespeichert");
		set_ovfj($ovfjname);
	}
	
	while (1) {
		my $sel = $dlg->Show;
		if ($sel eq 'Speichern') {
			my %ovfj = get_ovfj();
			OVJ::write_ovfjfile($ovfjname, \%ovfj );
			last;
		}
		elsif ($sel eq 'Importieren...') {
			do_import_ovfjfile($mw);
		}
		elsif ($sel eq 'Auswerten') {
			do_eval_ovfj($ovfjname) if CheckForOverwriteOVFJ();
		}
		elsif ($sel eq 'Hilfe') {
			show_help('schritt3.htm');
		}
		else {
			last if CheckForOverwriteOVFJ();
		}
	}
}

sub reset_general {
	set_general() if CheckForSaveGenfile();
}

sub set_general {
	set_genfilename(shift);
	modify_general(@_);
	%orig_general = get_general();
	$orig_ovfj_link = $gui_fjlist->Contents();
	return 1;
}

sub modify_general {
	my %new_general = @_;
	$gui_ExcludeTln->{Value} = $new_general{Exclude_Checkmark} || 0; 
	$new_general{ovfj_link} ||= [];
	$gui_fjlist->Contents( join("\n", @{$new_general{ovfj_link}}) );
	$gui_fjlist->markSet('insert','0.0'); # Workaround für Bug bei ersten Cursorbewegungen
	$gui_fjlist->see('insert');
	map {
		$gui_general{$_}->delete(0, "end");
		$gui_general{$_}->insert(0, $new_general{$_} || '');
	} keys %gui_general;
}

#Aktualisieren der aktuellen Generellen Daten im Hash
sub get_general {
	my %general;
	while (my ($key,$value) = each(%gui_general)) {
		$general{$key} = $value->get();
	}
	$general{Exclude_Checkmark} = $gui_ExcludeTln->{Value};
	@{$general{ovfj_link}} = split "\n", $gui_fjlist->Contents();
	return %general;
}

# Test auf Änderungen
sub general_modified {
	defined $orig_general{ovfj_link} or return;
	$orig_general{Exclude_Checkmark} ne $gui_ExcludeTln->{Value}
	or grep {
		$gui_general{$_}->get() ne ($orig_general{$_} || "");
	} keys %gui_general
	or $orig_ovfj_link ne $gui_fjlist->Contents();
}


sub get_selected_ovfj {
	return get_selected($gui_fjlist);
}


sub set_ovfj {
	my $ovfjname = shift; # FIXME: unbenutzt, aber evt. sinnvoll
	modify_ovfj(@_);
	%orig_ovfj = get_ovfj();
	return 1;
}

sub modify_ovfj {
	my %new_ovfj = @_;
	# GUI schon initialisiert ?
	if (defined $gui_ovfj{AusrichtDOK}) { 
		map {
			$gui_ovfj{$_}->delete(0, "end");
			$gui_ovfj{$_}->insert(0, $new_ovfj{$_} || '');
		} keys %gui_ovfj;
		$gui_ovfj_view->configure(-state => 'normal');
		$gui_ovfj_view->Contents(
			$new_ovfj{OVFJDatei} ? OVJ::read_ovfj_infile($new_ovfj{OVFJDatei}) : '' );
		$gui_ovfj_view->configure(-state => 'disabled');
	}
	return 1;
}

sub get_ovfj {
	my %ovfj;
	# GUI schon initialisiert ?
	if (defined $gui_ovfj{AusrichtDOK}) { 
		while (my ($key,$value) = each(%gui_ovfj)) {
			$ovfj{$key} = $value->get();
		}
		foreach my $key (qw(AusrichtDOK Verantw_CALL Verantw_DOK)) {
			$ovfj{$key} = uc $ovfj{$key};
		}
	}
	return %ovfj;
}

# Test auf Änderungen
sub ovfj_modified {
	# GUI schon initialisiert ?
	return unless defined $gui_ovfj{AusrichtDOK};
	grep {
		$gui_ovfj{$_}->get ne ($orig_ovfj{$_} || "");
	} keys %gui_ovfj;
}


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

sub set_genfilename {
	$OVJ::genfilename = shift || UNNAMED;
	$gui_general_label->configure(
		-text => "OV-Jahresauswertung: $OVJ::genfilename" );
	my $button_state = ($OVJ::genfilename ne UNNAMED) ? 'normal' : 'disabled';
	foreach ($edit_ovfj_button, $eval_ovfj_button, $eval_all_button) {
		$_->configure(-state => $button_state);
	}
}

#Über Box aus dem 'Hilfe' Menu
sub About {
	my $tk_version = $Tk::VERSION || $Tk::Version || $Tk::version;
	$mw->messageBox(-icon => 'info', 
						-message => <<"END_ABOUT",
OV Jahresauswertung
by Matthias Kühlewein, DL3SDO

Stark modifiziert von/
Fehlerberichte an:
Kai Pastor, DG0YT

OVJ Version $OVJ::VERSION
- Kern: Revision $OVJ::REVISION ($OVJ::REVDATE)
- GUI: Revision $REVISION ($REVDATE)
- Tk: Version $tk_version
- Plattform: $^O
END_ABOUT
						-title => 'Über', -type => 'Ok');
}


# Hilfe im Browser öffnen
# Verzeichnis durch globale Variable vorgegeben
# Parameter: Hilfe-Datei (optional, Default: index.htm)
sub show_help {
	my $location = $help_dir . '/' . (shift || 'index.htm');
	OVJ::Browser::open($location);
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
			-message => "Liste der Auswertungsmuster wurden geändert\n".
			            "und noch nicht gespeichert.\n\n".
						"Speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Yes')    { 
			my $ret = OVJ::save_patterns(get_patterns()) and 
				set_patterns(get_patterns());
			return $ret;
		}
	}
	
	return 1;
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
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Yes')    { 
			my %ovfj = get_ovfj();
			return OVJ::write_ovfjfile($ovfjname, \%ovfj) 
		}
	}
	
	return 1;
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
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Yes')    { return save_file_general() }
	}
	
	return 1;
}


#Prüfen, ob Generelle Daten verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForGenfilename {
	if ($OVJ::genfilename eq UNNAMED) {
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => "Generelle Daten speichern?", 
			-message => "Die generellen Daten wurden noch nicht gespeichert.\n\n".
						"Speichern?", 
			-type    => 'OkCancel', 
			-default => 'Ok');
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Ok')    { return save_as_file_general() }
	}
	
	return 1;
}


#Datei/Beenden oder Fenster schließen
sub Leave {
	return unless (CheckForSaveGenfile());		# Abbruch durch Benutzer
	$mw->destroy();
}


# Meldung anzeigen.
# Parameter: Typ, Meldung
# Rückgabe: FALSE bei Fehlermeldung, WAHR sonst
sub meldung {
	my ($type, $message) = @_;

	my $err_icon;
	if    ($type eq OVJ::FEHLER)  { $err_icon = 'error' }
	elsif ($type eq OVJ::WARNUNG) { $err_icon = 'warning' }

	if ($err_icon) {
		$gui_meldung->insert('end', "$type: $message");
		$mw->messageBox(
			-icon    => $err_icon, 
			-title   => $type, 
			-message => $message,
			-type    => 'Ok' );
	}
	else {
		# Einfache Meldung
		$gui_meldung->insert('end', "$message");
	}
	$gui_meldung->see('end');
	$gui_meldung->update();

	return if ($type eq OVJ::FEHLER);
	return 1;
}

sub clear_meldung {
	$gui_meldung->delete(0,"end");
}

# Bestimmt einzelne ausgewählte Zeile aus Tk::Text
# Rückgabe: FALSE bei Fehler, ausgewählte Zeile sonst
sub get_selected {
	my $listbox = shift;

	if (! $listbox->tagRanges('sel')) {
		# Keine Auswahl -> aktuelle Zeile auswählen
		$listbox->tagAdd('sel', 'insert linestart', 'insert lineend');
	}
	if (! $listbox->tagRanges('sel')) {
		return meldung(OVJ::FEHLER, 'Nichts ausgewählt');
	}
	my $selected = $listbox->get('sel.first linestart', 'sel.last - 1 chars lineend');
	chomp $selected;
	$selected !~ /\n/
	 or return meldung(OVJ::FEHLER, 'Nur eine Zeile markieren!');
	return $selected;
}

#Auswahl einer Veranstaltung durch den Anwender
sub do_edit_ovfj {
	my $ovfjname = get_selected_ovfj()
	 or return;
	CheckForGenfilename() 
	 or return;
	do_ovfj_dialog($ovfjname);
}


#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	my $parent = $_[0] 
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	my $fjdir = $OVJ::inputpath.'/'.$OVJ::genfilename;
	(-e $fjdir && -d $fjdir)
	 or return meldung(OVJ::FEHLER, "Verzeichnis '$fjdir' nicht vorhanden");
	
	my $types = [['Text Files','.txt'],['All Files','*',]];
	# Unter KDE/Linux öffnet getOpenFile sein Fenster hinter 
	# den anderen OVJ-Fenstern ... Tk::Fbox tut das selbe, aber richtig
	# http://www.perltk.org/index.php?option=com_content&task=view&id=21&Itemid=28
	#my $selfile = $parent->getOpenFile(
	my $selfile = $parent->FBox(-type => 'open')->Show(
		-initialdir => $fjdir,
		-filetypes  => $types,
		-title      => "FJ Datei auswählen");
	return unless ($selfile && $selfile ne "");

	$selfile =~ s/^.*\///;
	my %ovfj = OVJ::import_fjfile($selfile)
	 or return;
	modify_ovfj(%ovfj);
}


sub do_import_ovfjfile {
	my $parent = $_[0] 
	  or carp "Parameter für übergeordnetes Fenster fehlt";
	my $dir = $OVJ::configpath.'/'.$OVJ::genfilename;
	(-e $dir && -d $dir)
	 or return meldung(OVJ::FEHLER, "Verzeichnis '$dir' nicht vorhanden");

	my $types = [['OVJ Files','*_ovj.txt'],['All Files','*',]];
	# Unter KDE/Linux öffnet getOpenFile sein Fenster hinter 
	# den anderen OVJ-Fenstern ... Tk::Fbox tut das selbe, aber richtig
	# http://www.perltk.org/index.php?option=com_content&task=view&id=21&Itemid=28
	#my $selfile = $parent->getOpenFile(
	my $selfile = $parent->FBox(-type => 'open')->Show(
		-initialdir => $dir,
		-filetypes  => $types,
		-title      => "OVFJ Datei auswählen");
	return unless ($selfile && $selfile ne "");

#	$selfile =~ s/^.*\///;
	my %ovfj = OVJ::read_ovfjfile($selfile)
	 or return;
	my %old_ovfj = get_ovfj();
	foreach ('Datum', 'Band', 'TlnManuell', 'OVFJDatei') {
		$ovfj{$_} = $old_ovfj{$_};
	}
	modify_ovfj(%ovfj);
}



sub open_file_general {
	CheckForSaveGenfile()
	 or return;		# Abbruch durch Benutzer

	my $filename = shift;
	if (! $filename) {
		my $types = [['Text Files','.txt'],['All Files','*',]];
		$filename = $mw->getOpenFile(
			-initialdir => $OVJ::configpath,
			-filetypes  => $types,
			-title      => "Generelle Daten laden");
		return unless $filename;
		$filename =~ s(^.*/([^/]+)/.*$)($1);	# tiefster Verzeichnisname
	}
	if ($filename ne UNNAMED) {
		clear_meldung();
		meldung(OVJ::HINWEIS,"Lade '$filename'");
		set_general($filename, OVJ::read_genfile($filename));
	}
}

sub import_file_general {
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
	$general{Jahr} = $general_alt{Jahr};
	$general{PMVorjahr} = $general_alt{PMVorjahr};
	$general{PMaktJahr} = $general_alt{PMaktJahr};
	modify_general(%general);
	return 1;
}

sub save_file_general {
	return save_as_file_general($OVJ::genfilename);
}

sub save_as_file_general {
	my $filename = shift;
	if (! $filename || $filename eq UNNAMED) {
		my $types = [['Text Files','.txt'],['All Files','*',]];
		$filename = $mw->getSaveFile(
			-initialdir => $OVJ::configpath,
			-filetypes  => $types,
			-title      => "Generelle Daten speichern");
		return unless $filename;
		$filename =~ s/^.*\///;		# Pfadangaben entfernen
		$filename =~ s/\.txt$//;	# .txt Erweiterung entfernen
	}
	set_genfilename($filename);
	meldung(OVJ::HINWEIS, "Speichere '$filename'");
	OVJ::write_genfile($filename, get_general());
}

# Auswertung und Export von OVFJ
# Parameter: Liste der OVFJ
sub do_eval_ovfj {
	CheckForGenfilename() or return;
	my $i = 1;
	my $success = 0;
	my $retval;
	
	$mw->Busy();
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
		my %ovfj = OVJ::read_ovfjfile($ovfjname)
		 or next;
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
	$mw->Unbusy();
}


1;
