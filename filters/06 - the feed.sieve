# THE FEED
# Only add to the feed those senders we've either:
# - specifically put into the Newsletters contact group; or
# - have an aliased address with a category of 'newsletter(s)?'.
#
# Of those matched, only expire those senders not also
# put into any other contact group (e.g., "Learning").

# THE FEED - aliased address indicator
# Shortcut to not have to add every new sender to contacts.
if header :regex [
  "To",
  "X-Simplelogin-Envelope-To",
  "X-Original-To"
  ] [
    {{email alias regexes.txt string expansion}}
] {
  # match 0 is whole string
  set :lower "company" "${1}";
  set :lower "category" "${2}";
  if allof(
    string :value "gt" :comparator "i;ascii-numeric" "${category}" "0",
    string :matches "${category}" "*newsletter*"
   ) {
      fileinto "newsletters";
      fileinto "The Feed";
      stop;
    }
}

# THE FEED - contact groups indicator
if header :list "from" ":addrbook:personal?label=Newsletters" {
  fileinto "The Feed";
  fileinto "newsletters";
  if not anyof(
    # to populate without using generate script,
    # add your own contact groups in the format:
    # header :list "from" ":addrbook:personal?label=Accommodation",
    # do not include Newsletters here.
    {{contact groups.txt list expansion excluding Newsletters}}
  ) {
    if header :comparator "i;unicode-casemap" :matches "from" "*hello@deals.going.com*" {
      # Going.com deals no good after a week
      expire "day" "${non_critical_alerts_expiry_days}";
    } else {
      expire "day" "${newsletter_expiry_relative_days}";
    }
    fileinto "expiring";
  }
  stop;
}
