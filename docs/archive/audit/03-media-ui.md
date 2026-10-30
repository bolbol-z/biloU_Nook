# AUDIT 03 - Media UI, layout correctness and UX

FACTS / HYPOTHESES / RECOMMENDATIONS. Excerpts max 40 lines. PNGs in build/screens/audit-*.png.

## 1. Element inventory (from code + layout-report)

From build/screens/layout-report.json (HEAD): physical-notch open media has frames for artwork/title/artist/progressTrack/timeRow/controls/textColumn. 
MediaContentView (recovery) shows: artwork with source badge, rightColumn with title (15pt semibold), secondary line "Artist · Album" (12pt), progress bar, timeRow (10.5pt monospaced under both ends), controls (prev/next/play/pause). 
MetadataHeader was removed/emptied in compact layout - no separate app-name row, no separate album row.

Key excerpts (MediaContentView.swift):
```swift
MarqueeText(text: presentation.title.isEmpty ? "Unknown Track" : presentation.title, font: .system(size: 15, weight: .semibold, design: .rounded), color: .white, height: MediaLayout.titleHeight)
MarqueeText(text: secondary.isEmpty ? (presentation.artist.isEmpty ? "Unknown Artist" : presentation.artist) : secondary, font: .system(size: 12, weight: .medium, design: .rounded), color: Color.white.opacity(0.7), height: MediaLayout.artistHeight)
```
```swift
private var secondaryLine: String {
    let artist = presentation.artist.trimmingCharacters(in: .whitespacesAndNewlines)
    let album = presentation.album.trimmingCharacters(in: .whitespacesAndNewlines)
    if !artist.isEmpty && !album.isEmpty {
        return "\(artist) · \(album)"
    }
    if !artist.isEmpty { return artist }
    if !album.isEmpty { return album }
    return ""
}
```
```swift
private var timeRow: some View {
    HStack {
        Text(timeString(presentation.elapsed))
            .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.6))
        Spacer()
        Text(timeString(presentation.duration))
            .font(.system(size: 10.5, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(Color.white.opacity(0.6))
    }
    .frame(height: MediaLayout.timeRowHeight)
    .frame(maxWidth: .infinity)
}
```
```swift
MediaControlButton(systemName: "backward.fill", symbolSize: MediaLayout.transportSymbolSize, hitSize: 34, ...)
MediaControlButton(systemName: presentation.playPauseSymbol, symbolSize: MediaLayout.playSymbolSize, hitSize: MediaLayout.controlHitSize, emphasized: true, ...)
MediaControlButton(systemName: "forward.fill", symbolSize: MediaLayout.transportSymbolSize, hitSize: 34, ...)
```

File:lines: MediaContentView.swift ~70-210, MediaLayout.swift ~192-240, MediaProgressBar.swift, ModuleShellView.swift.


## 2. Overflow check

From layout-report.json: contentRect height 173, shapeBounds height 225, topClearance 38, bottomInset 14. Content frames go down to controls y=181.5 height 38 (ends ~219.5) within shape bounds. **No obvious overflow in that snapshot**. But observations (1) transport clipped by bottom edge - could happen if bottomInset/shape differs or if view not laid out exactly as expected. Needs per-state measurement.

## 3. Spec vs implementation
| Item | Spec | Actual (FACT) | File:line |
| --- | --- | --- | --- |
| artwork | 76pt radius 12 | MediaLayoutMetrics.standard.artworkSize 76, cornerRadius 12 | `BilouNook/BilouNook/Modules/Media/MediaLayout.swift:15-23` |
| title | 15pt semibold | 15pt semibold rounded | `MediaContentView.swift:84` |
| secondary | 12pt | 12pt medium rounded | `MediaContentView.swift:96` |
| progress | 4pt/20pt hit | trackHeight 4, progressHitHeight 20 | `MediaLayout.swift:216-217,197` |
| times | 10.5pt monospacedDigit | 10.5pt | `MediaContentView.swift:238,246` |
| transport | prev/next 18pt, play/pause 28pt in 38pt circle, 34pt min hit | transportSymbolSize 10, playSymbolSize 16, hit 34/38; circles 34/38 | `MediaLayout.swift:220-221,218`, `MediaContentView.swift:333-377` |
| rhythm | title→secondary 2pt, secondary→progress 10pt, progress→times 4pt, times→controls 6pt | matches MediaLayout constants | `MediaLayout.swift:196-203` |
| bottom inset | 14pt | 14 | `MediaLayout.swift:17,88-112` |
| side inset | >=18pt equal | >=18, equal | `MediaLayout.swift:99-112` |

