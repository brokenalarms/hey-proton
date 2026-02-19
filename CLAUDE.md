- goals for the program are in README.md, check as part of CLAUDE.md.
- augmentation of filters should be incorporated to existing rules where appropriate to expand their applicability, but should never change the logic or actions any existing rules, unless there is a bug I have specifically requested be fixed.
- don't add comments to existing rules unless explicitly instructed. Ones to explain a new rule that follow the format of the existing ones are ok.

## generate.sh

`scripts/generate.sh` expands macros in `filters/` using private data from `private/` and writes output to `dist/output-NN.sieve`.

Key behaviors:
- `01 - setup.sieve` is always prepended to every output file (required for each Proton filter to function independently).
- `CHARACTER_LIMIT`: Proton's per-filter character limit. Filters are packed greedily to stay within it. Set to 0 to disable splitting.
- After generating, the script copies each output to clipboard in turn and prompts the user to paste into Proton before advancing to the next.
- Private data files (`private/*`) are gitignored; `private-examples/` contains representative fixtures.
- Tests: `bash tests/generate_test.sh` (uses example fixtures for any missing private files, cleans up after itself).
