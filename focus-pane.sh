#!/bin/bash
# focus-pane.sh <kitty-window-id>
#
# Bring the kitty pane with the given id to the foreground.
#
# Two steps, because neither alone is reliable:
#   1. `kitten @ focus-window` switches kitty's internal focus and asks the
#      compositor to raise the OS window. Under niri that raise is a focus
#      request subject to focus-stealing prevention: if the user's last input
#      went to another surface (e.g. clicking the notification itself), niri
#      silently ignores it and the command still exits 0.
#   2. So we also map the kitty pane to its niri window (same title, app_id
#      "kitty") and focus that id directly. Compositor IPC is not subject to
#      focus-stealing prevention, so this always lands.
#
# Prints a one-line summary on stdout for the caller's log.
set -u

pane="${1:?usage: focus-pane.sh <kitty-window-id>}"
pid=$(pgrep -x kitty | head -n1) || { echo "no kitty process"; exit 1; }
sock="unix:@mykitty-$pid"

# Step 0 — clear any DMS popout. The notification center takes exclusive
# keyboard focus from the compositor; while it is up niri reports no focused
# window and silently ignores every focus request.
qspid=$(pgrep -x qs | head -n1)
if [ -n "${qspid:-}" ]; then
    qs ipc --pid "$qspid" call notifications dismissAllPopups >/dev/null 2>&1
    qs ipc --pid "$qspid" call notifications close >/dev/null 2>&1
    sleep 0.15
fi

# Step 1 — best effort. Failure here is expected sometimes; don't bail.
kitten @ --to "$sock" focus-window --match "id:$pane" >/dev/null 2>&1

# Read back the pane title so we can find the matching OS window.
title=$(kitten @ --to "$sock" ls 2>/dev/null | python3 -I -c '
import json, sys
pane = int(sys.argv[1])
for w in json.load(sys.stdin):
    for t in w.get("tabs", []):
        for p in t.get("windows", []):
            if p.get("id") == pane:
                print(p.get("title", ""))
                raise SystemExit
' "$pane")

if [ -z "${title:-}" ]; then
    echo "pane $pane: no title from kitty ls"
    exit 1
fi

# Step 2 — focus the niri window with the same title. Compare with the
# status glyph stripped, since the glyph flips between ◑ (busy) and ✳ (idle).
nid=$(niri msg --json windows 2>/dev/null | python3 -I -c '
import json, re, sys

def norm(s):
    return re.sub(r"^[^\w]+", "", s or "", flags=re.UNICODE).strip()

key = norm(sys.argv[1])
ids = [w["id"] for w in json.load(sys.stdin)
       if w.get("app_id") == "kitty" and norm(w.get("title")) == key]
print(ids[0] if ids else "")
' "$title")

if [ -z "$nid" ]; then
    echo "pane $pane: kitty ok, no niri window matches title [$title]"
    exit 1
fi

niri msg action focus-window --id "$nid" >/dev/null 2>&1
rc=$?
echo "pane $pane -> niri $nid rc=$rc title=[$title]"
exit $rc