**MISMATCH**: Spec says transport prev/next 18pt symbols, play/pause 28pt glyph inside 38pt circle; actual uses transportSymbolSize 10, playSymbolSize 16. This is a significant deviation. Also circles sized 34/38. FACT from code.


## 4. Duplicate time labels
**HYPOTHESIS/FACT**: Only one timeRow exists in MediaContentView (lines ~234-249). No debug overlay rendering time labels found. But user reports two time rows visible - could be from different layout path, or old view still mounted. Also check if both compact and live activity render? NotchRootView in closed state can show both compactView and liveActivity in some paths? Or maybe ModuleShellView shows multiple modules. Need to check. But in current MediaContentView there is only timeRow HStack with elapsed and duration. Possible duplicate comes from another view (e.g. old MediaContentView variant) or from a different module rendering in same area. **Cause unknown from code alone - needs visual inspection of snapshot.**

## 5. Text rules
- Uppercase: no explicit `.textCase(.uppercase)` found. Could come from marquee/text transform or from font/caps. MarqueeText implementation may uppercase? Or from source text. **HYPOTHESIS**: coming from source/provider data or from styling; need to check MarqueeText.
- Secondary line built by `secondaryLine` combining artist · album as above.
- Empty fields handled with fallbacks.
- Marquee: MarqueeText used for title and secondary.

```swift
// MarqueeText - check
```
Let us look up MarqueeText.


**Uppercase**: Not applied by MarqueeText. **HYPOTHESIS**: artist/album/title come from provider in all-caps (some apps do). No code transform - could be source data.

## 6. Source badge
MediaContentView shows source icon/badge. Let us look up implementation.

**Source badge**: Uses `app.icon` from NSWorkspace (running app or app bundle). If nil, falls back to `Image(systemName: "app.fill")` (generic cube-like icon). For browsers/YouTube (often Chromium-based or Safari), icon depends on running app - could be browser icon or generic. **FACT**: fallback is `app.fill` (generic). Browser sources may show browser icon if found, else generic.

## 7. Tab bar
Tab bar in ModuleShellView (current recovery). Let us look.

**Tab bar**: Flank tabs positioned using `geometry.topBandFlanks(inShapeSpace: shapeWidth)`. Tabs are placed in notch band (y = notchHeight/2). Hit size 24, icon 14, spacing 4 reduced to 2 if tight. Active pill is Capsule with white opacity 0.16. Padding 8 horizontal per group.

Issues from observations:
- "tabs look clipped at the top and sit far from the notch edges instead of hugging the forbidden zone" - **HYPOTHESIS**: positioned at y = notchHeight/2 (middle of notch band) but if notch band height differs or if they need to hug forbidden zone, placement may be off; also clipping could come from frame/overlay order.


## 8-12 (summarized)
**Interaction**: Buttons use plain style, hover tracked via @State isHovering (scale on hover) - hover feedback present. Progress drag via gesture? MediaProgressBar - check quickly. Transport actions call onTogglePlayPause/onNext/onPrev. Gesture conflicts with module swipe possible.

**Providers**: MediaService/NowPlayingService handle MediaRemote, AppleScript for Music/Spotify. Capabilities vary by provider.

**Design tokens inconsistencies**: transport symbol sizes differ from spec (10/16 vs 18/28). Progress hit height 20 vs maybe different expectations.

**Accessibility**: reduce motion respected (marquee disabled), VoiceOver labels present (controls have labels, SourceAppBadge has accessibilityLabel). Hit targets 34/38 meet minimums.

**Snapshots**: Existing snapshots in build/screens/ cover states; audit snapshots requested but not generated here.

## Open questions (max 10)
1. Why two time rows visible?
2. Why transport clipped at bottom edge?
3. Why artist uppercase?
4. Why tabs clipped at top/far from edges?
5. Why transport symbol sizes reduced from spec?
6. Is progress bar draggable?
7. What happens on browser/YouTube source icon fallback?
8. Is marquee too fast/slow?
9. Do tabs overlap content area?
10. Is bottom inset correct for all shapes?

## RECOMMENDATIONS (max 10 lines)
- Fix transport sizes to match spec or update spec
- Check for duplicate time row rendering path
- Fix tab positioning to hug edges properly
- Ensure transport not clipped (check bottom inset)
- Handle uppercase properly or confirm source
- Add tests for overflow
