#!/usr/bin/env python3
"""
gen_audio.py — synthesize every sound effect in Royal Spin from scratch.

No samples, no licensing, no downloads: each effect is built out of oscillators,
noise and envelopes. Re-run it to retune anything.

    python3 tools/gen_audio.py

Writes 16-bit 44.1kHz WAVs to both platforms:
    ios/RoyalSpin/RoyalSpin/Audio/*.wav
    android/app/src/main/res/raw/*.wav

Only needs numpy. Android's res/raw refuses filenames with dashes or capitals, so
everything is lower_snake_case — that constraint drives the naming on both sides.
"""

import math
import os
import struct
import wave

import numpy as np

SR = 44100


# ─────────────────────────────────────────────────────────────── primitives ──

def t(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * t(dur) + phase)


def saw(freq, dur):
    """Bandlimited-ish saw via summed harmonics; cheap and avoids harsh aliasing."""
    x = t(dur)
    out = np.zeros_like(x)
    n = 1
    while freq * n < SR / 2.4 and n <= 24:
        out += np.sin(2 * np.pi * freq * n * x) / n
        n += 1
    return out * (2 / np.pi)


def noise(dur):
    return np.random.uniform(-1, 1, int(SR * dur))


def env_ad(dur, attack, decay, curve=2.5):
    """Attack/decay envelope. `curve` >1 gives a percussive, fast-falling tail."""
    n = int(SR * dur)
    a = max(1, int(SR * attack))
    d = max(1, n - a)
    atk = np.linspace(0, 1, a) ** 0.6
    dec = np.linspace(1, 0, d) ** curve
    return np.concatenate([atk, dec])[:n]


def env_adsr(dur, a, d, s, r):
    n = int(SR * dur)
    ai, di = int(SR * a), int(SR * d)
    ri = int(SR * r)
    si = max(1, n - ai - di - ri)
    return np.concatenate([
        np.linspace(0, 1, max(1, ai)),
        np.linspace(1, s, max(1, di)),
        np.full(si, s),
        np.linspace(s, 0, max(1, ri)),
    ])[:n]


def lowpass(x, cutoff, resonance=0.0):
    """One-pole lowpass, optionally fed back for a little resonant bite."""
    alpha = 1 - math.exp(-2 * math.pi * cutoff / SR)
    out = np.zeros_like(x)
    y = 0.0
    prev = 0.0
    for i, v in enumerate(x):
        y += alpha * ((v + resonance * (y - prev)) - y)
        prev = y
        out[i] = y
    return out


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def fit(a, b):
    """Pad the shorter of two arrays so they can be summed."""
    n = max(len(a), len(b))
    return (np.pad(a, (0, n - len(a))), np.pad(b, (0, n - len(b))))


def mix(*layers):
    out = np.zeros(max(len(l) for l in layers))
    for l in layers:
        out[:len(l)] += l
    return out


def at(x, delay, total=None):
    """Place `x` starting at `delay` seconds."""
    pre = np.zeros(int(SR * delay))
    out = np.concatenate([pre, x])
    if total is not None:
        n = int(SR * total)
        out = np.pad(out, (0, max(0, n - len(out))))[:n]
    return out


def normalize(x, peak=0.92):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-9 else x


def declick(x, ms=4):
    """Short fades top and tail so nothing starts or ends on a step."""
    n = int(SR * ms / 1000)
    if len(x) < 2 * n:
        return x
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name, data, targets):
    data = declick(normalize(data))
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    for d in targets:
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, name + ".wav")
        with wave.open(path, "w") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
    return len(data) / SR


# ────────────────────────────────────────────────────────────────── effects ──

def bell(freq, dur, brightness=1.0, amp=1.0):
    """
    Inharmonic partial stack — the classic FM-bell recipe.

    Real bells and coins ring on ratios that aren't integer multiples, which is
    exactly what makes them read as *metal* rather than as a tuned instrument.
    """
    ratios = [1.0, 2.0, 2.76, 3.76, 4.63, 5.43]
    decays = [1.0, 0.82, 0.61, 0.44, 0.31, 0.22]
    out = np.zeros(int(SR * dur))
    for r, dk in zip(ratios, decays):
        f = freq * r
        if f > SR / 2.2:
            continue
        e = env_ad(dur, 0.001, dur * dk, curve=3.2)
        out += sine(f, dur) * e * (dk ** 1.4) * brightness
    return out * amp


def coin_ching():
    """
    The money sound. Two strikes — the 'cha' and the 'CHING' — with the second
    higher and longer, because that rising second hit is what sells it.
    """
    a = bell(1180, 0.30, brightness=1.0, amp=0.75)
    # A hair of noise transient gives the strike a physical edge.
    a = mix(a, highpass(noise(0.03), 3500) * env_ad(0.03, 0.0005, 0.03, 4) * 0.35)

    b = bell(1760, 0.85, brightness=1.15, amp=1.0)
    b = mix(b, highpass(noise(0.04), 4000) * env_ad(0.04, 0.0005, 0.04, 4) * 0.4)

    total = 1.05
    return mix(at(a, 0.0, total), at(b, 0.085, total))


