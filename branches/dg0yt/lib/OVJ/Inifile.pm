=head1 OVJ::Inifile;

=head2 Synopsis

	my %config = OVJ::Inifile::read("OVJ.ini");
	my $param = $config{param};
	$config{param} = "foo";
	OVJ::Inifile::save("OVJ.ini",%config);

=cut

package OVJ::Inifile;

use strict;
use Carp;	# carp/croak instead of warn/die

sub read {
	my $inifilename = shift
	  or croak "Dateiname fehlt";
	open (my $inifile,"<",$inifilename)
	  or return;
	my %inihash = ( '.comment' => '' );
	while (<$inifile>) {
		s/\r//;
		if (/^((?:\w|-)+)\s*=\s*(.*?)\s*$/) {
			$inihash{$1} = $2;
		}
		else {
			$inihash{'.comment'} .= $_;
		}
	}
	close ($inifile) 
	  or warn "Kann INI-Datei '$inifilename' nicht schließen: $!";
	return wantarray ? %inihash : \%inihash;
}


sub write {
	my $inifilename = shift
	  or croak "Dateiname fehlt";
	my %inihash = (ref $_[0]) ? %{$_[0]} : @_;
	my $key;
	open (my $inifile,">",$inifilename)
	  or return;
	print $inifile $inihash{'.comment'};
	foreach $key (keys %inihash) {
		next if $key eq '.comment';
		print $inifile "$key = $inihash{$key}\n";
	}
	close ($inifile);
}

1;
