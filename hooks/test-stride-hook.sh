#!/usr/bin/env bash
# test-stride-hook.sh — Tests for the Codex Stride hook surface
#
# Test Group 1 covers the loop-state record (W2141). The Stop-hook gate and
# its permit paths are W2142/W2143 and will land as Test Group 2.
#
# No network: this hook makes no API calls at all (case 1h asserts that
# structurally), so unlike the sibling ports' suites there is no curl stub.

set -uo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/stride-hook.sh"
HOOKS_JSON="$SCRIPT_DIR/hooks.json"
PORT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Colors (if terminal supports them)
RED=""
GREEN=""
RESET=""
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  RESET='\033[0m'
fi

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo -e "  ${GREEN}PASS${RESET}: $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${RESET}: $label"
    echo "    expected: $(echo "$expected" | head -5)"
    echo "    actual:   $(echo "$actual" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo -e "  ${GREEN}PASS${RESET}: $label"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${RESET}: $label"
    echo "    expected to contain: $needle"
    echo "    actual: $(echo "$haystack" | head -5)"
    FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" -eq "$actual" ]; then
    echo -e "  ${GREEN}PASS${RESET}: $label (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo -e "  ${RED}FAIL${RESET}: $label"
    echo "    expected exit: $expected"
    echo "    actual exit:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

# ============================================================
# Test Group 1: loop state on completion (W2141)
# ============================================================
#
# NOT PORTED from the sibling suites, deliberately — recorded so the omissions
# read as decisions rather than oversights, and so a later port-parity audit
# does not re-add them:
#   Gemini 18p / Claude Code cross-half byte-identity — this port ships no
#       .ps1 twin (see stride-hook.sh's "DELIBERATELY OMITTED" block), so
#       there is no second half to compare against. Windows records no loop
#       state until that twin ships; the gap is flagged in the CHANGELOG.
#   Claude Code 33h/33i Tier-2 snapshot recovery — this port implements no
#       Tier 2. A truncated success records nothing (the safe miss), so those
#       cases would fail by design.
#
# Claude Code 33g ("a truncated 422 must not inherit the previous claim's
# payload") IS ported, as 1w, and is the one case Gemini could skip but this
# port cannot: Gemini has no .stride/.last-api-response.json, whereas the
# Codex skills tee every /complete response into exactly that path. The
# hazard is live here, so the guard is tested here.

echo ""
echo "=== Test Group 1: loop state on completion (W2141) ==="

if ! command -v jq > /dev/null 2>&1; then
  echo "  SKIP: Test Group 1 (jq not available — the hook self-gates on jq)"
