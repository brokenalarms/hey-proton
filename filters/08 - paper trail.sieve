# PAPER TRAIL
# Things we need to have around for a while, but don't need our attention taken up by.
# Mail marked as personal correspondence, eg responding to an "order cancelled"
# email, will still end up in the paper trail,
# although dually marked as `correspondence`.
#
# Rules
# ANY match in here MUST:
# - move to `Paper Trail` folder
# - mark as seen
# - set to expire
# - call `stop`.

# PAPER TRAIL - statements

if header :comparator "i;unicode-casemap" :regex ["Subject"] [
  ".*(^|[^a-zA-Z0-9])statement([^a-zA-Z0-9]|$).*"
  ] {
  fileinto "statements";
  # Keep focus narrow on expiring statements, in case they
  # contain more important context, e.g., medical,
  # otherwise surface to inbox
  if header :comparator "i;unicode-casemap" :regex ["Subject"] [
    ".*(^|[^a-zA-Z0-9])available([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])bank(ing)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])bill([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])card([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])month(ly)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])online([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])ready([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Jan(uary)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Feb(ruary)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Mar(ch)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Apr(il)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])May([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Jun(e)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Jul(y)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Aug(ust)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Sept(ember)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Oct(ober)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Nov(ember)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Dec(ember)?([^a-zA-Z0-9]|$).*"
  ] {
    expire "day" "${paper_trail_expiry_relative_days}";
    addflag "\\Seen";
    fileinto "Paper Trail";
    fileinto "expiring";
    fileinto "statements";
    addflag "\\Seen";
    stop;
  }
}

# PAPER TRAIL - returns

if allof (
  not header :comparator "i;unicode-casemap" :matches "subject" [
    "*tax*"
  ],
  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])return([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])refund([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])rma([^a-zA-Z0-9]|$).*"
  ],
  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])authoriz(e|ed|ing|ation)([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])confirm(ed|ing|ation)([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])complete(d|ing)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])label([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])notif(y|ied|ing|ication)([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])parcel([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])order([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])rma([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])receive?(d|ing)?([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
  ]
) {
  expire "day" "${paper_trail_expiry_relative_days}";
  addflag "\\Seen";
  fileinto "Paper Trail"; 
  fileinto "expiring";
  fileinto "shopping";
  fileinto "returns";
  addflag "\\Seen";
  stop;
}

# PAPER TRAIL - tracking

if anyof(
  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])pick(- )?up confirm(ed|ation)([^a-zA-Z0-9]|$).*"
  ],
  allof (
    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])delivery([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])driver([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])item([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])label([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])order([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])package([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])payment([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])purchase([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])forwarding([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipment([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])arriv(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])cancel(led|ling)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])complet(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])clear(ed)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])deliver(y|ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])dispatch(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])notif(y|ied|ication)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])on the way([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])print(ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])(re)?schedul(ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])sent([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipp(ed|ing)([^a-zA-Z0-9]|$).*", # not shipment
      ".*(^|[^a-zA-Z0-9])sign(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])status([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])track(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])prepar(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])updat(e|ed|ing)([^a-zA-Z0-9]|$).*"
    ]
)) {
  expire "day" "${paper_trail_expiry_relative_days}";
  addflag "\\Seen";
  fileinto "Paper Trail";
  fileinto "expiring";
  fileinto "shopping";
  fileinto "tracking";
  addflag "\\Seen";
  stop;
}

# PAPER TRAIL - transactions

if allof(
  header :comparator "i;unicode-casemap" :regex "Subject" [
   ".*(^|[^a-zA-Z0-9])credit([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])debit([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])deposit([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])eft([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])electronic funds transfer([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])listing([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])pay(ment)?([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])trade([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])transaction([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])withdrawal([^a-zA-Z0-9]|$).*",
   ".*(^|[^a-zA-Z0-9])you([^a-zA-Z0-9]|$).*"
  ],
  header :comparator "i;unicode-casemap" :regex "Subject" [
  ".*(^|[^a-zA-Z0-9])authorized([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])bought([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])confirm(ed|ation)?([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])initiat(ed|ing)([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])paid([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])receiv(ed|ing)([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])sent([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])set([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])successful([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])transfer(red|ring)?([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
]) {
  expire "day" "${paper_trail_expiry_relative_days}";
  addflag "\\Seen";
  fileinto "Paper Trail";
  fileinto "expiring";
  fileinto "transactions";
  addflag "\\Seen";
  stop;
}

# PAPER TRAIL - receipts
# Comes last as catch all for more specific paper trail states above.

if anyof(
  header :comparator "i;unicode-casemap" :regex "subject" [
  ".*(^|[^a-zA-Z0-9])order #? ?[0-9]+([^a-zA-Z0-9]|$).*"
  ],

  header :comparator "i;unicode-casemap" :matches "Subject" [
    "*receipt*"
  ],

  allof (
    header :comparator "i;unicode-casemap" :matches "Subject" [
      "*charge*",
      "*domain*",
      "*invoice*",
      "*order*",
      "*payment*",
      "*purchase*",
      "*sale*",
      "*shopping*",
      "*ultimate rewards*"
    ],

    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])confirm(ed|ation)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])details([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])from([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])plac(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])receiv(e|ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])sale([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])submit(ted)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])summary([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])thank([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
    ])
  ) {
  expire "day" "${paper_trail_expiry_relative_days}";
  addflag "\\Seen";
  fileinto "Paper Trail";
  fileinto "expiring";
  fileinto "shopping";
  fileinto "receipts";
  addflag "\\Seen";
  stop;
}

# EXPIRY OVERRIDE
# Let's be cautious and unexpire certain items here in one spot.
if anyof (
    header :matches "X-Attached" "*",
    header :contains "Content-Type" "multipart/mixed",
    header :list "from" ":addrbook:personal?label=Conversations",
    header :list "from" ":addrbook:personal?label=Family",
    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])download([^a-zA-Z0-9]|$).*",
      "^fw: .*",
      "^fwd: .*",
      ".*(^|[^a-zA-Z0-9])link([^a-zA-Z0-9]|$).*",
      "^re: .*"
    ]) {
    unexpire;
}