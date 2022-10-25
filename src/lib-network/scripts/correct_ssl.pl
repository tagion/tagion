#!/usr/bin/perl -i.bak 
#  Correct numbers

my $alias_funcs = join("|",
    "wolfSSL_set_using_nonblock",
    "wolfSSL_get_using_nonblock",
    "wolfSSL_SSL_CTX_get_client_CA_list",
    "wolfSSL_KeyPemToDer", 
    "wolfSSL_CertPemToDer",
    "wolfSSL_PemPubKeyToDer", 
    "wolfSSL_PubKeyPemToDer",
    "wolfSSL_PemCertToDer",   
    "wolfSSL_UseAsync",
    "wolfSSL_CTX_UseAsync",
);

while (<>) {
    s/^(\s*)enum(\s+($alias_funcs)\s+=)/$1alias$2/;
    s/(^\s+)d(\s+d;)/$1_D$2/;
    s/(^\s+struct\s+)d/$1_D/;
    s/^(\s*(warning_return|fatal_return)\s+=\s+)/$1cast(int)/;
    s/^(\s*struct\s+WOLFSSL_EVP_PKEY)_/$1/;
    print;
}