def lever_pull():
    """Spring tension, then a mechanical clunk as the arm bottoms out."""
    # Rising spring creak: filtered noise with climbing cutoff.
    d = 0.34
    n = highpass(noise(d), 700)
    sweep = np.linspace(900, 2600, len(n))
    creak = np.zeros_like(n)
    y = 0.0
    for i, v in enumerate(n):
        alpha = 1 - math.exp(-2 * math.pi * sweep[i] / SR)
        y += alpha * (v - y)
        creak[i] = y
    creak *= env_adsr(d, 0.05, 0.1, 0.55, 0.15) * 0.22

    # The clunk: pitch-dropping sine plus a thick noise thump.
    cd = 0.22
    x = t(cd)
    drop = 190 * np.exp(-14 * x) + 48
    thunk = np.sin(2 * np.pi * np.cumsum(drop) / SR) * env_ad(cd, 0.001, cd, 3.0)
    body = lowpass(noise(cd), 320) * env_ad(cd, 0.001, cd, 4.0) * 0.9
    clunk = mix(thunk * 0.9, body)

    total = 0.62
    return mix(at(creak, 0.0, total), at(clunk, 0.30, total))


def reel_spin_loop():
    """
    Seamlessly loopable whir: a rotating-machinery drone plus regular symbol
    clicks. Length is chosen so the click pattern wraps exactly.
    """
    clicks_per_loop = 12
    click_gap = 0.0455
    dur = clicks_per_loop * click_gap  # 0.546s, wraps cleanly

    x = t(dur)
    # Motor drone: two detuned saws an octave apart, heavily filtered.
    drone = (saw(88, dur) * 0.5 + saw(132, dur) * 0.3)
    drone = lowpass(drone, 1400) * 0.28
    # Slow amplitude wobble so it doesn't sound static.
    drone *= 1 + 0.12 * np.sin(2 * np.pi * 7.3 * x)

    air = highpass(noise(dur), 2200) * 0.05

    ticks = np.zeros(int(SR * dur))
    for i in range(clicks_per_loop):
        c = highpass(noise(0.012), 4200) * env_ad(0.012, 0.0004, 0.012, 5.0) * 0.5
        c = mix(c, sine(2400, 0.012) * env_ad(0.012, 0.0004, 0.012, 6.0) * 0.25)
        start = int(SR * i * click_gap)
        end = min(start + len(c), len(ticks))
        ticks[start:end] += c[:end - start]

    out = mix(drone, air, ticks)
    # Wrap the tail into the head so the loop point is inaudible.
    fade = int(SR * 0.02)
    out[:fade] = out[:fade] * np.linspace(0, 1, fade) + out[-fade:] * np.linspace(1, 0, fade)
    return out[:-fade]


def reel_stop():
    """Reel hitting its detent — a short, dry, weighty knock."""
    d = 0.20
    x = t(d)
    drop = 320 * np.exp(-24 * x) + 72
    tone = np.sin(2 * np.pi * np.cumsum(drop) / SR) * env_ad(d, 0.0008, d, 3.4)
    body = lowpass(noise(d), 480) * env_ad(d, 0.0008, d, 4.5) * 0.75
    snap = highpass(noise(0.02), 5000) * env_ad(0.02, 0.0003, 0.02, 5.0) * 0.30
    return mix(tone * 0.85, body, at(snap, 0.0, d))


def ui_tap():
    d = 0.07
    return mix(
        sine(880, d) * env_ad(d, 0.001, d, 4.0) * 0.5,
        sine(1320, d) * env_ad(d, 0.001, d, 5.0) * 0.3,
        highpass(noise(0.012), 4000) * env_ad(0.012, 0.0003, 0.012, 5.0) * 0.2,
    )


def near_miss():
    """
    The 'oh, so close' sting: two notes falling a minor third, with a slight
    downward pitch bend on the tail. Deliberately unresolved — it should feel
    like a question that never gets answered.
    """
    d1, d2 = 0.20, 0.55
    a = bell(740, d1, brightness=0.8, amp=0.6)
    x = t(d2)
    bend = 622 * (1 - 0.06 * (x / d2))
    b = np.sin(2 * np.pi * np.cumsum(bend) / SR) * env_ad(d2, 0.006, d2, 2.0) * 0.5
    b = mix(b, bell(622, d2, brightness=0.55, amp=0.4))
    total = 0.8
    return mix(at(a, 0.0, total), at(b, 0.18, total))


