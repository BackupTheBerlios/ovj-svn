#
# Script zum Erzeugen der OV Jahresauswertung für
# OV Peilwettbewerbe
# Autor:   Matthias Kuehlewein, DL3SDO
# Version: 0.95
# Datum:   2.1.2007
#
#!/usr/bin/perl -w
#
# Copyright (C) 2006  Matthias Kuehlewein, DL3SDO
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
use strict;		# um 'besseren' Code zu erzwingen
use Tk;
use Tk::FileSelect;

my $ovjdate = "2.1.2007";
my $ovjvers = "0.95";
my $patternfilename = "OVFJ_Muster.txt";
my $overridefilename = "Override.txt";
my $inputpath = "input";		# Pfad für die Eingangsdaten
my $outputpath = "output";		# Pfad für die Ergebnisdaten
my $reportpath = "report";		# Pfad für die Reportdaten
my $configpath = "config";		# Pfad für die Konfigurationsdaten
										# (OVJ_Generell_20XX.txt, sowie die OVFJ Dateien (*_ovj.txt))

my ($genfile,$genfilename,$ovfjfile,$ovfjfilename,$ovfjrepfilename);
my $year;				# Auswertungsjahr 
my %genhash;			# Hash für Generelle Einstellungen
my %genhashsaved;		# gespeicherter Hash fuer Generelle Einstellungen
my @fjlist;				# Liste der OV Veranstaltungen, nur die Namen, keine Details
my $fjlistsaved;		# gespeicherte Liste der OV Veranstaltungen, auf Basis des Eingabefeldes, daher
                     # keine Liste
my %ovfjhash;			# Hash für eine OV Veranstaltung, Kopfdaten
my %ovfjhashsaved;	# gespeicherter Hash fuer eine OV Veranstaltung, Kopfdaten
my $ovfjname;			# Name der aktiven OV Veranstaltung
my %tn;					# Hash für die Teilnehmer, Elemente sind wiederum Hashes
my %auswerthash;		# Hash zur Kontrolle, welche OVFJ schon ausgewertet sind
my $lfdauswert=0;		# Nummer der lfd. OVFJ Auswertung
my $nicknames;			# Inhalt der Spitznamen Datei
my ($i,$str);			# temp. Variablen
my $pattern;			# Das 'richtige' Pattern, das aus dem textuellen erzeugt wird
my @ovfjlist;			# Liste aller ausgewerteten OV FJ mit Details der Kopfdaten
                  	# Elemente sind die %ovfjhash Daten
my @ovfjanztlnlist;	# Liste aller ausgewerteten OV FJ mit der Info über die Anzahl 
                     # der Teilnehmer, wird parallel zur @ovfjlist Liste geführt
my $patternsaved;		# Auswertungsmuster, die gespeichert wurden. Abgleich der aktuellen
                     # Auswertungsmuster mit diesen, falls das Programm beendet werden soll,
                     # um Datenverluste zu verhindern
my $overrides=undef;	# Overrides
my @pmvjarray;			# Array mit PMVJ Daten
my @pmaktarray;		# Array mit aktuellen PM Daten


$str = "*  OVJ ".$ovjvers." by DL3SDO, ".$ovjdate."  *";
print "\n".'*'x length($str)."\n";
print $str."\n";
print '*'x length($str)."\n";

my $mw = MainWindow->new;

my $menu_bar = $mw->Frame(-relief => 'raised', -borderwidth => 2)->pack(-side => 'top', -anchor => "nw", -fill => "x");
my $help = $menu_bar->Menubutton(-text => 'Datei', -menuitems => [
				[ Button => "Exit",-command => \&Leave]])
							->pack(-side => 'left');
my $help = $menu_bar->Menubutton(-text => 'Hilfe', , -menuitems => [
				[ Button => "Über",-command => \&About]])
							->pack(-side => 'left');
$menu_bar->Button(
        -text    => 'Exit',
        -command => \&Leave)->pack(-side => 'right');
$menu_bar->Label(-text => "OVJ $ovjvers by DL3SDO, $ovjdate")->pack;
    
my $fr1 = $mw->Frame(-borderwidth => 5, -relief => 'raised');
$fr1->pack;
$fr1->Label(-text => 'Generelle Daten')->pack;
my $fr11 = $fr1->Frame->pack(-side => 'left');
my $fr111 = $fr11->Frame->pack;
$fr111->Label(-text => 'Jahr')->pack(-side => 'left');
my $jahr = $fr111->Entry(-width => 4)->pack(-side => 'left');
$fr111->Button(
        -text => 'Importieren',
        -command => sub{do_file_general(3)}
    )->pack(-side => 'right',-padx => 1);
$fr111->Button(
        -text => 'Speichern',
        -command => sub{do_file_general(0)}
    )->pack(-side => 'right',-padx => 1);
$fr111->Button(
        -text => 'Laden',
        -command => sub{do_file_general(1)}
    )->pack(-side => 'right',-padx => 1);

my $fr112 = $fr11->Frame->pack;
my $distrikt = $fr112->Entry()->pack(-side => 'right');
$fr112->Label(-text => 'Distrikt')->pack(-side => 'left');

my $fr113 = $fr11->Frame->pack;
my $distriktskenner = $fr113->Entry(-width => 1)->pack(-side => 'right');
$fr113->Label(-text => 'Distriktskenner')->pack(-side => 'left');

my $fr12 = $fr1->Frame->pack(-side => 'left');
my $fr121 = $fr12->Frame->pack;
my $name = $fr121->Entry(-width => 16)->pack(-side => 'right');
$fr121->Label(-text => 'Name')->pack(-side => 'left');
my $fr122 = $fr12->Frame->pack;
my $vorname = $fr122->Entry(-width => 16)->pack(-side => 'right');
$fr122->Label(-text => 'Vorname')->pack(-side => 'left');
my $fr123 = $fr12->Frame->pack;
$fr123->Label(-text => 'CALL')->pack(-side => 'left');
my $call = $fr123->Entry(-width => 8)->pack(-side => 'left');
my $dok = $fr123->Entry(-width => 4)->pack(-side => 'right');
$fr123->Label(-text => 'DOK')->pack(-side => 'left');

my $fr13 = $fr1->Frame->pack(-side => 'left');
my $fr131 = $fr13->Frame->pack;
my $telefon = $fr131->Entry()->pack(-side => 'right');
$fr131->Label(-text => 'Telefon')->pack(-side => 'left');
my $fr132 = $fr13->Frame->pack;
my $homebbs = $fr132->Entry()->pack(-side => 'right');
$fr132->Label(-text => 'Home-BBS')->pack(-side => 'left');
my $fr133 = $fr13->Frame->pack;
my $email = $fr133->Entry()->pack(-side => 'right');
$fr133->Label(-text => 'E-Mail')->pack(-side => 'left');

my $fr14 = $fr1->Frame->pack(-side => 'left');
my $fr141 = $fr14->Frame->pack;
my $pmvj = $fr141->Entry(-width => 15)->pack(-side => 'right');
$fr141->Button(
        -text => 'PM Vorjahr',
        -command => sub{do_select_pmfile(0)}
    )->pack(-side => 'left');
my $fr142 = $fr14->Frame->pack;
my $pmaj = $fr142->Entry(-width => 15)->pack(-side => 'right');
$fr142->Button(
        -text => 'PM akt. Jahr',
        -command => sub{do_select_pmfile(1)}
    )->pack(-side => 'left');
my $fr143 = $fr14->Frame->pack;
my $nickfile = $fr143->Entry(-width => 15)->pack(-side => 'right');
$fr143->Button(
        -text => 'Spitznamen',
        -command => sub{do_get_nickfile()}
    )->pack(-side => 'left');

my $fr2 = $mw->Frame(-borderwidth => 5, -relief => 'raised');
$fr2->pack;
$fr2->Label(-text => 'Liste der OV Wettbewerbe')->pack;
my $fr21 = $fr2->Frame->pack();
my $fjlistbox = $fr21->Scrolled('Text',-scrollbars =>'oe',width => 40, height => 4)->pack(-side => 'left');
my $fr21b = $fr21->Frame->pack(-side => 'right');
$fr21b->Button(
        -text => 'Editieren/Erzeugen',
        -command => sub{do_edit_ovfj(0)}
    )->pack();
$fr21b->Button(
        -text => 'Erzeugen aus aktuellem OV Wettbewerb',
        -command => sub{do_edit_ovfj(1)}
    )->pack();
my $fr22 = $fr2->Frame()->pack();
$fr22->Button(
        -text => 'Alle OV Wettbewerbe auswerten und exportieren',
        -command => sub{do_eval_allovfj()}
    )->pack(-side => 'left');
my $reset_eval_button = $fr22->Button(
        -text => 'Auswertung im Speicher löschen',
        -command => sub{do_reset_eval()},
        -state => 'disabled'
    )->pack(-side => 'left');
my $fr23 = $fr2->Frame->pack();
my $exp_eval_button = $fr23->Button(
        -text => 'Auswertung exportieren',
        -command => sub{Export()},
        -state => 'disabled'
    )->pack(-side => 'left');

$fr23->Label(-text => 'Beim Export Teilnehmer ohne offizielle Veranstaltung im akt. Jahr ausschliessen')->pack(-side => 'left');
my $check_ExcludeTln = $fr23->Checkbutton()->pack(-side => 'left');

my $fr4 = $mw->Frame(-borderwidth => 5, -relief => 'raised');
$fr4->pack;
$fr4->Label(-text => 'Liste der Auswertungsmuster')->pack;
my $fr41 = $fr4->Frame->pack(-side => 'left');
my $patterns = $fr41->Scrolled('Text',-scrollbars =>'oe',-width => 91, -height => 4)->pack();
my $fr42 = $fr4->Frame->pack(-side => 'right');
$fr42->Button(
        -text => 'Speichern',
        -command => sub{do_save_patterns()}
    )->pack();
my $copy_pattern_button = $fr42->Button(
        -text => 'Kopiere',
        -command => sub{do_copy_pattern()},
        -state => 'disabled'
    )->pack();

my $fr3 = $mw->Frame(-borderwidth => 5, -relief => 'raised');
$fr3->pack;
my $ovfjnamelabel = $fr3->Label(-text => 'OV Wettbewerb:')->pack();
my $fr30 = $fr3->Frame->pack(-side => 'top');
my $ovfj_save_button = $fr30->Button(
        -text => 'Speichern',
        -command => sub{do_write_ovfjfile()},
        -state => 'disabled'
        )
		->pack(-side => 'left',-padx => 2);
my $ovfj_eval_button = $fr30->Button(
        -text => 'Auswertung',
        -command => sub{do_eval_ovfj(0)},
        -state => 'disabled'
        )
		->pack(-side => 'left',-padx => 2);


my $fr3b = $fr3->Frame->pack();

