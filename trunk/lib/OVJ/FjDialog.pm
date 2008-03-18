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

package OVJ::FjDialog;

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
use OVJ::TkTools;

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


sub new {
	my ($proto, $parent, $project, $ovfjname) = @_;
	$parent or croak "Parameter f�r �bergeordnetes Fenster fehlt";
	my $class = ref($proto) || $proto;
	my $self = {
		project=> $project,
		parent => $parent,
		name   => $ovfjname,
		ovfj   => $project->{$ovfjname},
		parts  => { },
		views  => { },
		gui    => 0,
	};
	bless $self, $class;
	$self->{gui} = $self->make_frame();

	my $ovfj     = $project->{$ovfjname};
	if (defined $ovfj) {
		$self->set_ovfj($ovfjname, %$ovfj);
	}
	else {
		OVJ::meldung(OVJ::INFO, "OV-Wettbewerb hinzuf�gen...");
		$self->set_ovfj($ovfjname);
	}

	return $self;
}


sub make_frame {
	my $self = shift;

	my $dlg = $self->{parent}->DialogBox(
	  -title          => "OVFJ ".$self->title(), # FIXME
	  -buttons        => ['�bernehmen', 'Importieren...', 'Auswerten', 'Hilfe', 'Abbrechen'],
	  -default_button => 'Abbrechen',
	);
	# http://www.annocpan.org/~NI-S/Tk-804.027/pod/DialogBox.pod
	$dlg->protocol( WM_DELETE_WINDOW => sub {
		$dlg->{selected_button} = 'Abbrechen' } );
	my $fr0 = $dlg->add('Frame', -relief => 'flat')
	  ->pack(-fill => 'both', -expand => 1);
	
#	my $fr0 = $parent->Frame();
	$fr0->gridColumnconfigure([1,4,7], -weight => 1);
	$fr0->gridColumnconfigure([2,5,8], -minsize => 15);
	$fr0->gridRowconfigure([5], -weight => 1);

	$fr0->Button(
	        -text => 'Ergebnisliste',
	        -state => 'normal',
	        -command => sub{ $self->do_select_fjfile() } ) ->grid(
	$self->{parts}->{OVFJDatei} = $fr0->Entry(-width => 20),
	'-','-','-',
	'x',
	$fr0->Label(-text => 'Anz. Teilnehmer manuell', -anchor => 'w'),
	'-','-','-',
	$self->{parts}->{TlnManuell} = $fr0->Entry(-width => 2),
	-sticky => 'we');

	$fr0->Label(-text => 'Datum', -anchor => 'w') ->grid(
	$self->{parts}->{Datum} = $fr0->Entry(-width => 10),
	'x',
	#$fr0->Label(-text => 'Ausricht. OV', -anchor => 'w'),
	$fr0->Button(
		-text    => 'Ausricht. OV', 
		-state   => 'normal',
		-command => sub { $self->select_ov() } ),
	$self->{parts}->{AusrichtOV} = $fr0->Entry(-width => 3),
	'x',
	$fr0->Label(-text => 'DOK', -anchor => 'w'),
	$self->{parts}->{AusrichtDOK} = $fr0->Entry(-width => 4),
	'x',
	$fr0->Label(-text => 'Band', -anchor => 'w'),
	$self->{parts}->{Band} = $fr0->Entry(-width => 2),
	-sticky => 'we', -pady => 5);

	#$fr0->Label(-text => 'Name', -anchor => 'w') ->grid(
	$fr0->Button(
		-text    => 'Verantw. Name', 
		-state   => 'normal',
		-command => sub { $self->select_name() } ) ->grid(	# FIXME
	$self->{parts}->{Verantw_Name} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'Vorname', -anchor => 'w'),
	$self->{parts}->{Verantw_Vorname} = $fr0->Entry(),
	'x',
	$fr0->Label(-text => 'Call', -anchor => 'w'),
	$self->{parts}->{Verantw_CALL} = $fr0->Entry(-width => 8),
	'x',
	$fr0->Label(-text => 'DOK', -anchor => 'w'),
	$self->{parts}->{Verantw_DOK} = $fr0->Entry(-width => 4),
	-sticky => 'we');
	
	$fr0->Label(-text => 'Geburtsjahr', -anchor => 'w') ->grid(
	$self->{parts}->{Verantw_GebJahr} = $fr0->Entry(-width => 4),
	-sticky => 'we');

	$fr0->Button(
		-text    => 'Muster', 
		-state   => 'normal',
		-command => sub { $self->do_pattern_dialog() } ) ->grid(	# FIXME
	$self->{parts}->{Auswertungsmuster} = $fr0->Entry(-width => 70),
	'-','-','-','-','-','-','-','-','-',
	-sticky => 'we');

