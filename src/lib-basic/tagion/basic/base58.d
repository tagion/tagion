/*
 * Copyright 2011 Google Inc.
 * ported to D (c) 2016 Stefan Hertenberger
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// https://github.com/bitcoinj/bitcoinj/blob/840df06b79beac1b984e6e247e90fcdedc4ad6e0/core/src/main/java/org/bitcoinj/core/Base58.java
module tagion.basic.base58;

import std.conv;

/**
 * Base58 is a way to encode Bitcoin addresses (or arbitrary data) as alphanumeric strings.
 * <p>
 * Note that this is not the same base58 as used by Flickr, which you may find referenced around the Internet.
 * <p>
 * You may want to consider working with {@link VersionedChecksummedubytes} instead, which
 * adds support for testing the prefix and suffix ubytes commonly found in addresses.
 * <p>
 * Satoshi explains: why base-58 instead of standard base-64 encoding?
 * <ul>
 * <li>Don't want 0OIl characters that look the same in some fonts and
 *     could be used to create visually identical looking account numbers.</li>
 * <li>A string with non-alphanumeric characters is not as easily accepted as an account number.</li>
 * <li>E-mail usually won't line-break if there's no punctuation to break at.</li>
 * <li>Doubleclicking selects the whole number as one word if it's all alphanumeric.</li>
 * </ul>
 * <p>
 * However, note that the encoding/decoding runs in O(n&sup2;) time, so it is not useful for large data.
 * <p>
 * The basic idea of the encoding is to treat the data ubytes as a large number represented using
 * base-256 digits, convert the number to be represented using base-58 digits, preserve the exact
 * number of leading zeros (which are otherwise lost during the mathematical operations on the
 * numbers), and finally represent the resulting base-58 digits as alphanumeric ASCII characters.
 */
enum ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
enum INDICES = generateindices();

int[128] generateindices() {
    int[128] indices;
    foreach (i; 0 .. indices.length) {
        indices[i] = -1;
    }
    foreach (i; 0 .. ALPHABET.length) {
        indices[ALPHABET[i]] = cast(int)i;
    }
    return indices;
}
  
/**
   * Encodes the given ubytes as a base58 string (no checksum is appended).
   *
   * @param input the ubytes to encode
   * @return the base58-encoded string
   */
public static string encode(ubyte[] inp) pure {
  if (inp.length == 0) {
    return "";
  }       
  // Count leading zeros.
  int zeros = 0;
  while (zeros < inp.length && inp[zeros] == 0) {
    ++zeros;
  }
  // Convert base-256 digits to base-58 digits (plus conversion to ASCII characters)
  auto input = new ubyte[inp.length];
  input[0 .. inp.length] = inp[0 .. $]; // since we modify it in-place
  auto encoded = new char[input.length * 2]; // upper bound
  auto outputStart = encoded.length;
  for (int inputStart = zeros; inputStart < input.length; ) {
    encoded[--outputStart] = ALPHABET[divmod(input, inputStart, 256, 58)];
    if (input[inputStart] == 0) {
      ++inputStart; // optimization - skip leading zeros
    }
  }
  // Preserve exactly as many leading encoded zeros in output as there were leading zeros in input.
  while (outputStart < encoded.length && encoded[outputStart] == ALPHABET[0]) {
    ++outputStart;
  }
  while (--zeros >= 0) {
    encoded[--outputStart] = ALPHABET[0];
  }
  // Return encoded string (including encoded leading zeros).
  return encoded[outputStart .. encoded.length].to!string();
}

/**
   * Decodes the given base58 string into the original data ubytes.
   *
   * @param input the base58-encoded string to decode
   * @return the decoded data ubytes
   * @throws AddressFormatException if the given string is not a valid base58 string
   */
public static ubyte[] decode(const(char[]) input) pure {
  if (input.length == 0) {
    return new ubyte[0];
  }
  // Convert the base58-encoded ASCII chars to a base58 ubyte sequence (base58 digits).
  ubyte[] input58 = new ubyte[input.length];
  for (int i = 0; i < input.length; ++i) {
    char c = input[i];
    int digit = c < 128 ? INDICES[c] : -1;
    if (digit < 0) {
      throw new Exception("Illegal character " ~ c ~ " at position " ~ to!string(i));
    }
    input58[i] = cast(ubyte) digit;
  }
  // Count leading zeros.
  int zeros = 0;
  while (zeros < input58.length && input58[zeros] == 0) {
    ++zeros;
  }
  // Convert base-58 digits to base-256 digits.
  ubyte[] decoded = new ubyte[input.length];
  int outputStart = cast(int)decoded.length;
  for (int inputStart = zeros; inputStart < input58.length; ) {
    decoded[--outputStart] = divmod(input58, inputStart, 58, 256);
    if (input58[inputStart] == 0) {
      ++inputStart; // optimization - skip leading zeros
    }
  }
  // Ignore extra leading zeroes that were added during the calculation.
  while (outputStart < decoded.length && decoded[outputStart] == 0) {
    ++outputStart;
  }
  // Return decoded data (including original number of leading zeros).
  return decoded[outputStart - zeros .. decoded.length];
}

/**
   * Divides a number, represented as an array of ubytes each containing a single digit
   * in the specified base, by the given divisor. The given number is modified in-place
   * to contain the quotient, and the return value is the remainder.
   *
   * @param number the number to divide
   * @param firstDigit the index within the array of the first non-zero digit
   *        (this is used for optimization by skipping the leading zeros)
   * @param base the base in which the number's digits are represented (up to 256)
   * @param divisor the number to divide by (up to 256)
   * @return the remainder of the division operation
   */
private static ubyte divmod(ubyte[] number, int firstDigit, int base, int divisor) pure {
  // this is just long division which accounts for the base of the input digits
  int remainder = 0;
  for (int i = firstDigit; i < number.length; i++) {
    int digit = cast(int) number[i] & 0xFF;
    int temp = remainder * base + digit;
    number[i] = cast(ubyte)(temp / divisor);
    remainder = temp % divisor;
  }
  return cast(ubyte) remainder;
}
