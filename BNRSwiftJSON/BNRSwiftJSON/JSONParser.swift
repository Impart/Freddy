//
//  JSONParser.swift
//  BNRSwiftJSON
//
//  Created by John Gallagher on 4/18/15.
//  Copyright (c) 2015 BigNerdRanch. All rights reserved.
//

import Foundation
import Result

public func JSONFromString(s: String) -> Result<JSON> {
    return s.nulTerminatedUTF8.withUnsafeBufferPointer { nulTerminatedBuffer in
        // don't want to include the nul termination in the buffer - trim it off
        let buffer = UnsafeBufferPointer(start: nulTerminatedBuffer.baseAddress, count: nulTerminatedBuffer.count - 1)
        return JSONFromUnsafeBufferPointer(buffer)
    }
}

public func JSONFromUTF8Data(data: NSData) -> Result<JSON> {
    let buffer = UnsafeBufferPointer(start: UnsafePointer<UInt8>(data.bytes), count: data.length)
    return JSONFromUnsafeBufferPointer(buffer)
}

public func JSONFromUnsafeBufferPointer(buffer: UnsafeBufferPointer<UInt8>) -> Result<JSON> {
    var parser = Parser(input: buffer)
    switch parser.parse() {
    case .Ok(let json):
        return Result(success: json)
    case .Err(let error):
        return Result(failure: error)
    }
}

private func makeParseError(reason: String) -> Parser.Result {
    return .Err(JSON.makeError(.CouldNotParseJSON, problem: reason))
}

private struct Literal {
    static let BACKSLASH     = UInt8(ascii: "\\")
    static let BACKSPACE     = UInt8(ascii: "\u{0008}")
    static let COLON         = UInt8(ascii: ":")
    static let COMMA         = UInt8(ascii: ",")
    static let DOUBLE_QUOTE  = UInt8(ascii: "\"")
    static let FORMFEED      = UInt8(ascii: "\u{000c}")
    static let LEFT_BRACE    = UInt8(ascii: "{")
    static let LEFT_BRACKET  = UInt8(ascii: "[")
    static let MINUS         = UInt8(ascii: "-")
    static let NEWLINE       = UInt8(ascii: "\n")
    static let PERIOD        = UInt8(ascii: ".")
    static let PLUS          = UInt8(ascii: "+")
    static let RETURN        = UInt8(ascii: "\r")
    static let RIGHT_BRACE   = UInt8(ascii: "}")
    static let RIGHT_BRACKET = UInt8(ascii: "]")
    static let SLASH         = UInt8(ascii: "/")
    static let SPACE         = UInt8(ascii: " ")
    static let TAB           = UInt8(ascii: "\t")

    static let a = UInt8(ascii: "a")
    static let b = UInt8(ascii: "b")
    static let c = UInt8(ascii: "c")
    static let d = UInt8(ascii: "d")
    static let e = UInt8(ascii: "e")
    static let f = UInt8(ascii: "f")
    static let l = UInt8(ascii: "l")
    static let n = UInt8(ascii: "n")
    static let r = UInt8(ascii: "r")
    static let s = UInt8(ascii: "s")
    static let t = UInt8(ascii: "t")
    static let u = UInt8(ascii: "u")

    static let A = UInt8(ascii: "A")
    static let B = UInt8(ascii: "B")
    static let C = UInt8(ascii: "C")
    static let D = UInt8(ascii: "D")
    static let E = UInt8(ascii: "E")
    static let F = UInt8(ascii: "F")

    static let zero  = UInt8(ascii: "0")
    static let one   = UInt8(ascii: "1")
    static let two   = UInt8(ascii: "2")
    static let three = UInt8(ascii: "3")
    static let four  = UInt8(ascii: "4")
    static let five  = UInt8(ascii: "5")
    static let six   = UInt8(ascii: "6")
    static let seven = UInt8(ascii: "7")
    static let eight = UInt8(ascii: "8")
    static let nine  = UInt8(ascii: "9")
}

private struct Parser {
    enum Result {
        case Ok(JSON)
        case Err(NSError)
    }

    let input: UnsafeBufferPointer<UInt8>
    var loc = 0

    init(input: UnsafeBufferPointer<UInt8>) {
        self.input = input
    }

    func head() -> UInt8? {
        if loc < input.count {
            return input[loc]
        }
        return nil
    }

