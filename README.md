# Mailpit Mail-Testing Stack

A drop-in **mail sink** for developers. Point your application's SMTP at it
instead of a real mail server: it captures every outgoing message, sends nothing
onward, and shows you the result in a web UI — including HTML rendering, raw
source, headers, attachments and link checks.

Built on [Mailpit](https://mailpit.axllent.org). The only thing this repo adds on
top is **TLS that works out of the box**, so you can test `STARTTLS` and `SMTPS`
without ever touching a certificate.

```bash
docker compose up -d
# → Web UI:  http://localhost:8025
# → SMTP:    localhost:1025
```

That's it. Configure your app with the [connection settings](#connection-settings)
below and your mail lands in the inbox at <http://localhost:8025>.

---

## Quick start

```bash
git clone <this repo>
cd MailTesting
docker compose up -d          # or: task up
```

Open <http://localhost:8025>. Optionally `cp .env.example .env` first if you need
to change ports or enable an optional feature.

One-shot, without cloning:

```bash
docker run --rm -p 8025:8025 -p 1025:1025 axllent/mailpit
```

---

## Connection settings

Configure your application's mail transport with:

| Setting          | Value                                          |
| ---------------- | ---------------------------------------------- |
| SMTP host        | `127.0.0.1` (`localhost`)                      |
| SMTP port        | `1025`                                         |
| Encryption       | none, or `STARTTLS` (both work on `1025`)      |
| Username / pass  | anything, or none — any login is accepted      |
| Web UI / API     | <http://localhost:8025>                        |
| POP3             | `127.0.0.1:1110` (only if enabled — see below) |

Any username/password is accepted (`MP_SMTP_AUTH_ACCEPT_ANY`), so your existing
mail config "just works" — you don't have to provision credentials.

---

## Testing encrypted SMTP

The image ships a self-signed certificate that Mailpit generates itself at
startup (via its native `sans:` mechanism — no files, no setup).

- **STARTTLS** — on by default. Connect to `1025` in plain text and upgrade, or
  send plain text without TLS. Both are accepted on the same port.
- **Implicit TLS (SMTPS)** — in `.env` set `MP_SMTP_REQUIRE_TLS=true` **and**
  `MP_SMTP_AUTH_ALLOW_INSECURE=false`, then restart. The SMTP port now requires
  TLS from the first byte (like classic port 465). Both are needed: "require TLS"
  conflicts with the default "allow insecure auth", and Mailpit refuses to start
  if you set only one.

> **One mode at a time.** Mailpit has a single SMTP listener, and STARTTLS and
> implicit TLS cannot share a port. `MP_SMTP_REQUIRE_TLS=true` therefore
> *disables* STARTTLS. Flip it per the transport you're testing.

Because the certificate is self-signed, your mail client must be told to accept
it (in **test** configuration only):

```bash
# Verify STARTTLS from the shell:
openssl s_client -starttls smtp -connect localhost:1025

# Verify implicit TLS (with MP_SMTP_REQUIRE_TLS=true):
openssl s_client -connect localhost:1025
```

If you need certificate validation to *pass* (rather than disabling it), mount
your own cert/key and point `MP_SMTP_TLS_CERT` / `MP_SMTP_TLS_KEY` at the files
instead of using the built-in `sans:` cert, then trust that CA on the client.

---

## Framework examples

All examples target `localhost:1025`. The `STARTTLS` variants accept the
self-signed cert; drop the TLS lines for plain (unencrypted) testing.

<details>
<summary><strong>Node.js — Nodemailer</strong></summary>

```js
nodemailer.createTransport({
  host: "localhost",
  port: 1025,
  secure: false,           // false = plain/STARTTLS, not implicit TLS
  requireTLS: true,        // force STARTTLS (omit for plain)
  tls: { rejectUnauthorized: false }, // accept the self-signed dev cert
});
```
</details>

<details>
<summary><strong>Laravel — .env</strong></summary>

```dotenv
MAIL_MAILER=smtp
MAIL_HOST=127.0.0.1
MAIL_PORT=1025
MAIL_ENCRYPTION=tls      # STARTTLS; use null for plain
MAIL_USERNAME=null
MAIL_PASSWORD=null
```

For the self-signed cert, append `?verify_peer=0` to the Symfony mailer DSN, or
set the stream option `verify_peer => false`.
</details>

<details>
<summary><strong>Python — Django settings</strong></summary>

```python
EMAIL_HOST = "localhost"
EMAIL_PORT = 1025
EMAIL_USE_TLS = True     # STARTTLS; set False for plain
EMAIL_HOST_USER = ""
EMAIL_HOST_PASSWORD = ""
```
</details>

<details>
<summary><strong>Spring Boot — application.properties</strong></summary>

```properties
spring.mail.host=localhost
spring.mail.port=1025
spring.mail.properties.mail.smtp.starttls.enable=true
spring.mail.properties.mail.smtp.ssl.trust=*
```
</details>

<details>
<summary><strong>.NET — MailKit</strong></summary>

```csharp
using var client = new SmtpClient();
client.ServerCertificateValidationCallback = (s, c, h, e) => true; // dev only
client.Connect("localhost", 1025, SecureSocketOptions.StartTls);
```
</details>

---

## Optional features

Enable in `.env` (or add to the `environment:` block in `docker-compose.yml`):

| Goal                         | Setting                                              |
| ---------------------------- | ---------------------------------------------------- |
| Protect the UI/API           | `MP_UI_AUTH=dev:dev`                                  |
| Enable POP3                  | `MP_POP3_AUTH=dev:dev` (then connect to `1110`)      |
| Implicit TLS / SMTPS         | `MP_SMTP_REQUIRE_TLS=true`                           |
| Keep more / fewer messages   | `MP_MAX_MESSAGES=5000` (image default) / `MP_MAX_AGE=24h` |
| Prometheus metrics           | `MP_ENABLE_PROMETHEUS=true` → scrape `/metrics` on the UI port |
| Webhook on new mail          | `MP_WEBHOOK_URL=https://…`                           |

See the full list of `MP_*` variables in the
[Mailpit runtime options](https://mailpit.axllent.org/docs/configuration/runtime-options/).

---

## Persistence & reset

Captured mail lives in the named Docker volume `mailpit-data` (a named volume,
not a host bind mount, so SQLite/WAL stays reliable on Docker Desktop).

```bash
docker compose restart    # mail survives a restart
docker compose down -v    # wipe everything (task reset)
```

---

## Why it's just one file

This repo is deliberately small: a single `docker-compose.yml` on top of the
official Mailpit image. No custom image, no build pipeline, no scaffolding. The
reasoning, so it stays that way:

- **No custom image.** Everything a `Dockerfile` would do here is set environment
  variables — and env belongs in compose, where you can see and change it. An
  image carrying only `ENV` lines just adds a build/publish pipeline that buys
  nothing.
- **TLS with no certificate tooling.** `MP_SMTP_TLS_CERT=sans:…` tells Mailpit to
  generate its own self-signed cert at startup, so STARTTLS works immediately —
  no openssl, no entrypoint script, no mounted files. The tool's native feature
  instead of scaffolding around it.
- **No resource limits, labels, `security_opt`, or restated healthcheck.** The
  image already ships a `HEALTHCHECK`; the rest added nothing.
- **No "send a test mail" script.** This is a *sink* — the thing under test is the
  application sending mail, not this stack. A self-send helper would test nothing
  real. Use `openssl s_client` (above) or your own app.
- **Updates via `docker compose pull`.** The `:latest` tag tracks upstream
  Mailpit; pull when you want the newest version.

If you're tempted to add to this, document *why* — the same way this section does.

---

## Troubleshooting

| Symptom                              | Fix                                                                 |
| ------------------------------------ | ------------------------------------------------------------------- |
| `port is already allocated`          | Another stack uses `8025`/`1025`/`1110` — set `MP_*_PORT` in `.env` |
| TLS handshake fails / cert rejected  | Self-signed cert — trust it or disable verification in test config  |
| STARTTLS refused                     | `MP_SMTP_REQUIRE_TLS=true` is set (implicit TLS only) — unset it     |
| POP3 won't connect                   | POP3 is off until `MP_POP3_AUTH` is set                             |
| Changed auth but it still applies    | Restart the container — auth is read at startup                     |
| Need a clean inbox                   | `docker compose down -v` (or `task reset`)                          |

---

## License

[MIT](LICENSE) © BAUER GROUP
