const std = @import("std");
const Allocator = std.mem.Allocator;

const Tls = @This();

pub const HandshakeType = enum(u8) {
    hello_request = 0,
    client_hello = 1,
    server_hello = 2,
    certificate = 11,
    server_key_exchange = 12,
    certificate_request = 13,
    server_hello_done = 14,
    certifiate_verify = 15,
    client_key_exchange = 16,
    finished = 20,
};

pub const Handshake = struct {
    msg_type: HandshakeType,
    length: u24,
    body: []const u8,
};

pub const ProtocolVersion = packed struct {
    major: u8,
    minor: u8,
};

pub const CipherSuite = enum([2]u8) {
    /// This cipher suite is no different than sending unsecured messages
    null_with_null_null         = .{ 0x00,0x00 },
    /// These cipher suites require the server to provide an RSA certificate.
    rsa_with_null_md5           = .{ 0x00,0x01 },
    rsa_with_null_sha           = .{ 0x00,0x02 },
    rsa_with_null_sha256        = .{ 0x00,0x3B },
    rsa_with_rc4_128_md5        = .{ 0x00,0x04 },
    rsa_with_rc4_128_sha        = .{ 0x00,0x05 },
    rsa_with_3des_ede_cbc_sha   = .{ 0x00,0x0A },
    rsa_with_aes_128_cbc_sha    = .{ 0x00,0x2F },
    rsa_with_aes_256_cbc_sha    = .{ 0x00,0x35 },
    rsa_with_aes_128_cbc_sha256 = .{ 0x00,0x3C },
    rsa_with_aes_256_cbc_sha256 = .{ 0x00,0x3D },
    /// These cipher suites are used for server-authenticated (and optionally client-authenticated)
    /// Diffie-Hellman. DHE denotes ephemeral Diffie-Hellman.
    dh_dss_with_3des_ede_cbc_sha    = .{ 0x00,0x0D },
    dh_rsa_with_3des_ede_cbc_sha    = .{ 0x00,0x10 },
    dhe_dss_with_3des_ede_cbc_sha   = .{ 0x00,0x13 },
    dhe_rsa_with_3des_ede_cbc_sha   = .{ 0x00,0x16 },
    dh_dss_with_aes_128_cbc_sha     = .{ 0x00,0x30 },
    dh_rsa_with_aes_128_cbc_sha     = .{ 0x00,0x31 },
    dhe_dss_with_aes_128_cbc_sha    = .{ 0x00,0x32 },
    dhe_rsa_with_aes_128_cbc_sha    = .{ 0x00,0x33 },
    dh_dss_with_aes_256_cbc_sha     = .{ 0x00,0x36 },
    dh_rsa_with_aes_256_cbc_sha     = .{ 0x00,0x37 },
    dhe_dss_with_aes_256_cbc_sha    = .{ 0x00,0x38 },
    dhe_rsa_with_aes_256_cbc_sha    = .{ 0x00,0x39 },
    dh_dss_with_aes_128_cbc_sha256  = .{ 0x00,0x3E },
    dh_rsa_with_aes_128_cbc_sha256  = .{ 0x00,0x3F },
    dhe_dss_with_aes_128_cbc_sha256 = .{ 0x00,0x40 },
    dhe_rsa_with_aes_128_cbc_sha256 = .{ 0x00,0x67 },
    dh_dss_with_aes_256_cbc_sha256  = .{ 0x00,0x68 },
    dh_rsa_with_aes_256_cbc_sha256  = .{ 0x00,0x69 },
    dhe_dss_with_aes_256_cbc_sha256 = .{ 0x00,0x6A },
    dhe_rsa_with_aes_256_cbc_sha256 = .{ 0x00,0x6B },
    /// These cipher suites are used for completely anonymous Diffie-Hellman communications in
    /// which neither party are authenticated.
    dh_anon_with_rc4_128_md5        = .{ 0x00,0x18 },
    dh_anon_with_3des_ede_cbc_sha   = .{ 0x00,0x1B },
    dh_anon_with_aes_128_cbc_sha    = .{ 0x00,0x34 },
    dh_anon_with_aes_256_cbc_sha    = .{ 0x00,0x3A },
    dh_anon_with_aes_128_cbc_sha256 = .{ 0x00,0x6C },
    dh_anon_with_aes_256_cbc_sha256 = .{ 0x00,0x6D },
};

pub const Random = struct {
    gmt_unix_time: u32,
    random_bytes: [28]u8,
};

pub const ClientHello = struct {
    client_version: ProtocolVersion,
    random: Random,
    session_id: [32]u8,
    cipher_suites: []CipherSuite,
    compression_methods: []u8,
};




