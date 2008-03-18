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

package OVJ::MainWindow;

use strict;
use Carp;

use Tk;
use Tk::Text;
use Tk::BrowseEntry;
use Tk::Dialog;
use Tk::DialogBox;
use Tk::NoteBook;
require Tk::FBox if ($^O !~ /MSwin32/);

use OVJ 0.98;
use OVJ::Browser 0.1;
use OVJ::FjDialog 0.1;

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

my %district = (
	A => 'Baden',
	B => 'Franken',
	C => 'Oberbayern',
	D => 'Berlin',
	E => 'Hamburg',
	F => 'Hessen',
	G => 'K�ln-Aachen',
	H => 'Niedersachsen',
	I => 'Nordsee',
	K => 'Rheinland-Pfalz',
	L => 'Ruhrgebiet',
	M => 'Schleswig-Holstein',
	N => 'Westfalen-Nord',
	O => 'Westfalen-S�d',
	P => 'W�rttemberg',
	Q => 'Saar',
	R => 'Nordrhein',
	S => 'Sachsen',
	T => 'Schwaben',
	U => 'Bayern-Ost',
	V => 'Mecklenburg-Vorpommern',
	W => 'Sachsen-Anhalt',
	X => 'Th�ringen',
	Y => 'Brandenburg',
	Z => 'VFDB',
);

my $help_dir = "doku";

my $mw;
my $gui_projectname;
my %gui_general;
my $gui_district;
my $gui_district_id;
my $gui_ExcludeTln;
my $gui_fjlist;
my $gui_meldung;

my $edit_ovfj_button;
my $eval_ovfj_button;
my $del_ovfj_button;
my $eval_all_button;

my @curr_ovfj_link;
my @curr_ovfj_link_modified;

# Unsere neue Projektstruktur
my $project;

=head2 sub run

Kontrollfluss an GUI �bergeben.

=cut
sub run {
	MainLoop();
	
	# GUI beendet, Meldungen und Warnungen nicht mehr abfangen
	OVJ::meldung_callback_remove(\&meldung);
	delete $SIG{'__WARN__'};
}

=head2 sub init(parameter => wert, ...)

GUI initialisieren.

Parameter:	Parameterliste (derzeit unbenutzt)

R�ckgabe: ein Tk::MainWindow

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

	# Warnungen abfangen
	$SIG{'__WARN__'} = sub {
		my $error = shift;
		chomp $error;
		meldung(OVJ::WARNUNG, $error);
	};
	# OVJ-Meldungen abfangen
	OVJ::meldung_callback_add(\&meldung);
	
	reset_project();
	if ($config{LastGenFile} && $config{LastGenFile} ne UNNAMED) {
		if (-f $config{LastGenFile}) {
			open_project($config{LastGenFile});
		}
		else {
			OVJ::meldung(OVJ::HINWEIS, "Die zuletzt bearbeitete Datei '$config{LastGenFile}' wurde nicht gefunden.");
		}
	}

	return $mw;
}


# Men� aufbauen
sub make_menu {
	my $parent = shift
	  or croak "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $menu_bar = $parent->Menu( -type=>'menubar' );
	$menu_bar->add('cascade', -label => 'Datei', -underline => 0, -menu => 
		$menu_bar->Menu( -tearoff => 0, -menuitems => [
			[ Button => "Neu", -underline => 0, -command => \&reset_project],
			[ Button => "�ffnen...", -underline => 1, -command => \&open_project],
			[ Button => "Importieren...", -underline => 0, -command => \&import_project],
			[ Button => "Speichern", -underline => 0, -command => \&save_project],
			# FIXME: "Speichern unter" m�sste Input-/Config-Verzeichnisse kopieren
			[ Button => "Speichern unter...", -underline => 0, -command => \&save_project_as],
			[ Separator => "--" ],
			[ Button => "Beenden", -underline => 0, -command => \&Leave] 
		] )
	);
	$menu_bar->add('cascade', -label => 'Hilfe', -underline => 0, -menu => 
		$menu_bar->Menu( -tearoff => 0, -menuitems => [
			[ Button => "Hilfethemen", -underline => 0,-command => \&show_help],
			[ Button => "Homepage", -underline => 0,-command => \&show_homepage],
			[ Button => "Fehler melden", -underline => 0,-command => \&report_bug],
			[ Separator => "--" ],
			[ Button => "�ber OVJ", -underline => 1,-command => \&About] 
		] )
	);
	return $menu_bar;
}
    
