#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/(^alias\s+[\w_]+\s+=\s+<unimplemented>)/\/\/ DSTEP : $1/;
    print;
}