else
  # A bare project dir. Deliberately NO .stride.md: this hook has no
  # .stride.md existence gate, unlike the Gemini port, because the loop-state
  # record must be written whether or not the project defines hook sections.
  # Every case below therefore also proves that decision.
  g_proj() {
    local d
    d=$(mktemp -d "$TMPDIR_TEST/g1.XXXXXX")
    printf '%s' "$d"
  }
  # $1=session_id  $2=command  $3=raw tool_response.stdout payload
  g_input() {
    jq -nc --arg s "$1" --arg c "$2" --arg r "$3" \
      '{session_id: $s, tool_input: {command: $c}, tool_response: {stdout: $r}}'
  }
  g_run() {  # $1=project dir  $2=input json  (stderr -> $G_ERR)
    printf '%s' "$2" | CODEX_PROJECT_DIR="$1" \
      bash "$HOOK_SCRIPT" post > "$G_OUT" 2> "$G_ERR"
  }

  G_ERR="$TMPDIR_TEST/g1.err"
  G_OUT="$TMPDIR_TEST/g1.out"
  G_CMD='curl -X PATCH https://stride.invalid/api/tasks/99/complete -H "Authorization: Bearer SECRETVALUE"'
  G_CLAIM='curl -X POST https://stride.invalid/api/tasks/claim'
  G_OK='{"data":{"id":99,"identifier":"W2141","needs_review":false},"hooks":[{"name":"before_review"}]}'
  G_OK_TRUE='{"data":{"id":99,"identifier":"W2141","needs_review":true},"hooks":[{"name":"before_review"}]}'
  G_422='{"errors":{"base":["completion is invalid"]}}'

  # 1a: a successful completion records all four fields
  D=$(g_proj); g_run "$D" "$(g_input 'sess-abc' "$G_CMD" "$G_OK")"
  S="$D/.stride/.loop-state.json"
  assert_eq "1a: records the identifier" "W2141" "$(jq -r '.identifier' "$S" 2>/dev/null)"
  assert_eq "1a: records needs_review false" "false" "$(jq -r '.needs_review' "$S" 2>/dev/null)"
  assert_eq "1a: records the session id" "sess-abc" "$(jq -r '.session_id' "$S" 2>/dev/null)"
  assert_eq "1a: completed_at is ISO8601 Z" "1" \
    "$(jq -r '.completed_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") | if . then 1 else 0 end' "$S" 2>/dev/null)"
  assert_eq "1a: the hook writes nothing to stdout" "0" "$(wc -c < "$G_OUT" | tr -d ' ')"
  assert_eq "1a: no .stride.md is needed to record" "absent" \
    "$([ -e "$D/.stride.md" ] && echo present || echo absent)"

  # 1b: needs_review=true is recorded verbatim AND as a real JSON boolean.
  # The type assert is the point: jq -r prints the string "true" and the
  # boolean true identically, so only `| type` can tell them apart.
  D=$(g_proj); g_run "$D" "$(g_input 'sess-b' "$G_CMD" "$G_OK_TRUE")"
  S="$D/.stride/.loop-state.json"
  assert_eq "1b: needs_review true recorded" "true" "$(jq -r '.needs_review' "$S" 2>/dev/null)"
  assert_eq "1b: needs_review is a boolean, not a string" "boolean" \
    "$(jq -r '.needs_review | type' "$S" 2>/dev/null)"

  # 1b2: a STRING "true" in the response is refused outright
  D=$(g_proj)
  g_run "$D" "$(g_input 'sess-b2' "$G_CMD" '{"data":{"id":9,"identifier":"W9","needs_review":"true"}}')"
  assert_eq "1b2: a quoted needs_review is refused, nothing recorded" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"

  # 1c: the session id falls back to the environment when the input omits it
  NOSID=$(jq -nc --arg c "$G_CMD" --arg r "$G_OK" '{tool_input:{command:$c},tool_response:{stdout:$r}}')
  D=$(g_proj)
  printf '%s' "$NOSID" | CODEX_PROJECT_DIR="$D" CLAUDE_SESSION_ID="env-sess" \
    bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1c: falls back to CLAUDE_SESSION_ID" "env-sess" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"
  D=$(g_proj)
  printf '%s' "$NOSID" | CODEX_PROJECT_DIR="$D" CODEX_SESSION_ID="codex-sess" CLAUDE_SESSION_ID="env-sess" \
    bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1c: CODEX_SESSION_ID wins over CLAUDE_SESSION_ID" "codex-sess" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"

  # 1d: an absent session id degrades to "unknown" rather than dropping the record
  D=$(g_proj)
  printf '%s' "$NOSID" | CODEX_PROJECT_DIR="$D" \
    env -u CODEX_SESSION_ID -u CLAUDE_SESSION_ID bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  S="$D/.stride/.loop-state.json"
  assert_eq "1d: absent session id degrades to unknown" "unknown" "$(jq -r '.session_id' "$S" 2>/dev/null)"
  assert_eq "1d: the record is still written" "W2141" "$(jq -r '.identifier' "$S" 2>/dev/null)"

  # 1e: a non-identifier-shaped session id degrades to "unknown", never recorded raw
  D=$(g_proj); g_run "$D" "$(g_input 'not a/session id' "$G_CMD" "$G_OK")"
  assert_eq "1e: unsafe session id degrades to unknown" "unknown" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"

  # 1f: a 422 completion does NOT write the record, and is not announced
  D=$(g_proj); g_run "$D" "$(g_input 'sess-f' "$G_CMD" "$G_422")"
  assert_eq "1f: a 422 completion writes nothing" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  assert_eq "1f: a well-formed 422 is not announced as unparsable" "0" \
    "$(grep -c 'unparsable' "$G_ERR" 2>/dev/null || true)"

  # 1g: a successful claim clears a previous completion's record
  D=$(g_proj); mkdir -p "$D/.stride"
  printf '{"identifier":"W_OLD","needs_review":false,"completed_at":"2026-01-01T00:00:00Z","session_id":"old"}\n' \
    > "$D/.stride/.loop-state.json"
  g_run "$D" "$(g_input 'sess-g' "$G_CLAIM" '{"data":{"id":1,"identifier":"W1"}}')"
  assert_eq "1g: a claim clears the record" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"

  # 1h: atomicity, stdout discipline and the no-network property, asserted
  # structurally on the source
  G_FN=$(awk '/^write_loop_state\(\) \{/,/^\}/' "$HOOK_SCRIPT")
  assert_eq "1h: never redirects straight at the destination" "0" \
    "$(printf '%s' "$G_FN" | grep -c '> *"\$LOOP_STATE_FILE"' || true)"
  assert_eq "1h: stages a temp in the destination directory" "1" \
    "$(printf '%s' "$G_FN" | grep -c 'mktemp "\$PROJECT_DIR/.stride/loop-state' || true)"
  assert_eq "1h: every diagnostic goes to stderr" "0" \
    "$(printf '%s' "$G_FN" | grep -c "printf '[^']*'[^>]*$" || true)"
  assert_eq "1h: the hook never invokes curl" "0" \
    "$(grep -cE '^[^#]*\bcurl\b' "$HOOK_SCRIPT" || true)"
  D=$(g_proj); g_run "$D" "$(g_input 'sess-h' "$G_CMD" "$G_OK")"
  assert_eq "1h: a successful write leaves no temp behind" "0" \
    "$(ls "$D/.stride" 2>/dev/null | grep -c '^loop-state\.' || true)"

  # 1i: exactly the four documented keys, and never the Bearer token.
  # The command in every case above embeds a synthetic SECRETVALUE precisely
  # so this assertion has something to catch.
  D=$(g_proj); g_run "$D" "$(g_input 'sess-i' "$G_CMD" "$G_OK")"
  S="$D/.stride/.loop-state.json"
  assert_eq "1i: exactly the four documented keys" "completed_at identifier needs_review session_id" \
    "$(jq -r '[keys_unsorted[]] | sort | join(" ")' "$S" 2>/dev/null)"
  assert_eq "1i: the token never reaches the record" "0" \
    "$(grep -c 'SECRETVALUE\|Bearer' "$S" 2>/dev/null || true)"

  # 1j: an unwritable .stride/ is announced and never fails the completion
  if [ "$(id -u)" -eq 0 ]; then
    echo "  SKIP: 1j (running as root — a 0500 directory would still be writable)"
  else
    D=$(g_proj); mkdir -p "$D/.stride"; chmod 500 "$D/.stride"
    printf '%s' "$(g_input 'sess-j' "$G_CMD" "$G_OK")" | CODEX_PROJECT_DIR="$D" \
      bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
    G_RC=$?
    assert_exit "1j: an unwritable .stride/ still exits 0" 0 "$G_RC"
    assert_contains "1j: the failure is announced on stderr" "loop state" "$(cat "$G_ERR")"
    chmod 700 "$D/.stride"
    assert_eq "1j: nothing was recorded" "absent" \
      "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  fi

  # 1k: the claim -> complete -> claim cycle leaves absent, present, absent
  D=$(g_proj)
  g_run "$D" "$(g_input 'sess-k' "$G_CLAIM" '{"data":{"id":1,"identifier":"W1"}}')"
  K1=$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)
  g_run "$D" "$(g_input 'sess-k' "$G_CMD" "$G_OK")"
  K2=$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)
  g_run "$D" "$(g_input 'sess-k' "$G_CLAIM" '{"data":{"id":2,"identifier":"W2"}}')"
  K3=$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)
  assert_eq "1k: claim/complete/claim cycles absent-present-absent" "absent present absent" "$K1 $K2 $K3"

  # 1l: a failed or unparsable claim STILL clears — the safe direction. The
  # empty-queue claim is the common case and the one that would otherwise
  # leave a record indistinguishable from a completed-and-never-claimed-again
  # agent.
  for G_BODY in '{"errors":{"base":["no task available"]}}' '{"data":{"identi'; do
    D=$(g_proj); mkdir -p "$D/.stride"
    printf '{"identifier":"W_OLD","needs_review":false,"completed_at":"2026-01-01T00:00:00Z","session_id":"old"}\n' \
      > "$D/.stride/.loop-state.json"
    g_run "$D" "$(g_input 'sess-l' "$G_CLAIM" "$G_BODY")"
    assert_eq "1l: a failed/unparsable claim still clears the record" "absent" \
      "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  done

  # 1m: an absent tool_response records nothing and is NOT announced as
  # unparsable — "no body at all" must stay out of a channel claiming a body
  # failed to parse.
  D=$(g_proj)
  NORESP=$(jq -nc --arg c "$G_CMD" '{session_id:"sess-m",tool_input:{command:$c}}')
  printf '%s' "$NORESP" | CODEX_PROJECT_DIR="$D" \
    bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
  G_RC=$?
  assert_exit "1m: an absent tool_response exits 0" 0 "$G_RC"
  assert_eq "1m: nothing recorded" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  assert_eq "1m: not announced as unparsable" "0" \
    "$(grep -c 'unparsable' "$G_ERR" 2>/dev/null || true)"

  # 1n: a truncated completion body records nothing and IS announced
  D=$(g_proj); g_run "$D" "$(g_input 'sess-n' "$G_CMD" '{"data":{"identifier":"W2 TRUNCA')"
  assert_eq "1n: a truncated body records nothing" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  assert_contains "1n: a truncated body is announced as unparsable" \
    "unparsable" "$(cat "$G_ERR")"

  # 1o: bash reads values through $( ), which strips every trailing newline.
  # An INTERIOR newline is refused by the charset gate.
  D=$(g_proj); g_run "$D" "$(g_input 'trail-nl
