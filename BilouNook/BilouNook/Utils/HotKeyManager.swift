import Carbon
import AppKit
import os.log

#if DEBUG
class HotKeyManager {
    static let shared = HotKeyManager()
    private static let logger = OSLog(subsystem: "com.bilou.BilouNook", category: "hotkeys")
    private static let signature: OSType = 0x42494C4F
    private var registered = false
    var hotKeyRefs: [EventHotKeyRef?] = []
    private var hapticShortcutName = "none"
    
    func register() {
        guard !registered else {
            os_log(.info, log: Self.logger, "register skipped already_registered=true")
            return
        }
        registered = true
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async {
                if hotKeyID.id == 1 {
                    os_log(.info, log: HotKeyManager.logger, "ENTRY id=1 shortcut=option+command+D action=debugOverlay")
                    DebugOverlayWindow.shared.toggle()
                    os_log(.info, log: HotKeyManager.logger, "EXIT id=1 shortcut=option+command+D action=debugOverlay")
                } else if hotKeyID.id == 2 {
                    os_log(.info, log: HotKeyManager.logger, "ENTRY id=2 shortcut=option+command+L action=animationLab")
                    AnimationLabWindow.shared.toggle()
                    os_log(.info, log: HotKeyManager.logger, "EXIT id=2 shortcut=option+command+L action=animationLab")
                } else if hotKeyID.id == 3 {
                    let key = HotKeyManager.shared.hapticShortcutName
                    os_log(.info, log: HotKeyManager.logger, "ENTRY id=3 shortcut=option+command+%@ action=haptic", key)
                    HapticsService.shared.playOnce(.generic)
                    os_log(.info, log: HotKeyManager.logger, "EXIT id=3 shortcut=option+command+%@ action=haptic", key)
                } else {
                    os_log(.info, log: HotKeyManager.logger, "fire unknown id=%{public}u", hotKeyID.id)
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
        os_log(.info, log: Self.logger, "InstallEventHandler status=%{public}d", handlerStatus)
        
        registerHotKey(id: 1, key: UInt32(kVK_ANSI_D), name: "D")
        registerHotKey(id: 2, key: UInt32(kVK_ANSI_L), name: "L")
        
        let hapticCandidates: [(UInt32, String)] = [
            (UInt32(kVK_ANSI_J), "J"),
            (UInt32(kVK_ANSI_K), "K"),
            (UInt32(kVK_ANSI_U), "U"),
        ]
        for (key, name) in hapticCandidates {
            if registerHotKey(id: 3, key: key, name: name) == noErr {
                hapticShortcutName = name
                break
            }
        }
        os_log(.info, log: Self.logger, "haptic shortcut=option+command+%@ note=option+command+H_is_reserved_by_macOS_hide_others", hapticShortcutName)
    }
    
    @discardableResult
    private func registerHotKey(id: UInt32, key: UInt32, name: String) -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(key, UInt32(optionKey | cmdKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        os_log(.info, log: Self.logger, "RegisterEventHotKey id=%{public}u key=%{public}@ status=%{public}d", id, name, status)
        if status == noErr {
            hotKeyRefs.append(hotKeyRef)
        }
        return status
    }
}
#endif