# Allgemeine Daten
sub make_general {
	my $parent = shift
	  or croak "Parameter f�r �bergeordnetes Fenster fehlt";

	my $fr00 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
	my $fr0 = $fr00->Frame()->pack(-fill => 'both', -padx => 5, -pady => 5);

	$fr0->gridColumnconfigure([1,4,7], -weight => 1);
	$fr0->gridColumnconfigure([2,5,8], -minsize => 15);
	my $all_columns = 11;

	$gui_projectname = $fr0->Label(-text => 'OV-Jahresauswertung', -anchor => 'w')->grid(
	'-','-','-','-','-','-','-','-',
	$fr0->Button(
	        -text => 'Hilfe',
	        -command => sub { show_help('schritt1.htm') }),
	'-',
	-sticky => 'we', -pady => 3);
	
	$fr0->Label(-text => 'Distrikt', -anchor => 'w')->grid(
	$fr0->BrowseEntry(-choices  => [ sort values %district], 
	                  -variable => \$gui_district,
	                  -browsecmd => sub { my @district_id = grep { 
	                                           $district{$_} eq $gui_district
	                                      } keys %district or return;
	                                      $gui_district_id = $district_id[0] }, ),
	'x',
	$fr0->Label(-text => 'Distriktskenner', -anchor => 'w'),
	$fr0->BrowseEntry(-choices  => [ sort keys %district ], 
	                  -variable => \$gui_district_id,
	                  -browsecmd => sub { return unless exists $district{$gui_district_id};
	                                      $gui_district = $district{$gui_district_id} }, ),
	'x',
	$fr0->Label(-text => 'Jahr', -anchor => 'w'),
	$gui_general{Jahr} = $fr0->Entry(-width => 4),
	-sticky => 'we');
		
	$fr0->Button(
		-text    => 'Peilref. Name', 
		-state   => 'normal',
		-command => sub { select_name_ovj($parent) } ) ->grid(
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
		-text => "Beim Export Teilnehmer ohne offizielle Veranstaltung im aktuellen Jahr ausschliessen")
	  ->grid('-','-','-','-','-','-','-','-','-','-',-sticky => 'w');
	
	return $fr00;
}

