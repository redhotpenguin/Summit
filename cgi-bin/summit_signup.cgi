#!/usr/bin/env perl

use strict;
use warnings;

use lib '../lib';

use Summit::Signup;

#use Data::Dumper qw( Dumper );

my $summit = Summit::Signup->new();
$summit->run;

1;
