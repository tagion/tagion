#!/usr/bin/perl -i.bak 
#  Correct numbers

my $aliasfuncs = join("|",
    "wc_Des_EcbDecrypt",
);

while (<>) {
    s/^(\s*)enum(\s+\w+\s+=\s+($std_funcs))/$1alias$2/;
    print;
}


