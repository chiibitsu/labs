// seal.js — seal a mine.txt with a device passkey, and verify one.
// No server, no account, no email. The private key never leaves the device;
// the public key travels inside mine.txt so anyone (or any agent) can check it.
//
// What a seal proves: a person was present at the device that holds this key
// (Face ID, fingerprint or device PIN), and the list hasn't changed since.
// What it doesn't prove: a legal identity. That's the point.
//
// File format (lines in mine.txt):
//   Seal: passkey · YYYY-MM-DD · verify at labs.chiibitsu.com/mine/verify
//   Seal-key: ES256 <base64url SPKI public key>
//   Seal-proof: <base64url authenticatorData>.<base64url clientDataJSON>.<base64url signature>
//
// The signed text is every line that isn't blank, a # comment, or a Seal line,
// trimmed and joined with "\n". Its SHA-256 is the WebAuthn challenge.
"use strict";
const Seal = (() => {
  const enc = new TextEncoder();
  const b64u = buf => btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const unb64u = s => {
    s = String(s).replace(/-/g, "+").replace(/_/g, "/");
    while (s.length % 4) s += "=";
    const bin = atob(s), u = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    return u;
  };
  const sha256 = async data => new Uint8Array(await crypto.subtle.digest("SHA-256", typeof data === "string" ? enc.encode(data) : data));
  const ALG = { "-7": "ES256", "-257": "RS256" };

  function canonical(text) {
    return String(text).replace(/\r/g, "").split("\n").map(l => l.trim())
      .filter(l => l && !l.startsWith("#") && !/^Seal(-[\w]+)?:/.test(l)).join("\n");
  }

  function available() {
    return !!(window.isSecureContext && window.PublicKeyCredential && navigator.credentials && window.crypto && crypto.subtle);
  }

  // Make a new device key for sealing. One prompt: Face ID / fingerprint / PIN.
  async function createKey(label) {
    const name = (label || "Mine.").slice(0, 40);
    const cred = await navigator.credentials.create({ publicKey: {
      challenge: crypto.getRandomValues(new Uint8Array(32)),
      rp: { name: "Mine. by Chiibitsu Labs", id: location.hostname },
      user: { id: crypto.getRandomValues(new Uint8Array(16)), name, displayName: name },
      pubKeyCredParams: [{ type: "public-key", alg: -7 }, { type: "public-key", alg: -257 }],
      authenticatorSelection: { userVerification: "required", residentKey: "preferred" },
      attestation: "none", timeout: 120000
    } });
    const r = cred.response;
    const spki = typeof r.getPublicKey === "function" ? r.getPublicKey() : null;
    if (!spki) throw Object.assign(new Error("This browser can't share the key's public half."), { code: "unsupported" });
    return { id: b64u(cred.rawId), key: b64u(spki), alg: ALG[String(r.getPublicKeyAlgorithm())] || "ES256" };
  }

  // Sign the list's text with that key. One prompt.
  async function sign(keyInfo, text) {
    const challenge = await sha256(canonical(text));
    const a = await navigator.credentials.get({ publicKey: {
      challenge, rpId: location.hostname, userVerification: "required", timeout: 120000,
      allowCredentials: [{ type: "public-key", id: unb64u(keyInfo.id) }]
    } });
    const r = a.response;
    return `${b64u(r.authenticatorData)}.${b64u(r.clientDataJSON)}.${b64u(r.signature)}`;
  }

  // ECDSA signatures arrive DER-encoded; WebCrypto wants raw r||s.
  function derToRaw(der, size = 32) {
    let i = 2;
    if (der[0] !== 0x30) throw new Error("bad signature");
    if (der[1] & 0x80) i += der[1] & 0x7f;
    const part = () => {
      if (der[i++] !== 0x02) throw new Error("bad signature");
      const len = der[i++]; let v = der.slice(i, i + len); i += len;
      while (v.length > size && v[0] === 0) v = v.slice(1);
      if (v.length > size) throw new Error("bad signature");
      const out = new Uint8Array(size); out.set(v, size - v.length); return out;
    };
    const r = part(), s = part(), raw = new Uint8Array(size * 2);
    raw.set(r); raw.set(s, size); return raw;
  }

  // A short, comparable name for a key: the first 6 bytes of its SHA-256.
  async function fingerprint(keyB64) {
    const h = await sha256(unb64u(keyB64));
    return [...h.slice(0, 6)].map(b => b.toString(16).padStart(2, "0")).join(":");
  }

  // Check a mine.txt. Returns { state: "sealed" | "changed" | "broken" | "unsealed", ... }.
  async function verify(text) {
    const lines = String(text).replace(/\r/g, "").split("\n").map(l => l.trim());
    const get = k => { const l = lines.find(x => x.startsWith(k + ":")); return l ? l.slice(k.length + 1).trim() : null; };
    const keyLine = get("Seal-key"), proof = get("Seal-proof"), sealLine = get("Seal");
    if (!keyLine || !proof) return { state: "unsealed" };
    let fp = null;
    try {
      const [alg, key] = keyLine.split(/\s+/);
      const parts = proof.split(".");
      if (parts.length !== 3 || !key) return { state: "broken", why: "The seal lines are incomplete." };
      const [authData, clientBytes, sig] = parts.map(unb64u);
      const client = JSON.parse(new TextDecoder().decode(clientBytes));
      fp = await fingerprint(key);
      const base = { fp, alg, origin: client.origin || null, sealed: sealLine };
      if (client.type !== "webauthn.get" || authData.length < 37) return { state: "broken", why: "This isn't a signing record.", ...base };
      const flags = authData[32];
      const signed = new Uint8Array(authData.length + 32);
      signed.set(authData); signed.set(await sha256(clientBytes), authData.length);
      let ok;
      if (alg === "RS256") {
        const k = await crypto.subtle.importKey("spki", unb64u(key), { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
        ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", k, sig, signed);
      } else {
        const k = await crypto.subtle.importKey("spki", unb64u(key), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
        ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, k, derToRaw(sig), signed);
      }
      if (!ok) return { state: "broken", why: "The seal doesn't match its key.", ...base };
      if (client.challenge !== b64u(await sha256(canonical(text)))) return { state: "changed", ...base };
      return { state: "sealed", present: !!(flags & 0x01), verified: !!(flags & 0x04), ...base };
    } catch (e) {
      return { state: "broken", why: "The seal couldn't be read.", fp };
    }
  }

  return { available, createKey, sign, verify, canonical, fingerprint };
})();
