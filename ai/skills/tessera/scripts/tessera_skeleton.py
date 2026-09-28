"""Deterministic catalog skeleton: candidate sources, exports and real non-test usages.

The skeleton is evidence for the curating agent, never a catalog. It reads Git
objects at one revision, receives paths already filtered by the inventory
policy (tests removed, protected paths marked) and never opens either.
"""
from __future__ import annotations

import os
import re
import subprocess
from pathlib import PurePosixPath

SOURCE_SUFFIXES = (".vue", ".svelte", ".ts", ".tsx", ".mts", ".cts", ".js", ".jsx", ".mjs", ".cjs",
                   ".css", ".scss", ".sass", ".less")
CONSUMER_SUFFIXES = SOURCE_SUFFIXES + (".html", ".astro", ".md", ".mdx")
STYLE_SUFFIXES = (".css", ".scss", ".sass", ".less")
TOOLING = {".eslintrc.js", ".eslintrc.cjs", "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
           "babel.config.js", "babel.config.cjs", "commitlint.config.js", "commitlint.config.cjs",
           "prettier.config.js", "prettier.config.mjs", ".prettierrc.js", "stylelint.config.js",
           "stylelint.config.mjs", "postcss.config.js", "postcss.config.cjs", "postcss.config.mjs"}
# Framework conventions: files used by the framework without an import. The text
# is a hint for usage_gap; the agent still reads the code and decides.
CONVENTIONS = {
    "nuxt": [
        ("app/pages/", "Nuxt file-based route: invoked by the router, not imported."),
        ("pages/", "Nuxt file-based route: invoked by the router, not imported."),
        ("app/layouts/", "Nuxt layout: applied by the framework."),
        ("layouts/", "Nuxt layout: applied by the framework."),
        ("app/plugins/", "Nuxt plugin: auto-registered at startup."),
        ("plugins/", "Nuxt plugin: auto-registered at startup."),
        ("app/middleware/", "Nuxt route middleware: auto-registered by the framework."),
        ("middleware/", "Nuxt route middleware: auto-registered by the framework."),
        ("server/api/", "Nitro API route: invoked over HTTP by path, not imported."),
        ("server/routes/", "Nitro route: invoked over HTTP by path, not imported."),
        ("server/middleware/", "Nitro server middleware: auto-registered for every request."),
        ("server/plugins/", "Nitro plugin: auto-registered at server startup."),
        ("app/app.vue", "Nuxt root component, mounted by the framework."),
        ("app.vue", "Nuxt root component, mounted by the framework."),
        ("app/error.vue", "Nuxt error page, rendered by the framework on errors."),
        ("error.vue", "Nuxt error page, rendered by the framework on errors."),
        ("app/app.config.ts", "Nuxt app config, read through useAppConfig."),
        ("app.config.ts", "Nuxt app config, read through useAppConfig."),
        ("app/router.options.ts", "Nuxt router options, loaded by the framework."),
        ("nuxt.config.ts", "Nuxt configuration loaded by the framework."),
        ("content.config.ts", "Nuxt Content configuration loaded by the module."),
    ],
    "vue-cli": [
        ("src/main.ts", "Application entry point loaded by the Vue CLI build."),
        ("src/main.js", "Application entry point loaded by the Vue CLI build."),
        ("vue.config.js", "Vue CLI build configuration loaded by vue-cli-service."),
    ],
    "vite": [
        ("src/main.ts", "Application entry point referenced by index.html."),
        ("src/main.js", "Application entry point referenced by index.html."),
        ("vite.config.ts", "Vite configuration loaded by the build tool."),
        ("vite.config.js", "Vite configuration loaded by the build tool."),
        ("vite.config.mjs", "Vite configuration loaded by the build tool."),
    ],
    "next": [
        ("app/", "Next.js App Router file: invoked by the framework by path."),
        ("pages/", "Next.js Pages Router file: invoked by the framework by path."),
        ("src/app/", "Next.js App Router file: invoked by the framework by path."),
        ("src/pages/", "Next.js Pages Router file: invoked by the framework by path."),
        ("middleware.ts", "Next.js middleware: invoked by the framework for matching requests."),
        ("next.config.js", "Next.js configuration loaded by the framework."),
        ("next.config.mjs", "Next.js configuration loaded by the framework."),
        ("next.config.ts", "Next.js configuration loaded by the framework."),
    ],
}
MARKERS = {
    "nuxt": ("nuxt.config.ts", "nuxt.config.js", "nuxt.config.mjs"),
    "vue-cli": ("vue.config.js",),
    "vite": ("vite.config.ts", "vite.config.js", "vite.config.mjs"),
    "next": ("next.config.js", "next.config.mjs", "next.config.ts"),
}
GENERIC = [
    ("scripts/", "CLI script run from package.json scripts, hooks or CI."),
    ("rollup.config.mjs", "Rollup build configuration run by the Rollup CLI."),
    ("rollup.config.js", "Rollup build configuration run by the Rollup CLI."),
]
EXPORT = re.compile(r"\s*export\s+(?:default\s+)?(?:declare\s+)?(?:abstract\s+)?(?:async\s+)?"
                    r"(?:function\*?|const|let|var|interface|type|class|enum)\s+([A-Za-z_$][\w$]*)")
EXPORT_LIST = re.compile(r"\s*export\s*(?:type\s*)?\{([^}]*)\}")
MAX_USAGES = 3
LONG_LINE = 2000


def frameworks(paths):
    return [name for name, markers in MARKERS.items() if any(marker in paths for marker in markers)]


