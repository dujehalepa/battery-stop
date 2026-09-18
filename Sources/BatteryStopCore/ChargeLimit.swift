import Foundation
import ObjectiveC.runtime

/// Состояние встроенного в macOS ограничения заряда (Maximum Charge Limit).
public struct ChargeLimitState: Equatable, Sendable {
    /// Лимит поддерживается этим Mac и этой версией macOS.
    public var supported: Bool
    /// Ограничение включено.
    public var enabled: Bool
    /// Текущий порог в процентах (100 — без ограничения).
    public var limit: Int
    /// Значения, которые разрешает прошивка, например [80, 85, 90, 95, 100].
    public var availableLimits: [Int]

    public static let unsupported = ChargeLimitState(supported: false, enabled: false,
                                                     limit: 100, availableLimits: [])
}

public enum ChargeLimitError: LocalizedError {
    case unavailable
    case callFailed(String, Error?)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "This Mac or this version of macOS does not support charge limiting"
        case .callFailed(let what, let error):
            if let error { return "\(what): \(error.localizedDescription)" }
            return "\(what): the system refused the request"
        }
    }
}

/// Управляет ограничением заряда через приватный PowerUI.framework —
/// тот же механизм, что и «Системные настройки → Аккумулятор → Лимит заряда».
/// Порог хранится в прошивке, поэтому действует и во сне, и после перезагрузки,
/// и не требует ни прав root, ни фоновой службы.
public final class ChargeLimitController {
    private typealias BoolNoArg = @convention(c) (AnyObject, Selector) -> Bool
    private typealias BoolErr   = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> Bool
    private typealias SetU8Err  = @convention(c) (AnyObject, Selector, UInt8, UnsafeMutablePointer<NSError?>?) -> Bool
    private typealias U8Err     = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> UInt8
    private typealias U64Err    = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> UInt64
    private typealias ObjectErr = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<NSError?>?) -> Unmanaged<AnyObject>?

    private static let frameworkPath = "/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI"
    private static let className = "PowerUISmartChargeClient"

    private let clientClass: AnyClass
    private let client: AnyObject

    public init() throws {
        guard dlopen(Self.frameworkPath, RTLD_NOW) != nil,
              let clientClass = NSClassFromString(Self.className)
        else { throw ChargeLimitError.unavailable }

        // Класс приватный, поэтому создаём его через runtime.
        // Клиент живёт всё время работы приложения, так что владение здесь не критично.
        guard let allocated = (clientClass as AnyObject).perform(NSSelectorFromString("alloc"))?
                .takeUnretainedValue(),
              let client = allocated.perform(NSSelectorFromString("initWithClientName:"),
                                             with: Bundle.main.bundleIdentifier ?? "BatteryStop")?
                .takeUnretainedValue()
        else { throw ChargeLimitError.unavailable }

        self.clientClass = clientClass
        self.client = client
    }

    // MARK: - Чтение

    public var isSupported: Bool {
        guard let (call, selector) = method("isMCLSupported", as: BoolNoArg.self) else { return false }
        return call(client, selector)
    }

    public var isEnabled: Bool {
        guard let (call, selector) = method("isMCLCurrentlyEnabled:", as: U64Err.self) else { return false }
        var error: NSError?
        return call(client, selector, &error) != 0
    }

    public var currentLimit: Int {
        guard let (call, selector) = method("getMCLLimitWithError:", as: U8Err.self) else { return 100 }
        var error: NSError?
        let value = Int(call(client, selector, &error))
        return error == nil && value > 0 ? value : 100
    }

    public var availableLimits: [Int] {
        guard let (call, selector) = method("availableChargeLimitsWithError:", as: ObjectErr.self) else { return [] }
        var error: NSError?
        guard let values = call(client, selector, &error)?.takeUnretainedValue() as? [NSNumber] else { return [] }
        return values.map(\.intValue).sorted()
    }

    public func state() -> ChargeLimitState {
        guard isSupported else { return .unsupported }
        return ChargeLimitState(supported: true,
                                enabled: isEnabled,
                                limit: currentLimit,
                                availableLimits: availableLimits)
    }

    // MARK: - Запись

    /// Ставит порог заряда. 100% трактуется как «без ограничения».
    public func setLimit(_ percent: Int) throws {
        guard isSupported else { throw ChargeLimitError.unavailable }
        guard percent < 100 else {
            try setEnabled(false)
            return
        }
        guard let (call, selector) = method("setMCLLimit:error:", as: SetU8Err.self) else {
            throw ChargeLimitError.unavailable
        }
        var error: NSError?
        guard call(client, selector, UInt8(clamped(percent)), &error) else {
            throw ChargeLimitError.callFailed("Could not set the \(percent)% limit", error)
        }
        try setEnabled(true)
    }

    public func setEnabled(_ enabled: Bool) throws {
        guard isSupported else { throw ChargeLimitError.unavailable }
        let name = enabled ? "enableMCL:" : "disableMCL:"
        guard let (call, selector) = method(name, as: BoolErr.self) else {
            throw ChargeLimitError.unavailable
        }
        var error: NSError?
        guard call(client, selector, &error) else {
            throw ChargeLimitError.callFailed(enabled ? "Could not turn on the charge limit"
                                                      : "Could not turn off the charge limit", error)
        }
    }

    // MARK: - Внутреннее

    private func method<T>(_ name: String, as type: T.Type) -> (T, Selector)? {
        let selector = NSSelectorFromString(name)
        guard let method = class_getInstanceMethod(clientClass, selector) else { return nil }
        return (unsafeBitCast(method_getImplementation(method), to: T.self), selector)
    }

    private func clamped(_ percent: Int) -> Int {
        let limits = availableLimits
        guard !limits.isEmpty else { return min(max(percent, 80), 100) }
        // Прошивка принимает только фиксированные шаги, поэтому берём ближайший разрешённый.
        return limits.min(by: { abs($0 - percent) < abs($1 - percent) }) ?? 100
    }
}
