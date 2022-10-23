#!/usr/bin/perl -i.bak 
# Correct naming

while (<>) {
    s/(^\s+)d(\s+d;)/$1_D$2/;
    s/(^\s+struct\s+)d/$1_D/;
    s/^(\s*)enum(\s+(wolfSSL_set_using_nonblock|wolfSSL_get_using_nonblock)\s+=)/$1alias$2/;
    s/^(\s*(warning_return|fatal_return)\s+=\s+)/$1cast(int)/;
    print;
}
