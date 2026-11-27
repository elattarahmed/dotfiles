# Orders the right side of the bar by role, groups apart by a small spacer:
# apps · tools · music · network · system · privacy. Widgets not listed stay
# first, in their order. Spacers added here carry dotfilesSpacer, so a new run
# replaces them instead of adding more.
def groups: [
  ["dotfiles.apps", "omarchy.agents"],
  ["dotfiles.clipboard-button", "elattarahmed.whichport"],
  ["dotfiles.visualizer", "omarchy.audio"],
  ["interstellar-ip"],
  ["dotfiles.sysstats", "omarchy.power", "dotfiles.control-center"],
  ["dotfiles.privacy"]
];
def spacer: {"id": "omarchy.spacer", "size": 14, "dotfilesSpacer": true};

(.bar.layout.right // []) as $right
| ($right | map(select(.dotfilesSpacer != true))) as $items
| (groups | flatten) as $known
| ($items | map(select(.id as $id | $known | index($id) | not))) as $others
| [groups[] | [.[] as $id | $items[] | select(.id == $id)] | select(length > 0)] as $present
| .bar.layout.right = ($others + reduce $present[] as $g ([]; if length == 0 then $g else . + [spacer] + $g end))