my $fr31 = $fr3b->Frame->pack(-side => 'left');
my $fr311 = $fr31->Frame->pack;
$fr311->Label(-text => 'Ausricht. OV')->pack(-side => 'left');
my $ovname = $fr311->Entry()->pack(-side => 'left');
my $ovnum = $fr311->Entry(-width => 4)->pack(-side => 'right');
$fr311->Label(-text => 'DOK')->pack(-side => 'left');
my $fr313 = $fr31->Frame->pack;
$fr313->Label(-text => 'Datum')->pack(-side => 'left');
my $datum = $fr313->Entry(-width => 10)->pack(-side => 'left');
$fr313->Label(-text => 'Band')->pack(-side => 'left');
my $band = $fr313->Entry(-width => 2)->pack(-side => 'left');
$fr313->Label(-text => 'Anz. Teilnehmer manuell')->pack(-side => 'left');
my $anztlnmanuell = $fr313->Entry(-width => 2)->pack(-side => 'left');
my $fr315 = $fr31->Frame->pack;
my $ovfj_fileset_button = $fr315->Button(
        -text => 'OVFJ Auswertungsdatei',
        -state => 'disabled',
        -command => sub{do_select_fjfile()}
    )->pack(-side => 'left');
my $fjfile = $fr315->Entry(-width => 27)->pack(-side => 'right');

my $fr32 = $fr3b->Frame->pack(-side => 'left');
my $fr321 = $fr32->Frame->pack;
my $verantname = $fr321->Entry()->pack(-side => 'right');
$fr321->Label(-text => 'Name')->pack(-side => 'left');
my $fr325 = $fr32->Frame->pack;
my $verantvorname = $fr325->Entry()->pack(-side => 'right');
$fr325->Label(-text => 'Vorname')->pack(-side => 'left');
my $fr322 = $fr32->Frame->pack;
$fr322->Label(-text => 'CALL')->pack(-side => 'left');
my $verantcall = $fr322->Entry(-width => 8)->pack(-side => 'left');
$fr322->Label(-text => 'DOK')->pack(-side => 'left');
my $verantdok = $fr322->Entry(-width => 4)->pack(-side => 'left');
my $verantgeb = $fr322->Entry(-width => 4)->pack(-side => 'right');
$fr322->Label(-text => 'Geburtsjahr')->pack(-side => 'left');

my $fr33 = $fr3->Frame->pack();
#$fr33->Button(
#        -text => 'Teste Muster',
#        -state => 'disabled',
#        -command => sub{do_test_pattern()}
#    )->pack(-side => 'left');
$fr33->Label(-text => 'Muster')->pack(-side => 'left');
my $ovjpattern = $fr33->Entry(-width => 70)->pack(-side => 'right');

my $fr4 = $mw->Frame(-borderwidth => 5, -relief => 'raised');
$fr4->pack;
$fr4->Label(-text => 'Meldungen')->pack;
my $meldung = $fr4->Scrolled('Listbox',-scrollbars =>'e',-width => 116, -height => 12)->pack();

do_file_general(2);	# Lade Generelle Daten Datei falls vorhanden
do_read_patterns();	# Lade die Musterdatei (sollte vorhanden sein, ansonsten bleibt die Liste
							# halt leer

unless (-e $configpath && -d $configpath)
{
	mkdir($configpath);
	$meldung->insert('end',"Erzeuge Verzeichnis \'".$configpath."\'");
}
unless (-e $reportpath && -d $reportpath)
{
	mkdir($reportpath);
	$meldung->insert('end',"Erzeuge Verzeichnis \'".$reportpath."\'");
}
unless (-e $outputpath && -d $outputpath)
{
	mkdir($outputpath);
	$meldung->insert('end',"Erzeuge Verzeichnis \'".$outputpath."\'");
}
unless (-e $inputpath && -d $inputpath)
{
	$meldung->insert('end',"Warnung: Verzeichnis \'".$outputpath."\' nicht vorhanden");
}

$fjlistsaved = $fjlistbox->Contents();
MainLoop;

#Auswahl der FJ Datei per Button
#und Pruefen, ob automatisch OVFJ Kopfdaten ausgefuellt werden koennen
sub do_select_fjfile {
	my $FSref = $fr3->FileSelect(-directory => $inputpath);
	my $selfile = $FSref->Show;
	return if ($selfile eq "");
	my $tp;
	my @fi;
	$selfile =~ s/^.*\///;
	$fjfile->delete(0,"end");
	$fjfile->insert(0,$selfile);

	if (!open (INFILE, $inputpath."\\".$selfile))
	{
		$meldung->insert('end',"FEHLER: Kann OVFJ Datei ".$selfile." nicht lesen");
		return;
	}
	while (<INFILE>)
	{
		if (/^Organisation:\s*(.+)$/)
		{
			$tp = $1;
			$tp =~ s/^OV\s+//;
			$tp =~ s/\s+$//;
			$ovname->delete(0,"end");
			$ovname->insert(0,$tp);
			next;
		}
		if (/^DOK:\s*([A-Z]\d{2})$/i) # Case insensitive
		{
			$tp = uc($1);
			$tp =~ s/\s+$//;
			$ovnum->delete(0,"end");
			$ovnum->insert(0,$tp);
			next;
		}
		if (/^Datum:\s*(\d{1,2}\.\d{1,2}\.\d{2,4})$/)
		{
			$tp = $1;
			$tp =~ s/\s+$//;
			$datum->delete(0,"end");
			$datum->insert(0,$tp);
			next;
		}
		if (/^Verantwortlich:\s*(.+)$/)
		{
			$tp = $1;
			$tp =~ s/\s+$//;
			$tp =~ tr/,/ /;
			@fi = split(/\s+/,$tp);
			$verantvorname->delete(0,"end");
			$verantvorname->insert(0,$fi[0]) if (@fi >= 1);
			$verantname->delete(0,"end");
			$verantname->insert(0,$fi[1]) if (@fi >= 2);
			$verantcall->delete(0,"end");
			$verantcall->insert(0,uc($fi[2])) if (@fi >= 3);
			$verantdok->delete(0,"end");
			$verantdok->insert(0,uc($fi[3])) if (@fi >= 4);
			$verantgeb->delete(0,"end");
			$verantgeb->insert(0,$fi[4]) if (@fi >= 5);
			next;
		}
		if (/^Teilnehmerzahl:\s*(\d+)/)
		{
			$anztlnmanuell->delete(0,"end");
			$anztlnmanuell->insert(0,$1);
			next;
		}
		if (/^Band:\s*(\d{1,2})/)
		{
			$band->delete(0,"end");
			$band->insert(0,$1);
			next;
		}
		last if (/^---/);		# Breche bei --- ab 
	}
	close (INFILE) || die "close: $!";
}

#Auswahl der Spitznamen Datei per Button
sub do_get_nickfile {
	my $FSref = $fr1->FileSelect(-directory => '.');
	my $selfile = $FSref->Show;
	return if ($selfile eq "");
	$selfile =~ s/^.*\///;
	$nickfile->delete(0,"end");
	$nickfile->insert(0,$selfile);
}

#Speichern der Pattern Datei
sub do_save_patterns {
	if (!open (OUTFILE, ">".$patternfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$patternfilename." nicht schreiben");
		return;
	}
	$_= $patterns->Contents();
	chomp;
	printf OUTFILE $_;
	$patternsaved = $_;
	close (OUTFILE) || die "close: $!";
}

#Lesen der Pattern Datei
sub do_read_patterns {
	return unless (-e $patternfilename);
	if (!open (INFILE, $patternfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$patternfilename." nicht öffnen");
		return;
	}
	else
	{
		local $/ = undef;
		$_ = <INFILE>;										# alles einlesen
		close (INFILE) || die "close: $!";
		$patterns->Contents($_);
		$patternsaved = $_;
	}
}

