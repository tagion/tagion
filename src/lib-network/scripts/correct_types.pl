#!/usr/bin/env perl -i.bak 
# Remove dublicat lines 
my $found=0;

while (<>) {
    if (m/^enum _WC_HASH_TYPE_MAX = wc_HashType.WC_HASH_TYPE_SHAKE256;/)  {
        if ($found) {
            print "// DSTEP: $_";
            next;
        }
        $found=1;
    }
    s/^(\s*)enum(\s+XSNPRINTF\s+=\s+snprintf;)/$1alias$2/;
    s/^(\s*)enum(\s+XGETENV\s+=\s+getenv;)/$1alias$2/;
    s/^\s*enum\s+([\w\_]+)\s+=\s+_Pragma\((\"[\w\s]+\")\);\s*/void $1() {pragma(msg, $2);}\n/; 
    s/(^alias\s+(XSTRNSTR|XSTRCASECMP|XSTRNCASECMP|XTOUPPER|XTOLOWER|PRAGMA_CLANG))/\/\/ DSTEP: $1/; 
      print;
}