    mutating func parse() -> Result {
        switch parseValue() {
        case let .Ok(value):
            if loc != input.count {
                skipWhitespace()
                if loc != input.count {
                    return makeParseError("unexpected data after parsed JSON")
                }
            }
            return .Ok(value)

        case let result:
            return result
        }
    }

    mutating func parseValue() -> Result {
        while let c = head() {
            switch c {
            case Literal.SPACE, Literal.TAB, Literal.RETURN, Literal.NEWLINE:
                ++loc

            case Literal.LEFT_BRACE:
                return decodeObject()

            case Literal.LEFT_BRACKET:
                return decodeArray()

            case Literal.DOUBLE_QUOTE:
                return decodeString()

            case Literal.MINUS:
                return decodeNumberNegative(loc)

            case Literal.zero:
                return decodeNumberLeadingZero(loc)

            case Literal.one
            ,    Literal.two
            ,    Literal.three
            ,    Literal.four
            ,    Literal.five
            ,    Literal.six
            ,    Literal.seven
            ,    Literal.eight
            ,    Literal.nine:
                return decodeNumberPreDecimalDigits(loc)

            case Literal.n:
                return decodeNull()

            case Literal.t:
                return decodeTrue()

            case Literal.f:
                return decodeFalse()

            default:
                return makeParseError("did not find start of valid JSON data")
            }
        }
        return makeParseError("did not find start of valid JSON data")
    }

    mutating func skipWhitespace() {
        while let c = head() {
            switch c {
            case Literal.SPACE, Literal.TAB, Literal.RETURN, Literal.NEWLINE:
                ++loc

            default:
                return
            }
        }
    }

    mutating func decodeNull() -> Result {
        if loc + 4 > input.count {
            return makeParseError("invalid token at position \(loc) - expected `null`")
        }

        if     input[loc+1] != Literal.u
            || input[loc+2] != Literal.l
            || input[loc+3] != Literal.l {
                return makeParseError("invalid token at position \(loc) - expected `null`")
        }

        loc += 4
        return .Ok(.Null)
    }

    mutating func decodeTrue() -> Result {
        if loc + 4 > input.count {
            return makeParseError("invalid token at position \(loc) - expected `true`")
        }

        if     input[loc+1] != Literal.r
            || input[loc+2] != Literal.u
            || input[loc+3] != Literal.e {
            return makeParseError("invalid token at position \(loc) - expected `true`")
        }

        loc += 4
        return .Ok(.Bool(true))
    }

    mutating func decodeFalse() -> Result {
        if loc + 5 > input.count {
            return makeParseError("invalid token at position \(loc) - expected `false`")
        }

        if     input[loc+1] != Literal.a
            || input[loc+2] != Literal.l
            || input[loc+3] != Literal.s
            || input[loc+4] != Literal.e {
            return makeParseError("invalid token at position \(loc) - expected `false`")
        }

        loc += 5
        return .Ok(.Bool(false))
    }

    var stringDecodingBuffer = [UInt8]()
    mutating func decodeString() -> Result {
        let start = loc
        ++loc
        stringDecodingBuffer.removeAll(keepCapacity: true)
        while loc < input.count {
            switch input[loc] {
            case Literal.BACKSLASH:
                switch input[++loc] {
                case Literal.DOUBLE_QUOTE: stringDecodingBuffer.append(Literal.DOUBLE_QUOTE)
                case Literal.BACKSLASH:    stringDecodingBuffer.append(Literal.BACKSLASH)
                case Literal.SLASH:        stringDecodingBuffer.append(Literal.SLASH)
                case Literal.b:            stringDecodingBuffer.append(Literal.BACKSPACE)
                case Literal.f:            stringDecodingBuffer.append(Literal.FORMFEED)
                case Literal.r:            stringDecodingBuffer.append(Literal.RETURN)
                case Literal.t:            stringDecodingBuffer.append(Literal.TAB)
                case Literal.n:            stringDecodingBuffer.append(Literal.NEWLINE)
                case Literal.u:
                    if let escaped = readUnicodeEscape(loc + 1) {
                        stringDecodingBuffer.extend(escaped)
                        loc += 4
                    } else {
                        return makeParseError("invalid unicode escape sequence at position \(loc)")
                    }

                default:
                    return makeParseError("invalid escape sequence at position \(loc)")
                }
                ++loc

            case Literal.DOUBLE_QUOTE:
                ++loc
                stringDecodingBuffer.append(0)
                return stringDecodingBuffer.withUnsafeBufferPointer { buffer -> Result in
                    if let s = String.fromCString(UnsafePointer<CChar>(buffer.baseAddress)) {
                        return .Ok(.String(s))
                    } else {
                        return makeParseError("invalid string at position \(start) - possibly malformed unicode characters")
                    }
                }

            case let other:
                stringDecodingBuffer.append(other)
                ++loc
            }
        }

        return makeParseError("unexpected end of data while parsing string at position \(start)")
    }