def convention(path, detected):
    for name in detected:
        for prefix, why in CONVENTIONS[name]:
            if path == prefix or (prefix.endswith("/") and path.startswith(prefix)):
                return why
    for prefix, why in GENERIC:
        if path == prefix or (prefix.endswith("/") and path.startswith(prefix)):
            return why
    if path.endswith(".d.ts"):
        return "Ambient type declaration applied by TypeScript without an import."
    return None


def read_objects(repo, objects):
    """Read blob contents by object id with one git process; returns {path: text}."""
    if not objects:
        return {}
    paths = list(objects)
    request = "".join(f"{objects[path]}\n" for path in paths).encode()
    output = subprocess.run(["git", "-C", str(repo), "cat-file", "--batch"], input=request,
                            capture_output=True, check=True).stdout
    texts, offset = {}, 0
    for path in paths:
        header_end = output.index(b"\n", offset)
        header = output[offset:header_end].split()
        size = int(header[2])
        body = output[header_end + 1:header_end + 1 + size]
        offset = header_end + 1 + size + 1
        try:
            texts[path] = body.decode("utf-8-sig")
        except UnicodeDecodeError:
            continue
    return texts


def kebab(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()


def exports(lines):
    names = []
    for line in lines:
        match = EXPORT.match(line)
        if match:
            names.append(match.group(1))
        match = EXPORT_LIST.match(line)
        if match:
            names += [part.strip().split(" as ")[-1].strip() for part in match.group(1).split(",") if part.strip()]
    return [name for name in dict.fromkeys(names) if re.fullmatch(r"[A-Za-z_$][\w$]*", name)]


def module_pattern(stem):
    return re.compile(r"(?:from\s+|import\s*\(\s*|require\s*\(\s*|import\s+|src=|href=|@import\s+|@use\s+)"
                      r"['\"][^'\"]*?(?<![\w.-])_?" + re.escape(stem) + r"(?:\.[A-Za-z]+)?['\"]")


def patterns(path, lines):
    base = PurePosixPath(path).name
    stem = base.split(".")[0]
    if path.endswith((".vue", ".svelte")):
        return [stem], [re.compile(r"<" + re.escape(stem) + r"(?:[\s>/]|$)"),
                        re.compile(r"<" + re.escape(kebab(stem)) + r"(?:[\s>/]|$)"), module_pattern(stem)]
    if path.endswith(STYLE_SUFFIXES):
        return [], [module_pattern(stem.lstrip("_"))]
    names = exports(lines)
    specific = [re.compile(r"\b" + re.escape(name) + r"\b") for name in names if len(name) > 3]
    return names, [module_pattern(stem if stem != "index" else PurePosixPath(path).parent.name)] + specific


def find_usages(path, rules, texts):
    usages = []
    for other, text in texts.items():
        if other == path:
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if len(line) < LONG_LINE and any(rule.search(line) for rule in rules):
                usages.append({"path": other, "start": number, "end": number})
                break
        if len(usages) >= MAX_USAGES:
            break
    return usages


def ident(path):
    value = re.sub(r"[^a-z0-9]+", "-", os.path.splitext(path)[0].lower()).strip("-")
    return re.sub(r"^(src|app)-", "", value) or value


def build(repo, revision, files):
    """``files`` is the inventory snapshot: {path: {oid, mode, review}} without tests."""
    readable = {path: info["oid"] for path, info in files.items()
                if not (info.get("review") or {}).get("kind") == "protected"
                and path.endswith(CONSUMER_SUFFIXES)}
    texts = read_objects(repo, readable)
    detected = frameworks(set(files))
    entries, other = [], []
    for path in sorted(files):
        review = files[path].get("review") or {}
        if review.get("kind") == "protected":
            continue
        name = PurePosixPath(path).name
        if not path.endswith(SOURCE_SUFFIXES) or name in TOOLING or path not in texts:
            other.append(path)
            continue
        lines = texts[path].splitlines()
        names, rules = patterns(path, lines)
        hints = []
        if ".min." in name or any(len(line) >= LONG_LINE for line in lines):
            hints.append("long_lines_or_minified: verify whether it is generated before cataloguing")
        gap = convention(path, detected)
        usages = [] if gap else find_usages(path, rules, texts)
        entry = {"id": ident(path), "name": ", ".join(names) or PurePosixPath(path).stem, "source": path,
                 "exports": names, "usages": usages, "loc": len(lines)}
        if not usages:
            entry["usage_gap"] = gap or ("No non-test consumer found by searching tags, imports and export "
                                         "names across tracked sources.")
        if hints:
            entry["hints"] = hints
        entries.append(entry)
    # Same stem with different extensions (Button.vue + Button.css): implementation keeps the id,
    # companion stylesheets and later duplicates get the extension as suffix.
    seen = set()
    for entry in sorted(entries, key=lambda item: item["source"].endswith(STYLE_SUFFIXES)):
        if entry["id"] in seen:
            entry["id"] = f"{entry['id']}-{PurePosixPath(entry['source']).suffix.lstrip('.')}"
        seen.add(entry["id"])
    duplicates = {entry["id"] for entry in entries if sum(e["id"] == entry["id"] for e in entries) > 1}
    return {"schema": 1, "revision": revision, "frameworks": detected, "entries": entries,
            "other_paths": other, "duplicate_ids": sorted(duplicates),
            "note": "Evidence for curation only. Read each source and consumer, write contracts and constraints, "
                    "then classify every path with review batches. Usage lines are first matches, not ranges."}
