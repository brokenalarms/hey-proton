# MIGRATION EXCEPTIONS
# Emails we don't want to go to screener, that we can't migrate away from
# eg., emails from Google account that will always go to old Gmail address

if allof(
  header :list [
    "bcc",
    "cc",
    "to",
    "X-Original-To",
    "X-Simplelogin-Envelope-To"
  ] ":addrbook:personal?label=My Old Addresses",
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}",
  header :comparator "i;unicode-casemap" :matches [
    "from",
    "X-Simplelogin-Original-From"
    ] [
      "*@google.com*"
    ]
) {
  stop;
}