' "$G_CMD" "$G_OK")"
  assert_eq "1o: a trailing newline in the session id is stripped, not refused" "trail-nl" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"
  D=$(g_proj); g_run "$D" "$(g_input 'a
b' "$G_CMD" "$G_OK")"
  assert_eq "1o: an interior newline is refused" "unknown" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"

  # 1q: the OVERWRITE path — a completion over an EXISTING record. Every case
  # above starts from a fresh directory, and 1g/1k/1l pre-create the file only
  # to run a CLAIM, which removes it — so without this case `mv -f` over an
  # existing destination never executes. Atomicity is the property that only
  # matters when a destination already exists, so this is the case AC2 is
  # actually about.
  D=$(g_proj); mkdir -p "$D/.stride"
  printf '{"identifier":"W_OLD","needs_review":true,"completed_at":"2026-01-01T00:00:00Z","session_id":"old"}\n' \
    > "$D/.stride/.loop-state.json"
  g_run "$D" "$(g_input 'sess-q' "$G_CMD" "$G_OK")"
  S="$D/.stride/.loop-state.json"
  assert_eq "1q: a completion overwrites an existing record" "W2141" "$(jq -r '.identifier' "$S" 2>/dev/null)"
  assert_eq "1q: the overwritten record carries the new needs_review" "false" "$(jq -r '.needs_review' "$S" 2>/dev/null)"
  assert_eq "1q: the overwritten record carries the new session id" "sess-q" "$(jq -r '.session_id' "$S" 2>/dev/null)"
  assert_eq "1q: the overwrite leaves no temp behind" "0" \
    "$(ls "$D/.stride" 2>/dev/null | grep -c '^loop-state\.' || true)"

  # 1q2: a loop-state path that is a DIRECTORY is refused, not moved into.
  # `mv` into a directory SUCCEEDS by relocating the temp inside it, so
  # without the explicit non-regular-file guard the record would land where no
  # reader looks and the temp would survive indefinitely.
  D=$(g_proj); mkdir -p "$D/.stride/.loop-state.json"
  printf '%s' "$(g_input 'sess-q2' "$G_CMD" "$G_OK")" | CODEX_PROJECT_DIR="$D" \
    bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
  G_RC=$?
  assert_exit "1q2: a directory at the record path still exits 0" 0 "$G_RC"
  assert_contains "1q2: the refusal is announced" "not a regular file" "$(cat "$G_ERR")"
  assert_eq "1q2: nothing was moved inside the directory" "0" \
    "$(ls -A "$D/.stride/.loop-state.json" 2>/dev/null | wc -l | tr -d ' ')"

  # 1r: the charset gate must be LOCALE-INDEPENDENT. Written as A-Z / a-z
  # ranges it is not — a glob bracket RANGE is collation-ordered rather than
  # codepoint-ordered on bash < 5.0 (macOS ships 3.2) under a UTF-8 locale, so
  # accented Latin letters would pass here while a codepoint-based reader
  # refuses them. Run under both a UTF-8 locale and C.
  for G_LOC in en_US.UTF-8 C; do
    D=$(g_proj)
    printf '%s' "$(g_input 'sess-r' "$G_CMD" '{"data":{"id":9,"identifier":"Wé144","needs_review":true}}')" \
      | CODEX_PROJECT_DIR="$D" LC_ALL="$G_LOC" bash "$HOOK_SCRIPT" post > /dev/null 2>&1
    assert_eq "1r: an accented identifier is refused under LC_ALL=$G_LOC" "absent" \
      "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  done

  # 1s: session-id TYPE handling. The value is read with
  # `jq -r '.session_id // ...'`, so a non-scalar renders multi-line and the
  # charset gate refuses it WITHOUT falling back to the environment, while a
  # number renders plainly and is kept, and a literal false is absent to `//`
  # so the environment wins.
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg c "$G_CMD" --arg r "$G_OK" '{session_id:["abc"],tool_input:{command:$c},tool_response:{stdout:$r}}')" \
    | CODEX_PROJECT_DIR="$D" CLAUDE_SESSION_ID="env-sess" bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1s: an array session id degrades to unknown, never the env value" "unknown" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg c "$G_CMD" --arg r "$G_OK" '{session_id:12345,tool_input:{command:$c},tool_response:{stdout:$r}}')" \
    | CODEX_PROJECT_DIR="$D" bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1s: a numeric session id is recorded as its plain rendering" "12345" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg c "$G_CMD" --arg r "$G_OK" '{session_id:false,tool_input:{command:$c},tool_response:{stdout:$r}}')" \
    | CODEX_PROJECT_DIR="$D" CLAUDE_SESSION_ID="env-sess" bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1s: a literal false session id is absent to jq, so the env wins" "env-sess" \
    "$(jq -r '.session_id' "$D/.stride/.loop-state.json" 2>/dev/null)"

  # 1t: a mixed-case key is refused, matching jq's case-SENSITIVE .data path
  D=$(g_proj)
  g_run "$D" "$(g_input 'sess-t' "$G_CMD" '{"Data":{"id":9,"Identifier":"W9","Needs_Review":true}}')"
  assert_eq "1t: a mixed-case response key is refused" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"

  # 1v: a mixed-case tool_response key unwraps nothing and records nothing —
  # and is not announced either, because an empty payload is "no body at all",
  # not a body that failed to parse.
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg c "$G_CMD" --arg r "$G_OK" '{session_id:"sess-v",tool_input:{command:$c},Tool_Response:{stdout:$r}}')" \
    | CODEX_PROJECT_DIR="$D" bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
  assert_eq "1v: a mixed-case tool_response key records nothing" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  assert_eq "1v: and is not announced as unparsable" "0" \
    "$(grep -c 'unparsable' "$G_ERR" 2>/dev/null || true)"

  # ----------------------------------------------------------
  # Codex-specific cases (no precedent in the sibling suites)
  # ----------------------------------------------------------

  # 1w: THE CACHE IS NEVER READ. This is the case Gemini could skip and this
  # port cannot — the Codex skills tee every /complete response into
  # .stride/.last-api-response.json, so a canonical-file-first reader would
  # have a live second source to inherit from. Structural half plus the
  # functional half that actually demonstrates the bug it prevents.
  # Comments are excluded deliberately: the correct implementation DOCUMENTS
  # the cache by name in order to forbid it, so a whole-file grep would fail
  # on the very comment that prevents the bug. What must be zero is executable
  # lines naming it.
  assert_eq "1w: no executable line names the response cache" "0" \
    "$(grep -v '^[[:space:]]*#' "$HOOK_SCRIPT" | grep -c 'last-api-response' || true)"
  assert_eq "1w: and the hazard is documented in a comment" "2" \
    "$(grep -c '^[[:space:]]*#.*last-api-response' "$HOOK_SCRIPT" || true)"
  D=$(g_proj); mkdir -p "$D/.stride"
  # A perfectly valid PREVIOUS response sitting in the cache...
  printf '%s\n' "$G_OK" > "$D/.stride/.last-api-response.json"
  # ...and a TRUNCATED body for the call actually being hooked.
  g_run "$D" "$(g_input 'sess-w' "$G_CMD" '{"data":{"identifier":"W2 TRUNCA')"
  assert_eq "1w: a truncated body does not inherit the cached payload" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
  assert_contains "1w: and the truncation is still announced" "unparsable" "$(cat "$G_ERR")"
  # Same guard on the 422 path: a 422 alongside a valid cache records nothing.
  D=$(g_proj); mkdir -p "$D/.stride"
  printf '%s\n' "$G_OK" > "$D/.stride/.last-api-response.json"
  g_run "$D" "$(g_input 'sess-w2' "$G_CMD" "$G_422")"
  assert_eq "1w: a 422 does not inherit the cached payload either" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"

  # 1x: the tee'd command still routes. The Codex skills pipe the /complete
  # curl through `| tee .stride/.last-api-response.json`; tee passes stdout
  # through unchanged, so both the routing match and the payload read must be
  # unaffected by the pipeline.
  D=$(g_proj)
  g_run "$D" "$(g_input 'sess-x' \
    "$G_CMD | tee \"\$CLAUDE_PROJECT_DIR/.stride/.last-api-response.json\"" "$G_OK")"
  assert_eq "1x: a tee'd completion command still routes and records" "W2141" \
    "$(jq -r '.identifier' "$D/.stride/.loop-state.json" 2>/dev/null)"

  # 1y: two sessions in one checkout (edge case; no precedent — designed here).
  #
  # NON-GOAL, stated so a later reader does not mistake this for a bug: the
  # record is NOT per-session. A checkout has exactly one loop state, and
  # W2142's gate reads it without knowing who wrote it, so interleaved
  # sessions can mask each other's gate. That is accepted for the same reason
  # the claim clear is unconditional — a missed gate is the safe side, and a
  # session-keyed map would be a different (and unread) contract.
  D=$(g_proj)
  g_run "$D" "$(g_input 'sess-A' "$G_CMD" "$G_OK")"
  S="$D/.stride/.loop-state.json"
  assert_eq "1y: session A records its own completion" "sess-A" "$(jq -r '.session_id' "$S" 2>/dev/null)"
  g_run "$D" "$(g_input 'sess-B' "$G_CMD" \
    '{"data":{"id":100,"identifier":"W2142","needs_review":true}}')"
  assert_eq "1y: session B's completion wins outright — no merge" "W2142 true sess-B" \
    "$(jq -r '[.identifier, (.needs_review|tostring), .session_id] | join(" ")' "$S" 2>/dev/null)"
  assert_eq "1y: still exactly four keys — no session-keyed map crept in" "4" \
    "$(jq -r 'keys | length' "$S" 2>/dev/null)"
  assert_eq "1y: the record is a single regular file" "present" \
    "$([ -f "$S" ] && echo present || echo absent)"
  assert_eq "1y: no leftover temps" "0" \
    "$(find "$D/.stride" -maxdepth 1 -name 'loop-state.*' 2>/dev/null | wc -l | tr -d ' ')"
  assert_eq "1y: and nothing else in .stride/" "1" \
    "$(find "$D/.stride" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
  # Session A's claim clears session B's record — the record belongs to the
  # checkout, not to whoever wrote it.
  g_run "$D" "$(g_input 'sess-A' "$G_CLAIM" '{"data":{"id":1,"identifier":"W1"}}')"
  assert_eq "1y: either session's claim clears the shared record" "absent" \
    "$([ -e "$S" ] && echo present || echo absent)"

  # 1z: the registration shape. Guards the three facts verified against the
  # Codex hooks documentation, and keeps W2142's Stop entry out of this file.
  assert_eq "1z: hooks.json is valid JSON" "0" \
    "$(jq empty "$HOOKS_JSON" > /dev/null 2>&1; echo $?)"
  assert_eq "1z: registers PostToolUse with the Bash matcher" "Bash" \
    "$(jq -r '.hooks.PostToolUse[0].matcher' "$HOOKS_JSON" 2>/dev/null)"
  assert_eq "1z: the handler is async false" "false" \
    "$(jq -r '.hooks.PostToolUse[0].hooks[0].async' "$HOOKS_JSON" 2>/dev/null)"
  assert_eq "1z: the handler is a command hook ending in the post phase" "1" \
    "$(jq -r '.hooks.PostToolUse[0].hooks[0] | if (.type == "command" and (.command | endswith("/hooks/stride-hook.sh post"))) then 1 else 0 end' "$HOOKS_JSON" 2>/dev/null)"
  # Seconds, not milliseconds: a Gemini-style 300000 here would be 3.5 days.
  assert_eq "1z: the timeout is a plausible seconds value" "1" \
    "$(jq -r '.hooks.PostToolUse[0].hooks[0].timeout | if (. > 0 and . <= 600) then 1 else 0 end' "$HOOKS_JSON" 2>/dev/null)"
  assert_eq "1z: no Stop entry — that is W2142's, and must be ADDED not edited" "false" \
    "$(jq -r '.hooks | has("Stop")' "$HOOKS_JSON" 2>/dev/null)"
  # The expansion must stay QUOTED: an install path with whitespace or shell
  # metacharacters would otherwise split into the wrong argv or be evaluated.
  # endswith(" post") alone passes either way, so this needs its own assertion.
  assert_eq "1z: the plugin-root expansion is quoted" "1" \
    "$(jq -r '.hooks.PostToolUse[0].hooks[0].command | if startswith("\"${PLUGIN_ROOT}\"/") then 1 else 0 end' "$HOOKS_JSON" 2>/dev/null)"

  # 1z2: the dead-file regression. The hook surface is inert unless the
  # installers actually copy it — neither did before W2141.
  #
  # These assert the COPY LINES, not the bare word "hooks". An earlier version
  # matched the word anywhere in the file, which both installers also carry in
  # their next-steps prose — so deleting the actual cp lines would have left
  # this case green, which is precisely the regression it claims to guard.
  assert_eq "1z2: install.sh copies the hook script" "1" \
    "$(grep -cE '^cp .*/hooks/stride-hook\.sh" "\$INSTALL_DIR/hooks/stride-hook\.sh"$' "$PORT_ROOT/install.sh" || true)"
  assert_eq "1z2: install.sh copies the registration" "1" \
    "$(grep -cE '^cp .*/hooks/hooks\.json" "\$INSTALL_DIR/hooks/hooks\.json"$' "$PORT_ROOT/install.sh" || true)"
  assert_eq "1z2: install.sh creates the hooks directory" "1" \
    "$(grep -cE '^mkdir -p .*\$INSTALL_DIR/hooks"' "$PORT_ROOT/install.sh" || true)"
  assert_eq "1z2: install.ps1 copies both hook files" "1" \
    "$(grep -cF "foreach (\$hookFile in @('stride-hook.sh', 'hooks.json'))" "$PORT_ROOT/install.ps1" || true)"
  assert_eq "1z2: install.ps1 creates the hooks directory" "1" \
    "$(grep -cF "New-Item -ItemType Directory -Force -Path (Join-Path \$InstallDir 'hooks')" "$PORT_ROOT/install.ps1" || true)"
  assert_eq "1z2: the port gitignores .stride/" "1" \
    "$(grep -cE '^\.stride/$' "$PORT_ROOT/.gitignore" || true)"
  # The documented install path is `curl ... | bash`, which works regardless —
  # but a user who clones and runs ./install.sh needs the exec bit, and an
  # editing pass can silently drop it.
  assert_eq "1z2: install.sh is executable" "yes" \
    "$([ -x "$PORT_ROOT/install.sh" ] && echo yes || echo no)"
  assert_eq "1z2: the hook script is executable" "yes" \
    "$([ -x "$HOOK_SCRIPT" ] && echo yes || echo no)"
  # The README's MANUAL install path is a third way to install, and it was the
  # one place the hook files stayed dead code after the installers were fixed.
  assert_eq "1z2: the README bash manual block copies the hook script" "1" \
    "$(grep -cF 'cp -p stride-codex/hooks/stride-hook.sh .agents/hooks/stride-hook.sh' "$PORT_ROOT/README.md" || true)"
  assert_eq "1z2: the README bash manual block copies the registration" "1" \
    "$(grep -cF 'cp stride-codex/hooks/hooks.json .agents/hooks/hooks.json' "$PORT_ROOT/README.md" || true)"
  assert_eq "1z2: the README PowerShell manual block copies both" "2" \
    "$(grep -cE '^Copy-Item stride-codex\\hooks\\(stride-hook\.sh|hooks\.json) ' "$PORT_ROOT/README.md" || true)"
  # A .agents/ install is not a plugin bundle, so the surface is inert unless
  # the user registers it. Both installers must say so, with the path filled in.
  assert_eq "1z2: install.sh tells the user to register the hook" "1" \
    "$(grep -cF 'is not auto-discovered' "$PORT_ROOT/install.sh" || true)"
  assert_eq "1z2: install.ps1 tells the user to register the hook" "1" \
    "$(grep -cF 'is not auto-discovered' "$PORT_ROOT/install.ps1" || true)"
  assert_eq "1z2: and the README documents where to register it" "1" \
    "$(grep -cF '### Registering the hook' "$PORT_ROOT/README.md" || true)"

  # 1z7: symlink guards. `mkdir -p` succeeds silently on an existing symlink to
  # a directory, so without an explicit guard the temp would be staged and
  # renamed inside the LINK TARGET — a directory this hook never created.
  # Neither the write nor the clear may reach through one.
  D=$(g_proj); OUTSIDE=$(mktemp -d "$TMPDIR_TEST/outside.XXXXXX")
  ln -s "$OUTSIDE" "$D/.stride"
  printf '%s' "$(g_input 'sess-z7' "$G_CMD" "$G_OK")" | CODEX_PROJECT_DIR="$D" \
    bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
  G_RC=$?
  assert_exit "1z7: a symlinked .stride still exits 0" 0 "$G_RC"
  assert_eq "1z7: nothing is written through the symlink" "0" \
    "$(find "$OUTSIDE" -mindepth 1 2>/dev/null | wc -l | tr -d ' ')"
  assert_contains "1z7: the refusal is announced" "symlink" "$(cat "$G_ERR")"
  # The claim clear refuses too, and says so — a stale record is the dangerous
  # direction, so silence here would be worse than the refusal.
  printf 'stale\n' > "$OUTSIDE/.loop-state.json"
  printf '%s' "$(g_input 'sess-z7' "$G_CLAIM" '{"data":{"id":1,"identifier":"W1"}}')" \
    | CODEX_PROJECT_DIR="$D" bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
  assert_eq "1z7: the clear does not delete through the symlink" "present" \
    "$([ -f "$OUTSIDE/.loop-state.json" ] && echo present || echo absent)"
  assert_contains "1z7: and the stale-record risk is announced" "stale" "$(cat "$G_ERR")"
  # A symlink at the RECORD path is refused as well: -f follows the link, so
  # without an explicit -L test it would pass the regular-file gate.
  D=$(g_proj); mkdir -p "$D/.stride"
  TARGET="$TMPDIR_TEST/linktarget.$$"; printf 'do not clobber\n' > "$TARGET"
  ln -s "$TARGET" "$D/.stride/.loop-state.json"
  printf '%s' "$(g_input 'sess-z8' "$G_CMD" "$G_OK")" | CODEX_PROJECT_DIR="$D" \
    bash "$HOOK_SCRIPT" post > /dev/null 2> "$G_ERR"
  assert_eq "1z7: a symlinked record path is not written through" "do not clobber" \
    "$(cat "$TARGET" 2>/dev/null)"
  assert_contains "1z7: that refusal is announced too" "symlink" "$(cat "$G_ERR")"

  # 1z3: PROJECT_DIR resolution. Codex sets no *_PROJECT_DIR of its own, so
  # the event's own `.cwd` is the fallback that makes the hook work at all.
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg s 'sess-cwd' --arg c "$G_CMD" --arg r "$G_OK" --arg d "$D" \
    '{session_id:$s,cwd:$d,tool_input:{command:$c},tool_response:{stdout:$r}}')" \
    | env -u CODEX_PROJECT_DIR -u CLAUDE_PROJECT_DIR bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1z3: falls back to the event's cwd when no PROJECT_DIR is set" "W2141" \
    "$(jq -r '.identifier' "$D/.stride/.loop-state.json" 2>/dev/null)"

  # 1z4: Codex's shell tool takes argv-style arguments, so the command may
  # arrive as an ARRAY rather than a string.
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg s 'sess-argv' --arg r "$G_OK" \
    '{session_id:$s,tool_input:{command:["curl","-X","PATCH","https://stride.invalid/api/tasks/99/complete"]},tool_response:{stdout:$r}}')" \
    | CODEX_PROJECT_DIR="$D" bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1z4: an argv-array command routes like a string command" "W2141" \
    "$(jq -r '.identifier' "$D/.stride/.loop-state.json" 2>/dev/null)"
  D=$(g_proj)
  printf '%s' "$(jq -nc --arg s 'sess-argv2' --arg r '{"data":{"id":1,"identifier":"W1"}}' \
    '{session_id:$s,tool_input:{command:["curl","-X","POST","https://stride.invalid/api/tasks/claim"]},tool_response:{stdout:$r}}')" \
    | CODEX_PROJECT_DIR="$D" bash "$HOOK_SCRIPT" post > /dev/null 2>&1
  assert_eq "1z4: an argv-array claim clears too" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"

  # 1z5: unrelated tool calls and the unrouted mark_reviewed arm are no-ops
  for G_OTHER in 'ls -la' 'curl https://stride.invalid/api/tasks/next' \
                 'curl -X PATCH https://stride.invalid/api/tasks/99/mark_reviewed'; do
    D=$(g_proj); mkdir -p "$D/.stride"
    printf '{"identifier":"W_KEEP","needs_review":false,"completed_at":"2026-01-01T00:00:00Z","session_id":"keep"}\n' \
      > "$D/.stride/.loop-state.json"
    printf '%s' "$(g_input 'sess-z5' "$G_OTHER" "$G_OK")" | CODEX_PROJECT_DIR="$D" \
      bash "$HOOK_SCRIPT" post > /dev/null 2>&1
    assert_eq "1z5: '$G_OTHER' neither records nor clears" "W_KEEP" \
      "$(jq -r '.identifier' "$D/.stride/.loop-state.json" 2>/dev/null)"
  done

  # 1z6: a phase other than `post` is inert
  D=$(g_proj)
  printf '%s' "$(g_input 'sess-z6' "$G_CMD" "$G_OK")" | CODEX_PROJECT_DIR="$D" \
    bash "$HOOK_SCRIPT" pre > /dev/null 2>&1
  assert_eq "1z6: the pre phase records nothing" "absent" \
    "$([ -e "$D/.stride/.loop-state.json" ] && echo present || echo absent)"
fi

echo ""
echo "============================================================"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "============================================================"

[ "$FAIL" -eq 0 ] || exit 1
exit 0
