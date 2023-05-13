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

my $trusted = join("|",
    "wolfSSL_new",
    "wolfSSL_free",
    "wolfSSL_set_verify",
    "wolfSSL_set_fd",
    "wolfSSL_connect",
    "wolfSSL_accept",
    "wolfSSL_write",
    "wolfSSL_read",
    "wolfSSL_pending",
    "wolfSSL_shutdown",
    "wolfSSL_CTX_new",
    "wolfSSL_CTX_free",
    "wolfSSL_get_error",
    "wolfSSL_ERR_get_error",
    "wolfSSL_ERR_clear_error",
    "wolfTLS_client_method",
    "wolfTLS_server_method",
   
);

while (<>) {
    s/^(\s*)enum(\s+($alias_funcs)\s+=)/$1alias$2/;
    s/(^\w+\*?\s+($trusted))/\@trusted $1/;
    s/(^\s+)d(\s+d;)/$1_D$2/;
    s/(^\s+struct\s+)d/$1_D/;
    s/^(\s*(warning_return|fatal_return)\s+=\s+)/$1cast(int)/;
    s/^(\s*struct\s+WOLFSSL_EVP_PKEY)_/$1/;
    s/(int\s+wolfSSL_get_error\s*\()(\w+)/$1const\($2\)/;
    s/(alias\s+wolfSSL_PemCertToDer\s*=)/\/\/ DSTEP: $1/;
    s/(char\[)(CTC_NAME_SIZE\])/$1Ctc_Misc.$2/;
    s/(enum\s+WOLFSSL_EVP_PKEY_DEFAULT\s*=)/\/\/ DSTEP: $1/;
    print;
}

