# HEY Proton!

**Advanced Sieve Filters for Proton Mail**

These Sieve filters implement the concepts of a HEY-styled email client combined with the power of the Contact Groups feature in Proton Mail for advanced customization and flexibility.

<div style="text-align: center;">
   <img src="docs/folders%20example.png" alt="folders" width="200"/>
  <img src="docs/contact%20groups.png" alt="contact groups" width="200"/>
  <img src="docs/labels.png" alt="labelling" width="200"/>
</div>

It also provides a clear path to migrate away from your old email addresses to a more secure aliased system.

Adopt my system to avoid:

- rolling your own;
- discovering undocumented Proton issues yourself;
- making scores of labels in Proton to try and 'imply' variables not directly debuggable in Sieve; and
- needing to go back to the Sieve _draft_ RFCs from 1991 for further clarifications 🤦‍♂️

## Caution

I have tested this fairly comprehensively, but since it uses relative dates it is _designed to set some of your emails to immediately expire on first run_.

It also adopts a highly opinionated workflow in the manner it chooses to expire some items, in particular, alerts designated as non-critical.

I may be up for accepting suggestions or even PRs, but this is a personal project and my time and support is not guaranteed. Use at your own risk.

## Concepts

The workflow can be represented by only 3 folders in use:

- `Inbox`
- `The Feed`
- `Paper Trail`

with labels used for any further classification within these.

This email flow preserves your time and attention with concepts inspired by Hey, plus a few extras:

### Paper Trail

Most of what you recieve via email is a `receipt`, `statement`, `return`, `tracking` update or `transaction` that you would like to have on hand for a while, but usually don't need to review individually.

Anything going into the `Paper Trail` is marked as seen and set to expire in 2 years, unless it has an attachment or is part of your personal `conversations`.

### Screening

Except for important or timely alerts and anything bound for the `Paper Trail`, messages from senders you haven't seen before arrive in the `Inbox` unlabelled, to be screened there as part of triage: reply, archive, unsubscribe, or add the sender to a contact group so their mail is routed and labelled from then on. Screening happens where you already look, so new senders are never hidden in a folder you have to remember to check.

### The Feed

Newsletters for casual reading purposes should arrive in a flow whereby old content is pushed down and eventually discarded.

If an email arrives from the `Newsletter` contact group, it will be placed in `The Feed`. In addition, if it is not listed in any other contact group, it is assumed to be for entertanment only, and will be set to expire in 3 months. This keeps your Feed fresh.

### Inbox

Finally, only those emails:

- requiring immediate or more timely attention as an `alert`; or
- mail from senders that doesn't fit into the categories above, whether already classified or still to be screened;

will actually make it to your Inbox and ask for your attention.

### Expiration Philosophy

Expiration sets emails to auto-delete after a period - it doesn't hide them. Archiving and marking as seen hides emails.

