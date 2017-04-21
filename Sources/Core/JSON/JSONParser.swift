#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CYAJL

public struct JSONParserError: Error, CustomStringConvertible {
    let reason: String

    public var description: String {
        return reason
    }
}

public final class JSONParser: ViewParser {

    public struct Options: OptionSet {
        public let rawValue: Int
        public static let allowComments = Options(rawValue: 1 << 0)
        public static let dontValidateStrings = Options(rawValue: 1 << 1)
        public static let allowTrailingGarbage = Options(rawValue: 1 << 2)
        public static let allowMultipleValues = Options(rawValue: 1 << 3)
        public static let allowPartialValues = Options(rawValue: 1 << 4)

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public let options: Options

    fileprivate var state: JSONParserState = JSONParserState(dictionary: true)
    fileprivate var stack: [JSONParserState] = []

    fileprivate let bufferCapacity = 8*1024
    fileprivate let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: 8*1024)

    fileprivate var result: View?

    fileprivate var handle: yajl_handle!

    public convenience init() {
        self.init(options: [])
    }

    public init(options: Options = []) {
        self.options = options
        self.state.dictionaryKey = "root"
        self.stack.reserveCapacity(12)

        handle = yajl_alloc(&yajl_handle_callbacks,
                            nil,
                            Unmanaged.passUnretained(self).toOpaque())

        yajl_config_set(handle, yajl_allow_comments, options.contains(.allowComments) ? 1 : 0)
        yajl_config_set(handle, yajl_dont_validate_strings, options.contains(.dontValidateStrings) ? 1 : 0)
        yajl_config_set(handle, yajl_allow_trailing_garbage, options.contains(.allowTrailingGarbage) ? 1 : 0)
        yajl_config_set(handle, yajl_allow_multiple_values, options.contains(.allowMultipleValues) ? 1 : 0)
        yajl_config_set(handle, yajl_allow_partial_values, options.contains(.allowPartialValues) ? 1 : 0)

    }
    deinit {
        yajl_free(handle)
        buffer.deallocate(capacity: bufferCapacity)
    }

    public func parse(buffer: UnsafeBufferPointer<Byte>) throws -> ViewParserResult {
        let final = buffer.isEmpty

        if let result = result {
            guard final else {
                throw JSONParserError(reason: "Unexpected bytes. Parser already completed.")
            }
            return .done(result)
        }

        let status: yajl_status
        if !final {
            status = yajl_parse(handle, buffer.baseAddress!, buffer.count)
        } else {
            status = yajl_complete_parse(handle)
        }

        guard status == yajl_status_ok else {
            let reasonBytes = yajl_get_error(handle, 1, buffer.baseAddress!, buffer.count)
            defer {
                yajl_free_error(handle, reasonBytes)
            }
            let reason = String(cString: reasonBytes!)
            throw JSONParserError(reason: reason)
        }

        if stack.count == 0 || final {
            switch state.view {
            case .dictionary(let value):
                result = value["root"]
            default:
                break
            }
        }

        if final {
            guard let result = result else {
                throw JSONParserError(reason: "Unexpected end of bytes")
            }

            return .done(result)
        }

        return .continue
    }

    fileprivate func appendNull() -> Int32 {
        return state.appendNull()
    }

    fileprivate func appendBoolean(_ value: Bool) -> Int32 {
        return state.append(value)
    }

    fileprivate func appendInteger(_ value: Int64) -> Int32 {
        return state.append(value)
    }

    fileprivate func appendDouble(_ value: Double) -> Int32 {
        return state.append(value)
    }

    fileprivate func appendString(_ value: String) -> Int32 {
        return state.append(value)
    }

    fileprivate func startMap() -> Int32 {
        stack.append(state)
        state = JSONParserState(dictionary: true)
        return 1
    }

    fileprivate func mapKey(_ key: String) -> Int32 {
        state.dictionaryKey = key
        return 1
    }

    fileprivate func endMap() -> Int32 {
        if stack.count == 0 {
            return 0
        }
        var previousState = stack.removeLast()
        let result: Int32 = previousState.append(state.view)
        state = previousState
        return result
    }

    fileprivate func startArray() -> Int32 {
        stack.append(state)
        state = JSONParserState(dictionary: false)
        return 1
    }

    fileprivate func endArray() -> Int32 {
        if stack.count == 0 {
            return 0
        }
        var previousState = stack.removeLast()
        let result: Int32 = previousState.append(state.view)
        state = previousState
        return result
    }

}

