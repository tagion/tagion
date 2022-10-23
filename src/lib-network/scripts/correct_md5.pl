#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/^(\s*)enum(\s+(MD5_Init|MD5_Update|MD5_Final|MD5_Transform)\s+=)/$1alias$2/;
    print;
}


