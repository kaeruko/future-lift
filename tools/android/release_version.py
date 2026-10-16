#!/usr/bin/env python3
"""Plan or persist a one-step Android build-number bump.

The bump is persisted *only after* the caller has successfully built and
verified a signed AAB. Never updates pubspec on a failed build.
"""
import argparse
import json
from pathlib import Path
import re

VERSION_RE = re.compile(r"(?m)^version:[ \t]*([0-9]+\.[0-9]+\.[0-9]+)\+([1-9][0-9]*)[ \t]*$")


def read_version(path):
    source = path.read_text(encoding="utf-8")
    matches = list(VERSION_RE.finditer(source))
    version_lines = re.findall(r"(?m)^version:", source)
    if len(matches) != 1 or len(version_lines) != 1:
        raise ValueError("pubspec.yaml requires one version: MAJOR.MINOR.PATCH+BUILD line")
    name, number = matches[0].groups()
    build = int(number)
    if build >= 2_100_000_000:
        raise ValueError("Android versionCode cannot be incremented safely")
    return source, matches[0], name, build


def plan(path):
    _source, _match, name, build = read_version(path)
    return {"build_name": name, "source_version": f"{name}+{build}",
            "next_build_number": build + 1}


def persist(path, expected_version, next_build_number):
    source, match, name, build = read_version(path)
    expected = f"{name}+{build}"
    if expected != expected_version:
        raise ValueError(f"Version changed during build: expected {expected_version}, found {expected}")
    if build + 1 != next_build_number:
        raise ValueError(f"Next build number must be {build + 1}, received {next_build_number}")
    replacement = f"version: {name}+{next_build_number}"
    updated = source[:match.start()] + replacement + source[match.end():]
    path.write_text(updated, encoding="utf-8", newline="")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("plan")
    p.add_argument("--format", choices=("json", "github-env"), default="json")
    p = sub.add_parser("persist")
    p.add_argument("--expected-version", required=True)
    p.add_argument("--next-build-number", required=True, type=int)
    args = parser.parse_args()
    if args.command == "plan":
        values = plan(args.pubspec)
        if args.format == "github-env":
            print("BUILD_NAME=" + values["build_name"])
            print("SOURCE_VERSION=" + values["source_version"])
            print("NEXT_BUILD_NUMBER=" + str(values["next_build_number"]))
        else:
            print(json.dumps(values))
    else:
        persist(args.pubspec, args.expected_version, args.next_build_number)
        print(f"Updated {args.pubspec}: {args.expected_version} -> "
              f"{args.expected_version.split('+')[0]}+{args.next_build_number}")


if __name__ == "__main__":
    main()
