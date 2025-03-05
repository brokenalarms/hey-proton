# ALERTS
# Stay in inbox, although may expire.
# Don't resurface anything else to inbox besides alerts past migration date
#
# Rules:
# - ANY match in here MUST call 'stop'.
# - Matches in here with received date beyond migration date MUST be sent to inbox.

# ALERTS - Potentially serious security alerts
# Surface regardless of age, to make sure to delete if no longer relevant.

if allof(
  not header :comparator "i;unicode-casemap" :matches "subject" [
    "*benefits*",
    "*deposit*", # No "security deposit"
    "*offer*" # no "declined offer"
  ],
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*breach*",
    "*card*not*",
    "*declin*",
    "*identity*",
    "*fraud*",
    "*large purchase*",
    "*security*"
  ]
) {
  fileinto "alerts";
  fileinto "security";
  if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
    fileinto "inbox";
  }
  stop;
}

# ALERTS - failed email deliveries

if allof(
  header :comparator "i;unicode-casemap" :matches [
    "from", 
    "X-Simplelogin-Original-From"
    ] [
    "*mail delivery subsystem*"
  ],

  header :comparator "i;unicode-casemap" :matches "subject" [
    "*delivery status*"
  ]
) {
  expire "day" "${non_critical_alerts_expiry_days}";
  fileinto "expiring";
  fileinto "alerts";
  if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
    fileinto "inbox";
  }
  stop;
}

# ALERTS - discount codes (long expiration)

if allof(
  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])[0-9]{1,3}%([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])coupon([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])discount([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])sale([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])voucher([^a-zA-Z0-9]|$).*"
  ],
  not header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])download([^a-zA-Z0-9]|$).*"
  ]) {
    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring"; 
    fileinto "shopping";
    fileinto "alerts";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
  }
  stop;
}

# ALERTS - exclusions
# All subject to date check to avoid dredging up old irrelevant items
# if re-running on whole mailbox, and Conversations contact group check
# to avoid alerting on manually started conversation threads
# that still contain an 'alerting' subject.