#	$fr0->Label(-text => "Datei-Inhalt", -anchor => 'nw') ->grid(
#	$self->{views}->{input} = $fr0->Scrolled('Text',-scrollbars =>'ose',-width => 70, -height => 10, -state => 'disabled'),
#	'-','-','-','-','-','-','-','-','-',
#	-sticky => "nswe");
	$fr0->Label(-text => "Datei-Inhalt", -anchor => 'nw') ->grid(
	$self->{notebook} = $fr0->NoteBook(),
	'-','-','-','-','-','-','-','-','-',
	-sticky => "nswe");
	
	$self->{views}->{input_nb} = $self->{notebook}->add( 
	  "Input", -label=>"Ergebnisliste");
	$self->{views}->{output_nb} = $self->{notebook}->add(
	  "Output", -label=>"Auswertung");
	$self->{views}->{report_nb} = $self->{notebook}->add(
	  "Report", -label=>"Report");
	
	$self->{views}->{input} = $self->{views}->{input_nb}->Scrolled(
	  'Text', -scrollbars =>'ose', -width => 70, -height => 15, -wrap=>'none',
              -state => 'disabled')
	->pack(-anchor=>'nw', -fill=>'both', -expand=>1);
	$self->{views}->{output} = $self->{views}->{output_nb}->Scrolled(
	  'Text', -scrollbars =>'ose', -width => 70, -height => 15, -wrap=>'none',
              -state => 'disabled')
	->pack(-anchor=>'nw', -fill=>'both', -expand=>1);
	$self->{views}->{report} = $self->{views}->{report_nb}->Scrolled(
	  'Text', -scrollbars =>'ose', -width => 70, -height => 15, 
	          -wrap=>'word', # Report hat oft �berlange Zeilen...
              -state => 'disabled')
	->pack(-anchor=>'nw', -fill=>'both', -expand=>1);

	return $dlg;
}

#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	my $self = shift;
	my $parent = $self->{parent};
	my $fjdir = OVJ::TkTools::tk_dir(OVJ::get_path($OVJ::genfilename, $OVJ::inputdir));
	(-e $fjdir && -d $fjdir)
	 or return OVJ::meldung(OVJ::FEHLER, "Verzeichnis '$fjdir' nicht vorhanden");
	
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
	$self->modify_ovfj(%ovfj);
}


sub set_ovfj {
	my $self = shift;
	my $ovfjname = shift;
	$self->modify_ovfj(@_);
	$self->fill_ovfj_tabs($ovfjname);
	return 1;
}

sub modify_ovfj {
	my $self = shift;
	my %new_ovfj = @_;
	# GUI schon initialisiert ?
	if (defined $self->{parts}->{AusrichtDOK}) { 
		map {
			$self->{parts}->{$_}->delete(0, "end");
			$self->{parts}->{$_}->insert(0, $new_ovfj{$_} || '');
		} keys %{$self->{parts}};
		$self->{views}->{input}->configure(-state => 'normal');
		$self->{views}->{input}->Contents(
			$new_ovfj{OVFJDatei} ? OVJ::read_ovfj_infile($new_ovfj{OVFJDatei}) : '' );
		$self->{views}->{input}->configure(-state => 'disabled');
	}
	return 1;
}


sub fill_ovfj_tabs {
	my $self = shift;
	my $ovfjrepfilename = $_[0];
	my $general = $self->{project}->{General};
	# GUI schon initialisiert ?
	if (defined $self->{parts}->{AusrichtDOK}) { 
		$ovfjrepfilename .= "_report_ovj.txt";
		$ovfjrepfilename =~ s/^OVFJ //;
		#print $ovfjrepfilename."\n"; # FIXME: entfernen
		$self->{views}->{report}->configure(-state => 'normal');
		$self->{views}->{report}->Contents(
			$ovfjrepfilename ? OVJ::read_ovfj_repfile($ovfjrepfilename) : '' ); # FIXME: sinnlose Abfrage, ersetzen oder loeschen
		$self->{views}->{report}->configure(-state => 'disabled');
		
		$self->{views}->{output}->configure(-state => 'normal');
		$self->{views}->{output}->Contents(OVJ::read_txtoutfile($general));
		$self->{views}->{output}->configure(-state => 'disabled');
	}
	return 1;
}


sub get_ovfj {
	my $self = shift;
	my %ovfj;
	# GUI schon initialisiert ?
	if (defined $self->{parts}->{AusrichtDOK}) { 
		while (my ($key,$value) = each(%{$self->{parts}})) {
			$ovfj{$key} = $value->get();
		}
		foreach my $key (qw(AusrichtDOK Verantw_CALL Verantw_DOK)) {
			$ovfj{$key} = uc $ovfj{$key};
		}
	}
	return %ovfj;
}

# Test auf �nderungen
sub is_modified {
	my $self = shift;
	# GUI schon initialisiert ?
	return unless defined $self->{parts}->{AusrichtDOK};
	my $orig = ref $_[0] ? $_[0] : ();
	grep {
		$self->{parts}->{$_}->get() ne ($orig->{$_} || "");
	} keys %{$self->{parts}};
}


