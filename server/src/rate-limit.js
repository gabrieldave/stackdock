/**
 * Rate limiter en memoria: máximo N intentos por ventana fija deslizante.
 * Devuelve Retry-After (segundos) cuando se excede.
 */
export function createRateLimiter({ max, windowMs }) {
  const hits = new Map();

  function check(ip, now = Date.now()) {
    const key = String(ip || 'unknown');
    const recent = (hits.get(key) || []).filter((ts) => ts > now - windowMs);

    if (recent.length >= max) {
      hits.set(key, recent);
      return {
        limited: true,
        retryAfter: Math.max(1, Math.ceil((recent[0] + windowMs - now) / 1000)),
      };
    }

    recent.push(now);
    hits.set(key, recent);
    if (hits.size > 10_000) {
      for (const [other, timestamps] of hits) {
        if (!timestamps.some((ts) => ts > now - windowMs)) hits.delete(other);
      }
    }
    return { limited: false, retryAfter: 0 };
  }

  function reset() {
    hits.clear();
  }

  return { check, reset };
}
