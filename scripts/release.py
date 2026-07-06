import re

MARKETING_RE = re.compile(r"(MARKETING_VERSION = )([^;]+)(;)")
BUILD_RE = re.compile(r"(CURRENT_PROJECT_VERSION = )([^;]+)(;)")


def current_build_number(pbxproj):
    values = [match.group(2).strip() for match in BUILD_RE.finditer(pbxproj)]
    if not values:
        raise ValueError("no CURRENT_PROJECT_VERSION found")
    unique = set(values)
    if len(unique) != 1:
        raise ValueError(f"CURRENT_PROJECT_VERSION not uniform: {sorted(unique)}")
    if not values[0].isdigit():
        raise ValueError(f"CURRENT_PROJECT_VERSION is not an integer: {values[0]}")
    return int(values[0])


def bump_pbxproj(pbxproj, marketing, build):
    marketing_values = {
        match.group(2).strip() for match in MARKETING_RE.finditer(pbxproj)
    }
    if not marketing_values:
        raise ValueError("no MARKETING_VERSION found")
    if len(marketing_values) != 1:
        raise ValueError(f"MARKETING_VERSION not uniform: {sorted(marketing_values)}")
    current_build_number(pbxproj)
    result = MARKETING_RE.sub(lambda m: f"{m.group(1)}{marketing}{m.group(3)}", pbxproj)
    result = BUILD_RE.sub(lambda m: f"{m.group(1)}{build}{m.group(3)}", result)
    after_marketing = {
        match.group(2).strip() for match in MARKETING_RE.finditer(result)
    }
    after_build = {match.group(2).strip() for match in BUILD_RE.finditer(result)}
    if after_marketing != {marketing}:
        raise ValueError("MARKETING_VERSION not uniform after bump")
    if after_build != {str(build)}:
        raise ValueError("CURRENT_PROJECT_VERSION not uniform after bump")
    return result


def latest_version_tag(tags):
    parsed = []
    for tag in tags:
        text = tag.strip()
        match = re.fullmatch(r"v(\d+(?:\.\d+)*)", text)
        if match:
            key = tuple(int(part) for part in match.group(1).split("."))
            parsed.append((key, text))
    if not parsed:
        return None
    parsed.sort()
    return parsed[-1][1]


def deslug(branch):
    words = branch.replace("-", " ").replace("_", " ").split()
    if not words:
        return branch
    return " ".join(words).capitalize()


def _branch_from_subject(subject):
    match = re.search(r"Merge branch '([^']+)'", subject)
    return match.group(1) if match else None


def highlights_from_merges(merges):
    result = []
    for subject, body in merges:
        first_body_line = next(
            (line.strip() for line in body.splitlines() if line.strip()), ""
        )
        if first_body_line:
            result.append(first_body_line)
        else:
            branch = _branch_from_subject(subject)
            result.append(deslug(branch) if branch else subject.strip())
    return result


def render_changelog_entry(version, entry_date, highlights, commit_subjects):
    lines = [f"## v{version} — {entry_date.isoformat()}", "### Highlights"]
    lines.extend(f"- {item}" for item in highlights)
    lines.append("<details><summary>All changes</summary>")
    lines.append("")
    lines.extend(f"- {subject}" for subject in commit_subjects)
    lines.append("</details>")
    return "\n".join(lines) + "\n"


def highlights_plaintext(entry):
    out = []
    in_highlights = False
    for line in entry.splitlines():
        if line.strip() == "### Highlights":
            in_highlights = True
            continue
        if in_highlights:
            if (
                line.startswith("## ")
                or line.startswith("### ")
                or line.startswith("<details")
            ):
                break
            if line.strip().startswith("- "):
                out.append(line.strip()[2:])
    return "\n".join(out) + "\n"


def finalize_entry(edited_text):
    lines = edited_text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.startswith("## ")), None)
    if start is None:
        raise ValueError("release notes are empty (no '## ' header found)")
    kept = "\n".join(lines[start:]).strip()
    has_highlights = "### Highlights" in kept
    has_bullet = any(line.strip().startswith("- ") for line in kept.splitlines())
    if not (has_highlights and has_bullet):
        raise ValueError("release notes have no highlights")
    return kept + "\n"
