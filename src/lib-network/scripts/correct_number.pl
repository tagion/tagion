#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/0[xX]([0-9a-fA-F]+)l/0x$1L/;
    s/([0-9]+)l/$1L/;
    print;
}


