"""Speaker verification for spoken turns.

The learner enrolls once by reading aloud; we keep only the resulting speaker
embedding (a voiceprint), never the recording. Each spoken turn's audio is
decoded in memory, embedded, compared with the voiceprint and discarded.

Model: WeSpeaker ResNet34 (VoxCeleb), run through sherpa-onnx. It is downloaded
once to SPEAKER_MODEL_PATH (default .jac/models/) on first use.
"""

import base64
import io
import logging
import os
import struct
import threading
import urllib.request

import numpy as np

SAMPLE_RATE = 16000
MODEL_URL = (
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/"
    "speaker-recongition-models/wespeaker_en_voxceleb_resnet34.onnx"
)
MODEL_PATH = os.environ.get(
    "SPEAKER_MODEL_PATH",
    os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        ".jac", "models", "wespeaker_en_voxceleb_resnet34.onnx",
    ),
)
# Cosine similarity at or above which a turn is attributed to the learner.
MATCH_THRESHOLD = float(os.environ.get("SPEAKER_MATCH_THRESHOLD", "0.5"))
# Shorter speech is too little to judge; callers fall back to turn-taking.
MIN_TURN_SPEECH_SECONDS = 1.0
MIN_ENROLL_SPEECH_SECONDS = 6.0
# Accept at most ~3 minutes of 16-bit 48 kHz stereo before decoding.
MAX_AUDIO_BYTES = 40_000_000

_extractor = None
_lock = threading.Lock()
log = logging.getLogger(__name__)


def _get_extractor():
    global _extractor
    with _lock:
        if _extractor is None:
            import sherpa_onnx

            if not os.path.exists(MODEL_PATH):
                os.makedirs(os.path.dirname(MODEL_PATH) or ".", exist_ok=True)
                partial = MODEL_PATH + ".part"
                urllib.request.urlretrieve(MODEL_URL, partial)
                os.replace(partial, MODEL_PATH)
            config = sherpa_onnx.SpeakerEmbeddingExtractorConfig(
                model=MODEL_PATH, num_threads=1, debug=False, provider="cpu"
            )
            if not config.validate():
                raise RuntimeError("Invalid speaker model configuration.")
            _extractor = sherpa_onnx.SpeakerEmbeddingExtractor(config)
        return _extractor