    func readUnicodeEscape(from: Int) -> [UInt8]? {
        if from + 4 > input.count {
            return nil
        }
        var codepoint: UInt16 = 0
        for i in from ..< from + 4 {
            let nibble: UInt16
            switch input[i] {
            case Literal.zero
            ,    Literal.one
            ,    Literal.two
            ,    Literal.three
            ,    Literal.four
            ,    Literal.five
            ,    Literal.six
            ,    Literal.seven
            ,    Literal.eight
            ,    Literal.nine:
                nibble = UInt16(input[i] - Literal.zero)

            case Literal.a
            ,    Literal.b
            ,    Literal.c
            ,    Literal.d
            ,    Literal.e
            ,    Literal.f:
                nibble = 10 + UInt16(input[i] - Literal.a)

            case Literal.A
            ,    Literal.B
            ,    Literal.C
            ,    Literal.D
            ,    Literal.E
            ,    Literal.F:
                nibble = 10 + UInt16(input[i] - Literal.A)

            default:
                return nil
            }
            codepoint = (codepoint << 4) | nibble
        }
        // UTF16-to-UTF8, via wikipedia
        if codepoint <= 0x007f {
            return [UInt8(codepoint)]
        } else if codepoint <= 0x07ff {
            return [0b11000000 | UInt8(codepoint >> 6),
                0b10000000 | UInt8(codepoint & 0x3f)]
        } else {
            return [0b11100000 | UInt8(codepoint >> 12),
                0b10000000 | UInt8((codepoint >> 6) & 0x3f),
                0b10000000 | UInt8(codepoint & 0x3f)]
        }
    }

    mutating func decodeArray() -> Result {
        let start = loc
        ++loc
        var items = [JSON]()

        while loc < input.count {
            skipWhitespace()

            if head() == Literal.RIGHT_BRACKET {
                ++loc
                return .Ok(.Array(items))
            }

            if !items.isEmpty {
                if head() == Literal.COMMA {
                    ++loc
                } else {
                    return makeParseError("invalid array at position \(start) - missing `,` between elements")
                }
            }

            switch parseValue() {
            case .Ok(let json):
                items.append(json)

            case let error:
                return error
            }
        }

        return makeParseError("unexpected end of data while parsing array at position \(start)")
    }

    mutating func decodeObject() -> Result {
        let start = loc
        ++loc
        var pairs = [(String,JSON)]()

        while loc < input.count {
            skipWhitespace()

            if head() == Literal.RIGHT_BRACE {
                ++loc
                var obj = [String:JSON](minimumCapacity: pairs.count)
                for (k, v) in pairs {
                    obj[k] = v
                }
                return .Ok(.Dictionary(obj))
            }

            if !pairs.isEmpty {
                if head() == Literal.COMMA {
                    ++loc
                    skipWhitespace()
                } else {
                    return makeParseError("invalid object at position \(start) - missing `,` between elements")
                }
            }

            let key: String
            if head() == Literal.DOUBLE_QUOTE {
                switch decodeString() {
                case .Ok(let json):
                    key = json.string!
                case let error:
                    return error
                }
            } else {
                return makeParseError("invalid object at position \(start) - missing key")
            }

            skipWhitespace()
            if head() == Literal.COLON {
                ++loc
            } else {
                return makeParseError("invalid object at position \(start) - missing `:` between key and value")
            }

            switch parseValue() {
            case .Ok(let json):
                pairs.append((key, json))
            case let error:
                return error
            }
        }

        return makeParseError("unexpected end of data while parsing object at position \(start)")
    }

    mutating func decodeNumberNegative(start: Int) -> Result {
        if ++loc >= input.count {
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }

        switch input[loc] {
        case Literal.zero:
            return decodeNumberLeadingZero(start)

        case Literal.one
        ,    Literal.two
        ,    Literal.three
        ,    Literal.four
        ,    Literal.five
        ,    Literal.six
        ,    Literal.seven
        ,    Literal.eight
        ,    Literal.nine:
            return decodeNumberPreDecimalDigits(start)

        default:
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }
    }

