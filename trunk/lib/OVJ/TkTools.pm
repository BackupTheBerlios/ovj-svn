# $Id$
#
# (C) 2007-2008 Kai Pastor, DG0YT <dg0yt AT darc DOT de>
#           and Matthias Kuehlewein, DL3SDO
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

package OVJ::TkTools;

use strict;
use Carp;

#use Tk;
#use Tk::Text;
#use Tk::BrowseEntry;
#use Tk::Dialog;
#use Tk::DialogBox;
#use Tk::NoteBook;
#require Tk::FBox if ($^O !~ /MSwin32/);

use OVJ 0.98;
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

# Verwende plattformspezifischen Pfadseparator f�r "initialdir" der Tk-Dialoge
# Perl selbst gen�gt '/'
sub tk_dir {
	my $dir = shift;
	my $sep = $^O =~ /MSWin32/ ? '\\' : '/';
	$dir =~ s/\//$sep/g;
	return -d $dir ? $dir : '.';
}


# Katalog bekannter OVs
my %ov_catalogue;

sub ov_dialog {
	my ($project, $parent) = @_;
	my $dlg = $parent->DialogBox(
	  -title          => 'OV-Katalog',
	  -buttons        => ['�bernehmen', 'Importieren...', 'Hilfe', 'Abbrechen'],
	  -default_button => '', # Kein Default-Button,
	                         # da sonst Return-Taste nicht verwendbar
	);
	# http://www.annocpan.org/~NI-S/Tk-804.027/pod/DialogBox.pod
	$dlg->protocol( WM_DELETE_WINDOW => sub { 
		$dlg->{selected_button} = 'Abbrechen' } );
	my $listbox = $dlg->add('Scrolled', 'Listbox', 
		-scrollbars => 'osoe' )
	  ->pack(-fill => 'both', -expand => 1);
	my $ov_catalogue = get_ov_catalogue($project); # FIXME
	$listbox->insert(0, sort keys %$ov_catalogue);
	while (1) {
		$listbox->activate(0);
		my $sel = $dlg->Show;
		if ($sel eq '�bernehmen') {
			my $item = $listbox->curselection() or next;
			return $ov_catalogue->{$listbox->get($item->[0])};
			#$ovfj_tmp{AusrichtDOK} = $record->[0];
			#$ovfj_tmp{AusrichtOV}  = $record->[1];
		}
		elsif ($sel eq 'Importieren...') {
			my $types = [['OVJ-Projekt', '.ovj'],['Alle Dateien','*',]];
			my $selfile = $parent->getOpenFile(
				-initialdir => tk_dir(OVJ::get_path($OVJ::genfilename,$OVJ::configdir)),
				-filetypes => $types, 
				-title => "OVs aus anderem OVJ-Projekt einlesen" );
			return if (!defined($selfile) || $selfile eq "");
			my $other = OVJ::read_ovj_file($selfile) or next;
			$ov_catalogue = get_ov_catalogue($other);
			$listbox->delete(0, 'end');
			$listbox->insert(0, sort keys %$ov_catalogue);
		}
		elsif ($sel eq 'Hilfe') {
			warn "Noch nicht implementiert"; # TODO
#			show_help('auswertungsmuster.htm');
		}
		elsif ($sel eq 'Abbrechen') {
			last;
		}
		else {
			warn "Fehler: Kommando '$sel' nicht bekannt";
			last;
		}
	}
	return;
}


sub get_ov_catalogue {
	my $project = shift;

	foreach (@{$project->{General}{ovfj_link}}) {
		my $ov  = $project->{$_}{AusrichtOV}  || '?';
		my $dok = $project->{$_}{AusrichtDOK} || '?';
		my $key = "$dok - $ov";
		$ov_catalogue{$key} = [$dok, $ov] unless ($key eq '? - ?');
	}
	return wantarray ? %ov_catalogue : \%ov_catalogue;
}


# Katalog bekannter Personen
my %name_catalogue;

sub name_dialog {
	my ($project, $parent) = @_;
	my $dlg = $parent->DialogBox(
	  -title          => 'Namenskatalog',
	  -buttons        => ['�bernehmen', 'Importieren...', 'Hilfe', 'Abbrechen'],
	  -default_button => '', # Kein Default-Button,
	                         # da sonst Return-Taste nicht verwendbar
	);
	# http://www.annocpan.org/~NI-S/Tk-804.027/pod/DialogBox.pod
	$dlg->protocol( WM_DELETE_WINDOW => sub { 
		$dlg->{selected_button} = 'Abbrechen' } );
	my $listbox = $dlg->add('Scrolled', 'Listbox', 
		-scrollbars => 'osoe' )
	  ->pack(-fill => 'both', -expand => 1);
	my $name_catalogue = get_name_catalogue($project);
	$listbox->insert(0, sort keys %$name_catalogue);
	while (1) {
		$listbox->activate(0);
		my $sel = $dlg->Show;
		if ($sel eq '�bernehmen') {
			my $item = $listbox->curselection() or next;
			return $name_catalogue->{$listbox->get($item->[0])};
		}
		elsif ($sel eq 'Importieren...') {
			my $types = [['OVJ-Projekt', '.ovj'],['Alle Dateien','*',]];
			my $selfile = $parent->getOpenFile(
				-initialdir => tk_dir(OVJ::get_path($OVJ::genfilename,$OVJ::configdir)),
				-filetypes => $types, 
				-title => "Namen aus anderem OVJ-Projekt einlesen" );
			return if (!defined($selfile) || $selfile eq "");
			my $other = OVJ::read_ovj_file($selfile) or next;
			$name_catalogue = get_name_catalogue($other);
			$listbox->delete(0, 'end');
			$listbox->insert(0, sort keys %$name_catalogue);
		}
		elsif ($sel eq 'Hilfe') {
			warn "Noch nicht implementiert";
#			show_help('auswertungsmuster.htm');
		}
		elsif ($sel eq 'Abbrechen') {
			last;
		}
		else {
			warn "Fehler: Kommando '$sel' nicht bekannt";
			last;
		}
	}
	return;
}

