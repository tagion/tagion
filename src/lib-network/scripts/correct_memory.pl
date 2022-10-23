#!/usr/bin/perl -i.bak 

while (<>) {
    ## Correction for odd bug in dstep
    s/^e(module\s+)/$1/;
    s/^(xtern)/e$1/;
    print;
}


