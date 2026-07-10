import Foundation

/// 小时输入 0-24，限制只能输入 0-2 开头的合法数字
final class HourFormatter: Formatter {
    override func string(for obj: Any?) -> String {
        guard let num = obj as? Int else { return "00" }
        let clamped = min(24, max(0, num))
        return String(format: "%02d", clamped)
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let val = Int(string), val >= 0, val <= 24 {
            obj?.pointee = val as NSObject
            return true
        }
        obj?.pointee = nil
        return false
    }
    
    override func isPartialStringValid(_ partialString: String, newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if partialString.isEmpty { return true }
        guard partialString.count <= 2, let val = Int(partialString) else { return false }
        return val >= 0 && val <= 24
    }
}

/// 分钟输入 0-59，限制只能输入 0-5 开头的合法数字
final class MinuteFormatter: Formatter {
    override func string(for obj: Any?) -> String {
        guard let num = obj as? Int else { return "00" }
        let clamped = min(59, max(0, num))
        return String(format: "%02d", clamped)
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let val = Int(string), val >= 0, val <= 59 {
            obj?.pointee = val as NSObject
            return true
        }
        obj?.pointee = nil
        return false
    }
    
    override func isPartialStringValid(_ partialString: String, newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if partialString.isEmpty { return true }
        guard partialString.count <= 2, let val = Int(partialString) else { return false }
        return val >= 0 && val <= 59
    }
}

/// 课程时长输入 10-180
final class DurationFieldFormatter: Formatter {
    override func string(for obj: Any?) -> String {
        guard let num = obj as? Int else { return "45" }
        return "\(min(180, max(10, num)))"
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let val = Int(string) {
            obj?.pointee = min(180, max(10, val)) as NSObject
            return true
        }
        obj?.pointee = nil
        return false
    }
    
    override func isPartialStringValid(_ partialString: String, newEditingString: AutoreleasingUnsafeMutablePointer<NSString?>?, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if partialString.isEmpty { return true }
        guard let val = Int(partialString) else { return false }
        return val >= 0 && val <= 180
    }
}
