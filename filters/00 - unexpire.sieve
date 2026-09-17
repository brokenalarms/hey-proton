# Makes sure expire does not persist if we are running a full-inbox test,
# so items incorrectly expired during testing aren't lost.
# Comment this out if you don't want existing expiring emails to be reset,
# or once you have finished testing or setting up new filters.
#
# Only the first filter gets this. Proton runs every filter on each message
# even after an earlier one calls stop, and unexpire applies immediately,
# so in any later filter it would cancel an expiry set by an earlier one.
unexpire;

