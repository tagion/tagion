#include "hash_impl.h"

void secp256k1_sha256_initialize_w(secp256k1_sha256 *hash) {
    secp256k1_sha256_initialize(&hash);
}

void secp256k1_sha256_write_w(secp256k1_sha256 *hash, const unsigned char *data, size_t size) {
    secp256k1_sha256_write(&hash, data, size);
}

void secp256k1_sha256_finalize_w(secp256k1_sha256 *hash, unsigned char *out32) {
    secp256k1_sha256_finalize(&hash, out32);
}