# Mine.

Your AI can help with almost everything. Write down what it can't have.

One promise, two readers. Pick or write the things you want to keep doing yourself and sign the list.
The card is double-sided: the front is your handwriting, the back is the same promise as `mine.txt`
for your AI. Keep it three ways:

- **For your AI, today:** instructions to paste into any assistant's custom instructions.
- **For agents:** `mine.txt`, a plain file in the [manners.txt](../manners/) format.
- **For you:** a printable card, and a share link that carries the list inside the URL.

Private by design: no backend, no accounts, no tracking. Drafts stay in this browser's storage.
Shared links are rendered as text only. One `index.html`, no dependencies.

The starter suggestions come from [alt=human](../alt-human/) and [alt=machine](../alt-human/human-first/):
two opposite worlds that landed on the same list of things people shouldn't delegate.

Optional step 4: tick items to give to the commons. It opens a prefilled public GitHub issue with only
the ticked items (no name, no date), which feeds the tally on [manners.txt](../manners/). The list itself stays yours.

## The seal

Step 2 can also seal the list with a device passkey (Face ID, fingerprint or device PIN). The hand signature
is for people; the seal is for machines. It proves a person was present at the device that holds the key and
that the list hasn't changed since. No account, no email, no server: the private key never leaves the device,
and the public key travels inside `mine.txt`.

- [`seal.js`](./seal.js): sealing and verification, ~150 lines, no dependencies. The format is documented at the top.
- [`verify/`](./verify/): paste or drop a `mine.txt`; the check runs on the reader's own device.

Lost device: passkeys sync through iCloud Keychain or Google Password Manager. If the key is really gone,
seal the list again on the new device; the new `mine.txt` replaces the old one.
