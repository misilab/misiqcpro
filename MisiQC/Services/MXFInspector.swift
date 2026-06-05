import Foundation

/// Reads the MXF Header Partition Pack to extract the Operational Pattern
/// (SMPTE ST 377-1), without any external dependency.
///
/// Layout we parse:
///   - 0..<65536 bytes are scanned for the Header Partition Pack key
///     `06 0E 2B 34 02 05 01 01 0D 01 02 01 01 02 XX 00`
///     (byte 14 = partition status: 01 closed-complete, 02 open-complete, 04 closed-incomplete…)
///   - Skip the BER-coded length to reach the value.
///   - The OperationalPattern UL sits at value-offset 64 (after Major/MinorVersion,
///     KAGSize, ThisPartition, PreviousPartition, FooterPartition, HeaderByteCount,
///     IndexByteCount, IndexSID, BodyOffset, BodySID — total 64 bytes).
///   - Bytes 13/14 of that UL encode the OP number / item-complexity letter:
///     `06 0E 2B 34 04 01 01 01 0D 01 02 01 01 <N> <L> 00`
enum MXFInspector {

    /// Returns the detected Operational Pattern (e.g. "OP1a", "OP2b", "OP-Atom")
    /// or `nil` if the file is not a parseable MXF Header Partition.
    static func operationalPattern(url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 65_536)
        return findOperationalPattern(in: data)
    }

    private static let partitionKeyPrefix: [UInt8] = [
        0x06, 0x0E, 0x2B, 0x34, 0x02, 0x05, 0x01, 0x01,
        0x0D, 0x01, 0x02, 0x01, 0x01, 0x02
    ]

    static func findOperationalPattern(in data: Data) -> String? {
        let bytes = [UInt8](data)
        let prefixLen = partitionKeyPrefix.count
        guard bytes.count >= prefixLen + 32 else { return nil }

        for i in 0...(bytes.count - prefixLen - 32) {
            var matches = true
            for j in 0..<prefixLen where bytes[i + j] != partitionKeyPrefix[j] {
                matches = false; break
            }
            guard matches else { continue }
            // bytes[i+14] = partition status (variable), bytes[i+15] must be 0x00.
            guard bytes[i + 15] == 0x00 else { continue }

            // BER length parsing.
            let lengthStart = i + 16
            guard lengthStart < bytes.count else { return nil }
            let first = bytes[lengthStart]
            let lengthBytes: Int
            let valueLength: Int
            if first < 0x80 {
                lengthBytes = 1
                valueLength = Int(first)
            } else {
                let n = Int(first - 0x80)
                guard n > 0, lengthStart + n < bytes.count else { return nil }
                lengthBytes = 1 + n
                var v = 0
                for k in 0..<n { v = (v << 8) | Int(bytes[lengthStart + 1 + k]) }
                valueLength = v
            }
            _ = valueLength  // not used further

            let valueStart = lengthStart + lengthBytes
            let opStart = valueStart + 64  // 16-byte OperationalPattern UL position
            guard opStart + 16 <= bytes.count else { return nil }

            let opNumber = bytes[opStart + 13]
            // SMPTE 378 / 391 / 407 encode the Package Complexity letter in the
            // low 3 bits of byte 14; high bits carry qualifier flags
            // (External Essence, Non-Streamable, Multi-Track…) we ignore for V1.
            let opComplexity = bytes[opStart + 14] & 0x07
            let letter: String
            switch opComplexity {
            case 0x01: letter = "a"
            case 0x02: letter = "b"
            case 0x03: letter = "c"
            default: letter = ""
            }
            switch opNumber {
            case 0x01: return "OP1\(letter)"
            case 0x02: return "OP2\(letter)"
            case 0x03: return "OP3\(letter)"
            case 0x10: return "OP-Atom"
            default: return "OP\(opNumber)\(letter)"
            }
        }
        return nil
    }
}