    mutating func decodeNumberLeadingZero(start: Int) -> Result {
        if ++loc >= input.count {
            return convertNumberFromPosition(start)
        }

        switch input[loc] {
        case Literal.PERIOD:
            return decodeNumberDecimal(start)

        default:
            return convertNumberFromPosition(start)
        }
    }

    mutating func decodeNumberPreDecimalDigits(start: Int) -> Result {
        while ++loc < input.count {
            switch input[loc] {
            case Literal.zero
            ,    Literal.one
            ,    Literal.two
            ,    Literal.three
            ,    Literal.four
            ,    Literal.five
            ,    Literal.six
            ,    Literal.seven
            ,    Literal.eight
            ,    Literal.nine:
                // loop again
                break

            case Literal.PERIOD:
                return decodeNumberDecimal(start)

            case Literal.e, Literal.E:
                return decodeNumberExponent(start)

            default:
                return convertNumberFromPosition(start)
            }
        }
        return convertNumberFromPosition(start)
    }

    mutating func decodeNumberDecimal(start: Int) -> Result {
        if ++loc >= input.count {
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }

        switch input[loc] {
        case Literal.zero
        ,    Literal.one
        ,    Literal.two
        ,    Literal.three
        ,    Literal.four
        ,    Literal.five
        ,    Literal.six
        ,    Literal.seven
        ,    Literal.eight
        ,    Literal.nine:
            return decodeNumberPostDecimalDigits(start)

        default:
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }
    }

    mutating func decodeNumberPostDecimalDigits(start: Int) -> Result {
        while ++loc < input.count {
            switch input[loc] {
            case Literal.zero
            ,    Literal.one
            ,    Literal.two
            ,    Literal.three
            ,    Literal.four
            ,    Literal.five
            ,    Literal.six
            ,    Literal.seven
            ,    Literal.eight
            ,    Literal.nine:
                // loop again
                break

            case Literal.e, Literal.E:
                return decodeNumberExponent(start)

            default:
                return convertNumberFromPosition(start)
            }
        }
        return convertNumberFromPosition(start)
    }

    mutating func decodeNumberExponent(start: Int) -> Result {
        if ++loc >= input.count {
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }

        switch input[loc] {
        case Literal.zero
        ,    Literal.one
        ,    Literal.two
        ,    Literal.three
        ,    Literal.four
        ,    Literal.five
        ,    Literal.six
        ,    Literal.seven
        ,    Literal.eight
        ,    Literal.nine:
            return decodeNumberExponentDigits(start)

        case Literal.PLUS, Literal.MINUS:
            return decodeNumberExponentSign(start)

        default:
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }
    }

    mutating func decodeNumberExponentSign(start: Int) -> Result {
        if ++loc >= input.count {
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }
        switch input[loc] {
        case Literal.zero
        ,    Literal.one
        ,    Literal.two
        ,    Literal.three
        ,    Literal.four
        ,    Literal.five
        ,    Literal.six
        ,    Literal.seven
        ,    Literal.eight
        ,    Literal.nine:
            return decodeNumberExponentDigits(start)

        default:
            return makeParseError("unexpected end of data while parsing number at position \(start)")
        }
    }

    mutating func decodeNumberExponentDigits(start: Int) -> Result {
        while ++loc < input.count {
            switch input[loc] {
            case Literal.zero
            ,    Literal.one
            ,    Literal.two
            ,    Literal.three
            ,    Literal.four
            ,    Literal.five
            ,    Literal.six
            ,    Literal.seven
            ,    Literal.eight
            ,    Literal.nine:
                // stay in same state
                break

            default:
                return convertNumberFromPosition(start)
            }
        }
        return convertNumberFromPosition(start)
    }
    
    var convertNumberBuffer = [UInt8]()
    mutating func convertNumberFromPosition(start: Int) -> Result {
        convertNumberBuffer.removeAll(keepCapacity: true)
        for i in start ..< loc {
            convertNumberBuffer.append(input[i])
        }
        convertNumberBuffer.append(0)
        return convertNumberBuffer.withUnsafeBufferPointer { buffer -> Result in
            let value = strtod(UnsafePointer<CChar>(buffer.baseAddress), nil)
            if value.isFinite {
                return .Ok(.Number(value))
            } else {
                return makeParseError("invalid number at position \(start)")
            }
        }
    }
}
