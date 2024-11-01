# SCREENER
# Anything that makes it this far and has a sender not added into the address book
# (with or without a Contact Group)
# will go to the Screener (needs attention).
#
# Even with mail that has been labelled using an aliased address,
# this will alert us if an unexpected contact gets a hold of it.
#
# Doesn't drag every single old item into Screener,
# uses migration date to just get contact group representation clean from that date.

if allof(
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}",
  not header :list "from" ":addrbook:personal") {
  fileinto "needs attention";
  fileinto "Screener";
  stop;
}

