#!/usr/bin/env perl -i.bak 

while (<>) {
    if (m/struct\s+WOLFSSL_HMAC_CTX/) {
        print "version(none) ";
    }
    print;
}


