#!/usr/bin/env swift
import Foundation
import CryptoKit

// Release-only verification against the public key embedded in the app.
// No private key is read, printed, or stored by this tool.
let arguments = CommandLine.arguments
if arguments.count == 2, arguments[1] == "--self-test" {
    let key = Curve25519.Signing.PrivateKey()
    let bytes = Data("disposable release verification".utf8)
    let signature = try key.signature(for: bytes)
    guard key.publicKey.isValidSignature(signature, for: bytes),
          !key.publicKey.isValidSignature(signature, for: bytes + Data([0])),
          !Curve25519.Signing.PrivateKey().publicKey.isValidSignature(signature, for: bytes) else { exit(1) }
    print("Ed25519 verification rejects tampered bytes and a mismatched public key")
    exit(0)
}
guard arguments.count == 4,
      let publicBytes = Data(base64Encoded: arguments[2]), publicBytes.count == 32,
      let signature = Data(base64Encoded: arguments[3]), signature.count == 64 else {
    FileHandle.standardError.write(Data("usage: verify_update_signature.swift ARCHIVE PUBLIC_KEY SIGNATURE\n".utf8))
    exit(64)
}
do {
    let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicBytes)
    let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
    guard publicKey.isValidSignature(signature, for: archive) else { throw CocoaError(.fileReadCorruptFile) }
    print("Update archive signature matches the application's public key")
} catch {
    FileHandle.standardError.write(Data("Update signature verification failed.\n".utf8))
    exit(1)
}
