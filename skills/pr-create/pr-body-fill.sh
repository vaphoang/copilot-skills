#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   pr-body-fill.sh --template <path> --config <json-path> --output <path> [--strip-comments]
#
# Builds a PR body from a template + JSON config while guaranteeing that
# every checkbox line from the template is preserved in the output.
# Exits non-zero if any checkbox would be lost or if the template/config
# cannot be read.
#
# Config JSON shape:
#   {
#     "sections": [
#       { "heading": "## Summary", "content": "Free-form markdown body." },
#       { "heading": "## Screenshots", "omit": true }
#     ],
#     "checks": [
#       "substring of checkbox label to tick",
#       "another substring (case-insensitive)"
#     ]
#   }
#
# Section fields:
#   heading  - must match template heading exactly (including ## level)
#   content  - replacement body text for the section
#   omit     - if true, remove the entire section and its heading from output
#              (use when the template says "delete this section if not applicable")
#
# Flags:
#   --strip-comments  remove HTML instruction comments (<!-- ... -->) from output
#
# Rules enforced by this script:
#   - Section bodies are replaced between their heading and the next
#     heading of the same or higher level. Checkbox lines inside the
#     section are preserved verbatim and re-appended after the new body.
#   - Sections marked "omit": true are deleted entirely (heading included).
#     Any checkboxes inside an omitted section are subtracted from the
#     expected count so the integrity check still passes.
#   - Checkboxes are only ticked if their label contains one of the
#     `checks` substrings (case-insensitive). The script never deletes,
#     reorders, or rewrites a non-omitted checkbox line.
#   - If --strip-comments is given, all <!-- ... --> blocks are removed
#     from the final output.
#   - The final checkbox count MUST equal the template's non-omitted
#     checkbox count or the script aborts with exit code 3.

TEMPLATE=""
CONFIG=""
OUTPUT=""
STRIP_COMMENTS=0

print_usage() {
  sed -n '3,42p' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)       TEMPLATE="${2:-}"; shift 2 ;;
    --config)         CONFIG="${2:-}";   shift 2 ;;
    --output)         OUTPUT="${2:-}";   shift 2 ;;
    --strip-comments) STRIP_COMMENTS=1; shift ;;
    -h|--help)  print_usage; exit 0 ;;
    *) echo "❌ Unknown arg: $1" >&2; print_usage >&2; exit 2 ;;
  esac
done

for name in TEMPLATE CONFIG OUTPUT; do
  if [[ -z "${!name}" ]]; then
    echo "❌ Missing required arg: --${name,,}" >&2
    print_usage >&2
    exit 2
  fi
done

[[ -f "$TEMPLATE" ]] || { echo "❌ Template not found: $TEMPLATE" >&2; exit 1; }
[[ -f "$CONFIG"   ]] || { echo "❌ Config not found: $CONFIG" >&2;   exit 1; }
command -v python3 >/dev/null || { echo "❌ python3 is required" >&2; exit 1; }

python3 - "$TEMPLATE" "$CONFIG" "$OUTPUT" "$STRIP_COMMENTS" <<'PY'
import json, re, sys

template_path, config_path, output_path, strip_flag = sys.argv[1:5]
strip_comments = strip_flag == "1"

with open(template_path, "r", encoding="utf-8") as f:
    lines = f.readlines()
with open(config_path, "r", encoding="utf-8") as f:
    config = json.load(f)

CHECKBOX_RE = re.compile(r'^(\s*[-*]\s*)\[( |x|X)\](\s*)(.*)$')
HEADING_RE  = re.compile(r'^(#{1,6})\s+(.*?)\s*$')
COMMENT_RE  = re.compile(r'<!--.*?-->', re.DOTALL)

def is_checkbox(line: str) -> bool:
    return bool(CHECKBOX_RE.match(line))

original_checkbox_lines = [l for l in lines if is_checkbox(l)]
original_count = len(original_checkbox_lines)

# --- Collect omit headings first so we can subtract their checkboxes ---
omit_headings = set()
for sec in config.get("sections", []):
    if sec.get("omit"):
        omit_headings.add(sec.get("heading", "").rstrip())

