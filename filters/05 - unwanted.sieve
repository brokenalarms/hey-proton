# UNWANTED
# Emails I never want to see in inbox or read,
# but would like some awareness of being proccesed if desired.
#
# Rules:
# - ANY match in here MUST:
#  - call `stop`
#  - set the mail to expire.
# - 'Unwanted' folder MUST NOT be used as a destination beyond this file.
#
# UNWANTED - unwanted contacts
# Emails I receive but can't opt out of;
# e.g., Venmo/Uber receipts I don't want or need in Paper Trail.
if header :list "from" ":addrbook:personal?label=Unwanted" {
  expire "day" "7";
  addflag "\\Seen";
  fileinto "Unwanted";
  fileinto "expiring";
  addflag "\\Seen";
  stop;
}

# UNWANTED - Google calendar auto-emails
# Prompt to remove existing email-based notifications
if anyof(
  header :comparator "i;unicode-casemap" :matches [
    "from",
    "X-Simplelogin-Original-From"
    ] [
    "*calendar-notification@google.com*"
  ],
  header :comparator "i;unicode-casemap" :matches ["Subject"] [ 
    "*accepted:*",
    "*cancellation of an event*"
]) {
  expire "day" "${calendar_expiry_days}";
  fileinto "expiring";
  fileinto "calendar";
  if header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*accepted:*"
  ] {
    fileinto "Unwanted";
    addflag "\\Seen";
  }
  stop;
}

# UNWANTED - Craigslist
# Needs specific rules since it already has its own email aliasing system
if header :comparator "i;unicode-casemap" :matches [
  "from",
  "X-Simplelogin-Original-From"
  ] [
    "*craigslist*"
  ] {
  fileinto "craigslist";
  if header :comparator "i;unicode-casemap" :matches [
    "from",
    "X-Simplelogin-Original-From"
    ] [
    "*automated*message*"
  ] {
    # Posting notification; I manage these via my craigslist app
    expire "day" "7";
    addflag "\\Seen";
    fileinto "Unwanted";
    fileinto "expiring"; 
    addflag "\\Seen";
  }
  stop;
}
