#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/^(\s*)enum(\s+(MD4_Init|MD4_Update|MD4_Final)\s+=)/$1alias$2/;
    print;
}


