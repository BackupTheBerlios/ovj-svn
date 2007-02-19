# $Id$
#
# Copyright (C) 2007 Kai Pastor, DG0YT <dg0yt AT darc DOT de>
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

=head1 OVJ::Browser

=head1 Synopsis

	use OVJ::Browser;

	OVJ::Browser::open("index.html")
	 or warn "Konnte Browser nicht starten";

=cut

package OVJ::Browser;

use strict;
use Carp;	# carp/croak instead of warn/die

use vars qw(
	$VERSION
);

BEGIN {
	$VERSION = "0.1";
}

=head1 Methoden

=head2 open(location)

Öffnet die als Argument 'location' übergebene Adresse (Pfad, URL)
in einem Browser.

=cut

sub open {
	my @arg = @_
	 or carp "usage: OVJ::Browser::open('index.htm')", return ;
	
	if ($^O =~ /Win/i) {
		# Windows
		unshift @arg, qw(cmd /c start);
		return 0 == system @arg;
	}
	else {
		# Linux et al.
		my $pid = fork;
		if (defined $pid && $pid == 0) {
			# Kindprozess ($pid == 0)
			delete $SIG{'__WARN__'}; # Sonst merkwürdige Fehler bei exec
			foreach (qw/firefox konqueror/) {
				{ exec $_, @arg }; # Hier Ende bei Erfolg!
			}
			exit 1; # Hier Ende bei Fehler
		}
		return $pid;
	}
}

=head1 Autor

Kai Pastor 

=cut

1;
