# PAPER TRAIL
# Things we need to have around for a while,
# but don't need our attention by surfacing to inbox.
# Nothing should end up here unless it is of limited value long-term:
# e.g., we are happy with it expiring, because everything that goes here will.
#
# Rules
# ANY match in here MUST:
# - set to expire and label as `expiring`; AND
# IF the contact is an existing contact
# - move to `Paper Trail` folder
# - mark as seen
# ELSE fall through to Screener.
#
# This allows all Paper Trail-like metadata to be applied,
# and after first contact review, the mail can be manually sent to that folder
# without needing to manipulate it further to match items in it.

if anyof(
  # allow messages to test addresses to be forwarded (faster testing without rewriting 'subject')
  header :comparator "i;unicode-casemap" :regex [
    "to",
    "X-Original-To"
  ] [
    {{test address regexes.txt string expansion}}
  ],
  not anyof (
    header :comparator "i;unicode-casemap" :regex "subject" [
      # <copy LABEL DECORATION - conversations>
      ".*fw: .*",
      ".*fwd: .*",
      ".*re: .*"
      # </copy LABEL DECORATION - conversations>
    ],
    header :list [
      "from",
      "to",
      "X-Original-To"] ":addrbook:personal?label=Conversations",
    header :list [
      "from",
      "to",
      "X-Original-To"] ":addrbook:personal?label=Family",
    header :list [
      "from",
      "to",
      "X-Original-To"] ":addrbook:personal?label=Personal",
    header :list [
      "from",
      "to",
      "X-Original-To"] ":addrbook:personal?label=Support",
    header :comparator "i;unicode-casemap" :regex "subject" [
      # <copy LABEL DECORATION - licence key checks>
      ".*(^|[^a-zA-Z0-9])download([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])licen(c|s)e([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])link([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])product ?key([^a-zA-Z0-9]|$).*",
      # </copy LABEL DECORATION - licence key checks>
      ".*(^|[^a-zA-Z0-9])tax(able|ed|ation)?([^a-zA-Z0-9]|$).*"
    ])
  ) {
      
  # PAPER TRAIL - statements

  if header :comparator "i;unicode-casemap" :regex ["Subject"] [
    ".*(^|[^a-zA-Z0-9])bill([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])report.*securities([^a-zA-Z0-9]|$).*", # Fidelity securites loan statements
    ".*(^|[^a-zA-Z0-9])statement([^a-zA-Z0-9]|$).*",
    ".*(^|[^a-zA-Z0-9])your.*transaction history([^a-zA-Z0-9]|$).*"
    ] {

    fileinto "statements";

    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  } elsif allof (

    # PAPER TRAIL - returns

    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])return([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])refund([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])rma([^a-zA-Z0-9]|$).*"
    ],
    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])authoriz(e|ed|ing|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])by mail([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])confirm(ed|ing|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])complete(d|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])label([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])notif(y|ied|ing|ication)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])parcel([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])order([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])rma([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])receive?(d|ing)?([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])request([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your?([^a-zA-Z0-9]|$).*"
    ]
  ) {
    fileinto "shopping";
    fileinto "returns";

    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  } elsif anyof(

    # PAPER TRAIL - tracking

    header :comparator "i;unicode-casemap" :regex "subject" [
      ".*(^|[^a-zA-Z0-9])arrived:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])delivered:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])pick(- )?up confirm(ed|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipped:([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])shipping.*confirm(ed|ation)([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your shipment([^a-zA-Z0-9]|$).*"
    ],

    allof (
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])delivery([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])driver([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])gear([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])item([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])label([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])order([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])package([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])payment([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])forwarding([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])shipment([^a-zA-Z0-9]|$).*"
      ],
      header :comparator "i;unicode-casemap" :regex "subject" [
        ".*(^|[^a-zA-Z0-9])arriv(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])chang(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])cancel(led|ling)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])coming (soon|today|tomorrow)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])complet(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])clear(ed)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])deliver(y|ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])dispatch(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])get ready([^a-zA-Z0-9]|$).*", # UPS - "get ready for your package"
        ".*(^|[^a-zA-Z0-9])making moves([^a-zA-Z0-9]|$).*", # Peak Design
        ".*(^|[^a-zA-Z0-9])notif(y|ied|ication)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])on (the|its) way([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])out for([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])prepar(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])print(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])process(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])(re)?schedul(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sent([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])shipp(ed|ing)([^a-zA-Z0-9]|$).*", # not shipment
        ".*(^|[^a-zA-Z0-9])sign(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])status([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])track(ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])updat(e|ed|ing)([^a-zA-Z0-9]|$).*"
      ]
  )) {

    fileinto "tracking";

    expire "day" "${paper_trail_expiry_relative_days}";
    fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    } 
    fileinto "Paper Trail";
    stop;
  } elsif anyof(

    # PAPER TRAIL - transactions
    # NB don't put "you" and "your" in each limb, too broad
    # (e.g., "your flight to SF is waiting for you")

    # Venmo transactions, without adding overly broad "you(r)" to main limbs
    header :comparator "i;unicode-casemap" :regex "Subject" [
          ".*(^|[^a-zA-Z0-9])requests.*[0-9]{1,}\\.[0-9]{2,2}.*"
    ],

    allof(
      # Kraken transactions, without adding overly broad "you(r)" to main limbs
      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])you([^a-zA-Z0-9]|$).*"
      ],
      anyof(
          header :comparator "i;unicode-casemap" :regex "Subject" [
          ".*(^|[^a-zA-Z0-9])bought([^a-zA-Z0-9]|$).*",
          ".*(^|[^a-zA-Z0-9])converted([^a-zA-Z0-9]|$).*",
          ".*(^|[^a-zA-Z0-9])paid([^a-zA-Z0-9]|$).*",
          ".*(^|[^a-zA-Z0-9])(sent|received).*(money|gift|$).*",
          ".*(^|[^a-zA-Z0-9])sold([^a-zA-Z0-9]|$).*" 
          ]
      )
    ),
    allof(
      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])credit([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])debit([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])deposit([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])eft([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])electronic funds transfer([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])listing([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])(auto)?pay(ment)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])purchase([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])rent([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])request([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])trade([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])transaction([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])transfer([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])withdrawal([^a-zA-Z0-9]|$).*"
      ],
      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])approve(d|al)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])authorized([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])bought([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])coming up([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])completed?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])confirm(ed|ation)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])for.*2[0-9]{3}([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])initiat(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])paid([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])pick(ing)?[ -]?up([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])process(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])receiv(ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sent([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])set([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])successful([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])thank(s|you) for([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])transfer(red|ring)([^a-zA-Z0-9]|$).*"
      ]
    )
  ) {

    fileinto "transactions";
    # expire "day" "${paper_trail_expiry_relative_days}";
    # fileinto "expiring";

    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  } elsif anyof(

    # PAPER TRAIL - receipts
    # Comes last as catch all for more specific paper trail states above.

    # specific cases
    header :comparator "i;unicode-casemap" :regex "Subject" [
      # Reverb
      ".*(^|[^a-zA-Z0-9])has sold([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])thanks for picking up([^a-zA-Z0-9]|$).*",
      # REI - picking up gear in person
      ".*(^|[^a-zA-Z0-9])thanks for picking up([^a-zA-Z0-9]|$).*",
      # Lyft
      ".*(^|[^a-zA-Z0-9])your ride with([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])your Lyft bike ride([^a-zA-Z0-9]|$).*",
      # Paypal: "seller: $xxx.xx USD"
      ".*:.{1,2}[0-9]{1,}\\.[0-9]{2,2}.*",
      # Storage - these are sent every month
      ".*(^|[^a-zA-Z0-9])safestor policy renewal([^a-zA-Z0-9]|$).*"
    ],

    # general
    header :comparator "i;unicode-casemap" :regex "Subject" [
      ".*invoice.*",
      ".*(^|[^a-zA-Z0-9])order #? ?[0-9]+([^a-zA-Z0-9]|$).*",
      ".*(^|[^a-zA-Z0-9])ordered:([^a-zA-Z0-9]|$).*",
      ".*receipt.*"
    ],

    allof (
      header :comparator "i;unicode-casemap" :matches "Subject" [
        "*charge*",
        "*checkout*",
        "*credit*",
        "*domain*",
        "*earnings*",
        "*item*",
        "*order*",
        "*payment*",
        "*purchase*",
        "*rental*",
        "*sale*",
        "*shopping*",   
        "*ultimate rewards*"
      ],

      header :comparator "i;unicode-casemap" :regex "Subject" [
        ".*(^|[^a-zA-Z0-9])accepted([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])confirm(ed|ation)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])details([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])from([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])issued([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])on the way([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])plac(e|ed|ing)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])receiv(e|ed|ing)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])refund(ed)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sale([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])sold([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])submit(ted)?([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])succe(ss|eded)([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])summary([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])thank(s|you) for([^a-zA-Z0-9]|$).*",
        ".*(^|[^a-zA-Z0-9])your([^a-zA-Z0-9]|$).*"
      ])
    ) {

    fileinto "receipts";

    if header :comparator "i;unicode-casemap" :matches "Subject" [
      "*invoice*",
      "*order*",
      "*purchase*",
      "*sale*",
      "*shopping*"
    ] {
      fileinto "shopping";
    }

    # expire "day" "${paper_trail_expiry_relative_days}";
    # fileinto "expiring";
    if header :list "from" ":addrbook:personal" {
      addflag "\\Seen";
    }
    fileinto "Paper Trail";
    stop;
  }
}