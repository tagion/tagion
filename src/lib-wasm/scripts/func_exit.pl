#!/usr/bin/env perl

use strict;
use warnings;

if (@ARGV != 1) {
    die "Usage: perl script.pl input_file\n";
}

my $input_file = $ARGV[0];

open my $fh, '<', $input_file or die "Cannot open $input_file: $!";
my $input_text = do { local $/; <$fh> };
close $fh;

my $pattern = qr{
    \(func \s+     
    \$__wasm_call_dtors   
    \s+             
    \(type \s+ 14\)    
    \s+             
    call \s+        
    \$__funcs_on_exit   
    \s+             
    call \s+        
    \$__stdio_exit  
    \)              
}xms;

my $replacement = <<'END_REPLACEMENT';
(func $__wasm_call_dtors (type 14)
  call $__stdio_exit)
END_REPLACEMENT

$input_text =~ s/$pattern/$replacement/xms;

print $input_text;

