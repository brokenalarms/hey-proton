# Proton Mail Filter API (Informal Spec)

Proton Mail does not publish an official external API for filter management.
This document records what is known from the open-source
[WebClients](https://github.com/ProtonMail/WebClients) codebase
(`packages/shared/lib/api/filters.ts`), which is the authoritative source.

**Status:** Unofficial. Proton may change these endpoints at any time without notice.
**Authentication:** Session-based — see [Authentication](#authentication) below.

---

## Base URL

```
https://mail.proton.me/api
```

---

## Authentication

Proton uses [Secure Remote Password (SRP)](https://proton.me/blog/encrypted_email_authentication)
for login, which is too complex to implement in bash. The practical approach for scripted access
is to extract a live session from the browser and store it in `private/proton-session.json`
(gitignored).

**To obtain session credentials:**

1. Open `mail.proton.me` in a browser and log in.
2. Open DevTools → Network tab → filter by `Fetch/XHR`.
3. Make any request (e.g., refresh the page).
4. Find any request to `mail.proton.me/api/...` and click it.
5. From the **Request Headers**, copy:
   - `x-pm-uid` → `UID`
   - `cookie` (the entire value) → `Cookie`
6. Save to `private/proton-session.json` (see `private-examples/proton-session.json`).

**Required headers for all API requests:**

```
x-pm-uid: <UID>
Cookie: <full cookie header value>
Content-Type: application/json
x-pm-appversion: Other
```

**Session lifetime:** Cookies expire (typically within hours). Refresh by
re-extracting from the browser.

---

## Filter Endpoints

All paths are relative to the base URL.

### List all filters

```
GET /mail/v4/filters
```

Response:
```json
{
  "Code": 1000,
  "Filters": [
    {
      "ID": "abc123",
      "Name": "hey-proton-01",
      "Status": 1,
      "Version": 2,
      "Priority": 1,
      "Sieve": "require [...];\n..."
    }
  ]
}
```

`Status`: `1` = active, `0` = disabled.
`Version`: `2` = Sieve, `1` = simple (UI-built) filter.

### Get a single filter

```
GET /mail/v4/filters/{id}
```

### Create a Sieve filter

```
POST /mail/v4/filters
```

Body:
```json
{
  "Name": "hey-proton-01",
  "Status": 1,
  "Version": 2,
  "Sieve": "require [...];\n..."
}
```

### Update a filter

```
PUT /mail/v4/filters/{id}
```

Same body shape as create. The `Name` and `Sieve` fields are updated in place.
The `ID` comes from listing filters first — there is no name-based PUT endpoint.

### Delete a filter

```
DELETE /mail/v4/filters/{id}
```

### Enable / disable a filter

```
PUT /mail/v4/filters/{id}/enable
PUT /mail/v4/filters/{id}/disable
```

### Validate Sieve syntax (without saving)

```
PUT /mail/v4/filters/check
```

Body:
```json
{ "Sieve": "require [...];\n..." }
```

Response includes `{ "Code": 1000 }` on success, or error details with line info.

### Reorder filters

```
PUT /mail/v4/filters/order
```

Body:
```json
{ "FilterIDs": ["id1", "id2", "id3"] }
```

---

## Filter naming convention for this repo

`generate.sh` outputs one file per source filter, preserving the source slug:

| Source filter file              | Output file                                    | Proton filter name                        |
|---------------------------------|------------------------------------------------|-------------------------------------------|
| `02 - spam & ignored.sieve`     | `dist/output-02 - spam & ignored.sieve`        | `hey-proton-02 - spam & ignored`          |
| `07 - the feed.sieve`           | `dist/output-07 - the feed.sieve`              | `hey-proton-07 - the feed`                |
| …                               | …                                              | …                                         |

`upload.sh` derives the Proton filter name by stripping `output-` from the
filename stem and prepending the prefix: `hey-proton-NN - <slug>`.

To use a different prefix, set `FILTER_NAME_PREFIX` in `private/proton-session.json`
or override with the `--prefix` flag (see `scripts/upload.sh --help`).

---

## Security considerations

**Unofficial API.** Proton provides no stability guarantee for these endpoints.
A web client update could rename, version, or remove them.

**Session credentials are sensitive.**
`private/proton-session.json` contains a live session token equivalent to a
logged-in browser session. It grants full mailbox access. It must never be committed.
The `private/` directory is gitignored for this reason.

**AccessTokens expire.** A stale token returns HTTP 401. You must re-extract from
the browser. There is no API key or long-lived credential mechanism for the filter API.

**Operations are live and destructive.** The upload script operates on your real
Proton account — there is no sandbox. Updating a filter immediately changes how your
mail is processed. Creating a filter with the same name as an existing one creates a
duplicate (Proton allows duplicate names); `upload.sh` avoids this by looking up by
name first.

**No rollback built into the API.** Before running `upload.sh` for the first time,
capture a backup snapshot of your current filters via `GET /mail/v4/filters` and
save the response.

**jq is required.** `scripts/upload.sh` uses `jq` for JSON parsing. Install via
your package manager (`brew install jq`, `apt install jq`, etc.).

---

## References

- Source of truth for endpoints: [`ProtonMail/WebClients` — `packages/shared/lib/api/filters.ts`](https://github.com/ProtonMail/WebClients/blob/main/packages/shared/lib/api/filters.ts)
- Proton Sieve documentation: [proton.me/support/sieve-advanced-custom-filters](https://proton.me/support/sieve-advanced-custom-filters)
- Proton authentication (SRP): [`ProtonMail/go-proton-api`](https://github.com/ProtonMail/go-proton-api)
