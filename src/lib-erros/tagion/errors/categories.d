module tagion.errors.categories;

enum ERRORS {
    HIBON = 10_000, /// HiBON format errors 
    HASHGRAPH = 11_000, /// Hashgraph consensus errors
    GOSSIPNET = 12_000, /// Gossip-network errors
    DART = 13_000, /// DART Database errors
    SECURITY = 14_000, /// Security errors signing and verification
    CIPHER = 15_000, /// Encryption and Decryptions errors
    CREDITIAL = 16_000, /// Network and contracts Authentications 
    NETWORK = 17_000, /// Basic network errors
    TVM = 18_000, /// Tagion virtual machine errors
}


