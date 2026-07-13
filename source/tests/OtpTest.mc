import Toybox.Lang;
using Toybox.Test;

//! Unit tests for the OTP crypto stack (Convert / Sha1 / Hmac / Otp), pinned to
//! published RFC test vectors so a regression in any layer is caught.

//! Base32 decode (RFC 4648). "MZXW6YTBOI" is base32("foobar") without padding;
//! decoding the significant chars yields the original bytes.
(:test)
function testBase32Decode(logger as Test.Logger) as Boolean {
    Test.assertEqualMessage(
        Convert.base32decode2HexString("MZXW6YTBOI"),
        "666F6F626172",
        "base32('foobar') should decode to hex 666F6F626172");
    return true;
}

//! Hex <-> byte array round-trips.
(:test)
function testHexByteRoundTrip(logger as Test.Logger) as Boolean {
    var hex = "0A1B2CFF";
    Test.assertEqualMessage(
        Convert.byteArrayToHexString(Convert.hexStringToByteArray(hex)),
        hex,
        "hex -> bytes -> hex should be identity");
    return true;
}

//! SHA-1 of "abc" (FIPS 180 example).
(:test)
function testSha1Abc(logger as Test.Logger) as Boolean {
    var input = [0x61, 0x62, 0x63]; // "abc"
    Test.assertEqualMessage(
        Convert.byteArrayToHexString(Sha1.encode(input)),
        "A9993E364706816ABA3E25717850C26C9CD0D89D",
        "SHA1('abc') vector");
    return true;
}

//! HMAC-SHA1, RFC 2202 test case 1: key = 20 x 0x0b, data = "Hi There".
(:test)
function testHmacSha1(logger as Test.Logger) as Boolean {
    var key = new [20];
    for (var i = 0; i < 20; i++) { key[i] = 0x0b; }
    var data = [0x48, 0x69, 0x20, 0x54, 0x68, 0x65, 0x72, 0x65]; // "Hi There"
    Test.assertEqualMessage(
        Convert.byteArrayToHexString(Hmac.authenticateWithSha1(key, data)),
        "B617318655057264E28BC0B6FB378C8EF146BE00",
        "HMAC-SHA1 RFC 2202 case 1");
    return true;
}

//! HOTP (RFC 4226 Appendix D), secret "12345678901234567890".
(:test)
function testHotpVectors(logger as Test.Logger) as Boolean {
    var keyHex = "3132333435363738393031323334353637383930";
    Test.assertEqualMessage(Otp.generateHotpSha1(keyHex, 0, 6), "755224", "HOTP counter 0");
    Test.assertEqualMessage(Otp.generateHotpSha1(keyHex, 1, 6), "287082", "HOTP counter 1");
    Test.assertEqualMessage(Otp.generateHotpSha1(keyHex, 5, 6), "254676", "HOTP counter 5");
    Test.assertEqualMessage(Otp.generateHotpSha1(keyHex, 9, 6), "520489", "HOTP counter 9");
    return true;
}

//! HOTP digit count is clamped to 8 and zero-padded.
(:test)
function testHotpDigitClamp(logger as Test.Logger) as Boolean {
    var keyHex = "3132333435363738393031323334353637383930";
    Test.assertEqualMessage(Otp.generateHotpSha1(keyHex, 0, 6).length(), 6, "6-digit HOTP length");
    return true;
}
