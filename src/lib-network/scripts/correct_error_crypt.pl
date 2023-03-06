#!/usr/bin/perl -i.bak 

while (<>) {
    s/^(\s*enum)$/$1 wolfCrypt_ErrorCodes/;
	if (!m/^\s+WC_LAST_E\s*=\s*-292/) {
		print;
	}
}

