#!/bin/sh

perl -Ilib -e 'use Test::Harness qw(&runtests $verbose);
               $verbose=1; runtests @ARGV;' t/*.t
