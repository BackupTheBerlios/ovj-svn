#!/bin/sh

if test -z "$1" ; then
  DEFAULT_TESTS=t/*.t
else
  DEFAULT_TESTS=
fi
perl -Ilib -e 'use Test::Harness qw(&runtests $verbose);
               $verbose=1; runtests @ARGV;' $* $DEFAULT_TESTS
