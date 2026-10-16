- goals for the program are in README.md, check as part of CLAUDE.md.
- augmentation of filters should be incorporated to existing rules where appropriate to expand their applicability, but should never change the logic or actions any existing rules, unless there is a bug I have specifically requested be fixed.
- don't add comments to existing rules unless explicitly instructed. Ones to explain a new rule that follow the format of the existing ones are ok.

## Filter architecture
- Filters run in numbered order, 01 to 07. `upload.sh` sets that order in Proton.
- `stop` ends all remaining filters. `return` ends only the current one.
- Processing is cumulative until a message is placed: labels, flags and expiries accrue across filters without stopping. Only the final placement, a folder `fileinto` or an alert, calls `stop`, so the first filter to place a message decides where it lives and later filters never see it.
- Priority follows the order: group-only routing (01, 02), label decoration (03, never stops), alerts (04), Paper Trail (05), The Feed (06), then needs admin, auto-archive and the Screener as the fallthrough (07).
- Proton Sieve can't tell sent from received. Sent mail is recognised by its sender being one of your own addresses (`:addrbook:myself`, My Addresses, Old Addresses), and filter 01 stops on it.

## generate.sh

`scripts/generate.sh` expands macros in `filters/` using `filters/shared/contact-groups.txt` plus private data from `private/` and writes output to `dist/hey-proton-NN - <slug>.sieve`.

Key behaviors:
- `00 - setup.sieve` is always prepended to every output file (required for each Proton filter to function independently).
- `00 - unexpire.sieve` is appended after setup in the first output file only.
- `CHARACTER_LIMIT`: Proton's per-filter character limit. Each source filter produces its own output file (`hey-proton-01 - spam & ignored.sieve` … `hey-proton-07 - needs admin and archive.sieve`); if a file exceeds the limit a warning is printed. Set to 0 to disable the check.
- After generating, the script copies each output to clipboard in turn and prompts the user to paste into Proton before advancing to the next.
- Private data files (`private/*`) are gitignored; `private-examples/` contains representative fixtures.
- `filters/shared/contact-groups.txt` is tracked and written by `scripts/sync-groups.sh` from the Proton API. Topic labels and contact groups are kept as pairs, the group's name lowercased being the label's: a label with no group and no `fileinto` in `filters/` gets a group, a group with no label gets one, and a rename or deletion on one side is followed on the other (deletions only after interactive confirmation). Pairs are tracked by ID in `filters/shared/contact-group-pairs.json`. Groups in `filters/shared/group-only-groups.txt` drive routing and never get a label; `generate.sh` excludes them from the label mirror in filter 03. `scripts/upload.sh` runs the sync before every upload. Never edit the list or the pairs by hand; rerun the sync.
- Tests: `bash tests/generate_test.sh` (uses example fixtures for any missing private files, cleans up after itself) and `bash tests/sync_groups_test.sh` (offline, uses saved API responses in `tests/fixtures`). Run tests in fail-fast mode — fix the first failing test before looking at subsequent ones.
