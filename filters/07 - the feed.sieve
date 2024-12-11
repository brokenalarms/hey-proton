# THE FEED
# Only add to the feed those senders we've
# added to the Newsletters contact group.
#
# Of those matched, only expire those senders not also
# put into any other contact group (e.g., "Learning").

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
