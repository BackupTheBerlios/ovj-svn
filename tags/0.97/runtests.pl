#!/usr/bin/perl -w
#
# $Id$
#
# (C) 2007 Kai Pastor <dg0yt AT darc DOT de>
#
# For documentation, copyright et al. see end of file, or run perldoc.

use strict;

use Test::Harness;

opendir my $tests, 't'
  or die "Can't open directory 't': $!";
my @tests = map { /\.t$/ ? "t/$_" : ()  } readdir $tests;
closedir $tests;

use lib 'lib';
exit runtests(@tests);



=head1 NAME

runtests.pl - run tests defined in the t directory

=head1 SYNOPSIS

C<./runtests.pl>

=head1 DESCRIPTION

runtests.pl builds a list of .t-files in the 't' subdirectory 
and passes that list to Test::Harness::runtests().

Before running the tests, 'lib' is added to the modules search path
(@INC).

=head1 OPTIONS

None.

=head1 RETURN VALUE

Success or failure, depending on the tests succeeding or failing.

=head1 SEE ALSO

Test::Simple(3), Test::More(3), Test::Harness(3)

=head1 AUTHOR

Kai Pastor, <dg0yt AT darc DOT de>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Kai Pastor

This library is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.

=cut

