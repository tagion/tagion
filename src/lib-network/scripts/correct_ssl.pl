#!/usr/bin/perl -i.bak 
# Correct naming

while (<>) {
    s/(^\s+)d(\s+d;)/$1_D$2/;
    s/(^\s+struct\s+)d/$1_D/;
    print;
}

