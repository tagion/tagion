#!/usr/bin/perl -i.bak 
#  Correct numbers

while (<>) {
    s/^(\s*)enum(\s+(InitDsaKey|FreeDsaKey|DsaSign|DsaVerify|DsaPublicKeyDecode|DsaPrivateKeyDecode|DsaKeyToDer)\s+=)/$1alias$2/;
    print;
}