sub get_name_catalogue {
	my $project = shift;

	my $catalogue_add = sub {
		my $input = shift;
		my %record;
		my $i = 0;
		map {
			$record{$_} = $input->{$_[$i++]} || ''
		} qw/Name Vorname Call DOK GebJahr Telefon Home-BBS E-Mail/;
		$record{CALL} = $record{Call}; # Vereinfachung bei Verwendern
		my $key = "$record{Name}, $record{Vorname}, $record{Call}";
		if ($key eq ', , ') {
			return
		}
		elsif (exists $name_catalogue{$key}) {
			map {
				$name_catalogue{$key}->{$_} ||= $record{$_};
			} qw/DOK GebJahr Telefon Home-BBS E-Mail/;
		}
		else {
			$name_catalogue{$key} = \%record;
		}
	};
		
	&$catalogue_add($project->{General}, 
	               qw/Name Vorname Call DOK - Telefon Home-BBS E-Mail/ );
	foreach (@{$project->{General}{ovfj_link}}) {
		&$catalogue_add($project->{$_},
		               qw/Verantw_Name Verantw_Vorname Verantw_CALL
					      Verantw_DOK Verantw_GebJahr - - -/);
	}
	return wantarray ? %name_catalogue : \%name_catalogue;
}

my $curr_patterns;
my $orig_patterns;

sub pattern_dialog { 
	my $parent = shift;
	my $dlg = $parent->DialogBox(
	  -title          => 'Musterkatalog',
	  -buttons        => ['�bernehmen', 'Speichern', 'Hilfe', 'Abbrechen'],
	  -default_button => '', # Kein Default-Button,
	                         # da sonst Return-Taste nicht verwendbar
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
	set_patterns(OVJ::read_patterns()) unless $orig_patterns;
	$textbox->Contents($orig_patterns);
	while (1) {
		my $sel = $dlg->Show;
		$curr_patterns = $textbox->Contents;
		chomp $curr_patterns;
		if ($sel eq '�bernehmen') {
			if ( my $pattern = get_selected($textbox) ) {
				next unless CheckForUnsavedPatterns($parent);
				$pattern =~ s/\/\/.*$//;	# Entferne Kommentare beim Kopieren
				$pattern =~ s/\s+$//;		# Entferne immer Leerzeichen nach dem Muster
				return $pattern;
				my %ovfj_tmp = get_ovfj();
				$ovfj_tmp{Auswertungsmuster} = $pattern;
				modify_ovfj(%ovfj_tmp);
				last;
			}
		}
		elsif ($sel eq 'Speichern') {
			if ( OVJ::save_patterns($curr_patterns) ) {
				$orig_patterns = $curr_patterns;
			}
		}
		elsif ($sel eq 'Hilfe') {
			show_help('auswertungsmuster.htm');
		}
		else {
			last if CheckForUnsavedPatterns($parent);
		}
	}
}


sub patterns_modified {
	return $orig_patterns ne $curr_patterns;
}

sub get_patterns {
	return $curr_patterns;
}

sub set_patterns {
	$curr_patterns = $orig_patterns = shift;
}

#Ueberpruefen beim Beenden des Programms, ob aktuelle Auswertungsmuster
#gespeichert wurden, und falls nicht, was passieren soll
sub CheckForUnsavedPatterns {
	my $parent = shift;
	if (patterns_modified()) {
		my $response = $parent->messageBox(
			-icon    => 'question', 
			-title   => 'Auswertungsmuster speichern?', 
			-message => "Liste der Auswertungsmuster wurden ge�ndert ".
			            "und noch nicht gespeichert.\n\n".
						"Jetzt speichern?", 
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


# Bestimmt einzelne ausgew�hlte Zeile aus Tk::Text
# R�ckgabe: FALSE bei Fehler, ausgew�hlte Zeile sonst
sub get_selected {
	my $listbox = shift;

	if (! $listbox->tagRanges('sel')) {
		# Keine Auswahl -> aktuelle Zeile ausw�hlen
		$listbox->tagAdd('sel', 'insert linestart', 'insert lineend');
	}
	if (! $listbox->tagRanges('sel')) {
		return OVJ::meldung(OVJ::FEHLER, 'Nichts ausgew�hlt');
	}
	my $selected = $listbox->get('sel.first linestart', 'sel.last - 1 chars lineend');
	chomp $selected;
	$selected !~ /\n/
	 or return OVJ::meldung(OVJ::FEHLER, 'Nur eine Zeile markieren!');
	return $selected;
}


1;
