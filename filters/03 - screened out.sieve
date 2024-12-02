# Screened Out
# Emails I never want to see in inbox or read,
# but would like some awareness of being proccesed if desired.
#
# Rules:
# - ANY match in here MUST:
#  - call `stop`
#  - set the mail to expire.
# - 'Screened Out' folder MUST NOT be used as a destination beyond this file.

# Screened Out - Screened Out contacts
# Emails I receive but can't opt out of
if header :list "from" ":addrbook:personal?label=Screened Out" {
  expire "day" "${expiry_grace_period_days}";
  addflag "\\Seen";
  fileinto "expiring";
  fileinto "archive";
  stop;
}

# Screened Out - Craigslist
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
    expire "day" "${expiry_grace_period_days}";
    addflag "\\Seen";
    fileinto "expiring";
    fileinto "Screened Out"; 
  }
  stop;
}

# Screened Out - calendar items
# Generally Screened Out and trying to migrate away from email-based reminders,
# but want to flag up those that come through, before "reminder"s
# hit Alerts.

# CALENDAR - Google calendar auto-emails
# Prompt to remove existing email-based notifications
# Auto-remove acceptance emails.
if anyof(
  header :comparator "i;unicode-casemap" :matches [
    "from",
    "X-Simplelogin-Original-From"
    ] [
    "*calendar-notification@google.com*"
  ],
  header :comparator "i;unicode-casemap" :regex ["Subject"] [ 
    ".*accepted:.*",
    ".*cancellation.*event.*",
    ".*notification.*@.*",
    ".*reminder.*event.*"
]) {
  expire "day" "${calendar_expiry_days}";
  fileinto "expiring";
  fileinto "calendar";
  if header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*accepted:*"
  ] {
    addflag "\\Seen";
    fileinto "Screened Out";
  }
  stop;
}