#Ueberpruefen beim Beenden des Programms, ob aktuelle Auswertungsmuster
#gespeichert wurden, und falls nicht, was passieren soll
sub CheckForUnsavedPatterns {
	$_= $patterns->Contents();
	chomp;
	return 0 if ($_ eq $patternsaved);
	my $response = $mw->messageBox(-icon => 'question', 
											-message => "Liste der Auswertungsmuster wurden geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => 'Auswertungsmuster speichern?', 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	do_save_patterns() if ($response eq "Yes");
	return 0;
}

#Auswahl der PMVorjahr (0) oder aktuellen (else) PM Datei per Button
sub do_select_pmfile {
	my ($choice) = @_;
	my $FSref = $fr1->FileSelect(-directory => '.');
	my $selfile = $FSref->Show;
	return if ($selfile eq "");
	$selfile =~ s/^.*\///;
	if ($choice == 0)
	{
		$pmvj->delete(0,"end");
		$pmvj->insert(0,$selfile);
	}
	else
	{
		$pmaj->delete(0,"end");
		$pmaj->insert(0,$selfile);
	}
}

#Kopieren des markierten Patterns in die Patternzeile des OV Wettbewerbs
sub do_copy_pattern {
	$_ = $patterns->Contents(); # erstmal
	my @patlist = split(/\n/); # die Daten im Speicher aktualisieren
	$_ = $patterns->getSelected();
	my @patlines = split(/\n/);
	if ($#patlines > 0)
		{
			$meldung->insert('end',"FEHLER: Nur eine Zeile markieren !");
			return;
		}
	if (!grep {$_ eq $patlines[0]} @patlist)
	{
			$meldung->insert('end',"FEHLER: Ganze Zeilen markieren !");
			return;
	}
	$patlines[0] =~ s/\/\/.*$//;	# Entferne Kommentare beim Kopieren
	$patlines[0] =~ s/\s+$//;		# Entferne immer Leerzeichen nach dem Muster
	$ovjpattern->delete(0,"end");
	$ovjpattern->insert(0,$patlines[0]);
}

#Speichern, Laden bzw. Erzeugen der Generellen Daten Datei
sub do_file_general {
	my ($choice) = @_;	# 0 = Speichern, 1 = Laden, 2 = im Verzeichnis vorhandene nehmen, 3 = Importieren
	
	if ($choice == 3)	# Importieren
	{	
		return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
		my $FSref = $fr1->FileSelect(-directory => '.');
		$genfilename = $FSref->Show;
		return if ($genfilename eq "");
		return(read_genfile(1));
	}
	
	if ($choice == 2) # lade Generelle Daten Datei falls vorhanden (nehme die letzte)
	{
		my @PotGenFiles = glob($configpath."\\OVJ_Generell_*.txt");
		if (@PotGenFiles > 0)
		{
			$genfilename = pop (@PotGenFiles);
			$genfilename =~ s/^.*?\\//;
			$choice = 1;
		}
		else
		{
			return 1;	# prinzipiell erfolgreich, trotzdem Rueckgabewert 1
		}
	}
	else
	{
		$year = $jahr->get;
		if ($year !~ /^\d{4}$/)
		{
			$meldung->insert('end',"FEHLER: Jahr ist keine gültige Zahl");
			return 1;	# Fehler
		}
		$genfilename = "OVJ_Generell_".$year.".txt";
	}

	if ($choice == 1)	# Laden
	{	
		return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
		if (-e $configpath."\\".$genfilename)
		{
			$meldung->insert('end',"Lade ".$genfilename);
			return(read_genfile(0));
		}
		else
		{
			$meldung->insert('end',"Kann ".$genfilename."nicht laden! Datei existiert nicht");
			return 1;	# Fehler
		}
	}
	else	# Speichern
	{
		if (-e $configpath."\\".$genfilename)
		{
			$meldung->insert('end',"Speichere ".$genfilename);
		}
		else
		{
			$meldung->insert('end',"Erzeuge ".$genfilename);
		}
		return(write_genfile());
	}
}

#Schreiben der Generellen Daten in die Genfile Datei
sub write_genfile {
	if (!open (OUTFILE, ">".$configpath."\\".$genfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$genfilename." nicht schreiben");
		return 1;	# Fehler
	}
	update_genhash(0);	# Hash aktualisieren auf Basis der Felder
	printf OUTFILE "#OVJ Toplevel-Datei für ".$year."\n\n";
	my $key;
	foreach $key (keys %genhash) {
		printf OUTFILE $key." = ".$genhash{$key}."\n";
	}
	printf OUTFILE "\n";
	$_ = $fjlistbox->Contents();
	my @fjlines = split(/\n/);
	foreach $str (@fjlines)
	{
		printf OUTFILE "ovfj_link = ".$str."\n";
	}
	%genhashsaved = %genhash;
	$fjlistsaved = $_;
	close (OUTFILE) || die "close: $!";
	return 0;	# kein Fehler
}

#Aktualisieren der aktuellen Generellen Daten im Hash
sub update_genhash {
	my ($mode) = @_;	# 0 = Update, 1 = Vergleich mit gespeicherten Daten
	my %genhashtemp;
	my ($key,$value);
		
	%genhashtemp = ("Jahr" => $jahr->get,
						"Distrikt" => $distrikt->get,
						"Distriktskenner" => $distriktskenner->get,
	   	         "Name" => $name->get,
	      	      "Vorname" => $vorname->get,
	         	   "Call" => $call->get,
	            	"DOK" => $dok->get,
		            "Telefon" => $telefon->get,
		            "Home-BBS" => $homebbs->get,
	   	         "E-Mail" => $email->get,
	      	      "PMVorjahr" => $pmvj->get,
	         	   "PMaktJahr" => $pmaj->get,
		            "Spitznamen" => $nickfile->get,
		            "Exclude_Checkmark" => $check_ExcludeTln->{'Value'}
	   	         );
	if ($mode == 0)
	{
		%genhash = %genhashtemp;
		return 0;
	}
	while (($key,$value) = each(%genhashtemp))
	{
		return 1 if ($genhashsaved{$key} ne $value); # Diskrepanz, also 1 zurückgeben
	}
	return 0;	# alles ok
}

#Lesen der Generellen Daten aus der Genfile Datei
sub read_genfile {
	my ($choice) = @_;	# 0 = Laden, 1 = Importieren

	if (!open (INFILE, ($choice == 0 ? $configpath."\\" : "").$genfilename))
	{
	$meldung->insert('end',"FEHLER: Kann ".$genfilename." nicht lesen");
	return 1;	# Fehler
	}

	$fjlistbox->selectAll();
	$fjlistbox->deleteSelected();
	while (<INFILE>)
	{
		next if /^#/;
		next if /^\s/;
		#print $_."\n";
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s+$/)
		{
			if ($1 eq "ovfj_link" && $choice == 0)
			{
				push(@fjlist,$2);
				$fjlistbox->insert("end",$2."\n");
			}
			$genhash{$1} = $2;
			#print $1."=".$2;
		}
	}
	close (INFILE) || die "close: $!";
	$jahr->delete(0,"end");
	$jahr->insert(0,$genhash{"Jahr"}) if ($choice == 0);
	$year = $genhash{"Jahr"};
	$distrikt->delete(0,"end");
	$distrikt->insert(0,$genhash{"Distrikt"});
	$distriktskenner->delete(0,"end");
	$distriktskenner->insert(0,$genhash{"Distriktskenner"});
	$name->delete(0,"end");
	$name->insert(0,$genhash{"Name"});
	$vorname->delete(0,"end");
	$vorname->insert(0,$genhash{"Vorname"});
	$call->delete(0,"end");
	$call->insert(0,$genhash{"Call"});
	$dok->delete(0,"end");
	$dok->insert(0,$genhash{"DOK"});
	$telefon->delete(0,"end");
	$telefon->insert(0,$genhash{"Telefon"});
	$homebbs->delete(0,"end");
	$homebbs->insert(0,$genhash{"Home-BBS"});
	$email->delete(0,"end");
	$email->insert(0,$genhash{"E-Mail"});
	$pmvj->delete(0,"end");
	$pmvj->insert(0,$genhash{"PMVorjahr"}) if ($choice == 0);
	$pmaj->delete(0,"end");
	$pmaj->insert(0,$genhash{"PMaktJahr"}) if ($choice == 0);
	$nickfile->delete(0,"end");
	$nickfile->insert(0,$genhash{"Spitznamen"});
	$check_ExcludeTln->{'Value'} = $genhash{"Exclude_Checkmark"};
	
	%genhashsaved = %genhash;
	$fjlistsaved = $fjlistbox->Contents();
	update_genhash(0) if ($choice == 1);	# einige Hashwerte löschen
	return 0;	# kein Fehler
}

#Prüfen, ob Generelle Daten verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForSaveGenfile {
	return 0 if (update_genhash(1)==0);
	my $response = $mw->messageBox(-icon => 'question', 
											-message => "Generelle Daten wurden geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => 'Generelle Daten speichern?', 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	return(do_file_general(0)) if ($response eq "Yes");
	return 0;
}

#Prüfen, ob OV Wettbewerbsliste (Teil der Generellen Daten) verändert wurde, 
#ohne gespeichert worden zu sein
sub CheckForOVFJList {
	return 0 if ($fjlistsaved eq $fjlistbox->Contents());
	my $response = $mw->messageBox(-icon => 'question', 
											-message => "Liste der OV Wettbewerbe wurde geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => 'Generelle Daten speichern?', 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	return(do_file_general(0)) if ($response eq "Yes");
	return 0;
}

#Auswahl einer Veranstaltung durch den Anwender
sub do_edit_ovfj {
	my ($choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb. Wird durchgereicht.
	$_ = $fjlistbox->Contents(); # erstmal
	@fjlist = split(/\n/); # die Daten im Speicher aktualisieren
	#print @fjlist."\n".$fjlistbox->Contents()."\n";
	$_ = $fjlistbox->getSelected();
	my @fjlines = split(/\n/);
	if ($#fjlines > 0)
		{
			$meldung->insert('end',"FEHLER: Nur eine Veranstaltung markieren !");
			return;
		}
	if (!grep {$_ eq $fjlines[0]} @fjlist)
	{
			$meldung->insert('end',"FEHLER: Ganze Veranstaltung markieren !");
			return;
	}
	CreateEdit_ovfj($fjlines[0],$choice);
	$ovfjname = $fjlines[0];
}

#Prüfen, ob OVFJ Veranstaltung verändert wurde, ohne gespeichert worden zu
#sein
sub CheckForOverwriteOVFJ {
	return 0 if !defined(%ovfjhash);
	return 0 if (update_ovfjhash(1)==0);
	my $response = $mw->messageBox(-icon => 'question', 
											-message => "Kopfdaten zum OV Wettbewerb ".$ovfjname." wurden geändert\nund noch nicht gespeichert.\n\nSpeichern?", 
											-title => 'OVFJ Daten speichern?', 
											-type => 'YesNoCancel', 
											-default => 'Yes');
	return 1 if ($response eq "Cancel");
	do_write_ovfjfile() if ($response eq "Yes");
	return 0;
}

#Anlegen bzw. Editieren einer OVFJ Veranstaltung
sub CreateEdit_ovfj {
	my ($ovfjf_name,$choice) = @_;	# Beim Erzeugen: 0 = neu, 1 = aus aktuellem OV Wettbewerb
	
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	
	$ovfjnamelabel->configure(-text => "OV Wettbewerb: ".$ovfjf_name);
	$ovfjfilename = $ovfjf_name."_ovj.txt";
	$ovfjrepfilename = $ovfjf_name."_report_ovj.txt";
	if (-e $configpath."\\".$ovfjfilename)
	{
		read_ovfjfile();
	}
	else
	{
		if ($choice == 0)
		{
			Clear_ovfj();
		}
		else
		{
			$datum->delete(0,"end");
			$fjfile->delete(0,"end");
		}
		update_ovfjhash(0);
		Show_ovfj();
	}
	$ovfj_fileset_button->configure(-state => 'normal');
	$ovfj_save_button->configure(-state => 'normal');
	$copy_pattern_button->configure(-state => 'normal');
	if (exists($auswerthash{$ovfjf_name}))
	{
		$ovfj_eval_button->configure(-state => 'disabled');
	}
	else
	{
		$ovfj_eval_button->configure(-state => 'normal');
	}
}

#Lesen der Daten aus einer OVFJ Datei
sub read_ovfjfile {
	if (!open (INFILE, $configpath."\\".$ovfjfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$ovfjfilename." nicht lesen");
		return;
	}

	while (<INFILE>)
	{
		next if /^#/;
		next if /^\s/;
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s+$/)
		{
			$ovfjhash{$1} = $2;
			#print $1."=".$2;
		}
	}
	close (INFILE) || die "close: $!";
	Show_ovfj();
	%ovfjhashsaved = %ovfjhash;
}

#Anzeige der aktuellen OVFJ Daten
sub Show_ovfj {
	Clear_ovfj();
	$ovname->insert(0,$ovfjhash{"AusrichtOV"});
	$ovnum->insert(0,$ovfjhash{"AusrichtDOK"});
	$datum->insert(0,$ovfjhash{"Datum"});
	$band->insert(0,$ovfjhash{"Band"});
	$anztlnmanuell->insert(0,$ovfjhash{"TlnManuell"});
	$verantname->insert(0,$ovfjhash{"Verantw_Name"});
	$verantvorname->insert(0,$ovfjhash{"Verantw_Vorname"});
	$verantcall->insert(0,$ovfjhash{"Verantw_CALL"});
	$verantdok->insert(0,$ovfjhash{"Verantw_DOK"});
	$verantgeb->insert(0,$ovfjhash{"Verantw_GebJahr"});
	$fjfile->insert(0,$ovfjhash{"OVFJDatei"});
	$ovjpattern->insert(0,$ovfjhash{"Auswertungsmuster"});
}

#Löschen der OVFJ Einträge in der Oberfläche
sub Clear_ovfj {
	$ovname->delete(0,"end");
	$ovnum->delete(0,"end");
	$datum->delete(0,"end");
	$band->delete(0,"end");
	$anztlnmanuell->delete(0,"end");
	$verantname->delete(0,"end");
	$verantvorname->delete(0,"end");
	$verantcall->delete(0,"end");
	$verantdok->delete(0,"end");
	$verantgeb->delete(0,"end");
	$fjfile->delete(0,"end");
	$ovjpattern->delete(0,"end");
}	

#Aktualisieren der aktuellen OVFJ Daten im Hash
sub update_ovfjhash {
	my ($mode) = @_;	# 0 = Update, 1 = Vergleich mit gespeicherten Daten
	my %ovfjhashtemp;
	my ($key,$value);
	%ovfjhashtemp = ("AusrichtOV" => $ovname->get,
		            "AusrichtDOK" => uc($ovnum->get),
		            "Datum" => $datum->get,
		            "Band" => $band->get,
		            "TlnManuell" => $anztlnmanuell->get,
		            "Verantw_Name" => $verantname->get,
		            "Verantw_Vorname" => $verantvorname->get,
		            "Verantw_CALL" => uc($verantcall->get),
		            "Verantw_DOK" => uc($verantdok->get),
		            "Verantw_GebJahr" => $verantgeb->get,
		            "OVFJDatei" => $fjfile->get,
		            "Auswertungsmuster" => $ovjpattern->get
		            );
	if ($mode == 0)
	{
		%ovfjhash = %ovfjhashtemp;
		return 0;
	}
	while (($key,$value) = each(%ovfjhashtemp))
	{
		return 1 if ($ovfjhashsaved{$key} ne $value); # Diskrepanz, also 1 zurückgeben
	}
	return 0;	# alles ok
}

#Schreiben der aktuellen OVFJ Daten
sub do_write_ovfjfile {
	if (!open (OUTFILE, ">".$configpath."\\".$ovfjfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$ovfjfilename." nicht schreiben");
		return;
	}
	update_ovfjhash(0);
	printf OUTFILE "#OVFJ Datei\n";
	my $key;
	foreach $key (keys %ovfjhash) {
		printf OUTFILE $key." = ".$ovfjhash{$key}."\n";
	}
	close (OUTFILE) || die "close: $!";
	%ovfjhashsaved = %ovfjhash;
}

#Löschen aller Auswertungen im Speicher
sub do_reset_eval {
	undef %tn;
	undef %auswerthash;
	undef @ovfjlist;
	undef @ovfjanztlnlist;
	$reset_eval_button->configure(-state => 'disabled');
	$ovfj_eval_button->configure(-state => 'normal');
	$exp_eval_button->configure(-state => 'disabled');
	$lfdauswert=0;
	$meldung->delete(0,"end");
}

#Lesen der Spitznamen Datei
sub get_nicknames {
	if ($genhash{"Spitznamen"} eq "")
	{
		$meldung->insert('end',"HINWEIS: Keine Spitznamen Datei spezifiziert");
		return;
	}	
	
	if (!open (INFILE, $genhash{"Spitznamen"}))
	{
		$meldung->insert('end',"FEHLER: Kann Spitznamen Datei ".$genhash{"Spitznamen"}." nicht lesen");
		return;
	}
	else
	{
		local $/ = undef;
		$_ = <INFILE>;										# alles einlesen
		close (INFILE) || die "close: $!";
	}
	s/^#.*?$//mg;
	$nicknames = $_;
}

#Lesen der Override Datei (falls vorhanden)
#Format: Name,Vorname,Rufzeichen,DOK,Gebjahr,NichtInPMVJ|IstInPMVJ
sub get_overrides {
	my $line = 0;
	$overrides = undef;
	return unless (-e $overridefilename);
	if (!open (INFILE, $overridefilename))
	{
		$meldung->insert('end',"FEHLER: Kann Override Datei ".$overridefilename." nicht lesen");
		return;
	}
	while (<INFILE>)
	{
		$line++;
		chomp;
		next if (/^#/);		# Kommentarzeilen ueberspringen
		next if (/^\W+/);		# Zeilen, die nicht mit einem Buchstaben beginnen ueberspringen
		next if ($_ eq "");	# Leerzeilen ueberspringen
		unless (/^[-a-zA-ZäöüÄÖÜß]+,[-a-zA-ZäöüÄÖÜß]+,(|---|\w+),(|---|\w+),(|\d{4}),(NichtInPMVJ|IstInPMVJ|)\s*$/)
		{
			$meldung->insert('end',"FEHLER: Formatfehler in Zeile ".$line." der Overridedatei: ".$_);
			next;
		}
		$overrides .= $_."\n";
	}
	#$meldung->insert('end',"INFO: Override Datei eingelesen");
	close (INFILE) || die "close: $!";
}
	
#Vergleiche Zeile aus Auswertungsdatei mit Pattern
sub MatchPat {
	my ($line) = @_;
	
	my $patmatched = 0;
	my $platz = "";
	my ($nachname,$vorname,$gebjahr) = ("","","");
	my ($call,$dok) = ("","");
	my ($quest,$kw);
	my $validkeyword;
	
	local $_ = $ovjpattern->get;
	s/^\s+//; # entferne evtl. vorhandene Leerzeichen am Anfang
	s/\s+$//; # und am Ende
	
	$line =~ s/^\s+//; # entferne evtl. vorhandene Leerzeichen am Anfang
	$line .= ' ';	# fuer den Sonderfall, dass am Ende optionale Elemente (d.h. mit Schlüsselwort?) kommen
						# wenn das Schlüsselwort? nach einem Leerzeichen folgt, so wuerden normale Matches das Leerzeichen
						# am Ende erwarten.
	
	while ($_ ne "")
	{
		if (/^([A-Z][a-z]+\??)/)
		{
			$quest = 0;
			$validkeyword = 0;
			$kw = $1;
			if ($kw =~ /\?$/)
			{
				$quest = 1;
				$kw =~ s/\?$//;
			}
			if ($kw eq "Platz")
			{
				$validkeyword = 1;
				if ($line =~ /^(\d+)\b/)
				{
					$platz = $1;
					$line =~ s/^\d+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Sender")
			{
				$validkeyword = 1;
				if ($line =~ /^\d+\b/)
				{
					$line =~ s/^\d+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Geburtsjahr" || $kw eq "Gebjahr")
			{
				$validkeyword = 1;
				if ($line =~ /^(\d{4})\b/)
				{
					$gebjahr = $1;
					$line =~ s/^\d+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Zeit")
			{
				$validkeyword = 1;
				if ($line =~ /^[.:0-9]+\b/)
				{
					$line =~ s/^[.:0-9]+\b//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Dok")
			{
				$validkeyword = 1;
				if ($line =~ /^(\S+)/)
				{
					$dok = uc($1);
					$dok = "---" if ($dok !~ /^[A-Z]\d\d$/);
					$line =~ s/^\S+//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Call" || $kw eq "Rufzeichen")
			{
				$validkeyword = 1;
				if ($line =~ /^(\S+)/)
				{
					$call = uc($1);
					$call = "---" if ($call =~ /^[A-Z]+$/ || $call =~ /^-+$/);
					$line =~ s/^\S+//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Egal" || $kw eq "Ignorier" || $kw eq "Ignoriere")
			{
				$validkeyword = 1;
				if ($line =~ /^\S+/)
				{
					$line =~ s/^\S+//;
				}
				else
				{
					if ($quest == 0) {return (0,$kw);} # Fehlschlag
				}
			}
			if ($kw eq "Nachname")
			{
				$validkeyword = 1;
				if ($line =~ /^\"([^"]+)\"/)
				{
					$nachname = $1;
					$line =~ s/^\"[^"]+\"//;
				}
				else
				{
					if ($line =~ /^([-a-zA-ZäöüÄÖÜß]+)/)
					{
						$nachname = $1;
						$line =~ s/^[-a-zA-ZäöüÄÖÜß]+//;
					}
					else
					{
						if ($quest == 0) {return 0;} # Fehlschlag
					}
				}
			}
			if ($kw eq "Vorname")
			{
				$validkeyword = 1;
				if ($line =~ /^\"([^"]+)\"/)
				{
					$vorname = $1;
					$line =~ s/^\"[^"]+\"//;
				}
				else
				{
					if ($line =~ /^([-a-zA-ZäöüÄÖÜß]+)/)
					{
						$vorname = $1;
						$line =~ s/^[-a-zA-ZäöüÄÖÜß]+//;
					}
					else
					{
						if ($quest == 0) {return (0,$kw);} # Fehlschlag
					}
				}
			}

			return (0,$kw." ist kein Schlüsselwort") if ($validkeyword != 1);	 # illegales Wort
			s/^([A-Z][a-z]+)//;	 # entferne Schluesselwort

			if ($quest == 1)
			{
				s/^\?//;
				$line = " ".$line;	# füge Leerzeichen am Anfang hinzu, weil Leerzeichen im Muster sonst
				                     # nicht gefunden werden.
			}

		} # Ende Wortoperation
		else {
		if (/^(\w+)/)
			{
				return (0,$1." ist kein Schlüsselwort");	 # illegales Wort
			}
		}
		if (/^\s+/)
		{
			if ($line =~ /^\s+/)
			{
				$line =~ s/^\s+//;
			}
			else
			{
				return (0,"Leerzeichen"); # Fehlschlag
			}
			s/^\s+//;
			next;
		}
		if (/^(\S+)/)
		{
			if ($line =~ /^($1)/)
			{
				$line =~ s/^$1//;
			}
			else
			{
				return (0,"Sonstige Zeichen"); # Fehlschlag
			}
			s/^\S+//;
		}
	}
	
	return (1,$platz,$nachname,$vorname,$gebjahr,$call,$dok);
}


#Auswertung und Export aller OVFJ
sub do_eval_allovfj {
	my $i = 0;
	do_reset_eval();
	$_ = $fjlistbox->Contents();
	my @fjlines = split(/\n/);
	foreach $str (@fjlines)
	{
		$ovfjname = $str;
		next if ($ovfjname !~ /\S+/);
		CreateEdit_ovfj($ovfjname,0);
		do_eval_ovfj($i++);
	}
	Export();
}

#Suche in PM Daten
sub SucheTlnInPM {
	local *FH = shift;
	my ($pmarray,$nachname,$vorname,$gebjahr,$call,$dok,$override_IsInPmvj,$CheckInAktPM) = @_;
	my ($rest,$name);
	my ($nname,$vname);
	my $callmismatch = 0;
	my $arindex;
	my (@mlist,@mlist2,@mlist3,@nicklist,$listelem,$lelem2);
	my $PMJahr = $CheckInAktPM == 0 ? "PMVorjahr" : "akt. PM Daten";
	my $foundbydokgeb;
	my $foundnachname = 0;
	
	if ($override_IsInPmvj == 2)
	{
		RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." durch Override 'NichtInPMVJ' von Suche in ".$PMJahr." ausgeschlossen");
		return (0,"Ausschluss wegen Override 'NichtInPMVJ'");
	}
	
	if ($call ne "---" && $call ne "" && uc($call) ne "SWL")	# Rufzeichen vorhanden
	{
		$callmismatch = 1;	# fuer unten merken
		for ($arindex = 0; $arindex < @$pmarray; $arindex++)
		{# ueber Call gefunden
			#print "Call ".$call." gefunden\n";
			#print "Call ".$pmarray->[$arindex]->[2]."\n";
			if ($pmarray->[$arindex]->[2] eq $call)
			{
				$callmismatch = 0;
				$nname = $pmarray->[$arindex]->[0];
				$vname = $pmarray->[$arindex]->[1];
				$rest = $pmarray->[$arindex];
				if ($nname eq $$nachname && $vname eq $$vorname)
				{
					return (1,"Call,Nachname,Vorname",$rest);		# Gefunden ueber Rufzeichen, Nachname und Vorname
				}
			
				if ($nname eq $$nachname)
				{ # Nachname stimmt, aber nicht der Vorname
					if ($nicknames =~ /^(".*?$$vorname.*)$/m)
						{
							$_ = $1;
							if (/\"$vname\"/)
							{
							RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$$nachname.", ".$vname." ueber Rufzeichen und Spitznamen in ".$PMJahr." gefunden, verwende neuen Vornamen");
							$$vorname = $vname;
							return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname
							}
						}
					RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$$nachname.", ".$vname." ueber Rufzeichen in ".$PMJahr." gefunden, verwende neuen Vornamen");
					$$vorname = $vname;
					return (5,"Call,Nachname;Vorname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Nachname und ersetzten Vorname				
				}
			
				if ($vname eq $$vorname)
				{ # Vorname stimmt, aber nicht der Nachname
					RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$$vorname." ueber Rufzeichen in ".$PMJahr." gefunden, verwende neuen Nachnamen");
					$$nachname = $nname;
					return (11,"Call,Vorname;Nachname ersetzt",$rest);		# Gefunden ueber Rufzeichen, Vorname; Nachname passt nicht
				}
			
				if ($dok ne "---" && $dok ne "") # jetzt zusaetzlich Abgleich ueber DOK 
				{
					if ($rest =~ /^\"$call\",\"$dok\"/)
					{# Vorname und Nachname stimmen nicht, aber DOK !
						RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen und DOK in ".$PMJahr." gefunden, verwende neue Namen");
						$$nachname = $nname;
						$$vorname = $vname;
						return (12,"Call,DOK",$rest);		# Gefunden ueber Rufzeichen, DOK; Vorname, Nachname passen nicht
					}
					else
					{# Vorname und Nachname und DOK stimmen nicht
						RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen aber mit falschem DOK in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
						return (0,"Call",$rest);		# Gefunden ueber Rufzeichen; DOK, Vorname, Nachname passen nicht
					}
				}
				else
				{
					RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." als ".$nname.", ".$vname." ueber Rufzeichen (kein DOK in OVFJ) in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
					return (0,"Call",$rest);		# Gefunden ueber Rufzeichen; Vorname, Nachname passen nicht; DOK nicht vorhanden zum Pruefen
				}
			}
		} # Ende Rufzeichen passt
	} # Ende Suche ueber Rufzeichen
	
	# Jetzt Suche ueber Namen, Vornamen und DOK
	# zunaechst alle mit passenden Nachnamen heraussuchen
	for ($arindex = 0; $arindex < @$pmarray; $arindex++)
	{
		if ($pmarray->[$arindex]->[0] eq $$nachname)
		{
			#print $$nachname.", ".$_."\n";
			$foundnachname = 1;
			push (@mlist,$pmarray->[$arindex]);
		}
		else
		{
			last if ($foundnachname == 1);	# Nachnamen sind zusammenhaengend in PM Datei, verlasse Schleife sobald 
														# nach gefundenen Nachnamen der erste nicht mehr stimmt
		}
	}
	if (@mlist == 0)	# kein Eintrag mit passenden Nachnamen gefunden
	{
		return (0,"",undef);		# Nicht ueber Nachname gefunden, verwerfe Eintrag
	}	
	foreach $listelem (@mlist) {
		#print $listelem."\n";
		if ($nicknames =~ /^(".*?$$vorname.*)$/m)
		{
			$_ = $1;
			tr/\"//d;							# entferne alle Anführungszeichen
			@nicklist = split(/=/);
			foreach $lelem2 (@nicklist) {
				#print $lelem2."\n";
				if ($listelem->[1] eq $lelem2)
				{
					push (@mlist2,$listelem);
					last;
				}
			}
		}
		else
		{
			push (@mlist2,$listelem) if ($listelem->[1] eq $$vorname);
		}
	}
	if (@mlist2 == 0)	# kein Eintrag mit passenden Vornamen gefunden
	{
		return (0,"Nachname",undef);		# Gefunden ueber Nachname, Vorname passt nicht, verwerfe Eintrag
	}
	$dok = "" if ($dok eq "---");
	$foundbydokgeb = 0;
	foreach $listelem (@mlist2) {
		if ($listelem->[3] eq $dok)
		{
			push (@mlist3,$listelem);
			$foundbydokgeb = 1;
			next;
		}
		if ($listelem->[4] eq $gebjahr && $gebjahr ne "" && $gebjahr ne "---" && $gebjahr ne "-")
		{
			push (@mlist3,$listelem);
			$foundbydokgeb = 2;
			next;
		}		
	}
	$dok = "---" if ($dok eq "");
	if (@mlist3 == 1)
	{
		$rest = $mlist3[0];
		if ($callmismatch == 1)
		{
			if ($foundbydokgeb == 1)
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit passendem DOK in PMVorjahr gefunden, aber Call: ".$call." stimmt nicht, verwende trotzdem PM Eintrag") if ($CheckInAktPM == 0);
				RepMeld(*FH,"INFO: ".join(',',@{$mlist3[0]})) if ($CheckInAktPM == 0);
				return (1,"Nachname,Vorname,DOK;Call stimmt nicht",$rest) 		# Gefunden ueber Nachname, Vorname und DOK; Call stimmt nicht!
			}
			if ($foundbydokgeb == 2)
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit passendem Geb.jahr in PMVorjahr gefunden, aber Call: ".$call." stimmt nicht, verwende trotzdem PM Eintrag") if ($CheckInAktPM == 0);
				RepMeld(*FH,"INFO: ".join(',',@{$mlist3[0]})) if ($CheckInAktPM == 0);
				return (1,"Nachname,Vorname,Geb.jahr;Call stimmt nicht",$rest) 		# Gefunden ueber Nachname, Vorname und Geb.jahr; Call stimmt nicht!
			}
		}
		return (1,"Nachname,Vorname,DOK",$rest) if ($foundbydokgeb == 1);		# Gefunden ueber Nachname, Vorname und DOK
		return (1,"Nachname,Vorname,Geb.jahr",$rest) if ($foundbydokgeb == 2);		# Gefunden ueber Nachname, Vorname und Geb.jahr
	}
	if (@mlist3 == 0)
	{
		if (@mlist2 == 1 && $override_IsInPmvj == 1)
		{
			if ($callmismatch == 1)
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." und Call: ".$call." stimmen nicht, verwende Daten aufgrund von 'IstInPMVJ Override'") if ($CheckInAktPM == 0);
			}
			else
			{
				RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." stimmt nicht, verwende Daten aufgrund von 'IstInPMVJ Override'") if ($CheckInAktPM == 0);
			}
			$rest = $mlist2[0];
			return (1,"Nachname,Vorname,! 'IstInPMVJ' Override !",$rest);		# Gefunden ueber Nachname, Vorname und 'IstInPMVJ' Override
		}
		
		if ($callmismatch == 1)
		{
			RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." und Call: ".$call." stimmen nicht, verwende Daten nicht") if ($CheckInAktPM == 0);
		}
		else
		{
			RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." in PMVorjahr gefunden, aber DOK: ".$dok." stimmt nicht, verwende Daten nicht") if ($CheckInAktPM == 0);
		}
		RepMeld(*FH,"INFO: mögliche Teilnehmer: ") if ($CheckInAktPM == 0);
		foreach $listelem (@mlist2) {
			RepMeld(*FH,join(',',@$listelem)) if ($CheckInAktPM == 0);
		}
		return (0,"Nachname,Vorname",undef);		# Gefunden ueber Nachname, Vorname, aber DOK stimmt nicht, verwerfe Eintrag
	}
	RepMeld(*FH,"INFO: ".$$nachname.", ".$$vorname." mit DOK ".$dok." bzw. Geb.jahr ".$gebjahr." mehrmals in PMVorjahr gefunden, verwende Daten nicht") if ($CheckInAktPM == 0);
	foreach $listelem (@mlist3) {
		RepMeld(*FH,join(',',@$listelem)) if ($CheckInAktPM == 0);
	}
	return (0,"Nachname,Vorname,DOK",undef);		# Gefunden ueber Nachname, Vorname, DOK, aber mehrmals vorhanden, verwerfe Eintrag
}

#Lesen der Vorjahr (mode == 0) oder der aktuellen (mode == 1) PM Daten
#Rückgabewerte: 0 = ok, 1 = Fehler
sub ReadPMDaten {
	local *FH = shift;
	my ($mode,$pmarray) = @_;	#mode: 0 = PMVJ Daten, 1 = akt. PM Daten
	my $anonarray = [];	# anonymes Array
	my ($pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum);
	if ($mode == 0)
	{
		if ($genhash{"PMVorjahr"} eq "")
		{
			RepMeld(*OUTFILE,"FEHLER: Keine PMVorjahr Datei spezifiziert");
			close (OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}

		if (!open (INFILE2, $genhash{"PMVorjahr"}))
		{
			RepMeld(*OUTFILE,"FEHLER: Kann PMVorjahr Datei ".$genhash{"PMVorjahr"}." nicht lesen");
			close (OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}
	}
	else
	{
		if ($genhash{"PMaktJahr"} eq "")
		{
			RepMeld(*OUTFILE,"FEHLER: Keine aktuelle PM Datei spezifiziert");
			close (OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}

		if (!open (INFILE2, $genhash{"PMaktJahr"}))
		{
			RepMeld(*OUTFILE,"FEHLER: Kann aktuelle PM Datei ".$genhash{"PMaktJahr"}." nicht lesen");
			close (OUTFILE) || die "close: $!";
			return 1;	# Fehler
		}
	}

	undef @$pmarray;
	while (<INFILE2>)
	{
		next unless (/^\"/);	# Zeile muss mit Anfuehrungszeichen beginnen
		tr/\"//d;				# entferne alle Anführungszeichen
		($pmname,$pmvorname,$pmcall,$pmdok,undef,undef,$pmgebjahr,undef,$pmpm,undef,$pmdatum,undef) = split(/,/);
		$anonarray = [$pmname,$pmvorname,$pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum];
		push (@$pmarray,$anonarray);
	}
	close (INFILE2) || die "close: $!";
	return 0;	# ok
}

#Auswertung der aktuellen OVFJ
sub do_eval_ovfj {
	my ($mode) = @_;	# 0 = erster Start, >0 = Aufruf aus Auswertung und Export aller OVFJ heraus
	my $patmatched;
	my $evermatched = 0;
	my ($platz,$ev_nachname,$ev_vorname,$ev_gebjahr);
	my ($ev_call,$ev_dok);
	my $anztln = 0;
	my $nichtpm = 0;
	my $oldnotpmplatz = 0;
	my $AddedVerant = 0;
	my $Helfermode = 0;
	my $Ignoriermode = 0;
	my $HelferInKopf;
	my $KeineSonderpunkte = 0;
	my $SPunktePlatz = 0;
	my ($IsPM,$tnkey);
	my ($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum,);
	my $tndata = {}; # ein anonymer Hash
	my $match;
	my %ovfjhashcopy;
	my ($name,$str,$str2);
	my $line = 0;
	my $oldline = 0;
	my ($override_call,$override_dok,$override_gebjahr,$override_IsInPmvj);
	my $SText;
	my $rest;
	my $aktJahr;	# Teilnahme im aktuellen Jahr
	my $matcherrortext;	# Fehlertext bei Pattern nicht matched
	my $TlnIstAusrichter;	# Teilnehmer ist auch Ausrichter
	
	#Auswertung
	update_genhash(0) if ($mode == 0);	# Generelle Hashdaten aktualisieren auf Basis der Felder
	update_ovfjhash(0) if ($mode == 0);	# Hashdaten aktualisieren
	
	$meldung->insert('end',"***************  ".$ovfjname."  ***************");
	
	$_ = $ovjpattern->get;
	unless (/Nachname/ && /Vorname/)
	{
		$meldung->insert('end',"FEHLER: Muster muss 'Nachname' und 'Vorname' beinhalten");
		return 1;	# Fehler
	}

	if ($mode == 0)
	{
		get_nicknames();  	# Spitznamen einlesen
		get_overrides();		# Lade die Override-Datei (falls vorhanden)
	}

	if (!open (OUTFILE, ">".$reportpath."\\".$ovfjrepfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$ovfjrepfilename." nicht schreiben");
		return 1;	# Fehler
	}	

	if ($mode == 0)
	{# Lese PMVJ Daten
		return 1 if (ReadPMDaten(*OUTFILE,0,\@pmvjarray) == 1);	# Fehler
	 # Lese aktuelle PM Daten
		return 1 if (ReadPMDaten(*OUTFILE,1,\@pmaktarray) == 1);	# Fehler
	}

	if ($ovfjhash{"OVFJDatei"} eq "")
	{
		RepMeld(*OUTFILE,"FEHLER: Keine OVFJ Datei spezifiziert");
		close (OUTFILE) || die "close: $!";
		return 1;	# Fehler
	}	
	
	if (!open (INFILE, $inputpath."\\".$ovfjhash{"OVFJDatei"}))
	{
		RepMeld(*OUTFILE,"FEHLER: Kann OVFJ Datei ".$ovfjhash{"OVFJDatei"}." nicht lesen");
		close (OUTFILE) || die "close: $!";
		return 1;	# Fehler
	}

	$auswerthash{$ovfjname} = 1;	# Wert ist egal, nur Vorhandensein des Schlüssels zählt
	$ovfj_eval_button->configure(-state => 'disabled');
	$reset_eval_button->configure(-state => 'normal');
	$exp_eval_button->configure(-state => 'normal');
	
	$lfdauswert++; # Fortlaufende Numerierung aller OVFJ Auswertungen

	while (<INFILE>)
	{
		$HelferInKopf = 0;
		if ($AddedVerant == 1)
		{
			#print $_;
			chomp;						# entferne CR am Zeilenende
			tr/\t/ /;					# ersetze Tabulatoren durch Leerzeichen
			next if /^#/;				# ignoriere Zeilen die mit einem # beginnen
			next if ($_ eq "");		# und leere Zeilen 
			next if /^\s+$/;			# und Zeilen, die nur aus Leerzeichen bestehen
			$line++;
			if (/^<(\/?)([^>]+)>$/)
			{
				if ($2 eq "Ignorier" || $2 eq "Ignoriere")
				{
					if ($1 eq '/')
					{
						$Ignoriermode = 0;
						RepMeldFile(*OUTFILE,"\n<Ende Ignorierabschnitt>");
					}
					else
					{
						$Ignoriermode = 1;
						RepMeldFile(*OUTFILE,"\n<Beginn Ignorierabschnitt>");
					}
				}
				next if ($Ignoriermode == 1);		# Ignoriere alles was sonst sein koennte
				
				if ($2 eq "Helfer")
				{
					if ($1 eq '/')
					{
						$Helfermode = 0;
						RepMeldFile(*OUTFILE,"\n<Ende Helferabschnitt>");
					}
					else
					{
						$Helfermode = 1;
						RepMeldFile(*OUTFILE,"\n<Beginn Helferabschnitt>");
					}
				}
				if ($2 eq "Keine Sonderpunkte")
				{
					if ($1 eq '/')
					{
						$KeineSonderpunkte = 0;
						RepMeldFile(*OUTFILE,"\n<Ende Abschnitt ohne Sonderpunkte>");
					}
					else
					{
						$KeineSonderpunkte = 1;
						RepMeldFile(*OUTFILE,"\n<Beginn Abschnitt ohne Sonderpunkte>");
					}
				}
#				if ($2 eq "TODO")
#				{
#					if ($1 eq '/')
#					{
#						$KeineSonderpunkte = 0;
#						RepMeldFile(*OUTFILE,"\n<Ende Abschnitt ohne Sonderpunkte>");
#					}
#					else
#					{
#						$KeineSonderpunkte = 1;
#						RepMeldFile(*OUTFILE,"\n<Beginn Abschnitt ohne Sonderpunkte>");
#					}
#				}
				next;
			}
			next if ($Ignoriermode == 1);		# Ignoriere alles was sonst sein koennte
			if (/^Helfer:\s*(.+)$/ && $evermatched == 0) # nur am Kopf der Datei matchen, nicht nach Auswertung
			{
				$str2 = $1;
				$str2 =~ s/\s+$//;
				$str2 =~ tr/,/ /;
				($ev_vorname,$ev_nachname,$ev_call,$ev_dok,$ev_gebjahr) = split(/\s+/,$str2);
				$ev_call = uc($ev_call);
				$ev_call = "---" if ($ev_call eq "" || uc($ev_call) eq "SWL");
				$ev_dok = uc($ev_dok);
				$ev_dok = "---" if ($ev_dok eq "");
				($patmatched,$platz) = (1,0);
				$HelferInKopf = 1;
				#print "Vorname: <".$ev_vorname."> Nachname: <".$ev_nachname."> Call: <".$ev_call."> DOK: <".$ev_dok."> Gebjahr: <".$ev_gebjahr.">\n";
			}
		}

		if ($AddedVerant == 1)
		{
			if ($HelferInKopf == 0)
			{
				($patmatched,$platz,$ev_nachname,$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok) = MatchPat($_);
				$str2 = "\nTeilnehmer: ";
				$str2 = "\nHelfer: " if ($Helfermode == 1);
				$matcherrortext = $platz if ($patmatched == 0);	# Fehlertext steht in zweitem Rückgabewert
			}
			else
			{
				$str2 = "\nHelfer: ";
			}
		}
		else
		{
			($patmatched,$platz,$ev_nachname,$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok) =
			(1,0,$ovfjhash{"Verantw_Name"},$ovfjhash{"Verantw_Vorname"},$ovfjhash{"Verantw_GebJahr"},$ovfjhash{"Verantw_CALL"},$ovfjhash{"Verantw_DOK"});
			$ev_call = "---" if ($ev_call eq "" || uc($ev_call) eq "SWL");
			$ev_dok = "---" if ($ev_dok eq "");
			$str2 = "\nAusrichter: ";
			$matcherrortext = $platz if ($patmatched == 0);	# Fehlertext steht in zweitem Rückgabewert
		}
		if ($patmatched)
		{
			$str2 .= $ev_nachname.", ".$ev_vorname.", ".$ev_gebjahr.", ".$ev_call.", ".$ev_dok;
			RepMeldFile(*OUTFILE,$str2);
			$override_call = 0;
			$override_dok = 0;
			$override_gebjahr = 0;
			$override_IsInPmvj = 0;
			if (defined $overrides)
			{
				if ($overrides =~ /^$ev_nachname,$ev_vorname,([^,]*),([^,]*),(\d*),(\w*)$/m)
				{
					RepMeldFile(*OUTFILE,"INFO: Overridedatensatz für ".$ev_nachname.", ".$ev_vorname." gefunden");
					if ($1 ne "")
					{
						$ev_call = $1;		# Override des Rufzeichens
						$override_call = 1;
					}
					if ($2 ne "")
					{
						$ev_dok = $2;		# Override des DOK
						$override_dok = 1;
					}
					if ($3 ne "")
					{
						$ev_gebjahr = $3;		# Override des Geburtsjahres
						$override_gebjahr = 1;
					}
					if ($4 ne "")
					{	# Override des PM Status im Vorjahr
						$override_IsInPmvj = 1 if ($4 eq "IstInPMVJ");
						$override_IsInPmvj = 2 if ($4 eq "NichtInPMVJ");
					}
				}
			}
			if ($AddedVerant == 1 && $HelferInKopf == 0 && $evermatched == 0)
			{
				RepMeld(*OUTFILE,"INFO: Erster Match mit: ".$_);
				$evermatched = 1;
			}
			#print $ev_nachname." ".$ev_vorname."\n";
			$anztln++ if ($AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0);
			
			#Check, ob Teilnehmer identisch mit Verantwortlichem, um Warnung auszugeben
			$TlnIstAusrichter = 0;
			if (($ev_nachname eq $ovfjhash{"Verantw_Name"}) &&
				 ($ev_vorname eq $ovfjhash{"Verantw_Vorname"}) &&
				 ($AddedVerant == 1) )
				{
				 	RepMeld(*OUTFILE,"WARNUNG: Verantwortlicher ($ev_nachname,$ev_vorname) ist in Teilnehmer Liste");
				 	$TlnIstAusrichter = 1;
				}

			#Suche, ob PM und ob Daten stimmen
			$IsPM = 0;
			$match = 0;

			($match,$SText,$rest) = SucheTlnInPM(*OUTFILE,\@pmvjarray,\$ev_nachname,\$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok,$override_IsInPmvj,0);
			if ($match > 0)
			{
				RepMeldFile(*OUTFILE,"In PMVorjahr gefunden da Übereinstimmung von: ".$SText);
			}
			else
			{
				RepMeldFile(*OUTFILE,"Nicht in PMVorjahr gefunden da nur Übereinstimmung von: ".$SText);
			}
		

			if ($match != 0)
			{
				($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum) = @{$rest}[2..6];

				$IsPM = 1 if ($pmpm eq "FM");

				if ($ev_gebjahr ne "" && ($ev_gebjahr ne $pmgebjahr))
				{
					RepMeld(*OUTFILE,"INFO: Geb.jahr unterschiedlich mit PMVorjahr: ");
					RepMeld(*OUTFILE,$ev_nachname.", ".$ev_vorname." :".$ev_gebjahr." <-> ".$pmgebjahr);
				}
			}

			# Verwaltung der Platzierung fuer Nicht-PMs. $nichtpm wird bei Nicht-PMs erhoeht
			if ($IsPM == 0 && $AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0)
			{
				if ($platz ne "")
				{
					$nichtpm++ if ($platz ne $oldnotpmplatz);	# nur erhoehen, wenn auf verschiedenen Plaetzen
					$oldnotpmplatz = $platz;
				}
				else
				{
					$nichtpm++;
				}
			}
			
			#Jetzt wird geschaut, ob Teilnehmer auch in aktueller Datei gefunden wird
			#oder ob z.B. der Vorname angepasst werden muss
			
			($match,$SText,$rest) = SucheTlnInPM(*OUTFILE,\@pmaktarray,\$ev_nachname,\$ev_vorname,$ev_gebjahr,$ev_call,$ev_dok,$override_IsInPmvj,1);
			

			$aktJahr = 0;							# Default: nicht in aktueller PM Datei gefunden
			if ($match > 0)
			{
				($pmcall,$pmdok,$pmgebjahr,$pmpm,$pmdatum) = @{$rest}[2..6];
				$str2 = "";
				$pmcall = "---" if ($pmcall eq "SWL");
				$pmdok = "---" if ($pmdok eq "");
				if ($ev_call ne "" && $pmcall ne $ev_call)
				{
					$str2 = "  Call: ".$ev_call.($override_call ? " (Override)" : " (OVFJ)")." <-> ".$pmcall." (akt.PMDatei)";
				}
				if ($ev_dok ne "" && $pmdok ne $ev_dok)
				{
					$str2 .= "  DOK: ".$ev_dok.($override_dok ? " (Override)" : " (OVFJ)")." <-> ".$pmdok." (akt.PMDatei)";
				}
				if ($ev_gebjahr ne "" && $pmgebjahr ne $ev_gebjahr)
				{
					$str2 .= "  Geb.jahr: ".$ev_gebjahr.($override_gebjahr ? " (Override)" : " (OVFJ)")." <-> ".$pmgebjahr." (akt.PMDatei)";
				}
				if ($str2 ne "")
				{
					$str2 = "INFO: ".$ev_nachname.", ".$ev_vorname.":".$str2;
					RepMeld(*OUTFILE,$str2);
				}
				$aktJahr = 1;	# zwar gefunden, aber keine Teilnahme im aktuellen Jahr (kann nachfolgend ueberschrieben werden)
				$aktJahr = 2 if ($pmdatum =~ /^$year\d{4}$/);
			}		
			
			if ($IsPM == 0 && $AddedVerant == 1 && $Helfermode == 0 && $HelferInKopf == 0 && $KeineSonderpunkte == 0)
			{
				$SPunktePlatz = 1;
			}
			else
			{
				$SPunktePlatz = 0;
			}
			
			$tnkey = join(',',$ev_nachname,$ev_vorname);	# key ist Nachname,Vorname
			if (exists($tn{$tnkey}))
			{
				#print "Found Call: ".$tn{$tnkey}->{call};
				$str2 = sprintf("%u",$lfdauswert);
				if ($tn{$tnkey}->{wwbw} =~ /$str2/)
				{
					if ($TlnIstAusrichter == 0)
					{
						RepMeld(*OUTFILE,"FEHLER: ".$ev_nachname.", ".$ev_vorname." ist bereits in laufender Auswertung");
					}
					else
					{
						RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname." ist als Ausrichter bereits in laufender Auswertung, ignoriere Teilnahme als Teilnehmer");
					}
					next;
				}					
				$str2 = $tnkey." ist bereits in Auswertung, Status: ";
				$tn{$tnkey}->{anzwwbw}++;
				$tn{$tnkey}->{wwbw} .= ",".sprintf("%u",$lfdauswert);
				$tn{$tnkey}->{anzausr} += ($AddedVerant == 0 ? 1 : 0);
				if ($SPunktePlatz == 1)
				{
					$tn{$tnkey}->{anzpl1} += ($nichtpm == 1 ? 1 : 0);
					$tn{$tnkey}->{anzpl2} += ($nichtpm == 2 ? 1 : 0);
				}
				$tn{$tnkey}->{anzhelf}++ if ($Helfermode == 1 || $HelferInKopf == 1);

				# Abgleich Rufzeichen
				$tn{$tnkey}->{call} = $ev_call if (($tn{$tnkey}->{call} eq "---" || $tn{$tnkey}->{call} eq "") && ($ev_call ne "---" && $ev_call ne ""));
				if ($tn{$tnkey}->{call} ne "---" && $tn{$tnkey}->{call} ne "" && $ev_call ne $tn{$tnkey}->{call})
				{
					RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": Rufzeichen unterschiedlich: ".$tn{$tnkey}->{call}." (alt, bleibt)<->(OVFJ) ".$ev_call);
				}

				# Abgleich DOK
				$tn{$tnkey}->{dok} = $ev_dok if ($tn{$tnkey}->{dok} eq "" && $ev_dok ne "");
				if ($tn{$tnkey}->{dok} ne "" && $ev_dok ne "" && $ev_dok ne $tn{$tnkey}->{dok})
				{
					RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": DOK unterschiedlich: ".$tn{$tnkey}->{dok}." (alt, bleibt)<->(OVFJ) ".$ev_dok);
				}

				# Abgleich Geburtsjahr
				$tn{$tnkey}->{gebjahr} = $ev_gebjahr if ($tn{$tnkey}->{gebjahr} eq "" && $ev_gebjahr ne "");
				if ($tn{$tnkey}->{gebjahr} ne "" && $ev_gebjahr ne "" && $ev_gebjahr ne $tn{$tnkey}->{gebjahr})
				{
					RepMeld(*OUTFILE,"INFO: ".$ev_nachname.", ".$ev_vorname.": Geburtsjahr unterschiedlich: ".$tn{$tnkey}->{gebjahr}." (alt, bleibt)<->(OVFJ) ".$ev_gebjahr);
				}
				
			}
			else
			{
				$str2 = $tnkey." ist neu in Auswertung, Status: ";
				$tndata = {	"nachname" => $ev_nachname,
								"vorname" => $ev_vorname,
								"call" => $ev_call,
								"dok" => $ev_dok,
								"gebjahr" => $ev_gebjahr,
								"pmvj" => $IsPM,
								"wwbw" => sprintf("%u",$lfdauswert),
								"anzwwbw" => 1,
								"anzpl1" => (($nichtpm == 1 && $SPunktePlatz == 1) ? 1 : 0),
								"anzpl2" => (($nichtpm == 2 && $SPunktePlatz == 1) ? 1 : 0),
								"anzausr" => ($AddedVerant == 0 ? 1 : 0),
								"anzhelf" => (($Helfermode == 1 || $HelferInKopf == 1) ? 1 : 0),
								"aktjahr" => $aktJahr
							};
				$tn{$tnkey} = $tndata;
			}
			$str2 .= "Helfer" if ($Helfermode == 1 || $HelferInKopf == 1);
			$str2 .= "Ausrichter" if ($AddedVerant == 0);
			$str2 .= "1 Extrapunkt für Platz 2 als Nicht-PM" if ($nichtpm == 2 && $SPunktePlatz == 1);
			$str2 .= "2 Extrapunkte für Platz 1 als Nicht-PM" if ($nichtpm == 1 && $SPunktePlatz == 1);
			$str2 .= "PM im Vorjahr" if ($IsPM && $Helfermode == 0 && $HelferInKopf == 0 && $AddedVerant == 1);
			RepMeldFile(*OUTFILE,$str2);
		}
		else
		{
			if ($evermatched == 1)
			{
				RepMeld(*OUTFILE,"\nINFO: kein Match (Ursache: ".$matcherrortext.") bei:") if ($oldline+1 < $line);
				RepMeld(*OUTFILE,$_);
				$oldline = $line;
			}
		}
		if ($AddedVerant == 0)
		{
			$AddedVerant = 1;
			redo; # Die Schleife noch einmal durchlaufen, diesmal mit der Auswertung des ersten
			      # Datensatzes. Durch das 'redo' wird aus INFILE nichts neues gelesen
		}
	} # Ende von while (<INFILE>)

	RepMeld(*OUTFILE,"INFO: kein einziger Match! Letzte Ursache: ".$matcherrortext) if ($evermatched == 0);

	%ovfjhashcopy = %ovfjhash;
	push (@ovfjlist,\%ovfjhashcopy);
	if ($ovfjhash{"TlnManuell"} ne "")
	{# Manuelle Vorgabe hat Vorrang vor automatischer Zaehlung
		push (@ovfjanztlnlist,$ovfjhash{"TlnManuell"});
	}
	else
	{
		push (@ovfjanztlnlist,$anztln);
	}

	$meldung->insert('end',"");	# Erzeuge Leerzeile zwischen Auswertungen

	close (OUTFILE) || die "close: $!";
	close (INFILE) || die "close: $!";
	return 0;	# kein Fehler
}

#Export der Auswertung(en) im Speicher in die verschiedenen Formate
sub Export {
	my ($rawresultfilename,$asciiresultfilename,$htmlresultfilename);
	my ($tnkey,$tndatakey);
	my $addoutput;
	my $ExcludeTln;
	my $ovfjlistelement;
	my ($i,$str2);
	my %maxlen = ("kombiname",0, #Vorbelegen um Abfrage unten zu sparen
					  "gebjahr",length("GebJahr  "),
					  "wwbw",length("Wettbewerbe"));
	my ($sec,$min,$hour,$mday,$mon,$myear,$wday,$yday,$isdst) = localtime(time);

	$ExcludeTln = $check_ExcludeTln->{'Value'};

	$rawresultfilename = "OVJ_Ergebnisse_".$genhash{"Distriktskenner"}."_".$year."raw.txt";
	if (!open (ROUTFILE, ">".$outputpath."\\".$rawresultfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$rawresultfilename." nicht schreiben");
		return;
	}
	$asciiresultfilename = "OVJ".$genhash{"Distriktskenner"}.$year.".txt";
	if (!open (AOUTFILE, ">".$outputpath."\\".$asciiresultfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$asciiresultfilename." nicht schreiben");
		return;
	}
	$htmlresultfilename = "OVJ_Ergebnisse_".$genhash{"Distriktskenner"}."_".$year.".htm";
	if (!open (HOUTFILE, ">".$outputpath."\\".$htmlresultfilename))
	{
		$meldung->insert('end',"FEHLER: Kann ".$htmlresultfilename." nicht schreiben");
		return;
	}
	
	printf AOUTFILE "             OV Jahresauswertung ".$year." des Distrikts ".$genhash{"Distrikt"}."\n\n";
	printf AOUTFILE "OV-Wettbewerbe des Distriktes   ".$genhash{"Distrikt"}."\n";
	printf AOUTFILE "für das Jahr                    ".$year."\n";
	printf AOUTFILE "Distriktspeilreferent\n";
	printf AOUTFILE "Name, Vorname                   ".$genhash{"Name"}.", ".$genhash{"Vorname"}."\n";
	printf AOUTFILE "Call                            ".$genhash{"Call"}."\n";
	printf AOUTFILE "DOK                             ".$genhash{"DOK"}."\n";
	printf AOUTFILE "Telefon                         ".$genhash{"Telefon"}."\n";
	printf AOUTFILE "Home-BBS                        ".$genhash{"Home-BBS"}."\n";
	printf AOUTFILE "E-Mail                          ".$genhash{"E-Mail"}."\n";
	printf AOUTFILE "Auswertung mit                  OVJ (Version ".$ovjvers." vom ".$ovjdate.")\n";
	printf AOUTFILE ("am                              %i.%i.%i\n",$mday,$mon+1,$myear+1900);
	if ($ExcludeTln == 1)
	{
		printf AOUTFILE "Hinweis                         Teilnehmer ohne Teilnahme an offiziellen Wettbewerb in ".$year."\n";
		printf AOUTFILE "                                wurden von OVJ entfernt\n";
	}

	printf AOUTFILE "\n********************************\n";
	printf AOUTFILE "* Durchgeführte OV-Wettbewerbe *\n";
	printf AOUTFILE "********************************\n";
	printf AOUTFILE "Nr. Ausrichtender OV           DOK  Verantwortlicher          Call    DOK  Datum       Band  Teilnehmer\n";
	printf AOUTFILE "-------------------------------------------------------------------------------------------------------\n";

	printf HOUTFILE "<html>\n<head>\n<title>OV Jahresauswertung ".$year." des Distrikts ".$genhash{"Distrikt"}."</title>\n</head>\n";
	printf HOUTFILE "<body>\n";
	printf HOUTFILE "<h1>Jahresauswertung der OV-Peilveranstaltungen</h1>\n";
	printf HOUTFILE "<table border=\"0\"><tbody align=\"left\">\n";
	printf HOUTFILE "<tr><td>OV-Wettbewerbe des Distriktes&nbsp;&nbsp;&nbsp;</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"Distrikt"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>für das Jahr</td>\n";
	printf HOUTFILE "<td><b>".$year."</b></td></tr>\n";
	printf HOUTFILE "<tr><td><b>Distriktspeilreferent</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Name, Vorname</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"Name"}.", ".$genhash{"Vorname"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Call</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"Call"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>DOK</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"DOK"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Telefon</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"Telefon"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>Home-BBS</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"Home-BBS"}."</b></td></tr>\n";
	printf HOUTFILE "<tr><td>E-Mail</td>\n";
	printf HOUTFILE "<td><b>".$genhash{"E-Mail"}."</b></td></tr>\n";
	printf HOUTFILE "</tbody></table><br><br>\n";

	printf HOUTFILE "<table border=\"1\">\n";
	printf HOUTFILE "<thead><tr><th colspan=\"9\">Durchgeführte OV-Wettbewerbe</b></th></tr>\n";
	printf HOUTFILE "<tr><th>Nr.</th><th>Ausrichtender OV</th><th>DOK</th><th>Verantwortlicher</th>";
	printf HOUTFILE "<th>Call</th><th>DOK</th><th>Datum</th><th>Band</th><th>Teilnehmer</th></tr>\n";
	printf HOUTFILE "</thead><tbody>\n";

	$i = 1;
	foreach $ovfjlistelement (@ovfjlist)
	{
		printf AOUTFILE substr(" ".$i."  ",0,4).substr($ovfjlistelement->{"AusrichtOV"}." "x27,0,27).substr($ovfjlistelement->{"AusrichtDOK"}."     ",0,5);
		printf AOUTFILE substr($ovfjlistelement->{"Verantw_Name"}.", ".$ovfjlistelement->{"Verantw_Vorname"}." "x26,0,26);
		printf AOUTFILE substr($ovfjlistelement->{"Verantw_CALL"}." "x8,0,8).substr($ovfjlistelement->{"Verantw_DOK"}." "x5,0,5);
		printf AOUTFILE substr($ovfjlistelement->{"Datum"}." "x13,0,13).substr($ovfjlistelement->{"Band"}." "x9,0,9).$ovfjanztlnlist[$i-1]."\n";

		printf HOUTFILE "<tr><td>".$i."</td><td>".$ovfjlistelement->{"AusrichtOV"}."</td><td>".$ovfjlistelement->{"AusrichtDOK"}."</td>";
		printf HOUTFILE "<td>".$ovfjlistelement->{"Verantw_Name"}.", ".$ovfjlistelement->{"Verantw_Vorname"}."</td>\n";
		printf HOUTFILE "<td>".($ovfjlistelement->{"Verantw_CALL"} eq "" ? "&nbsp;" : $ovfjlistelement->{"Verantw_CALL"})."</td>";
		printf HOUTFILE "<td>".($ovfjlistelement->{"Verantw_DOK"} eq "" ? "&nbsp;" : $ovfjlistelement->{"Verantw_DOK"})."</td>";
		printf HOUTFILE "<td>".$ovfjlistelement->{"Datum"}."</td><td>".$ovfjlistelement->{"Band"}."</td>";
		printf HOUTFILE "<td>".$ovfjanztlnlist[$i-1]."</td></tr>\n";
		$i++;
	}

	printf HOUTFILE "</tbody></table><br>\n";

	printf HOUTFILE "<br><table border=\"1\">\n";
	printf HOUTFILE "<thead><tr><th colspan=\"11\">Teilnehmer der OV-Wettbewerbe</b></th></tr>\n";
	printf HOUTFILE "<tr><th>Name, Vorname</th><th>Call</th><th>DOK</th><th>Geburtsjahr</th>";
	printf HOUTFILE "<th>PM im Vorjahr</th><th>Wettbewerbe</th><th>Anzahl OV FJ</th>";
	printf HOUTFILE "<th>Anz. Platz 1</th><th>Anz. Platz 2</th><th>Anz. Ausrichter</th><th>Anz. Helfer</th></tr></thead>\n<tbody>\n";

	foreach $tnkey (sort keys %tn)
	{
		foreach $tndatakey (keys %{$tn{$tnkey}})
		{
			if (exists($maxlen{$tndatakey}))
			{
				if (length($tn{$tnkey}->{$tndatakey})>$maxlen{$tndatakey})
				{
					$maxlen{$tndatakey} = length($tn{$tnkey}->{$tndatakey});
				}
			}
			else
			{
				$maxlen{$tndatakey} = length($tn{$tnkey}->{$tndatakey});
			}
		}
		# die Längeninfo für die Kombination beider Namen muss speziell erzeugt werden
		if (length($tn{$tnkey}->{nachname}.$tn{$tnkey}->{vorname})>$maxlen{kombiname})
		{
			$maxlen{kombiname} = length($tn{$tnkey}->{nachname}.$tn{$tnkey}->{vorname});
		}
	}

	printf AOUTFILE "\n*********************************\n";
	printf AOUTFILE "* Teilnehmer der OV-Wettbewerbe *\n";
	printf AOUTFILE "*********************************\n";

	$str = "Name, Vorname"." "x($maxlen{kombiname}-length("Name, Vorname")+4)."Call"." "x($maxlen{call}-length("Call")+2);
	$str .= "DOK"." "x($maxlen{dok}-length("DOK")+2)."GebJahr  "."PMVJ?  "."Wettbewerbe"." "x($maxlen{wwbw}-length("Wettbewerbe")+1);
	$str .= "AnzFJ  "."Platz1  "."Platz2  "."Ausrichter  "."Helfer";
	$str2 = $str;
	$str .= "  akt.Jahr" if ($ExcludeTln == 0);

	printf ROUTFILE $str."\n";
	printf ROUTFILE "-"x(length($str))."\n";
	printf AOUTFILE $str2."\n";
	printf AOUTFILE "-"x(length($str2))."\n";
	foreach $tnkey (sort keys %tn) {

		if ($ExcludeTln == 1 && $tn{$tnkey}->{aktjahr} == 1)
		{
			$addoutput .= "Schliesse ".$tn{$tnkey}->{nachname}.", ".$tn{$tnkey}->{vorname}." aus, da kein offizieller Wettbewerb in ".$year."\n";
			next;
		}

		if ($ExcludeTln == 1 && $tn{$tnkey}->{aktjahr} == 0)
		{
			$addoutput .= "Schliesse ".$tn{$tnkey}->{nachname}.", ".$tn{$tnkey}->{vorname}." aus, da Name nicht in aktueller PM Datei\n";
			next;
		}

		$str = $tn{$tnkey}->{nachname}.", ".
		$tn{$tnkey}->{vorname}." "x($maxlen{kombiname}-length($tn{$tnkey}->{nachname}.$tn{$tnkey}->{vorname})+2).
		$tn{$tnkey}->{call}." "x($maxlen{call}-length($tn{$tnkey}->{call})+2).
		$tn{$tnkey}->{dok}." "x($maxlen{dok}-length($tn{$tnkey}->{dok})+2).
		$tn{$tnkey}->{gebjahr}." "x($maxlen{gebjahr}-length($tn{$tnkey}->{gebjahr})+1).
		($tn{$tnkey}->{pmvj} ? "JA" : "--")."    ".
		$tn{$tnkey}->{wwbw}." "x($maxlen{wwbw}-length($tn{$tnkey}->{wwbw})+3).
		$tn{$tnkey}->{anzwwbw}."      ".($tn{$tnkey}->{anzwwbw}<10 ? " " : "").
		$tn{$tnkey}->{anzpl1}."       ".
		$tn{$tnkey}->{anzpl2}."        ".
		$tn{$tnkey}->{anzausr}."         ".
		$tn{$tnkey}->{anzhelf};
		$str2 = $str;
		$str .= ($tn{$tnkey}->{aktjahr} != 2 ? "       Nein" : "");
		
		printf ROUTFILE $str."\n";
		printf AOUTFILE $str2."\n";
		
		printf HOUTFILE "<tr><td>".$tn{$tnkey}->{nachname}.", ".$tn{$tnkey}->{vorname}."</td>";
		printf HOUTFILE "<td>".($tn{$tnkey}->{call} eq "" ? "&nbsp;" : $tn{$tnkey}->{call})."</td><td>".($tn{$tnkey}->{dok} eq "" ? "&nbsp;" : $tn{$tnkey}->{dok})."</td>\n";
		printf HOUTFILE "<td>".($tn{$tnkey}->{gebjahr} eq "" ? "&nbsp;" : $tn{$tnkey}->{gebjahr})."</td><td>".($tn{$tnkey}->{pmvj} ? "JA" : "--")."</td>";
		printf HOUTFILE "<td>".$tn{$tnkey}->{wwbw}."</td><td>".$tn{$tnkey}->{anzwwbw}."</td>\n";
		printf HOUTFILE "<td>".$tn{$tnkey}->{anzpl1}."</td><td>".$tn{$tnkey}->{anzpl2}."</td><td>".$tn{$tnkey}->{anzausr}."</td><td>".$tn{$tnkey}->{anzhelf}."</td></tr>\n";
	}
	
	if ($addoutput ne "")
	{
		printf ROUTFILE "\n".$addoutput."\n";
	}
	
	printf HOUTFILE "</tbody></table>\n";
	printf HOUTFILE "<h5>erzeugt durch OVJ  (Version ".$ovjvers." vom ".$ovjdate.")</h5>\n";
	printf HOUTFILE "</body>\n</html>\n";
	
	close (ROUTFILE) || die "close: $!";
	close (AOUTFILE) || die "close: $!";
	close (HOUTFILE) || die "close: $!";
}

#Ausgabe einer Meldung im Meldungsfenster und der Report-Datei
sub RepMeld {
	local *FH = shift;
	printf FH $_[0]."\n";
	local $_ = $_[0];
	tr/\n//d;							# entferne alle CRs
	$meldung->insert('end',$_);
}

#Ausgabe einer Meldung in der Report-Datei
sub RepMeldFile {
	local *FH = shift;
	printf FH $_[0]."\n";
}

#Über Box aus dem 'Hilfe' Menu
sub About {
	$mw->messageBox(-icon => 'info', 
						-message => "OV Jahresauswertung\n\n".
						"by Matthias Kühlewein, DL3SDO\n".
						"Version: $ovjvers - Datum: $ovjdate",
						-title => 'Über', -type => 'Ok');
}

#Exit Box aus dem 'Datei' Menu und 'Exit' Button
sub Leave {
	return if (CheckForOverwriteOVFJ());	# Abbruch durch Benutzer
	return if (CheckForUnsavedPatterns());	# Abbruch durch Benutzer
	return if (CheckForSaveGenfile());		# Abbruch durch Benutzer
	return if (CheckForOVFJList());			# Abbruch durch Benutzer
	exit;
}

die;