# Count checkboxes that will be removed via omit (excluded from expected count)
omit_checkbox_count = 0
i = 0
while i < len(lines):
    m = HEADING_RE.match(lines[i])
    if m and lines[i].rstrip() in omit_headings:
        level = len(m.group(1))
        j = i + 1
        while j < len(lines):
            m2 = HEADING_RE.match(lines[j])
            if m2 and len(m2.group(1)) <= level:
                break
            if is_checkbox(lines[j]):
                omit_checkbox_count += 1
            j += 1
    i += 1

expected_count = original_count - omit_checkbox_count

# --- Apply section replacements / omissions ---
for sec in config.get("sections", []):
    heading = sec.get("heading", "").rstrip()
    content = sec.get("content", "").rstrip("\n")
    omit    = sec.get("omit", False)
    if not heading:
        continue

    target_idx = None
    target_level = None
    for i, line in enumerate(lines):
        m = HEADING_RE.match(line)
        if m and line.rstrip() == heading:
            target_idx = i
            target_level = len(m.group(1))
            break

    if target_idx is None:
        print(f"⚠️  Heading not found in template, skipping: {heading}", file=sys.stderr)
        continue

    end_idx = len(lines)
    for j in range(target_idx + 1, len(lines)):
        m = HEADING_RE.match(lines[j])
        if m and len(m.group(1)) <= target_level:
            end_idx = j
            break

    if omit:
        # Remove the heading and its entire body
        lines = lines[:target_idx] + lines[end_idx:]
        continue

    body_slice = lines[target_idx + 1 : end_idx]
    preserved_checkboxes = [l for l in body_slice if is_checkbox(l)]

    new_block = [lines[target_idx], "\n"]
    if content:
        new_block.append(content + "\n")
        new_block.append("\n")
    if preserved_checkboxes:
        new_block.extend(preserved_checkboxes)
        if not new_block[-1].endswith("\n"):
            new_block[-1] += "\n"
        new_block.append("\n")

    lines = lines[:target_idx] + new_block + lines[end_idx:]

# --- Strip HTML instruction comments if requested ---
if strip_comments:
    full = "".join(lines)
    full = COMMENT_RE.sub("", full)
    # Collapse runs of blank lines left behind by comment removal
    full = re.sub(r'\n{3,}', '\n\n', full)
    lines = [l + ("\n" if not l.endswith("\n") else "") for l in full.split("\n")]
    # split adds an extra empty token at end; remove trailing blank lines
    while lines and lines[-1].strip() == "":
        lines.pop()
    lines.append("\n")

# --- Apply checkbox ticks ---
checks = [c.lower() for c in config.get("checks", []) if isinstance(c, str)]

def label_matches(label: str) -> bool:
    low = label.lower()
    return any(c in low for c in checks)

ticked_new = 0
for i, line in enumerate(lines):
    m = CHECKBOX_RE.match(line)
    if not m:
        continue
    prefix, state, mid, label = m.groups()
    if state == " " and label_matches(label):
        lines[i] = f"{prefix}[x]{mid}{label}\n"
        ticked_new += 1

# --- Verify checkbox count ---
final_checkbox_lines = [l for l in lines if is_checkbox(l)]
final_count = len(final_checkbox_lines)
if final_count != expected_count:
    print(
        f"❌ Checkbox count mismatch: expected {expected_count} "
        f"(template {original_count} minus {omit_checkbox_count} omitted), "
        f"output has {final_count}. Aborting without writing output.",
        file=sys.stderr,
    )
    sys.exit(3)

with open(output_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

already_ticked = sum(
    1 for l in original_checkbox_lines
    if CHECKBOX_RE.match(l).group(2).lower() == "x"
)
total_ticked = sum(
    1 for l in final_checkbox_lines
    if CHECKBOX_RE.match(l).group(2).lower() == "x"
)
omit_note = f" ({omit_checkbox_count} in omitted sections)" if omit_checkbox_count else ""
print(f"✅ Wrote {output_path}")
print(f"   Checkboxes in template: {original_count}{omit_note}")
print(f"   Checkboxes in output:   {final_count}")
print(f"   Ticked by this run:     {ticked_new}")
print(f"   Ticked total:           {total_ticked} / {final_count}")
if strip_comments:
    print("   HTML comments stripped: yes")
PY