def scatter_hit():
    """Bright ascending chime — a bonus symbol has landed."""
    notes = [784, 988, 1319]  # G5 B5 E6
    total = 0.9
    layers = []
    for i, f in enumerate(notes):
        layers.append(at(bell(f, 0.7, brightness=1.1, amp=0.8), i * 0.075, total))
    shimmer = at(highpass(noise(0.5), 6000) * env_ad(0.5, 0.02, 0.5, 2.0) * 0.12, 0.0, total)
    return mix(*layers, shimmer)


def fanfare(notes, note_dur, gap, detune=0.006, amp=1.0, brass=True):
    """Stacked-saw brass hit per note, with an octave-up sparkle layer."""
    total = gap * (len(notes) - 1) + note_dur + 0.35
    layers = []
    for i, f in enumerate(notes):
        e = env_adsr(note_dur, 0.012, 0.09, 0.62, note_dur * 0.55)
        if brass:
            v = (saw(f, note_dur) + saw(f * (1 + detune), note_dur)
                 + saw(f * (1 - detune), note_dur)) / 3
            v = lowpass(v, 3200 + f * 1.6) * e
        else:
            v = sine(f, note_dur) * e
        v = mix(v, bell(f * 2, note_dur * 0.8, brightness=0.5, amp=0.22))
        layers.append(at(v * amp, i * gap, total))
    return mix(*layers)


def win_small():
    return mix(coin_ching() * 0.9)


def win_nice():
    f = fanfare([523, 659, 784], 0.34, 0.11, amp=0.75)      # C E G
    return mix(f, at(coin_ching() * 0.55, 0.22, len(f) / SR))


def win_big():
    # C major triad climbing to the octave, then coins.
    f = fanfare([523, 659, 784, 1047], 0.45, 0.13, amp=0.85)
    total = len(f) / SR + 0.5
    coins = mix(*[at(coin_ching() * 0.45, 0.40 + i * 0.13, total) for i in range(4)])
    return mix(at(f, 0, total), coins)


def jackpot():
    """
    The big one. Rising fanfare, a cascade of coins, and a low timpani-ish hit
    underneath for weight.
    """
    f = fanfare([392, 523, 659, 784, 1047, 1319], 0.52, 0.135, amp=0.9)
    total = len(f) / SR + 1.4
    coins = mix(*[at(coin_ching() * (0.5 - i * 0.03), 0.45 + i * 0.085, total)
                  for i in range(11)])
    # Timpani: fast pitch drop into a low sine, doubled with filtered noise.
    td = 0.9
    x = t(td)
    drop = 110 * np.exp(-9 * x) + 55
    tim = np.sin(2 * np.pi * np.cumsum(drop) / SR) * env_ad(td, 0.002, td, 2.2) * 0.55
    tim = mix(tim, lowpass(noise(td), 200) * env_ad(td, 0.002, td, 3.0) * 0.3)
    shimmer = at(highpass(noise(1.6), 7000) * env_ad(1.6, 0.15, 1.6, 1.4) * 0.10, 0.35, total)
    return mix(at(f, 0, total), coins, at(tim, 0.0, total), shimmer)


def free_spins():
    f = fanfare([659, 784, 988, 1319], 0.42, 0.12, amp=0.8)
    total = len(f) / SR + 0.4
    return mix(at(f, 0, total), at(scatter_hit() * 0.6, 0.30, total))


def bust():
    """Out of credits. A descending, deflating minor cadence."""
    f = fanfare([392, 349, 294, 233], 0.40, 0.16, amp=0.6, brass=False)
    return f * 0.8


# ───────────────────────────────────────────────────────────────────── main ──

EFFECTS = {
    "lever_pull":   lever_pull,
    "reel_spin":    reel_spin_loop,
    "reel_stop":    reel_stop,
    "coin_ching":   coin_ching,
    "win_small":    win_small,
    "win_nice":     win_nice,
    "win_big":      win_big,
    "jackpot":      jackpot,
    "free_spins":   free_spins,
    "scatter_hit":  scatter_hit,
    "near_miss":    near_miss,
    "ui_tap":       ui_tap,
    "bust":         bust,
}


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    targets = [
        os.path.join(root, "ios", "RoyalSpin", "RoyalSpin", "Audio"),
        os.path.join(root, "android", "app", "src", "main", "res", "raw"),
    ]

    np.random.seed(0xC0FFEE)  # reproducible noise, so re-runs are byte-identical

    print("\nRoyal Spin — synthesizing audio\n")
    total = 0.0
    for name, fn in EFFECTS.items():
        dur = write(name, fn(), targets)
        total += dur
        print(f"  ✓ {name:<14} {dur:>5.2f}s")

    print(f"\n  {len(EFFECTS)} effects, {total:.1f}s of audio")
    for d in targets:
        print(f"  → {os.path.relpath(d, root)}")
    print()


if __name__ == "__main__":
    main()
