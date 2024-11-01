# OLD ADDRESSES (needing migration)
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
    "to"
  ] ":addrbook:personal?label=My Old Addresses",
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}"
) {
  fileinto "needs attention";
  fileinto "Screener";
  stop;
}