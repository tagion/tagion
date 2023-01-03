#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/(^\s+ubyte\[)(CTC_DATE_SIZE)(\])/$1Ctc_Misc.$2$3/;
    print;
}


