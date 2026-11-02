// Browser microphone capture for speaker recognition. Keeps the last minute of
// mono PCM in memory so a finalized utterance's audio can be cut out by time and
// sent once as a 16 kHz WAV; nothing is written to disk or kept longer.

const KEEP_MS = 60000;
const OUTPUT_RATE = 16000;

export function createAudioCapture() {
  let stream = null;
  let context = null;
  let processor = null;
  // Each chunk: { end: Date.now() when it arrived, data: Float32Array }.
  let chunks = [];

  async function start() {
    if (context) return;
    stream = await navigator.mediaDevices.getUserMedia({
      audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true },
    });
    context = new AudioContext();
    // Created after awaiting the permission prompt, so Safari may start it suspended.
    if (context.state === "suspended") await context.resume();
    const source = context.createMediaStreamSource(stream);
    processor = context.createScriptProcessor(4096, 1, 1);
    processor.onaudioprocess = (event) => {
      const now = Date.now();
      chunks.push({ end: now, data: new Float32Array(event.inputBuffer.getChannelData(0)) });
      while (chunks.length && now - chunks[0].end > KEEP_MS) chunks.shift();
    };
    // The processor only runs while connected to the output; a muted gain keeps it silent.
    const mute = context.createGain();
    mute.gain.value = 0;
    source.connect(processor);
    processor.connect(mute);
    mute.connect(context.destination);
  }

  function stop() {
    if (processor) processor.disconnect();
    if (stream) stream.getTracks().forEach((track) => track.stop());
    if (context) context.close();
    stream = context = processor = null;
    chunks = [];
  }

  // Base64 WAV of the audio between two Date.now() times, or "" if none was captured.
  function clip(startMs, endMs) {
    if (!context) return "";
    const rate = context.sampleRate;
    const parts = [];
    for (const chunk of chunks) {
      const chunkStart = chunk.end - (chunk.data.length / rate) * 1000;
      if (chunk.end < startMs || chunkStart > endMs) continue;
      const from = Math.max(0, Math.floor(((startMs - chunkStart) / 1000) * rate));
      const to = Math.min(chunk.data.length, Math.ceil(((endMs - chunkStart) / 1000) * rate));
      if (to > from) parts.push(chunk.data.subarray(from, to));
    }
    const total = parts.reduce((sum, part) => sum + part.length, 0);
    if (total === 0) return "";
    const samples = new Float32Array(total);
    let offset = 0;
    for (const part of parts) {
      samples.set(part, offset);
      offset += part.length;
    }
    return encodeWav(downsample(samples, rate));
  }

  return { start, stop, clip, isRunning: () => context !== null };
}

function downsample(samples, rate) {
  if (rate <= OUTPUT_RATE) return samples;
  const ratio = rate / OUTPUT_RATE;
  const out = new Float32Array(Math.floor(samples.length / ratio));
  for (let i = 0; i < out.length; i++) {
    // Average each output sample's window: a cheap low-pass before decimating.
    const from = Math.floor(i * ratio);
    const to = Math.min(samples.length, Math.floor((i + 1) * ratio));
    let sum = 0;
    for (let j = from; j < to; j++) sum += samples[j];
    out[i] = sum / Math.max(1, to - from);
  }
  return out;
}

function encodeWav(samples) {
  const bytes = new Uint8Array(44 + samples.length * 2);
  const view = new DataView(bytes.buffer);
  const text = (at, value) => [...value].forEach((c, i) => view.setUint8(at + i, c.charCodeAt(0)));
  text(0, "RIFF");
  view.setUint32(4, 36 + samples.length * 2, true);
  text(8, "WAVE");
  text(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM
  view.setUint16(22, 1, true); // mono
  view.setUint32(24, OUTPUT_RATE, true);
  view.setUint32(28, OUTPUT_RATE * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  text(36, "data");
  view.setUint32(40, samples.length * 2, true);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(44 + i * 2, s < 0 ? s * 0x8000 : s * 0x7fff, true);
  }
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}
