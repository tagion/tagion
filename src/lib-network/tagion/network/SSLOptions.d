module tagion.network.SSLOptions;

import tagion.utils.JSONCommon;

struct OpenSSL {
    string certificate; /// Certificate file name
    string private_key; /// Private key
    uint key_size;      /// Key size (RSA 1024,2048,4096)
    uint days;          /// Number of days the certificate is valid
    string country;     /// Country Name two letters
    string state;       /// State or Province Name (full name)
    string city;        /// Locality Name (eg, city)
    string organisation; /// Organization Name (eg, company)
    string unit;        /// Organizational Unit Name (eg, section)
    string name;        /// Common Name (e.g. server FQDN or YOUR name)
    string email;       /// Email Address
    import std.range : zip, repeat, only;
    import std.format;

    auto config() const pure nothrow @nogc {
        return only(
                country,
                state,
                city,
                organisation,
                name,
                email);
        //                "\n".repeat);

    }

    auto command() const pure {
        return only(
                "openssl",
                "req",
                "-newkey",
                format!"rsa:%d"(key_size),
                "-nodes",
                "-keyout",
                private_key,
                "-x509",
                "-days",
                days.to!string,
                "-out",
                certificate);
    }

    mixin JSONCommon;
}

struct SSLOption {
    string task_name; /// Task name of the SSLService used
    string response_task_name; /// Name of the respose task name (If this is not set the respose service is not started)
    string prefix;
    string address; /// Ip address
    ushort port; /// Port
    uint max_buffer_size; /// Max buffer size
    uint max_queue_length; /// Listener max. incomming connection req. queue length

    uint max_connections; /// Max simultanious connections for the scripting engine

    uint select_timeout; /// Select timeout in ms
    // string certificate; /// Certificate file name
    // string private_key; /// Private key
    uint client_timeout; /// Client timeout
    OpenSSL openssl; ///
    mixin JSONCommon;
}
