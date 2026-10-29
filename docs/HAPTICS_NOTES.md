HAPTICS_NOTES
Date: Sat Oct 25 2026

HapticsService uses NSHapticFeedbackManager.defaultPerformer.perform(pattern: .levelChange/.alignment/.generic, performanceTime: .now), main-thread only, rate-limited to >=40ms gap, respects hapticsEnabled. Open fires at acceptance moment (before animation), close on acceptance. No fire for cancelled/rejected intents. DEBUG tool plays patterns 600ms apart with os_log.

Note: Trackpad haptics only felt while a finger is touching the trackpad. If silent when opening by hover with finger on trackpad while another app is frontmost, this is expected behavior of NSHapticFeedbackManager and may require the app to be active/focused or may be suppressed; tried .now and .default via test tool.
