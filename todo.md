# Todo

- Switch from character-limit packing to one-filter-per-source-file layout. Currently `generate.sh` packs filters greedily into `dist/output-NN.sieve` files to fit Proton's character limit, which means the number and boundaries of output files vary. With a reliable API upload, the simpler and more maintainable approach is to produce exactly one Proton filter per source filter file (02 through 08), each with setup prepended, and let `upload.sh` update each by name. The `CHARACTER_LIMIT` split would only need to apply if a single source file exceeds the limit, which none currently do.
