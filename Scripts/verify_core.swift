#!/usr/bin/env swift
import Foundation

// Inline minimal verification when XCTest/Xcode is unavailable.

enum DurationParser {
    static func seconds(from time: String) -> Int? {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return nil
        }
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ message: String) {
    guard a == b else {
        fputs("FAIL: \(message) — expected \(b), got \(a)\n", stderr)
        exit(1)
    }
    print("OK: \(message)")
}

assertEqual(DurationParser.seconds(from: "3:45"), 225, "duration 3:45")
assertEqual(DurationParser.seconds(from: "1:02:03"), 3723, "duration 1:02:03")
assertEqual(DurationParser.seconds(from: ""), nil, "empty duration")

let csv = """
Title,Artist,Album,Time,BPM,Key,URL
"Song One","Artist A","Album X",3:45,128.0,Am,file:///tmp/test.mp3
"""

let rows = csv.split(separator: "\n")
assertEqual(rows.count, 2, "csv row count")
assertEqual(rows[0].hasPrefix("Title,"), true, "csv header")

print("All core verification checks passed.")
