import Foundation

enum HumanSizeParser {
    /// Parses a human-readable size such as "1.5GB", "890.4MB" or "1.125e+06kB"
    /// into bytes. Handles optional suffixes in parentheses (e.g. Docker's
    /// "2.345GB (2.345GB)"). Returns 0 when the input cannot be parsed.
    static func parse(_ raw: String) -> Int64 {
        guard let token = raw.split(separator: " ", maxSplits: 1).first.map({ String($0) }) else { return 0 }

        let pattern = #"^([0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)\s*([A-Za-z]*B)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: token, range: NSRange(token.startIndex..., in: token))
        else {
            return 0
        }

        let numberString = String(token[Range(match.range(at: 1), in: token)!])
        guard let value = Double(numberString) else { return 0 }

        let unitRange = Range(match.range(at: 2), in: token)
        let unit = unitRange.map { String(token[$0]) } ?? "B"

        let multiplier: Double
        switch unit.uppercased() {
        case "", "B":
            multiplier = 1
        case "KB", "KIB":
            multiplier = 1_000
        case "MB", "MIB":
            multiplier = 1_000_000
        case "GB", "GIB":
            multiplier = 1_000_000_000
        case "TB", "TIB":
            multiplier = 1_000_000_000_000
        case "PB", "PIB":
            multiplier = 1_000_000_000_000_000
        default:
            multiplier = 1
        }

        return Int64(value * multiplier)
    }
}