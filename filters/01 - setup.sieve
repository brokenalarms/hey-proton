require ["include", "environment", "variables", "relational", "comparator-i;ascii-numeric", "spamtest"];
require ["fileinto", "extlists", "imap4flags", "vnd.proton.expire", "regex"];
require ["date", "relational", "vnd.proton.eval"];

# Makes sure expire does not persist if we are running a full-inbox test,
# so items incorrectly expired during testing aren't lost.
# Comment this out if you don't want existing expiring emails to be reset,
# or once you have finished testing or setting up new filters.
unexpire;

# VARIABLE DECLARATIONS
# Relative dates are set up to work in days, so we can parse and compare using julian days method.

# From how long ago do you want to get prompted to migrate old accounts?
set "migration_date_in_days_ago" "0";

set "newsletter_expiry_days" "90";

set "screened_out_expiry_days" "30";

# on initial run for inbox cleanup, if a newsletter should already be expired,
# do we want a grace period to have the chance to check first?
set "expiry_grace_period_days" "7";

# Note: 730 (2 years) is the max expiration period supported by Proton (undocumented >:( )
# If you set to eg 1500, it will set to 730,
# but if you set to 2000, it just doesn't set it.
set "paper_trail_expiry_days" "730";
set "non_critical_alerts_expiry_days" "7";

# Current date
if currentdate :zone "+0000" :matches "julian" "*" {
  set "current_julian_day" "${1}";
}

# Received date
if date :zone "+0000" :matches "received" "julian" "*" {
  set "received_julian_day" "${1}";
}

# Migration date
set :eval "mail_age_in_days" "${current_julian_day} - ${received_julian_day}";
set :eval "migration_julian_day" "${current_julian_day} - ${migration_date_in_days_ago}";

# Relative expiration dates
# Expire newsletters and paper trail from the day they were received
# Warning - this will expire existing emails for initial inbox cleanup.
if string :comparator "i;ascii-numeric" :value "ge" "${mail_age_in_days}" "${newsletter_expiry_days}" {
  # initial test run
  set "newsletter_expiry_relative_days" "${expiry_grace_period_days}";
} else {
  # usual behavior for new incoming emails
  set :eval "newsletter_expiry_relative_days" "-${mail_age_in_days} + ${newsletter_expiry_days}";
}

if string :comparator "i;ascii-numeric" :value "ge" "${mail_age_in_days}" "${paper_trail_expiry_days}" {
  # initial test run
  set "paper_trail_expiry_relative_days" "${expiry_grace_period_days}";
} else {
  # usual behavior for new incoming emails
  set :eval "paper_trail_expiry_relative_days" "-${mail_age_in_days} + ${paper_trail_expiry_days}";
}

# Validation
# Keep a 'sieve issue' label present in the inbox, just as a catchall flag
if not allof(
  string :comparator "i;ascii-numeric" :value "ge" "${current_julian_day}" "0",
  string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "0",
  string :comparator "i;ascii-numeric" :value "ge" "${mail_age_in_days}" "0"
) {
  fileinto "needs admin";
  stop;
}