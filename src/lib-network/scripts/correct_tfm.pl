#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/(^alias\s+[\w_]+\s+=\s+<unimplemented>)/\/\/ DSTEP : $1/;
    s/(^alias\s+mp_clamp\s*=)/\/\/ DSTEP : $1/;
    print;
}


