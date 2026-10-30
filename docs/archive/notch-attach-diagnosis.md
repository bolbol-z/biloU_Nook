# Notch attachment diagnosis

Date: 2026-10-26
Build: Debug, `-derivedDataPath ./build`
Command: `./build/Build/Products/Debug/BilouNook.app/Contents/MacOS/BilouNook --notch-attach-diag`
Exit code: 0

## Raw evidence

```
ATTACH[closed]
screen.frame=x:0.000 y:0.000 w:1470.000 h:956.000 minX:0.000 maxX:1470.000 minY:0.000 maxY:956.000
screen.visibleFrame=x:0.000 y:58.000 w:1470.000 h:861.000 minX:0.000 maxX:1470.000 minY:58.000 maxY:919.000
screen.backingScaleFactor=2.0
screen.safeAreaInsets=top:32.0,left:0.0,bottom:0.0,right:0.0
screen.auxLeft=x:0.000 y:924.000 w:646.000 h:32.000 minX:0.000 maxX:646.000 minY:924.000 maxY:956.000
screen.auxRight=x:825.000 y:924.000 w:645.000 h:32.000 minX:825.000 maxX:1470.000 minY:924.000 maxY:956.000
hardwareNotchRect=x:646.000 y:924.000 w:179.000 h:32.000 minX:646.000 maxX:825.000 minY:924.000 maxY:956.000
panel.frame=x:395.000 y:708.000 w:680.000 h:248.000 minX:395.000 maxX:1075.000 minY:708.000 maxY:956.000
panel.levelRaw=3
mainMenuLevelRaw=24
panel.collectionBehaviorRaw=337
panel.constrainOverride=true
panel.hostingSafeArea.top=0.0
shape.rootFrame=x:0.000 y:0.000 w:680.000 h:248.000 minX:0.000 maxX:680.000 minY:0.000 maxY:248.000
shape.screenFrame=x:395.000 y:708.000 w:680.000 h:248.000 minX:395.000 maxX:1075.000 minY:708.000 maxY:956.000
shape.screenTop=956.000
menuBar.owner=Window Server
menuBar.name=Menubar
menuBar.layer=24
menuBar.bounds=x:0.000 y:0.000 w:1470.000 h:36.000 minX:0.000 maxX:1470.000 minY:0.000 maxY:36.000
panelAboveMenuBar=false
```

The open-state snapshot at 1.5s repeats the same values:

```
ATTACH[open]
panel.frame=x:395.000 y:708.000 w:680.000 h:248.000 minX:395.000 maxX:1075.000 minY:708.000 maxY:956.000
panel.levelRaw=3
mainMenuLevelRaw=24
shape.rootFrame=x:0.000 y:0.000 w:680.000 h:248.000 minX:0.000 maxX:680.000 minY:0.000 maxY:248.000
shape.screenTop=956.000
menuBar.layer=24
panelAboveMenuBar=false
```

## Hypothesis verdicts

### H1: panel level is not above the menu bar — CONFIRMED

`panel.levelRaw=3` while `mainMenuLevelRaw=24` and the Window Server menu bar layer is `24`.
`panelAboveMenuBar=false`. The panel is below the menu bar.

Root cause is initialization order in `NotchPanel.init()`: `isFloatingPanel = true` is assigned after
`level = mainMenu + 3`. Setting `isFloatingPanel` restores the panel level to `.floating` (`3`),
silently discarding the intended level. The override itself is present (`constrainOverride=true`),
but it cannot help while the window level is below the menu bar.

This exactly matches the photo: the body starts at the hardware notch bottom because everything from
`y=924` to `y=956` is covered by the wallpaper-colored menu bar band, and the visible black body starts
only where the menu bar ends.

### H2: frame positioned with `visibleFrame` or constrained by AppKit — REJECTED

`panel.frame.maxY=956.000` equals `screen.frame.maxY=956.000`.
`panel.frame` is not derived from `visibleFrame` (`visibleFrame.maxY=919`), and `constrainOverride=true`
shows the override is live. The frame is already attached to the top of the screen.

### H3: shape itself starts wide/lower — REJECTED

`panel.hostingSafeArea.top=0.0`.
`shape.rootFrame.minY=0.000` and `shape.screenTop=956.000`, equal to the screen top.
`NotchShape.path(in:)` uses `rect.minY` for its top edge, so the shape starts at the screen top rather
than below the menu bar. The shape geometry is not the cause.

## Verdict

Single root cause: **the panel level is reset to `.floating` (3) by `isFloatingPanel = true`, so the
panel renders under the menu bar.** The frame and shape are already top-attached. The fix is to set the
strictly-above-menu-bar level after all panel style/behavior configuration, keep the frame/constrain
behavior, align the frame to the screen backing scale, and recompute placement on screen parameter
changes. No shape or root geometry change is required.

## Post-fix verification

After setting the level after all panel configuration and aligning the frame:

```
ATTACH[closed]
panel.frame=x:395.000 y:708.000 w:680.000 h:248.000 minX:395.000 maxX:1075.000 minY:708.000 maxY:956.000
panel.levelRaw=27
mainMenuLevelRaw=24
shape.screenTop=956.000
menuBar.layer=24
panelAboveMenuBar=true
```

```
ATTACH[open]
panel.frame=x:395.000 y:708.000 w:680.000 h:248.000 minX:395.000 maxX:1075.000 minY:708.000 maxY:956.000
panel.levelRaw=27
shape.screenTop=956.000
panelAboveMenuBar=true
```

`./build/Build/Products/Debug/BilouNook.app/Contents/MacOS/BilouNook --notch-selfcheck`

```
SELFCHECK PASS
```

`--smoke-test` exits `0`. Full suite: `98 tests, 0 failures`. Release build succeeds.
