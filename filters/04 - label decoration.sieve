# LABEL DECORATION
# Decorates with additional labels based on subject and contact group,
# without blocking. Use for cumulative addition of context.
#
# Rules:
# - Only "subject" and "from" fields are inspected here to determine labelling.
# - ANY match in here MUST NOT call `stop`.
#
# Things like utilities/services (gas, cell, internet etc.)
# should be mostly manageable through contact groups instead.
# 
# Dual anyof(:regex) used in here and Paper Trail are usually in the format:
# - first match list: noun fragments;
# - second match list: verb fragments.
# This keeps implementation generic and prevents
# individual regexes from getting too messy.

# LABEL DECORATION - Email aliases

# Classifies emails from accounts for which I have already provided a parseable alias.
# Matches in format: ${company or website}.${category}.${optional subcategory}
#
# Shortcut to not have to add every new sender to contact group.
#
# These can be better managed in future by just adding or updating
# the contact group(s) for the generated address and keeping addresses
# category free, e.g., website.randomword@mydomain.com,
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
  # 3 is the optional group including period
  set :lower "subcategory" "${4}";
  if string :value "gt" :comparator "i;ascii-numeric" "${subcategory}" "0" {
    fileinto "${subcategory}";
  }
  if string :value "gt" :comparator "i;ascii-numeric" "${category}" "0" {

    # mapped labels - the downside of on-the-fly email aliases!
   
    if string :is "${category}" "banking" {
      fileinto "finance";
    } else {
      fileinto "${category}";
    }
  }
  if string :value "gt" :comparator "i;ascii-numeric" "${company}" "0"  {
    fileinto "${company}";
  }
}

# LABEL DECORATION - cell phone

if header :comparator "i;unicode-casemap" :matches "subject" [
  ".*(^|[^a-zA-Z0-9])cell([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])phone([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])sim([^a-zA-Z0-9]|$).*"
] {
  fileinto "cell";
}


# LABEL DECORATION - conversations

if header :comparator "i;unicode-casemap" :regex "subject" [
  # <LABEL DECORATION - conversations>
  ".*fw: .*",
  ".*fwd: .*",
  ".*re: .*"
  # </LABEL DECORATION - conversations>
] {
  fileinto "conversations";
}

# LABEL DECORATION - banking/insurance

if allof(
  header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*benefit*claim*",
    "*insurance*",
    "*policy*"
  ],
  not header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*acceptable use*",
    "*privacy*"
  ]) {
  fileinto "insurance";
}

if allof(
  header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
  ] [
    ".*(^|[^a-zA-Z0-9])tax(ed|able|ation)?([^a-zA-Z0-9]|$).*"
  ],
  not header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*sales*"
  ]) {
  fileinto "tax";
}

# LABEL DECORATION - recruitment
# Leads can be archived here and then
# batch retrieved when the time is right.

if allof(
  not header :comparator "i;unicode-casemap" :matches ["subject"] [
    "*confirm*",
    "*credit*",
    "*order*",
    "*receipt*",
    "*refund*",
    "*return*"
  ],
  header :comparator "i;unicode-casemap" :regex ["subject"] [
  ".*(^|[^a-zA-Z0-9])engineer(ing)?([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])full[ -]?stack([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])front[ -]?end([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])opportunit(y|ies)([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])role([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])remote(ly)?([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])recruit(ed|er|ing|ment)([^a-zA-Z0-9]|$).*",
  ".*(^|[^a-zA-Z0-9])swe([^a-zA-Z0-9]|$).*"
]) {
  fileinto "recruitment";
}

# LABEL DECORATION - reservations

if header :comparator "i;unicode-casemap" :matches "subject" [
  "*booking*",
  "*reservation*"
] {
  fileinto "reservations";
}

# LABEL DECORATION - accommodation

if anyof(
  allof(
    header :regex "subject" [
      ".*(^|[^a-zA-Z0-9])[aA]ccommodation([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])HI([^a-zA-Z0-9]|$).*", # Hostelling International
      ".*(^|[^a-zA-Z0-9])[hH]os?tel([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])resort(s)?([^a-zA-Z0-9]|$).*"
    ],

    header :comparator "i;unicode-casemap" :matches "subject" [
      "*book*",
      "*confirm*",
      "*reserv*"
    ]
  )
) {
  fileinto "accommodation";
  fileinto "reservations";
}

# LABEL DECORATION - calendar
if header :comparator "i;unicode-casemap" :matches [
  "from",
  "X-Simplelogin-Original-From",
  "subject"
  ] [
  "*calendar*"
  ] {
    fileinto "calendar";
}