def decode_wav(audio_b64: str) -> np.ndarray:
    """Decode a base64 WAV (PCM 16/32-bit or float32) to mono float32 at 16 kHz."""
    if len(audio_b64) > MAX_AUDIO_BYTES * 4 // 3 + 4:
        raise ValueError("Audio clip is too long.")
    data = base64.b64decode(audio_b64, validate=True)
    stream = io.BytesIO(data)
    if stream.read(4) != b"RIFF":
        raise ValueError("Audio must be a WAV file.")
    stream.read(4)
    if stream.read(4) != b"WAVE":
        raise ValueError("Audio must be a WAV file.")
    fmt = None
    pcm = None
    while True:
        header = stream.read(8)
        if len(header) < 8:
            break
        chunk_id, size = struct.unpack("<4sI", header)
        body = stream.read(size)
        if size % 2:
            stream.read(1)
        if chunk_id == b"fmt ":
            tag, channels, rate = struct.unpack("<HHI", body[:8])
            bits = struct.unpack("<H", body[14:16])[0]
            if tag == 0xFFFE and len(body) >= 26:  # WAVE_FORMAT_EXTENSIBLE
                tag = struct.unpack("<H", body[24:26])[0]
            fmt = (tag, channels, rate, bits)
        elif chunk_id == b"data":
            pcm = body
    if fmt is None or pcm is None:
        raise ValueError("WAV file has no audio.")
    tag, channels, rate, bits = fmt
    if tag == 1 and bits == 16:
        samples = np.frombuffer(pcm[: len(pcm) // 2 * 2], dtype="<i2") / 32768.0
    elif tag == 1 and bits == 32:
        samples = np.frombuffer(pcm[: len(pcm) // 4 * 4], dtype="<i4") / 2147483648.0
    elif tag == 3 and bits == 32:
        samples = np.frombuffer(pcm[: len(pcm) // 4 * 4], dtype="<f4").astype(np.float64)
    else:
        raise ValueError("Unsupported WAV encoding.")
    log.info(
        "speaker audio: format=%d channels=%d rate=%d bits=%d bytes=%d seconds=%.2f",
        tag, channels, rate, bits, len(pcm), len(samples) / max(channels, 1) / max(rate, 1),
    )
    if channels > 1:
        samples = samples[: len(samples) // channels * channels].reshape(-1, channels).mean(axis=1)
    if rate != SAMPLE_RATE and len(samples) > 1:
        count = int(len(samples) * SAMPLE_RATE / rate)
        samples = np.interp(
            np.linspace(0, len(samples) - 1, count), np.arange(len(samples)), samples
        )
    return samples.astype(np.float32)


def speech_only(samples: np.ndarray) -> np.ndarray:
    """Drop silent 30 ms frames (a simple energy gate) so pauses don't dilute the voiceprint."""
    frame = SAMPLE_RATE * 30 // 1000
    count = len(samples) // frame
    if count == 0:
        return samples[:0]
    frames = samples[: count * frame].reshape(count, frame)
    rms = np.sqrt((frames**2).mean(axis=1))
    gate = max(0.003, 0.1 * float(np.percentile(rms, 95)))
    return frames[rms >= gate].reshape(-1)


def embed(samples: np.ndarray) -> np.ndarray:
    extractor = _get_extractor()
    stream = extractor.create_stream()
    stream.accept_waveform(sample_rate=SAMPLE_RATE, waveform=samples)
    stream.input_finished()
    if not extractor.is_ready(stream):
        raise ValueError("Not enough speech to recognize the speaker.")
    vector = np.asarray(extractor.compute(stream), dtype=np.float64)
    norm = np.linalg.norm(vector)
    return vector / norm if norm > 0 else vector


# A recording whose loudest sample is below this carries no microphone signal
# (e.g. the iOS Simulator without macOS microphone access records silence).
SILENT_PEAK = 1e-3


def enroll(audio_clips: list[str]) -> list[float]:
    """Return the learner's voiceprint from an enrollment recording (one or more clips)."""
    samples = np.concatenate([decode_wav(clip) for clip in audio_clips]) if audio_clips else np.zeros(0, np.float32)
    if len(samples) == 0 or float(np.abs(samples).max()) < SILENT_PEAK:
        raise ValueError(
            "The recording was silent, so no audio reached the microphone. "
            "Check that the app (or, in the Simulator, the Mac) has microphone access."
        )
    speech = speech_only(samples)
    log.info(
        "enrollment: %.2fs recorded, %.2fs speech, peak %.4f",
        len(samples) / SAMPLE_RATE, len(speech) / SAMPLE_RATE, float(np.abs(samples).max()),
    )
    if len(speech) < MIN_ENROLL_SPEECH_SECONDS * SAMPLE_RATE:
        raise ValueError(
            f"Heard only {len(speech) / SAMPLE_RATE:.1f} seconds of speech in "
            f"{len(samples) / SAMPLE_RATE:.1f} seconds of recording. Read the passage "
            f"for at least {MIN_ENROLL_SPEECH_SECONDS:.0f} seconds, close to the phone."
        )
    return [float(x) for x in embed(speech)]


def learner_similarity(audio_b64: str, voiceprint: list[float]) -> float | None:
    """Cosine similarity between a turn's speech and the voiceprint, or None if too short to judge."""
    speech = speech_only(decode_wav(audio_b64))
    if len(speech) < MIN_TURN_SPEECH_SECONDS * SAMPLE_RATE:
        return None
    reference = np.asarray(voiceprint, dtype=np.float64)
    return float(np.dot(embed(speech), reference) / (np.linalg.norm(reference) or 1.0))