# Liste der OV-Wettbewerbe
sub make_ovfj_list {
	my $parent = shift
	  or croak "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $fr00 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
	my $fr0 = $fr00->Frame()->pack(-fill => 'both', -padx => 5, -pady => 5);

	$fr0->gridColumnconfigure(1, -weight => 2);
	$fr0->gridColumnconfigure(2, -minsize => 15);
	$fr0->gridColumnconfigure(3, -weight => 1);
	$fr0->gridRowconfigure(5, -weight => 1, -minsize => 5);

	$fr0->Label(-text => 'Liste der OV-Wettbewerbe')
	  ->grid(-sticky => 'nw', -columnspan => 3);
	
	$gui_fjlist = $fr0->Scrolled('Listbox',
		-scrollbars =>'ose') #osoe funktioniert zumindest unter Win32 nicht korrekt!
	  ->grid(-row => 1, -column => 1, -sticky => 'wens', -rowspan => 6);
	
	my ($col, $row) = (3, 1);
	$fr0->Button(
	        -text => 'OV-Wettbewerb hinzuf�gen',
	        -command => \&do_create_ovfj,
	        -state => 'normal')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$edit_ovfj_button = $fr0->Button(
	        -text => 'OV-Wettbewerb bearbeiten',
	        -command => \&do_edit_ovfj,
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$eval_ovfj_button = $fr0->Button(
	        -text => 'OV-Wettbewerb auswerten',
	        -command => sub {
				my $ovfjname = get_selected_ovfj();
				defined $ovfjname or return;
				do_eval_ovfj($ovfjname);
			},
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$del_ovfj_button = $fr0->Button(
	        -text => 'OV-Wettbewerb entfernen',
	        -command => \&do_delete_ovfj,
	        -state => 'normal')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	$row++;
	$eval_all_button = $fr0->Button(
	        -text => 'Jahresauswertung erstellen',
	        -command => sub{ 
				my %general = get_gui_general();
				do_eval_ovfj( @{$general{ovfj_link}} )
			},
	        -state => 'disabled')
	  ->grid(-row => $row++, -column => $col, -sticky => 'we');
	
	return $fr00;
}


# Statusmeldungen
sub make_meldungen {
	my $parent = shift
	  or croak "Parameter f�r �bergeordnetes Fenster fehlt";
	
	my $fr5 = $parent->Frame(-borderwidth => 1, -relief => 'raised');
	$fr5->gridColumnconfigure(0, -weight => 1);
	$fr5->gridRowconfigure(1, -weight => 1);
	$fr5->Label(-text => 'Meldungen')->grid(-stick => "w");
	$gui_meldung = $fr5->Scrolled('Listbox',-scrollbars =>'ose',-width => 80, -height => 6)
	  ->grid(-stick => "nswe");
	return $fr5;
}

sub select_name_ovj {
	my $parent = shift || $mw;
	my $record = OVJ::TkTools::name_dialog($project, $parent) or return;
	my %general_tmp = get_gui_general();
	map {
		$general_tmp{$_} = $record->{$_}
	} qw/Name Vorname Call DOK Telefon Home-BBS E-Mail/;
	modify_gui_general(%general_tmp);
}

sub do_ovfj_dialog {
	my $ovfjname = shift;
	update_project();
	my $dlg = new OVJ::FjDialog($mw, $project, $ovfjname);
	$dlg->Show();
}

=old

sub do_ovfj_dialog {
	my $ovfjname = shift;
	my $dlg = $mw->DialogBox(
	  -title          => sprintf("OVFJ %s", get_ovfj_string($ovfjname)),
	  -buttons        => ['�bernehmen', 'Importieren...', 'Auswerten', 'Hilfe', 'Abbrechen'],
	  -default_button => 'Abbrechen',
	);
	# http://www.annocpan.org/~NI-S/Tk-804.027/pod/DialogBox.pod
	$dlg->protocol( WM_DELETE_WINDOW => sub { 
		$dlg->{selected_button} = 'Abbrechen' } );
	my $fr = $dlg->add('Frame', -relief => 'flat')
	  ->pack(-fill => 'both', -expand => 1);
	my $dialog = new OVJ::FjDialog($project, $fr);
	$dialog->{gui}->pack(-fill => 'both', -expand => 1);

	update_project();
	if (exists $project->{$ovfjname}) {
		$dialog->set_ovfj($ovfjname, %{$project->{$ovfjname}});
	}
	else {
		meldung(OVJ::INFO, "OV-Wettbewerb hinzuf�gen...");
		$dialog->set_ovfj($ovfjname);
	}
	
	while (1) {
		my $sel = $dlg->Show;
		if ($sel eq '�bernehmen') {
			if ($dialog->is_modified($project->{$ovfjname})) {
				my %ovfj = $dialog->get_ovfj();
				# FIXME $project->{$ovfjname} = { };
				%{$project->{$ovfjname}} = %ovfj;
				set_dirty(1);
			}
			last;
		}
		elsif ($sel eq 'Importieren...') {
			do_import_ovfjfile($mw); #FIXME
		}
		elsif ($sel eq 'Auswerten') {
			if (CheckForOverwriteOVFJ($dialog, $ovfjname)) {
				do_eval_ovfj($ovfjname);
				$dialog->fill_ovfj_tabs($ovfjname);
			}
		}
		elsif ($sel eq 'Hilfe') {
			show_help('schritt3.htm');
		}
		else {
			last if CheckForOverwriteOVFJ($dialog, $ovfjname); # FIXME
		}
	}
}

=cut

sub reset_project {
	if (check_for_save_project()) {
		set_project(UNNAMED, { General => {}, } );
		clear_meldung();
	}
}

sub fjlist_sort {
	return sort {
		$project->{$a}{Datum} =~ /^(\d?\d)\.(\d?\d)\.((?:19|20)\d\d)$/ or return -1;
		my $dat_a = sprintf("%2d.%2d.%4d", $3, $2, $1);
		$project->{$b}{Datum} =~ /^(\d?\d)\.(\d?\d)\.((?:19|20)\d\d)$/ or return 1;
		my $dat_b = sprintf("%2d.%2d.%4d", $3, $2, $1);
		return $dat_a cmp $dat_b;
	} @_;
}

sub modify_gui_general {
	my %new_general = @_;
	$gui_ExcludeTln->{Value} = $new_general{Exclude_Checkmark} || 0; 
	$gui_district    = $new_general{Distrikt};
	$gui_district_id = $new_general{Distriktskenner};
	$new_general{ovfj_link} ||= [];
	@curr_ovfj_link = fjlist_sort(@{$new_general{ovfj_link}});
	$gui_fjlist->delete(0, 'end');
	$gui_fjlist->insert(0, map { get_ovfj_string($_) } @curr_ovfj_link );
	my $button_state = (scalar @curr_ovfj_link) ? 'normal' : 'disabled';
	foreach ($edit_ovfj_button, $eval_ovfj_button, $del_ovfj_button, $eval_all_button) {
		$_->configure(-state => $button_state);
	}
	map {
		$gui_general{$_}->delete(0, "end");
		$gui_general{$_}->insert(0, $new_general{$_} || '');
	} keys %gui_general;
}

#Aktualisieren der aktuellen Generellen Daten im Hash
sub get_gui_general {
	my %general;
	while (my ($key,$value) = each(%gui_general)) {
		$general{$key} = $value->get();
	}
	$general{Exclude_Checkmark} = $gui_ExcludeTln->{Value};
	$general{Distrikt} = $gui_district;
	$general{Distriktskenner} = $gui_district_id;
	@{$general{ovfj_link}} = @curr_ovfj_link;
	return %general;
}

# Test auf �nderungen
sub project_modified {
	defined $project->{General}{ovfj_link} or return; # Vor Laden des 1. Proj.
#	return 1 if $project->{dirty};
	  $project->{dirty} ||=
	  $project->{General}{Exclude_Checkmark} ne $gui_ExcludeTln->{Value} or
	  $project->{General}{Distrikt} ne $gui_district or
	  $project->{General}{Distriktskenner} ne $gui_district_id or
	  grep {
		$gui_general{$_}->get() ne ($project->{General}{$_} || "")
	  } keys %gui_general or
	  join (', ', @curr_ovfj_link) ne 
		join (', ',@{$project->{General}{ovfj_link}});
}


sub get_selected_ovfj {
	my $sel = $gui_fjlist->curselection() or return;
	return $curr_ovfj_link[$sel->[0]];
}


sub get_ovfj_string {
	my $ovfj = (ref $_[0]) ? $_[0] : $project->{$_[0]};
	my @items;
	push @items, $ovfj->{Datum} || 'Datum?';
	push @items, $ovfj->{AusrichtOV} || 'OV?';
	push @items, $ovfj->{AusrichtDOK} || 'DOK?';
	push @items, $ovfj->{Band} || '?';
	push @items, $ovfj->{OVFJDatei} || '?';
	$items[-1] =~ s:^.*/::;
	return sprintf "%s, %s (%s), Band: %s, Datei: %s", @items;
}

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

sub set_projectname {
	$OVJ::genfilename = shift || UNNAMED;
	$gui_projectname->configure(
		-text => "OV-Jahresauswertung: $OVJ::genfilename" );
}

sub set_dirty {
	$project->{dirty} = shift;
	my $dirty = $project->{dirty} ? " (ge�ndert)" : "";
	$gui_projectname->configure(
		-text => "OV-Jahresauswertung: $OVJ::genfilename $dirty");
	return $project->{dirty};
}

#�ber Box aus dem 'Hilfe' Menu
sub About {
	my $tk_version = $Tk::VERSION || $Tk::Version || $Tk::version;
	$mw->messageBox(-title   => '�ber OVJ',
	                -icon    => 'info', 
	                -type    => 'Ok',
	                -message => <<"END_ABOUT" );
OV Jahresauswertung
(C) 2007 Matthias K�hlewein, DL3SDO
         Kai Pastor, DG0YT

Download, Neuigkeiten,
Fehlermeldungen, �nderungsw�nsche:
http://developer.berlios.de/projects/ovj/

OVJ Version $OVJ::VERSION
- Kern: Revision $OVJ::REVISION ($OVJ::REVDATE)
- GUI: Revision $REVISION ($REVDATE)
- Tk: Version $tk_version
- Plattform: $^O
END_ABOUT
}


# Hilfe im Browser �ffnen
# Verzeichnis durch globale Variable vorgegeben
# Parameter: Hilfe-Datei (optional, Default: index.htm)
sub show_help {
	my $location = $help_dir . '/' . (shift || 'index.htm');
	OVJ::Browser::open($location);
}

# Homepage im Browser �ffnen
sub show_homepage {
	OVJ::Browser::open('http://developer.berlios.de/projects/ovj/');
}

# Bug melden
sub report_bug {
	OVJ::Browser::open('http://developer.berlios.de/bugs/?group_id=8259');
}


=old

#Pr�fen, ob OVFJ Veranstaltung ver�ndert wurde, ohne gespeichert worden zu
#sein
# Returns: wahr, wenn aktueller Vorgang fortgefahren werden soll 
#          falsch, wenn aktueller Vorgang abgebrochen werden soll
sub CheckForOverwriteOVFJ {
	my $dialog  = shift;
	my $ovfj_id = shift
	 or carp "OVFJ-ID erforderlich";
	if ($dialog->is_modified($project->{$ovfj_id})) {
		my $ovfjname = get_ovfj_string($ovfj_id);
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => 'OVFJ Daten �bernehmen?', 
			-message => sprintf("Kopfdaten zum OV Wettbewerb '%s' wurden ge�ndert\n",$ovfjname||'NEU').
			            "und noch nicht �bernommen.\n\n".
			            "Jetzt �bernehmen?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Yes')    { 
			my %ovfj = $dialog->get_ovfj();
			%{$project->{$ovfj_id}} = %ovfj;
			set_dirty(1);
		}
	}
	
	return 1;
}

=cut


#Pr�fen, ob Generelle Daten ver�ndert wurde, ohne gespeichert worden zu
#sein
# return: wahr, wenn aktueller Vorgang fortgefahren werden soll 
#         falsch, wenn aktueller Vorgang abgebrochen werden soll
sub check_for_save_project {
	if (project_modified()) {
		set_dirty(1);
		my $msg = ($OVJ::genfilename eq UNNAMED)
		          ? "Das Projekt wurde noch nicht gespeichert."
		          : "Datei '$OVJ::genfilename' wurde ge�ndert ".
		            "und noch nicht gespeichert.";
		my $response = $mw->messageBox(
			-icon    => 'question', 
			-title   => "Datei '$OVJ::genfilename' speichern?", 
			-message => "$msg\n\nJetzt speichern?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Yes')    { return save_project() }
	}
	
	return 1;
}


#Datei/Beenden oder Fenster schlie�en
sub Leave {
	return unless (check_for_save_project());		# Abbruch durch Benutzer
	$mw->destroy();
}


# Meldung anzeigen.
# Parameter: Typ, Meldung
# R�ckgabe: FALSE bei Fehlermeldung, WAHR sonst
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

# Bestimmt einzelne ausgew�hlte Zeile aus Tk::Text
# R�ckgabe: FALSE bei Fehler, ausgew�hlte Zeile sonst
sub get_selected {
	my $listbox = shift;

	if (! $listbox->tagRanges('sel')) {
		# Keine Auswahl -> aktuelle Zeile ausw�hlen
		$listbox->tagAdd('sel', 'insert linestart', 'insert lineend');
	}
	if (! $listbox->tagRanges('sel')) {
		return meldung(OVJ::FEHLER, 'Nichts ausgew�hlt');
	}
	my $selected = $listbox->get('sel.first linestart', 'sel.last - 1 chars lineend');
	chomp $selected;
	$selected !~ /\n/
	 or return meldung(OVJ::FEHLER, 'Nur eine Zeile markieren!');
	return $selected;
}

#Anlage einer neuen Veranstaltung
sub do_create_ovfj {
	# "Name" ist nur noch eindeutige Ziffer, 
	# da au�erhalb von OVJ kaum noch von Bedeutung
	my $ovfjname = 1 + scalar @curr_ovfj_link;
	while (grep /^$ovfjname$/, @curr_ovfj_link) { $ovfjname++ }
	do_ovfj_dialog($ovfjname);
	if (exists $project->{$ovfjname}) {
		my %new_general = get_gui_general();
		push @{$new_general{ovfj_link}}, $ovfjname;
		modify_gui_general(%new_general);
	}
}

#Auswahl einer Veranstaltung durch den Anwender
sub do_edit_ovfj {
	my $ovfjname = get_selected_ovfj()
	 or return;
	update_project();
	do_ovfj_dialog($ovfjname);
	modify_gui_general(get_gui_general()); # OVFJ-Liste aktualisieren
}

# L�schen einer Veranstaltung
sub do_delete_ovfj {
	my $ovfjname = get_selected_ovfj()
	 or return;
	my $dialog = $mw->Dialog(
		-title => 'OV-Wettbewerb entfernen',
		-bitmap => 'question',
		-text => sprintf("OV-Wettbewerb '%s' l�schen?", get_ovfj_string($ovfjname)),
		-buttons => ['L�schen', 'Abbrechen'] );
	my $answer = $dialog->Show();
	if ($answer eq "L�schen") {
		my %new_general = get_gui_general();
		@{$new_general{ovfj_link}} = grep !/^$ovfjname$/, @{$new_general{ovfj_link}};
		delete $project->{$ovfjname};
		set_dirty(1);
		modify_gui_general(%new_general);
		# mkw, FIXME: auch report Datei loeschen?
	}
}


#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	my $parent = $_[0] 
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";
	my $fjdir = OVJ::TkTools::tk_dir(OVJ::get_path($OVJ::genfilename, $OVJ::inputdir));
	(-e $fjdir && -d $fjdir)
	 or return meldung(OVJ::FEHLER, "Verzeichnis '$fjdir' nicht vorhanden");
	
	# Unter KDE/Linux �ffnet getOpenFile sein Fenster *hinter* 
	# den anderen OVJ-Fenstern ... 
	# Tk::Fbox tut das selbe unter KDE problemlos,
	# wird aber von pp unter Windows nicht ordentlich in eine .exe-Datei gepackt
	# http://www.perltk.org/index.php?option=com_content&task=view&id=21&Itemid=28
	my %dialog_options = (
		-initialdir => $fjdir,
		-filetypes  => [['Text Files','.txt'],['All Files','*',]],
		-title      => "FJ Datei ausw�hlen");
	my $selfile = ($^O =~ /MSWin32/) ?
		$parent->getOpenFile(%dialog_options) :
		$parent->FBox(-type => 'open')->Show(%dialog_options);
	return unless ($selfile && $selfile ne "");

	$fjdir =~ tr/\\/\//;
	$selfile =~ s/^$fjdir\/([^\/]+)$/$1/;
	my %ovfj = OVJ::import_fjfile($selfile)
	 or return;
	modify_ovfj(%ovfj);
}

=old ...

sub do_import_ovfjfile {
	my $parent = $_[0] 
	  or carp "Parameter f�r �bergeordnetes Fenster fehlt";
	my $dir = OVJ::TkTools::tk_dir(OVJ::get_path($OVJ::genfilename, $OVJ::configdir));
	(-e $dir && -d $dir)
	 or return meldung(OVJ::FEHLER, "Verzeichnis '$dir' nicht vorhanden");

	# Unter KDE/Linux �ffnet getOpenFile sein Fenster *hinter* 
	# den anderen OVJ-Fenstern ... 
	# Tk::Fbox tut das selbe unter KDE problemlos,
	# wird aber von pp unter Windows nicht ordentlich in eine .exe-Datei gepackt
	# http://www.perltk.org/index.php?option=com_content&task=view&id=21&Itemid=28
	my %dialog_options = (
		-initialdir => $dir,
		-filetypes  => [['Text Files','*_ovj.txt'],['All Files','*',]],
		-title      => "OVFJ Datei ausw�hlen");
	my $selfile = ($^O =~ /MSWin32/) ?
		$parent->getOpenFile(%dialog_options) :
		$parent->FBox(-type => 'open')->Show(%dialog_options);
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

=cut

sub open_project {
	check_for_save_project()
	 or return;		# Abbruch durch Benutzer

	my $filename = shift;
	if (! $filename) {
#		my $types = [['OVJ-Projekt', '.ovj'],['Textdatei','.txt'],['Alle Dateien','*',]];
		my $types = [['OVJ-Projekt', ['.ovj','.txt']],['Alle Dateien','*',]];
		$filename = $mw->getOpenFile(
			-initialdir => OVJ::TkTools::tk_dir(OVJ::get_path($OVJ::genfilename,$OVJ::configdir)),
			-filetypes  => $types,
			-title      => "OVJ-Projekt laden");
		return unless $filename;
	}
	clear_meldung();
	meldung(OVJ::HINWEIS,"Lade '$filename'");
	my $ovj_file;
	if ($filename =~ /\.txt$/i) { # .txt
		$ovj_file = OVJ::convert_genfile($filename) or return;
		OVJ::meldung(OVJ::WARNUNG, "Alle �nderungen werden als OVJ-Projekt (.ovj-Datei) gespeichert.");
	}		    
	else {
		$ovj_file = OVJ::read_ovj_file($filename) or return;
	}
	set_project($filename, $ovj_file);
}

sub import_project {
	my $types = [['OVJ-Projekt', '.ovj'],['Textdatei','.txt'],['Alle Dateien','*',]];
	my $filename = $mw->getOpenFile(
		-initialdir => OVJ::TkTools::tk_dir(OVJ::get_path($OVJ::genfilename,$OVJ::configdir)),
		-filetypes  => $types,
		-title      => "OVJ-Projekt laden");
	return unless $filename;
	my %general;
	my %general_alt = OVJ::GUI::get_gui_general();
	meldung(OVJ::HINWEIS,"Importiere '$filename'");
	my $ovj_file;
	if ($filename =~ /\.txt$/i) {
		$ovj_file = OVJ::convert_genfile($filename) or return;
	}
	else {
		$ovj_file = OVJ::read_ovj_file($filename) or return;
	}
	%general = %{$ovj_file->{General}};
	@{$general{ovfj_link}} = @{$general_alt{ovfj_link}};
	$general{Jahr} = $general_alt{Jahr};
	$general{PMVorjahr} = $general_alt{PMVorjahr};
	$general{PMaktJahr} = $general_alt{PMaktJahr};
	modify_gui_general(%general);
	set_dirty(project_modified());
	return 1;
}

# return: wahr bei Erfolg
#         falsch bei Fehler

sub save_project {
	return save_project_as($OVJ::genfilename);
}

sub save_project_as {
	my $filename = shift;
	if (! $filename || $filename eq UNNAMED) {
		my $types = [['OVJ-Projekt', '.ovj'],['Alle Dateien','*',]];
		$filename = $mw->getSaveFile(
#			-initialdir => $OVJ::configdir,
			-filetypes  => $types,
			-title      => "OVJ-Projekt speichern");
		return unless $filename;
	}
	$filename =~ s/(\.txt|\.ovj)?$/.ovj/i;
	meldung(OVJ::HINWEIS, "Speichere '$filename'");
	set_projectname($filename);
	update_project();
	delete $project->{dirty};
	OVJ::write_ovj_file($filename, $project) 
	  or return; # Fehler
	set_dirty(0);
	return 1; # Erfolg
}

# Auswertung und Export von OVFJ
# Parameter: Liste der OVFJ
sub do_eval_ovfj {
	check_for_save_project() or return;
	my $i = 1;
	my $success = 0;
	my $retval;
	
	$mw->Busy();
#	my %general = get_gui_general();
	update_project();
	my %tn;					# Hash f�r die Teilnehmer, Elemente sind wiederum Hashes
	my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
	                  	# Elemente sind die %ovfj Daten
	my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info �ber die Anzahl 
	                     # der Teilnehmer, wird parallel zur @ovfjlist Liste gef�hrt
	foreach my $str (@_)
	{
		my $ovfjname = $str;
		my $ovfjrepfilename = $str . "_report_ovj.txt";
		$ovfjrepfilename =~ s/^OVFJ //;
		next if ($ovfjname !~ /\S+/);
#		my %ovfj = OVJ::read_ovfjfile($ovfjname)
#		 or next;
		$retval = OVJ::eval_ovfj($i++,
		  $project->{General},
		  \%tn,
		  \@ovfjlist,
		  \@ovfjanztlnlist,
		  $project->{$ovfjname},
		  $ovfjname,
		  $ovfjrepfilename
		);
		$success = 1 if ($retval == 0);	# Stelle fest, ob wenigstens eine Auswertung erfolgreich war
		last if ($retval == 2);	# systematischer Fehler, Abbruch der Schleife
	}
	OVJ::export($project->{General},\%tn,\@ovfjlist,\@ovfjanztlnlist) if ($success);
	$mw->Unbusy();
}


# Aktuellen Stand des Projekts ermitteln
sub update_project {
	my %update = get_gui_general();
	while (my ($key, $value) = each %update) {
		$project->{General}{$key} = $value;
	}
	return $project;
}

# Neues/ge�ndertes Projekt anzeigen 
sub set_project {
	my ($name, $data) = (shift, shift);
	$project = $data;
	set_projectname($name);
	modify_gui_general(%{$project->{General}});
	%{$project->{General}} = get_gui_general(); # Auff�llen evt. fehlender Felder
	$project->{dirty} = 0;
	return $project;
}

1;
