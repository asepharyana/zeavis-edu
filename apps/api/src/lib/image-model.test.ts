import { afterEach, describe, expect, test } from 'vitest';
import { classifyImage } from './image-model';

const originalFetch = globalThis.fetch;

afterEach(() => {
  globalThis.fetch = originalFetch;
});

function makeImageFile(type = 'image/jpeg') {
  return new File([new Uint8Array([1, 2, 3])], 'leaf.jpg', { type });
}

function mockFetch(handler: (input: Parameters<typeof fetch>[0], init?: Parameters<typeof fetch>[1]) => Promise<Response>) {
  // `fetch.preconnect` is a Bun-only static — Node's `fetch` has none, and
  // `classifyImage` never calls it. Read it through a cast so the mock keeps
  // whatever statics the host runtime provides without needing bun's types.
  globalThis.fetch = Object.assign(handler, {
    preconnect: (originalFetch as unknown as { preconnect?: unknown }).preconnect,
  });
}

describe('classifyImage', () => {
  test('maps ML service prediction response to API classification result', async () => {
    mockFetch(async (input, init) => {
      expect(String(input)).toBe('http://127.0.0.1:8001/predict');
      expect(init?.method).toBe('POST');
      expect(init?.body).toBeInstanceOf(FormData);

      return new Response(
        JSON.stringify({
          label: 'Daun Sehat',
          confidence: 0.92,
          probabilities: {
            'Bercak Daun': 0.02,
            'Daun Sehat': 0.92,
            'Karat Daun': 0.03,
            'Hawar Daun': 0.03,
          },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      );
    });

    const result = await classifyImage(makeImageFile());

    expect(result.predictedDiseaseSlug).toBe('daun-sehat');
    expect(result.confidence).toBe(0.92);
    expect(result.probabilities).toEqual([
      { diseaseSlug: 'daun-sehat', label: 'Daun Sehat', confidence: 0.92 },
      { diseaseSlug: 'karat-daun', label: 'Karat Daun', confidence: 0.03 },
      { diseaseSlug: 'hawar-daun', label: 'Hawar Daun', confidence: 0.03 },
      { diseaseSlug: 'bercak-daun', label: 'Bercak Daun', confidence: 0.02 },
    ]);
  });

  test('rejects unsupported file types before calling ML service', async () => {
    let called = false;
    mockFetch(async () => {
      called = true;
      return new Response('{}');
    });

    await expect(classifyImage(makeImageFile('image/webp'))).rejects.toThrow('File must be JPEG or PNG');
    expect(called).toBe(false);
  });

  test('throws when ML service returns a non-success response', async () => {
    mockFetch(async () => new Response(JSON.stringify({ detail: 'Model is not loaded' }), { status: 503 }));

    await expect(classifyImage(makeImageFile())).rejects.toThrow('ML service returned 503: Model is not loaded');
  });

  test('throws when ML service returns malformed JSON', async () => {
    mockFetch(async () => new Response('not-json', { status: 200, headers: { 'content-type': 'application/json' } }));

    await expect(classifyImage(makeImageFile())).rejects.toThrow('Invalid ML service JSON response');
  });

  test('throws when ML service returns an unknown label', async () => {
    mockFetch(async () => new Response(
      JSON.stringify({
        label: 'Unknown Disease',
        confidence: 0.7,
        probabilities: { 'Unknown Disease': 0.7 },
      }),
      { status: 200, headers: { 'content-type': 'application/json' } },
    ));

    await expect(classifyImage(makeImageFile())).rejects.toThrow('Unknown ML service label: Unknown Disease');
  });
});
