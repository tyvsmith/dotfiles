# Virtual Surround 7.1

`graph.spa.json` is a HeSuVi 14-channel HRIR convolution graph (7.1 -> binaural),
loaded by WirePlumber's `node.software-dsp.rules` from
`~/.config/wireplumber/wireplumber.conf.d/51-software-dsp.conf`.

## Two hard constraints on this file

**No `#` comments.** WirePlumber parses it with `as-section`, and that path does
not strip comments the way the normal config parser does. `conf:open()` fails
silently with only `software-dsp.lua:49: Unable to load filter graph` in the log.
This cost a debugging round; do not re-add comments. Notes live here instead.

**Must be a single braced object.** A bare top-level body of key/value pairs
also fails to parse.

## Which endpoint is which

The Maxwell dongle exposes two Speaker terminals. They are **not** in the order
Audeze's documentation implies:

| ALSA | USB function | Role |
|---|---|---|
| `hw:4,0` / `pro-output-0` | Speaker T3 **+ Microphone T5** — duplex | **Chat** |
| `hw:4,1` / `pro-output-1` | Speaker T11 only — playback | **Game** |

Audeze's support docs say "the first one is Maxwell Game and the second one is
Maxwell Chat", but that is Windows enumeration order and does not match ALSA
device order. The reliable structural tell is the microphone: on a game/chat
headset the bidirectional function is chat.

Confirmed by measurement 2026-08-17. Do NOT use a simultaneous two-tone test —
it is ambiguous, because in Game/Chat mode the wheel is a *balance* that moves
both endpoints in opposite directions. The reliable method is to park the wheel
at a hard extreme and find which endpoint goes silent:

    wheel at full CHAT  ->  pro-output-1 silent  ->  pro-output-1 is Game
    wheel at full GAME  ->  pro-output-0 silent  ->  pro-output-0 is Chat

The wheel is also a three-mode control (volume / sidetone / game-chat balance)
that auto-reverts to Game/Chat after a few seconds idle; tapping announces the
mode. Sidetone is mic monitoring and touches neither playback endpoint — if the
wheel seems to do nothing to audio you are in sidetone mode, so wait rather than
tap again. The low boop / high beep are the sidetone range end-stops, not
endpoint limits. Any identification test must account for this or the result is
noise.

This graph targets `pro-output-1`, the Game endpoint.

Whether the Chat endpoint is voice-processed is UNRESOLVED. Two pink-noise A/B
runs on 2026-08-17 disagreed: the first heard Chat as audibly thinner, the
second (after `alsactl store` guaranteed both PCM levels stayed at 0 dB, and
without prior priming that voice DSP was expected) heard them as identical.
The second was better controlled, but one test does not overturn another - treat
it as open, and re-test if it ever matters.

It does not currently matter: game, film and music all live on Game, and Chat
carries voice only. It would only need resolving if music were ever moved to
Chat to gain the balance wheel as a mix control.

Level-match BEFORE judging timbre. An earlier attempt found Chat "louder and
maybe harsher" - that was a 19 dB hardware mismatch (PCM,1 had reset to
-20 dB), not processing, and louder always reads as harsher.

## Do not move this into `pipewire.conf.d/`

That directory is autoloaded by PipeWire at daemon start, which would make the
chain a permanent, device-independent sink — exactly what this design removes.
The whole point is that the filter is created on the Maxwell's `node-added` and
destroyed on its `node-removed`, so the HRTF path cannot reach the speakers.

## Differences from the older standalone version

- `node.linger` removed — the chain must die with the device
- `node.want-target-device` replaced by an explicit `target.object`
- convolver paths moved here from `pipewire.conf.d/`

## Swapping the spatializer

The binding is independent of the DSP. To try a different HeSuVi impulse
response, drop in another 14-channel WAV and update the sixteen `filename`
entries. For a SOFA-based spatializer, `libspa-filter-graph-plugin-sofa.so` is
installed and links `libmysofa`; replace the convolvers with eight
`type = sofa label = spatializer` nodes at 7.1 angles (FC 0, FL 30, FR 330,
SL 90, SR 270, RL 135, RR 225, LFE folded to 0).

Keep variants side by side and switch with the `filter-path` line in
`51-software-dsp.conf`.

## Everything goes through the chain - there is no music bypass

Removed 2026-08-17 after a blind A/B: 4/6, i.e. chance. With the stale +3.64 dB
gain fixed, the HRTF chain is not audibly distinguishable on stereo music, and
it was never buying rate fidelity either (the Maxwell supports only 48/96 kHz,
so 44.1 kHz Spotify is resampled on any path). The bypass cost a client.conf.d
file, an mpv profile, a per-app pin, and a whole class of "my routing got
rewritten" bugs, in exchange for nothing measurable.

So: music, games and film all take the same path. No per-app pinning, no
`node.dont-move`, nothing for omarchy's output switcher to corrupt.

`hide-parent` MUST remain false even so - see the comment in
51-software-dsp.conf. Hiding the parent breaks the volume keys.
