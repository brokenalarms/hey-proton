# IGNORED
# Use for emails you never want to see or have labelled.
#
# Rules:
# ANY match in here MUST call 'stop'.

# IGNORED - spam
if allof (
  environment :matches "vnd.proton.spam-threshold" "*",
  spamtest :value "ge" :comparator "i;ascii-numeric" "${1}"
) {
  stop;
}

# IGNORED - sent items
# Add all your pre-migration inbox addresses to 'From Me' contact group,
# but not the new Simplelogin forwarding addresses added to those mailboxes.
# remove 'My Addresses' match for any testing, or you'll get no matches!
if allof(
  anyof(
    header :list "from" ":addrbook:personal?label=My Addresses",
    header :list "from" ":addrbook:personal?label=Old Addresses"
  ),
  not header :comparator "i;unicode-casemap" :regex [
      "from",
      "to",
      "X-Original-To"
    ] [
      {{test address regexes.txt string expansion}}
    ]
 ) {
  stop;
}