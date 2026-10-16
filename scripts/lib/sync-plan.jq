# sync-plan.jq — Decide what scripts/sync-groups.sh does to keep labels and
# contact groups in step. Pure: reads everything as arguments and prints a
# plan, so the decisions can be tested offline and the script only executes.
#
# Arguments (--slurpfile, so each is wrapped in a one-element array):
#   $groups      GET core/v4/labels?Type=2 response
#   $labels      GET core/v4/labels?Type=1 response
#   $state       pairs written by the last sync: [{Group: {ID, Name}, Label: {ID, Name}}]
#   $group_only  names of groups that never get a label
#   $filed       label names that filters/ file into, so need no group

def lower: ascii_downcase;
def title: split(" ") | map((.[:1] | ascii_upcase) + .[1:]) | join(" ");
def by_id: map({key: .ID, value: .}) | from_entries;
def ref: {ID, Name};

($groups[0].Labels) as $all_groups
| ($labels[0].Labels) as $all_labels
| ($all_groups | by_id) as $group_by_id
| ($all_labels | by_id) as $label_by_id
| ($group_only[0] | map(lower)) as $only
| ($filed[0]) as $filed_names

| [$state[0][] | {pair: ., group: $group_by_id[.Group.ID], label: $label_by_id[.Label.ID]}] as $tracked
| [$tracked[] | select(.group and .label)] as $live
| [$tracked[] | select((.group == null) != (.label == null))] as $orphaned
| [$tracked[] | (.group.ID, .label.ID) | values] as $claimed

# A side whose name differs from the last sync was renamed there, so the
# other side follows it. Both renamed to names that no longer pair is a
# conflict left for the user.
| [$live[]
    | (.group.Name != .pair.Group.Name) as $group_renamed
    | (.label.Name != .pair.Label.Name) as $label_renamed
    | if .label.Name == (.group.Name | lower) then
        {pair: {Group: (.group | ref), Label: (.label | ref)}}
      elif $group_renamed and ($label_renamed | not) then
        {pair: {Group: (.group | ref), Label: {ID: .label.ID, Name: (.group.Name | lower)}},
         rename: {Kind: "label", ID: .label.ID, From: .label.Name, To: (.group.Name | lower), Color: .label.Color}}
      elif $label_renamed and ($group_renamed | not) then
        {pair: {Group: {ID: .group.ID, Name: (.label.Name | title)}, Label: (.label | ref)},
         rename: {Kind: "group", ID: .group.ID, From: .group.Name, To: (.label.Name | title), Color: .group.Color}}
      else
        {conflict: {Group: .group.Name, Label: .label.Name}, keep: .pair}
      end
  ] as $resolved

| [$orphaned[]
    | if .group then
        {Kind: "group", ID: .group.ID, Name: .group.Name, Gone: ("label " + .pair.Label.Name), Pair: .pair}
      else
        {Kind: "label", ID: .label.ID, Name: .label.Name, Gone: ("group " + .pair.Group.Name), Pair: .pair}
      end
  ] as $deletes

| [$all_groups[] | select(.ID as $id | $claimed | index($id) | not)] as $free_groups
| [$all_labels[] | select(.ID as $id | $claimed | index($id) | not)] as $free_labels

| [$free_groups[] | . as $g
    | ($free_labels | map(select(.Name == ($g.Name | lower))) | first) as $l
    | select($l)
    | {Group: ($g | ref), Label: ($l | ref)}
  ] as $matched
| [$matched[] | .Group.ID, .Label.ID] as $matched_ids

| [$free_groups[] | select(.ID as $id | $matched_ids | index($id) | not)] as $lone_groups
| [$free_labels[] | select(.ID as $id | $matched_ids | index($id) | not)] as $lone_labels

| {
    pairs: ([$resolved[] | .pair | values] + $matched | sort_by(.Group.Name)),
    conflicts: [$resolved[] | .conflict | values],
    kept: [$resolved[] | .keep | values],
    renames: [$resolved[] | .rename | values],
    deletes: $deletes,
    create_labels: [$lone_groups[]
        | select(.Name | lower | IN($only[]) | not)
        | {Name: (.Name | lower), Color, Group: ref}],
    create_groups: [$lone_labels[]
        | select(.Name | lower | IN($only[]) | not)
        | select(.Name | IN($filed_names[]) | not)
        | {Name: (.Name | title), Color, Label: ref}],
    group_only: [$lone_groups[] | select(.Name | lower | IN($only[])) | .Name] | sort
  }