if allof(
  not header :list [
  "from",
  "to",
  "X-Original-To"] ":addrbook:personal?label=Conversations",
  anyof (
    # exclude all statements, unless annual
    not header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])statement([^a-zA-Z0-9]|$).*", 
    header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])annual([^a-zA-Z0-9]|$).*"
  ),
  anyof(
    # exclude tips, unless flagged as important
    not header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])tip(s)?([^a-zA-Z0-9]|$).*", 
    header :comparator "i;unicode-casemap" :regex "Subject" ".*(^|[^a-zA-Z0-9])important([^a-zA-Z0-9]|$).*"
  ),
  not header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])(associate|report).*id([^a-zA-Z0-9]|$).*", # Amazon associates reports
    ".*(^|[^a-zA-Z0-9])bill.*review([^a-zA-Z0-9]|$).*", # exclude "your bill is ready for review"
    ".*(^|[^a-zA-Z0-9])get started([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])Fidelity Alerts: EFT([^a-zA-Z0-9]|$).*",
    # <copy LABEL DECORATION - conversations>
    ".*fw: .*",
    ".*fwd: .*",
    ".*re: .*"
    # </copy LABEL DECORATION - conversations>
  ]) {


  # ALERTS - reviews, basket prompts
  # Although these are generally wanted, we surface them as alerts so we can unsubscribe and delete.
  if allof(
    not header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])activity([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])credit([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])information([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])feedback([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])rat(e|ing)([^a-zA-Z0-9]|$).*", 
      ".*(^|[^a-zA-Z0-9])review(ing|s)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])tell us([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])waiting for you([^a-zA-Z0-9]|$).*"
    ]
  ) {
    fileinto "alerts";
    fileinto "needs admin";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
    }
    stop;
  }

  # ALERTS - single words
  if allof(
    not header :comparator "i;unicode-casemap" :regex [
      "Subject",
      "From",
      "To",
      "X-Simplelogin-Original-From",
      "X-Simplelogin-Envelope-To"
      ] [
      ".*(^|[^a-zA-Z0-9])event([^a-zA-Z0-9]|$).*", # exclude Eventbrite Visa meeting invites
      ".*(amazon|lyft|uber).*", # these cancellations can go to Paper Trail
      ".*(^|[^a-zA-Z0-9])ending in([^a-zA-Z0-9]|$).*", # not 'account ending in'
      ".*(^|[^a-zA-Z0-9])safestor policy (auto-)?renewal([^a-zA-Z0-9]|$).*", # safestor monthly renewals can go to Paper Trail
      ".*sign up.*" # asking you to sign up for text alerts
    ],
    # sole words sufficient to indicating attention is needed
    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*(^|[^a-zA-Z0-9])action([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])alert(s|ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])can('?t| ?not)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])cancell?(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])connect(e|ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])could[n ']n?o?'?t([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])decision([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])did you mean([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])disclosure([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])dispute([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9-])end(s|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])expir(y|ed|es|ing|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])fail([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])hold([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])impact(ed)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])important([^a-zA-Z0-9]).*",
      ".*(^|[^a-zA-Z0-9])issue([^a-zA-Z0-9]).*",
      ".*(^|[^a-zA-Z0-9])mailbox([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])multiple([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])new mail([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])(new|you|now).*owner([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])now([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])outstanding([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])primary([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])reactivate(d)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])reschedule(d)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])remind(er)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])remove(d)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])requir([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])renew(al|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])reversal([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])receiv(e|ed|ing)account[^a-zA-Z0-9].*mail([^a-zA-Z0-9]|$).*", # Travelingmailbox physical mail items
      ".*(^|[^a-zA-Z0-9])review([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])revision([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])safety([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])sensitive([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])service[^a-zA-Z0-9].*[^a-zA-Z0-9]end([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])special([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])tr(y|ied|ing)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])unable([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])unusual([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])urgent([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])were(n'?t| not)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])will not([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])won'?t([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])visas?([^a-zA-Z0-9]|$).*"
    ]
  ) {
    fileinto "alerts";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
    }
    stop;
  }

  # ALERTS - requiring action
  # These are most likely appearing while you're actively working;
  # Expire in case they weren't deleted at the time.

  if anyof(
    header :comparator "i;unicode-casemap" :regex "subject" 
    [
      ".*(^|[^a-zA-Z0-9])code: [0-9]{4,}([^a-zA-Z0-9]|$).*",  # Monarch code: 234324
      ".*(^|[^a-zA-Z0-9])pin code([^a-zA-Z0-9]|$).*",  # 'Pin code for order status check'
      ".*(^|[^a-zA-Z0-9])your code([^a-zA-Z0-9]|$).*",  # "Here is your code" (don't add your to main limbs, too broad)
      ".*(^|[^a-zA-Z0-9])sign in ?to([^a-zA-Z0-9]|$).*"  # email login links
    ],
    allof(
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])account([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])autopay([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])browser([^a-zA-Z0-9]|$).*",
        ".*card.*", # allows for Mastercard®
        ".*(^|[^a-zA-Z0-9])code([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])device([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])email([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])link([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])log[ -]?in([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])pass(code|key|word)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])profile([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])rent payment([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sign[ -][io]n([^a-zA-Z0-9]|$).*"
      ],
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])activat(e|ed|ion)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])add(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])approve(d)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])authenticat(e|ed|ion)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])confirm(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])identification([^a-zA-Z0-9]|$).*", # "Your Requested Online Banking Identification Code"
        ".*(^|[^a-zA-Z0-9])linked([^a-zA-Z0-9]|$).*", # "now linked in your account" versus download link
        ".*(^|[^a-zA-Z0-9])log(ged | |-)?in([^a-zA-Z0-9]|$).*", # allows for 'login code' or 'link to login', but not 'code' here as too broad
        ".*(^|[^a-zA-Z0-9])one[ -]time([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])new([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])set up([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])single[ -]use([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])ready([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])reset([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])update(d|ing)([^a-zA-Z0-9]|$).*", # not update, need action
        ".*(^|[^a-zA-Z0-9])verif(y|ied|ication)([^a-zA-Z0-9]|$).*"
      ]
    )
  ) {
    if not header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])statement([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])tax(ed|able|ation)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])welcome([^a-zA-Z0-9]|$).*"
    ] {
      expire "day" "${non_critical_alerts_expiry_days}";
      fileinto "expiring";
    }
    fileinto "alerts";
    if string :comparator "i;ascii-numeric" :value "ge" "${received_julian_day}" "${migration_julian_day}" {
      fileinto "inbox";
    }
    stop;
  }
}