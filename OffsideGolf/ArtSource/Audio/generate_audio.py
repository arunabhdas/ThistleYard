"""Original OffsideGolf audio. Deterministic synthesis, no recordings or third-party samples.
Requires Python 3 + NumPy. Run from any directory. Writes 48 kHz PCM WAV masters;
FFmpeg creates lossless stereo M4A loops for the runtime bundle.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np

RATE = 48000
SOURCE = Path(__file__).resolve().parent
PROJECT = SOURCE.parents[1]
DEST = PROJECT / 'App' / 'Resources' / 'Audio'
rng = np.random.default_rng(17092026)
records = []


def timeline(seconds):
    return np.arange(round(seconds * RATE)) / RATE


def noise(seconds, cutoff=2400, low=80):
    n = round(seconds * RATE)
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    spectrum = rng.normal(size=len(frequencies)) + 1j * rng.normal(size=len(frequencies))
    spectrum *= (1 - np.exp(-(frequencies / low) ** 2)) * np.exp(-(frequencies / cutoff) ** 2)
    spectrum[0] = 0
    result = np.fft.irfft(spectrum, n=n)
    return result / max(np.max(np.abs(result)), 1e-8)


def fade(signal, duration=.015):
    result = signal.copy()
    n = min(round(duration * RATE), len(result) // 2)
    curve = np.sin(np.linspace(0, np.pi / 2, n)) ** 2
    result[:n] *= curve
    result[-n:] *= curve[::-1]
    return result


def write(name, signal, peak, category, description, stereo=False):
    signal = fade(signal, .04 if stereo else .004)
    signal *= peak / max(np.max(np.abs(signal)), 1e-8)
    if stereo:
        # Gentle width while preserving a centered sound and silent seam endpoints.
        right = fade(.88 * signal + .12 * np.roll(signal, 127), .06)
        signal = np.stack([signal, right], axis=1)
    pcm = np.rint(signal * 32767).astype('<i2')
    target = SOURCE / (name + '.wav') if stereo else DEST / (name + '.wav')
    with wave.open(str(target), 'wb') as stream:
        stream.setnchannels(2 if stereo else 1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(pcm.tobytes())
    runtime = target
    if stereo:
        runtime = DEST / (name + '.m4a')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(target), '-c:a', 'alac', str(runtime)], check=True)
    records.append(dict(id=name, creator='OffsideGolf project', creationMethod=description,
                        source=str(target.relative_to(PROJECT)), runtime=runtime.name,
                        license='Original project synthesis; no third-party samples or compositions',
                        revision=1, status='original', category=category,
                        sampleRate=RATE, channels=2 if stereo else 1,
                        durationSeconds=len(pcm)/RATE, peak=float(np.max(np.abs(pcm.astype(float)))/32767),
                        sha256=hashlib.sha256(runtime.read_bytes()).hexdigest()))

# Short material gestures, deliberately soft with no sharp clipped transients.
t = timeline(.32)
write('golf_swing', noise(.32, 1800) * np.sin(np.pi * t / .32) ** 2, .18, 'sfx', 'Filtered noise air swish with sine envelope')
t = timeline(.16)
write('golf_impact', (.7*np.sin(2*np.pi*(860*t-900*t*t)) + .3*noise(.16, 5000)) * np.exp(-t*42), .48, 'sfx', 'Damped descending wood-like partial plus filtered contact noise')
t = timeline(.20)
write('golf_bounce', (np.sin(2*np.pi*290*t)+.25*noise(.20, 900))*np.exp(-t*32), .26, 'sfx', 'Damped low contact tone and turf noise')
t = timeline(.8)
write('golf_roll', noise(.8, 1800)*(0.6+.4*np.sin(2*np.pi*21*t)**2)*np.sin(np.pi*t/.8)**2, .13, 'sfx', 'Low rolling turf texture with shallow rhythmic modulation')
t = timeline(.5)
write('golf_sand', noise(.5, 7000)*np.exp(-t*8)*(1-np.exp(-t*200)), .25, 'sfx', 'Broadband granular sand brush with a soft attack')
t = timeline(.8)
water = noise(.8, 2400)*np.exp(-t*5)
for start, frequency in [(.04,330),(.13,470),(.26,280),(.39,520)]:
    u = np.maximum(0,t-start)
    water += .18*np.sin(2*np.pi*(frequency*u-100*u*u))*np.exp(-u*17)*(t>=start)
write('golf_splash', water, .34, 'sfx', 'Filtered water wash with four descending bubble tones')
t = timeline(.65)
write('golf_cup', (np.sin(2*np.pi*740*t)*np.exp(-t*17)+.45*np.sin(2*np.pi*1110*t)*np.exp(-t*9)), .31, 'sfx', 'Warm two-part cup resonance')
t = timeline(.085)
write('ui_tap', np.sin(2*np.pi*640*t)*np.sin(np.pi*t/.085)**2*np.exp(-t*25), .16, 'ui', 'Single rounded interface tone')

# Slowly evolving textures with silent crossfade endpoints for clean looping.
t = timeline(12)
write('coast_wind', noise(12, 700, 45)*(.55+.22*np.cos(2*np.pi*t/12)+.12*np.sin(2*np.pi*t/4)), .11, 'ambient', 'Original filtered periodic coastal air texture', True)
t = timeline(16)
write('coast_waves', noise(16, 2000, 100)*(.12+.88*(.5-.5*np.cos(2*np.pi*t/8))**2), .16, 'ambient', 'Original filtered surf with two long swell envelopes', True)
t = timeline(24)
birds = np.zeros(len(t))
for start, duration, base in [(1.2,.18,1800),(1.48,.22,2200),(7.5,.26,1650),(13.0,.20,2400),(13.30,.3,1900),(19.4,.35,2100)]:
    u = np.maximum(t-start,0)
    mask = (t>=start)&(t<start+duration)
    env = np.sin(np.pi*np.minimum(u/duration,1))**2 * mask
    birds += env*np.sin(2*np.pi*(base*u + 480*duration/np.pi*(1-np.cos(np.pi*u/duration))))
write('coast_birds', birds, .105, 'ambient', 'Six original softly frequency-modulated bird-like chirps', True)
t = timeline(48)
music = np.zeros(len(t))
# Original D-add9 / G6 pentatonic phrase; only 18 seconds voiced, then a long rest.
for start, frequency, amplitude in [(1,146.832,.44),(1,220,.22),(1,329.628,.13),(3.5,440,.18),(6,369.994,.16),(9,195.998,.34),(9,293.665,.18),(11.5,493.883,.13),(14,440,.12),(16.5,293.665,.13)]:
    u = np.maximum(t-start,0)
    env = (1-np.exp(-u*8))*np.exp(-u*.9)*(t>=start)*(u<9)
    music += amplitude*env*(np.sin(2*np.pi*frequency*u)+.2*np.sin(2*np.pi*frequency*2*u)+.045*np.sin(2*np.pi*frequency*3*u))
write('coast_music', music, .22, 'music', 'Original sparse ten-note pentatonic plucked-sine phrase with a long silent rest', True)
(DEST/'provenance.json').write_text(json.dumps(dict(schemaVersion=1, assets=records), indent=2)+'\n')
print(f'Created {len(records)} original assets')
