import Carbon
import Foundation

final class GlobalHotKey {
    enum RegistrationError: LocalizedError {
        case failed(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .failed(status):
                return status == OSStatus(eventHotKeyExistsErr)
                    ? "That shortcut is already being used by another app."
                    : "macOS could not register that shortcut (error \(status))."
            }
        }
    }

    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let callback: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) throws {
        self.callback = callback

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let owner = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard hotKeyID.signature == GlobalHotKey.signature else { return noErr }
            DispatchQueue.main.async { owner.callback() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard handlerStatus == noErr else { throw RegistrationError.failed(handlerStatus) }

        let hotKeyID = EventHotKeyID(signature: GlobalHotKey.signature, id: 1)
        let registrationStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &reference)
        if registrationStatus != noErr {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            throw RegistrationError.failed(registrationStatus)
        }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }

    private static let signature: OSType = 0x56535231 // "VSR1"
}
