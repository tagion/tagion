#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/^(\s*)enum(\s+(wc_Des_EcbDecrypt|wc_Des3_EcbDecrypt|MD4_Final)\s+=)/$1alias$2/;
    print;
}