sub select_ov {
	my $self = shift;
	my $ov = OVJ::TkTools::ov_dialog($self->{project}, $self->{parent});
	if ($ov) {
		my %ovfj_tmp = $self->get_ovfj();
		$ovfj_tmp{AusrichtDOK} = $ov->[0];
		$ovfj_tmp{AusrichtOV}  = $ov->[1];
		$self->modify_ovfj(%ovfj_tmp);
	}
	return $ov;
}


sub select_name {
	my $self = shift;
	my $record = OVJ::TkTools::name_dialog($self->{project}, $self->{parent}) or return;
	my %ovfj_tmp = $self->get_ovfj();
	map {
		$ovfj_tmp{"Verantw_$_"} = $record->{$_}
	} qw/Name Vorname CALL DOK GebJahr/;
	$self->modify_ovfj(%ovfj_tmp);
}


sub do_pattern_dialog { 
	my $self = shift;
	my $pattern = OVJ::TkTools::pattern_dialog($self->{parent});
	if ($pattern) {
		my %ovfj_tmp = $self->get_ovfj();
		$ovfj_tmp{Auswertungsmuster} = $pattern;
		$self->modify_ovfj(%ovfj_tmp);
	}
}


sub Show {
	my $self = shift;
	
	while (1) {
		my $sel = $self->{gui}->Show();
		if ($sel eq '�bernehmen') {
			if ($self->is_modified($self->{ovfj})) {
				my %ovfj = $self->get_ovfj();
				# FIXME $project->{$ovfjname} = { };
				%{$self->{ovfj}} = %ovfj;
				OVJ::MainWindow::set_dirty(1); # FIXME: OO-Rewrite
			}
			last;
		}
		elsif ($sel eq 'Importieren...') {
			$self->do_import();
		}
		elsif ($sel eq 'Auswerten') {
			if ($self->check_overwrite()) {
				OVJ::MainWindow::do_eval_ovfj($self->{name}); # FIXME: OO-Rewrite
				$self->fill_ovfj_tabs($self->{name});
			}
		}
		elsif ($sel eq 'Hilfe') {
			OVJ::MainWindow::show_help('schritt3.htm'); # FIXME
		}
		else {
			last if $self->check_overwrite(); # FIXME
		}
	}
}

#Pr�fen, ob OVFJ Veranstaltung ver�ndert wurde, ohne gespeichert worden zu
#sein
# Returns: wahr, wenn aktueller Vorgang fortgefahren werden soll 
#          falsch, wenn aktueller Vorgang abgebrochen werden soll
sub check_overwrite {
	my $self  = shift;
	if ($self->is_modified($self->{ovfj})) {
		my $ovfjname = $self->title();
		my $response = $self->{parent}->messageBox(
			-icon    => 'question', 
			-title   => 'OVFJ Daten �bernehmen?', 
			-message => sprintf("Kopfdaten zum OV Wettbewerb '%s' wurden ge�ndert\n",$ovfjname ||'NEU').
			            "und noch nicht �bernommen.\n\n".
			            "Jetzt �bernehmen?", 
			-type    => 'YesNoCancel', 
			-default => 'Yes');
		if    ($response eq 'Cancel') { return 0 }
		elsif ($response eq 'Yes')    { 
			my %ovfj = $self->get_ovfj();
			%{$self->{ovfj}} = %ovfj;
			OVJ::MainWindow::set_dirty(1); # FIXME
		}
	}
	
	return 1;
}


sub do_import {
	my $self = shift;
	my $dir = OVJ::TkTools::tk_dir(OVJ::get_path($OVJ::genfilename, $OVJ::configdir));
	(-e $dir && -d $dir)
	 or return OVJ::meldung(OVJ::FEHLER, "Verzeichnis '$dir' nicht vorhanden");

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
		$self->{parent}->getOpenFile(%dialog_options) :
		$self->{parent}->FBox(-type => 'open')->Show(%dialog_options);
	return unless ($selfile && $selfile ne "");

#	$selfile =~ s/^.*\///;
	my %ovfj = OVJ::read_ovfjfile($selfile)
	 or return;
	my %old_ovfj = $self->get_ovfj();
	foreach ('Datum', 'Band', 'TlnManuell', 'OVFJDatei') {
		$ovfj{$_} = $old_ovfj{$_};
	}
	$self->modify_ovfj(%ovfj);
}


sub title {
	my $self = shift;
	my $ovfj = $self->{ovfj};
	my @items;
	push @items, $ovfj->{Datum} || 'Datum?';
	push @items, $ovfj->{AusrichtOV} || 'OV?';
	push @items, $ovfj->{AusrichtDOK} || 'DOK?';
	push @items, $ovfj->{Band} || '?';
	push @items, $ovfj->{OVFJDatei} || '?';
	$items[-1] =~ s:^.*/::;
	return sprintf "%s, %s (%s), Band: %s, Datei: %s", @items;
}

1;