fileprivate struct JSONParserState {
    let isDictionary: Bool
    var dictionaryKey: String = ""

    var view: View {
        if isDictionary {
            return .dictionary(dictionary)
        } else {
            return .array(array)
        }
    }

    private var dictionary: [String: View]
    private var array: [View]

    init(dictionary: Bool) {
        self.isDictionary = dictionary
        if dictionary {
            self.dictionary = Dictionary<String, View>(minimumCapacity: 32)
            self.array = []
        } else {
            self.dictionary = [:]
            self.array = []
            self.array.reserveCapacity(32)
        }
    }

    mutating func append(_ value: Bool) -> Int32 {
        if isDictionary {
            dictionary[dictionaryKey] = .bool(value)
        } else {
            array.append(.bool(value))
        }
        return 1
    }

    mutating func append(_ value: Int64) -> Int32 {
        if isDictionary {
            dictionary[self.dictionaryKey] = .int(Int(value))
        } else {
            array.append(.int(Int(value)))
        }
        return 1
    }

    mutating func append(_ value: Double) -> Int32 {
        if isDictionary {
            dictionary[dictionaryKey] = .double(value)
        } else {
            array.append(.double(value))
        }
        return 1
    }

    mutating func append(_ value: String) -> Int32 {
        if isDictionary {
            dictionary[dictionaryKey] = .string(value)
        } else {
            array.append(.string(value))
        }
        return 1
    }

    mutating func appendNull() -> Int32 {
        if isDictionary {
            dictionary[dictionaryKey] = .null
        } else {
            array.append(.null)
        }
        return 1
    }

    mutating func append(_ value: View) -> Int32 {
        if isDictionary {
            dictionary[dictionaryKey] = value
        } else {
            array.append(value)
        }
        return 1
    }
}

fileprivate var yajl_handle_callbacks = yajl_callbacks(
    yajl_null: yajl_null,
    yajl_boolean: yajl_boolean,
    yajl_integer: yajl_integer,
    yajl_double: yajl_double,
    yajl_number: nil,
    yajl_string: yajl_string,
    yajl_start_map: yajl_start_map,
    yajl_map_key: yajl_map_key,
    yajl_end_map: yajl_end_map,
    yajl_start_array: yajl_start_array,
    yajl_end_array: yajl_end_array
)

fileprivate func yajl_null(_ ptr: UnsafeMutableRawPointer?) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.appendNull()
}

fileprivate func yajl_boolean(_ ptr: UnsafeMutableRawPointer?, value: Int32) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.appendBoolean(value != 0)
}

fileprivate func yajl_integer(_ ptr: UnsafeMutableRawPointer?, value: Int64) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.appendInteger(value)
}

fileprivate func yajl_double(_ ptr: UnsafeMutableRawPointer?, value: Double) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.appendDouble(value)
}

fileprivate func yajl_string(_ ptr: UnsafeMutableRawPointer?, buffer: UnsafePointer<Byte>?, bufferLength: Int) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()

    let str: String
    if bufferLength > 0 {
        if bufferLength < ctx.bufferCapacity {
            memcpy(UnsafeMutableRawPointer(ctx.buffer), UnsafeRawPointer(buffer!), bufferLength)
            ctx.buffer[bufferLength] = 0
            str = String(cString: UnsafePointer(ctx.buffer))
        } else {
            var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferLength + 1)
            defer { buffer.deallocate(capacity: bufferLength + 1) }
            buffer[bufferLength] = 0
            str = String(cString: UnsafePointer(buffer))
        }
    } else {
        str = ""
    }

    return ctx.appendString(str)
}

fileprivate func yajl_start_map(_ ptr: UnsafeMutableRawPointer?) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.startMap()
}

fileprivate func yajl_map_key(_ ptr: UnsafeMutableRawPointer?, buffer: UnsafePointer<Byte>?, bufferLength: Int) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()

    let str: String
    if bufferLength > 0 {
        if bufferLength < ctx.bufferCapacity {
            memcpy(UnsafeMutableRawPointer(ctx.buffer), UnsafeRawPointer(buffer!), bufferLength)
            ctx.buffer[bufferLength] = 0
            str = String(cString: UnsafePointer(ctx.buffer))
        } else {
            var buffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufferLength + 1)
            defer { buffer.deallocate(capacity: bufferLength + 1) }
            buffer[bufferLength] = 0
            str = String(cString: UnsafePointer(buffer))
        }
    } else {
        str = ""
    }

    return ctx.mapKey(str)
}

fileprivate func yajl_end_map(_ ptr: UnsafeMutableRawPointer?) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.endMap()
}

fileprivate func yajl_start_array(_ ptr: UnsafeMutableRawPointer?) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.startArray()
}

fileprivate func yajl_end_array(_ ptr: UnsafeMutableRawPointer?) -> Int32 {
    let ctx = Unmanaged<JSONParser>.fromOpaque(ptr!).takeUnretainedValue()
    return ctx.endArray()
}
