# SCREENER - old addresses
# Flag up new emails that still need to have the account login moved from previous provider.
#
# Rules:
# - ANY match in here MUST call `stop`.
#
# A date is provided to split out rules from running on your first time on the inbox
# (being aplied to all emails) # and when being applied past that date.
# Set it to your first run date.
# Assuming most migration has already been done, then we can only flag up future emails
# via Screener, and just label old mails.
#
# Possible actions:
# These may be archived or sent to the Paper Trail once the underlying account is updated:
# they won't come up next time due to the relative time period of ${migration_julian_day}.
# But we don't want them to go to Paper Trail without alerting us of the issue first.

if allof(
  # Assuming the bulk of migration is done, set to date of initial full mailbox run,
  # so we fileinto Screener only for new emails, not those with account already migrated
  # but still to the old address.
  header :list [
    "bcc",
    "cc",
    "to",
    "X-Original-To",
    "X-Simplelogin-Envelope-To"
  ] ":addrbook:personal?label=My Old Addresses",
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}"
) {
  fileinto "needs admin";
  fileinto "Screener";
  stop;
}


# SCREENER - final fallthrough
# Anything that makes it this far and has a sender not added into the address book
# (with or without a Contact Group) will go to the Screener.
#
# This includes items going to Paper Trail, to make sure we're aware of new contacts.
#
# Even with mail that has been labelled using an aliased address,
# an aliased address is really "me", not "from", and so should go to screener
# if the contact using it is unexpected.
#
# Doesn't drag every single old item into Screener,
# uses migration date to just get contact group representation clean from that date.

if allof(
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}",
  not header :list "from" ":addrbook:personal") {
  fileinto "needs admin";
  fileinto "Screener";
  stop;
}