- **Non-critical alerts** (cart reminders, webinar invites, upsells): Surface to inbox with "needs admin" tag for unsubscribing, then auto-expire in 7 days.
- **Paper trail** (receipts, tracking, transactions): Mark as seen (don't need attention) but kept for reference. These are things you don't need to see but might need later.
- **Screened out**: Archive + mark as seen + expire = truly hidden and eventually deleted.

## Interplay with Proton contact groups

Using Protons' contact groups, we can create a contact to hold a new unknown email to one or more new contacts, and also individually assign each of the emails under a contact to different contact groups:

<div style="text-align: center;">
  <img src="docs/contact%20example.png" alt="contact" width="300"/>
</div>

Once an email address is added to a contact, the lower case version of its name will be applied as a label (if you have created it, as below).

You don't need to add the email to any contact groups for this, but additionally assigning it to various contact groups will then have any mapped labels of those groups applied to each new email from that address:

<div style="text-align: center;">
  <img src="docs/contact%20groups.png" alt="contact groups" width="300"/>
  <img src="docs/labels.png" alt="labels" width="300"/>
</div>

Although less portable than having this all written in Sieve, in practice the code doesn't translate anyway due to Proton's unique extensions to the language. Furthermore, it gives you a really nice and fast UI for updating existing contacts to existing groups:

<div style="display: flex; justify-content: center;">
  <img src="docs/adding%20contacts.gif" alt="adding contacts" width="300"/>
</div>

## Contact group versus email alias classification

I used to create emails like `company.category.subcategory@mydomain.com` for automatic label generation from the `category` and `subcategory`. While effective, it proved brittle: for instance, merging my `banking` and `investments` labels into a single `finance` label left Old `company.banking@mydomain.com` addresses no longer able to generate useful labels, requiring manual updates.

Now, I use Proton contact groups and just generate email addresses like `companyorwebsitename.randomword@mydomain.com`, separate from labeling. Assigning them to contact groups on first receipt offers flexibility and allows grouping different emails under one contact.

I still use the alias auto-labelling approach for some things like newsletters, to save me having to add a contact for every single email.

## Installation

These scripts are set up to be maintained using Github and expanded into output
files using the provided `generate.sh` script.

Each source filter produces its own output file in `dist/`, so they can be
uploaded to Proton independently.

### Minimum required Proton setup

You will need to go through the code and understand the labels used to modify for your own use case. Proton will not automatically create these, so you either need to create them all as per this system or implement your own.

However, some labels are suggested for minimum baseline functionality. These are:

- Folders: `The Feed` and `Paper Trail`.
- Contact Groups: `Newsletters`, `My Addresses` and optional `Old Addresses` and `Migration Exceptions` as below.
- Minimum labels: `alerts`, `security` `expiring`,`needs admin`, and `newsletters`.
- Paper Trail labels: `receipts` `returns`, `shopping`, `statements`, `tracking` and `transactions`

Beyond this, you can add as many extra labels mentioned in `03 - label decoration.sieve` as you like to get extra classification granularity beyond the baseline folder system.

### Populating user-specific data

Using separate files for user-specific setup data along with script-based expansion macros ensures a single source of truth can be preserved for these lists on first creation or when they need updating.

The `scripts/generate.sh` script expands entries from `filters/shared/contact-groups.txt` and from files in your `/private` directory. You will need to create the `private` text files yourself since they contain personal information; the contact groups list is written for you by `scripts/sync-groups.sh`.

You can run this script directly one-time in Bash:

```bash
chmod +x scripts/generate.sh
scripts/generate.sh
```

This generates one output file per source filter in `dist/`, copies each to your clipboard in turn, and walks you through pasting into Proton Mail. Press Enter after pasting each filter when prompted.

`CHARACTER_LIMIT` at the top of `generate.sh` is Proton's per-filter character limit. If an output file exceeds it, a warning is printed. Set to 0 to disable the check.

### Optional contact groups

#### `My Addresses`

Emails will be ignored if they are sent from a mail in the `My Addresses` contact group. This is used to exclude sent items from further classification, as I prefer.

#### `Old Addresses`

Email adresses can also be added to an `Old Addresses` contact group if they refer to old pre-Proton accounts for which you wish to be reminded to update the senders/accounts. Use this if you want this mail also marked as `needs admin` and sent to the `Inbox`, to remind you to update the accounts still containing this address.

This can be further managed by the variable `migration_date_in_days_ago` to make sure every single old email copied to proton is not flagged on first run. It is also specified as a relative rather than absolute day to ensure that after you have fixed a bunch of accounts, but still have the old emails, these will not all get flagged up again if you re-run from scratch some time later.

It is recommended though that you run the filters originally with `migration_date_in_days_ago` backdated a month or two, migrate any obvious addresses, and then set it to 0 going forward.

#### `Screened Out` contacts

This is a special optional `Screened Out` contact group for mail that you don't want to block, but you don't want to see or have further labelled at all. Items will be archived and expire in 7 days.

#### `Migration Exceptions`

This is another optional contact group - members won't get flagged up as `needs admin` if they are not yet migrated. Use this for use cases like:

- senders that you know you need to migrate, but can't yet (waiting on response); or
- for mail that you can't ever migrate
  - for example, if you have moved all email from a Google account, but still use Drive or Photos on it, you can still expect emails from `@google.com` to that address.

### Contact groups list

Contact groups only exist inside Proton, so the list that `generate.sh` mirrors into labels is not maintained by hand. Each topic label is paired with a contact group of the same name, so all mail from the group's senders gets the label. To have all mail on a topic in one place, create either the label or the group, and `scripts/sync-groups.sh` does the rest. It reads your labels and contact groups from the Proton API (using the same session handling as `upload.sh`) and keeps the pairs in step:

- a label with no group gets one, title-cased, unless a rule in `filters/` files into that label;
- a group with no label gets one, lowercased;
- renaming either side renames the other;
- deleting either side offers to delete the other. Deleting a group loses its members and deleting a label removes it from every message, so each deletion is confirmed interactively, and runs that aren't interactive only report them.

New entries take the colour of the side they are created from. Groups listed in `filters/shared/group-only-groups.txt` (My Addresses, Old Addresses, Migration Exceptions and Screened Out) drive routing rather than labelling, so they never get a label.

Renames and deletions are detected by ID against the pairs from the last sync, kept in `filters/shared/contact-group-pairs.json`. Every paired group is written to `filters/shared/contact-groups.txt`, which is what `generate.sh` reads, so generating never needs a live session. Commit both files.

`scripts/upload.sh` runs the sync before every upload then regenerates the output files, so the flow is: create the label or group in Proton, run `upload.sh`, then add senders to the group. `--dry-run` reports what would change without touching Proton.

### Example user config files

Format for each text file is one entry per line. Refer to `/private-examples` for some starting examples.

- `alias-patterns.txt` - regex patterns for structured email aliases where labelling information is encoded in the address (e.g. `company.category@domain.com`)

## Development

Should you wish to fork this or submit a PR, it's good to keep in mind the following principles:

## File flow

Each sieve filter is designed to run in a specific order and and conform to certain rules for each file, to ensure that the flow is respected. Please refer to the rules in the comment header of each file for more details.

### Editing

- Always `expire` using a declared grace period from setup, never delete directly or send to `Trash`.
- Avoid the use of `return` in individual files, as they will not end up in separate filters; only use `stop` if required.
- Avoid filing into `Inbox`, as re-running will mess with emails already manually processed.
- The exception to this is for `alerts`; if you do want to file anything into `Inbox`, you can
  check against `${migration_julian_day}` first to avoid dredging up your deep mail history.

### Proton/Sieve Gotchas

#### Sucessfully marking as "seen" requires understanding of explicit versus implicit `keep`.

Initially, I thought that `addflag` was non-deterministic as sometimes it worked and sometimes it didn't. Other posts on Reddit indicated similar confusion.

However, my understanding of these representing syncrhronous steps was incorrect - `addflag` actually only adds to a currently-accruing state of flags, that is not applied until either:

- a `fileinto` command happens which explicitly also runs `keep` which only then applies the accumulated flags; or
- the filter code is finished, at which stage `keep` is implicitly run to set the flags.

Therefore if you run:

```
fileinto "my-label";
addflag "\\Seen";
stop;
```

...will not successfully apply the `seen` flag, as `keep` has been run explicitly by `fileinto` and is therefore no longer run implicitly after `addflag`!

Very un-ascertainable from the code on the page and maybe a questionable design decision today, but good to finally know!

Not that this _doesn't_ apply to `expire` since it's implemented by Proton - I got it confirmed from the Proton team that `expire` applies immediately and is not subject to implicit `keep`.

#### `expiry` has an undocumented maximum expiration period.

UPDATE: Proton have now added this to the documentation at my request - thanks! I still wish it wasn't arbitrarily restricted to 2 years, though 😉

The `proton.vnd.expiry` extension has a maximum supported expiration date of 2 years (730 days).

Again, this is undocumented and I only discovered it through trial and error. If you set 1500, it will set to the max of 730 for you, and if you set to 2000, it will just not set the expiration at all.

### Sieve does not support regex shorthands.

Sieve doesn't support any shorthands like `\\b`, `\\d`, `\\W` etc.

The spec that _MUST_ be supported is listed here: https://datatracker.ietf.org/doc/id/draft-ietf-sieve-regex-01.html#RFC5228

This tripped me up for days as it means inspecting regexes will fail not for the reason you think - eg in the example below, I thought Julian date extraction was broken:

```sieve
if currentdate :zone "+0000" :matches "julian" "*" {
    if not string :regex "${1}" "^\\d+$" {
        fileinto "fails; this label is set, but only because \\d doesn't work";
    }
    if not string :comparator "i;ascii-numeric" :value "ge" "${1}" "0" {
        filentio "passes; this label is set";
    }
}
```

### 'fileinto' UI order is simply alphabetical.

Maybe obvious, but after driving myself crazy trying to figure out how new labels were applied, and why it didn't seem deterministic that the applied order corresponded to UI order, I realized that the UI just displays them in alphabetical order. 😂