# LABEL DECORATION - air

if allof(
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*boarding*",
    "*flight*",
    "*trip*"
  ],

  header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])pass([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])itinerary([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])id([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
  ]
) {
  fileinto "reservations";
  fileinto "air";
}

# LABEL DECORATION - ground transportation

if anyof(
  allof(
    header :comparator "i;unicode-casemap" :regex [
      "from",
      "X-Simplelogin-Original-From",
      "subject"
      ] [
        ".*(^|[^a-zA-Z0-9])bus(es)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])ferr(y|ies)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])train([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])rail([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :matches "subject" [
      "*book*",
      "*confirm*",
      "*itinerary*",
      "*reserv*"
    ]
  )
) {
  fileinto "reservations";
  fileinto "ground";
}

# LABEL DECORATION - sea transportation

if allof(
  header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*(^|[^a-zA-Z0-9])ferr(y|ies)([^a-zA-Z0-9]|$).*"
  ],
  header :comparator "i;unicode-casemap" :matches "subject" [
    "*book*",
    "*confirm*",
    "*itinerary*",
    "*reserv*"
  ]
) {
  fileinto "reservations";
  fileinto "sea";
}

# LABEL DECORATION - support tickets and fun tickets

 if header :comparator "i;unicode-casemap" :regex ["subject"] [
    "^\[[0-9]+-[0-9].*\]$" # Google support tickets
  ] {
    fileinto "support";
  }

  if header :comparator "i;unicode-casemap" :regex ["subject"] [
    ".*(^|[^a-zA-Z0-9])ticket( |s|ing)?([^a-zA-Z0-9]|$).*" # not 'Ticketmaster' alone
  ] {
  if anyof(
      header :comparator "i;unicode-casemap" :matches [
        "from",
        "X-Simplelogin-Original-From"
      ] [
        "*support*"
      ],
      header :comparator "i;unicode-casemap" :regex ["subject"] [
        ".*(^|[^a-zA-Z0-9])account([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])case([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])close(d)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])create(d)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])get([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])id([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])number([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])open(ed)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sale([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])support([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])tech([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])ticket( id )?#?[0-9]{1,}([^a-zA-Z0-9]|$).*"
    ]
  ) {
      fileinto "support";
    } else {
      fileinto "tickets";
      fileinto "reservations";
    }
}

# LABEL DECORATION - software licences & subscriptions

if allof(

  header :comparator "i;unicode-casemap" :regex "subject" [
    # <label decoration - licence keys>
    ".*(^|[^a-zA-Z0-9])download([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])licen(c|s)e([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])link([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])product ?key([^a-zA-Z0-9]|$).*"
    # </label decoration - licence keys>
  ],

  not header :comparator "i;unicode-casemap" :matches ["subject", "from"] [
    "*change*",
    "*corrected link*",
    "*dmv*",
    "*urgent*",
    "*warning*",
    "*payment*",
    "*prescription*",
    "*insurance*",
    "*policy*",
    "*receipt*",
    "*vehicle*"
  ]
) {
  if header :comparator "i;unicode-casemap" :regex "subject" [
    ".*(^|[^a-zA-Z0-9])licen(c|s)e([^a-zA-Z0-9]|$).*"
  ] {
    fileinto "licence keys";
  } else {
    fileinto "subscriptions";
  }
}

# LABEL DECORATION - legal
if header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*e-?3.*",
      ".*greencard.*",
      ".*h1-?b.*",
      ".*passport.*",
      ".*visa.*"
  ] {
    fileinto "legal";
  }

# LABEL DECORATION - medical
if header :comparator "i;unicode-casemap" :regex [
    "from",
    "X-Simplelogin-Original-From",
    "subject"
    ] [
      ".*health ?care.*",
      ".*medical.*",
      ".*phys(io|ical )therapy.*",
      ".*vaccin.*"
  ] {
    fileinto "medical";
  }

# LABEL DECORATION - contact groups
# to populate without using generate script,
# add your own contact groups in the format, where ${contact group} matches
# your Contact Group, and ${label} matches the label for it.
# if header :list "from" ":addrbook:personal?label=${contact group}" {
  # fileinto "${label}";
# }
# do not include My Addresses, Migration Exceptions, Old Addresses, or Screened Out here.
{{contact groups.txt fileinto expansion excluding My Addresses, Migration Exceptions, Old Addresses, Screened Out}}