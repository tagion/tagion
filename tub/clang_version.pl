#!/usr/bin/perl -n
(m/version\s+(\d+\.\d+\.\d+)/) && print $1;
