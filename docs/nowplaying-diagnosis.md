# Now Playing diagnosis — this Mac

Date: 2026-10-26

## Environment

```
$ sw_vers
ProductName:		macOS
ProductVersion:		15.6
BuildVersion:		24G84

$ uname -m
arm64
```

At diagnosis time no media player was playing. Safari had a paused web media item
(`com.apple.WebKit.GPU`, title `Live Stream`).

## (a) MediaRemote via the perl adapter

The vendored `third_party/mediaremote-adapter` source was compiled locally into a
universal (arm64 + x86_64) `MediaRemoteAdapter.framework` with the macOS SDK.
The framework was ad-hoc signed. It was loaded through `/usr/bin/perl`, not linked
into the app.

```
$ /usr/bin/perl third_party/mediaremote-adapter/bin/mediaremote-adapter.pl \
    "$PWD/third_party/mediaremote-adapter/build/MediaRemoteAdapter.framework" get --now
{"playbackRate":0,"album":"","elapsedTimeNow":309.42223052127827,
 "elapsedTime":309.42223052127827,"timestamp":"2026-10-25T21:05:52Z",
 "bundleIdentifier":"com.apple.WebKit.GPU",
 "parentApplicationBundleIdentifier":"com.apple.Safari",
 "processIdentifier":91714,"title":"Live Stream","uniqueIdentifier":46928,
 "duration":422.19099999999997,"artist":"","contentItemIdentifier":"46928",
 "playing":false}
EXIT=0
```

`stream --no-diff` also worked and produced an initial event, then update events:

```
{"type":"data","diff":false,"payload":{}}
{"type":"data","diff":false,"payload":{... "title":"Live Stream" ...}}
STREAM_EXIT=0
```

Spotify was launched hidden and muted (original volume restored afterwards).
MediaRemote identified Spotify and returned artwork metadata:

```
{"album":"ASTROWORLD","mediaType":"kMRMediaRemoteNowPlayingInfoTypeAudio",
 "trackNumber":3,"elapsedTime":1.323,"timestamp":"2026-10-26T08:41:53Z",
 "bundleIdentifier":"com.spotify.client","processIdentifier":24836,
 "title":"SICKO MODE","artworkMimeType":"image/jpeg","duration":312.81999999999999,
 "artist":"Travis Scott","contentItemIdentifier":"24F6BA70-B7E7-4DDC-BFCE-2E328ED4A6AE",
 "playing":false}
```

A MediaRemote `send 1` (pause) command was accepted against Spotify, and the next
`get` reported `playing:false`. The stream and `get` commands therefore work on this
macOS 15.6 machine despite the macOS 15.4+ restriction on normal apps loading
MediaRemote directly. The perl host (`com.apple.perl`) is the key.

## (b) AppleScript / ScriptingBridge

Music and Spotify are both installed and expose `player state`, `player position`,
`current track`, and `playpause` in their scripting dictionaries.

Music (launched hidden, then quit):

```
$ osascript -e 'application "Music" is running'
true
$ osascript -e 'tell application "Music" to get {player state, player position,
    name of current track, artist of current track, album of current track,
    duration of current track}'
64:68: execution error: Music got an error: Can’t get name of current track. (-1728)
AS_EXIT=1
```

Music responded to AppleScript without an Automation prompt, but no track was loaded.
The error is the expected "no current track" result, not a permission failure.

Spotify (launched hidden, then quit):

```
$ osascript -e 'tell application "Spotify" to get {player state, player position,
    name of current track, artist of current track, album of current track,
    duration of current track}'
paused, 17.65299987793, Surround Sound (feat. 21 Savage & Baby Tate), JID,
The Forever Story (Extended Version), 229938
AS_EXIT=0
```

Spotify AppleScript metadata and transport properties work. A direct Swift
ScriptingBridge protocol cast against Spotify's raw `SBScriptableApplication`
failed (`Could not cast value of type 'SBScriptableApplication'`); the AppleScript
route is therefore the reliable fallback here. `osascript` is used for the fallback
provider instead of generated ScriptingBridge headers.

## (c) Distributed notifications

A Swift `DistributedNotificationCenter` listener was run while Spotify toggled
between play and pause, muted:

```
NOTIF com.spotify.client.PlaybackStateChanged userInfoKeys=Player State
NOTIF com.spotify.client.PlaybackStateChanged userInfoKeys=Album,Album Artist,
  Artist,Disc Number,Duration,Has Artwork,Name,Play Count,Playback Position,
  Player State,Popularity,Track ID,Track Number
```

Spotify notification delivery is real and carries the metadata needed to update
without polling. `com.apple.Music.playerInfo` was registered as the Music event
name; no Music event was observed because Music had no loaded track. Distributed
notifications are a viable event-driven fallback when AppleScript is available.

## Decision

1. **Primary:** MediaRemote adapter. It sees system-wide now-playing state
   (including browsers), exposes artwork, supports event streaming, and accepts
   play/pause/next/previous/seek commands.
2. **Fallback:** Spotify/Music over `osascript`, triggered by their distributed
   notifications when the app is running. This is event-driven for updates and
   works without MediaRemote.
3. No polling loop is used. The service reads provider events and ticks elapsed
   time locally only while `playing == true`.
