#!/usr/bin/env python3
"""Verify the repo-managed Pi and Antigravity environment without exposing secrets."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]


class Verifier:
    def __init__(self, *, no_external: bool = False, strict_credentials: bool = False):
        self.no_external = no_external
        self.strict_credentials = strict_credentials
        self.failures = 0
        self.warnings = 0

    def result(self, label: str, ok: bool, detail: str = "", *, warning: bool = False) -> None:
        if ok:
            print(f"PASS {label}" + (f" ({detail})" if detail else ""))
        elif warning:
            self.warnings += 1
            print(f"WARN {label}" + (f" ({detail})" if detail else ""))
        else:
            self.failures += 1
            print(f"FAIL {label}" + (f" ({detail})" if detail else ""))

    @staticmethod
    def command(argv: list[str], timeout: int = 20) -> subprocess.CompletedProcess[str] | None:
        try:
            return subprocess.run(argv, text=True, capture_output=True, timeout=timeout, check=False)
        except (OSError, subprocess.TimeoutExpired):
            return None

    @staticmethod
    def version(text: str) -> tuple[int, ...] | None:
        match = re.search(r"(?<!\d)(\d+)\.(\d+)(?:\.(\d+))?", text)
        if not match:
            return None
        return tuple(int(part or 0) for part in match.groups())

    def check_program(self, name: str, minimum: tuple[int, ...] | None = None, flag: str = "--version") -> None:
        resolved = shutil.which(name)
        if not resolved:
            self.result(f"{name} available", False, "not found on PATH")
            return
        if minimum is None:
            self.result(f"{name} available", True)
            return
        result = self.command([name, flag])
        output = "" if result is None else (result.stdout + "\n" + result.stderr)
        got = self.version(output)
        floor_text = ".".join(map(str, minimum))
        self.result(
            f"{name} version >= {floor_text}",
            bool(result and result.returncode == 0 and got is not None and got >= minimum),
            ".".join(map(str, got)) if got else "version unavailable",
        )

    def load_json(self, path: Path, label: str, *, required: bool = True) -> Any | None:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(value, dict):
                raise ValueError("expected JSON object")
            return value
        except FileNotFoundError:
            self.result(label, False, "missing") if required else None
        except (OSError, ValueError):
            self.result(label, False, "unreadable, invalid JSON, or wrong JSON shape")
        return None

    def check_equal_file(self, source: Path, target: Path, label: str) -> None:
        try:
            ok = source.read_bytes() == target.read_bytes()
        except OSError:
            ok = False
        self.result(label, ok)

    def check_link(self, source: Path, target: Path, label: str) -> bool:
        try:
            ok = target.is_symlink() and target.resolve(strict=True) == source.resolve(strict=True)
        except (OSError, RuntimeError):
            ok = False
        self.result(label, ok)
        return ok

    def check_secret_file(self, path: Path, label: str, *, required: bool) -> bool:
        try:
            info = path.stat()
        except OSError:
            self.result(label, False, "not configured", warning=not required)
            return False
        mode = stat.S_IMODE(info.st_mode)
        owner_ok = info.st_uid == os.getuid()
        permission_ok = stat.S_ISREG(info.st_mode) and owner_ok and (mode & 0o400) != 0 and (mode & 0o077) == 0
        if not permission_ok:
            self.result(label, False, "must be a regular owner-owned file with mode 0600 or stricter")
            return False
        self.result(label, True, f"owner-only mode {mode:04o}")
        return True

    def check_credentials(self, pi_secret_link: Path, mcp_config: dict[str, Any] | None) -> None:
        default_key = Path.home() / ".config/typesafe/jev_api_key"
        env_key = bool(os.environ.get("TYPESAFE_API_KEY", "").strip())
        env_key_file = os.environ.get("TYPESAFE_API_KEY_FILE", "").strip()
        mcp_servers = (mcp_config or {}).get("mcpServers") or {}
        mcp_server = (mcp_servers.get("pi-sandbox-jev") or {}) if isinstance(mcp_servers, dict) else {}
        mcp_env = mcp_server.get("env") or {} if isinstance(mcp_server, dict) else {}
        if not isinstance(mcp_env, dict):
            mcp_env = {}
        configured_key_file = env_key_file or mcp_env.get("TYPESAFE_API_KEY_FILE") or str(default_key)
        configured_key = env_key or bool(mcp_env.get("TYPESAFE_API_KEY"))

        pi_link_ok = False
        if pi_secret_link.is_symlink():
            try:
                pi_link_ok = pi_secret_link.resolve(strict=True) == default_key.resolve(strict=True)
            except (OSError, RuntimeError):
                pi_link_ok = False
        if default_key.exists():
            self.result("Pi Jev secret link targets the shared key file", pi_link_ok)
            self.check_secret_file(default_key, "shared TypeSafe key file", required=self.strict_credentials)
        elif env_key:
            self.result("Pi Jev credentials available", True, "environment variable set; value not displayed")
        else:
            self.result("Pi Jev credentials available", False, "manual setup required; key value is never read", warning=not self.strict_credentials)

        if configured_key:
            self.result("AGY Jev credentials available", True, "configured; value not displayed")
        else:
            self.check_secret_file(Path(configured_key_file).expanduser(), "AGY TypeSafe key file", required=self.strict_credentials)

    def check_external_skills(self) -> None:
        if self.no_external:
            self.result("pinned external skill checks", True, "skipped by --no-external")
            return
        lock = REPO_ROOT / "tools/skills.lock"
        try:
            lines = lock.read_text(encoding="utf-8").splitlines()
        except OSError:
            self.result("external skill lock file", False, "missing")
            return

        checked_repos: set[tuple[str, str, str]] = set()
        for line in lines:
            if not line or line.startswith("#"):
                continue
            fields = line.split("\t")
            if len(fields) != 7:
                self.result("external skill lock format", False, "expected seven tab-separated fields")
                return
            name, url, commit, clone_rel, source_subdir, pi_link, agy_link = fields
            clone_dir = Path(clone_rel).expanduser()
            if os.environ.get("PI_SANDBOX_SKILLS_ROOT"):
                clone_dir = Path(os.environ["PI_SANDBOX_SKILLS_ROOT"]).expanduser() / clone_dir.name
            repo_key = (str(clone_dir), url, commit)
            if repo_key not in checked_repos:
                checked_repos.add(repo_key)
                git = self.command(["git", "-C", str(clone_dir), "rev-parse", "HEAD"])
                origin = self.command(["git", "-C", str(clone_dir), "remote", "get-url", "origin"])
                dirty = self.command(["git", "-C", str(clone_dir), "status", "--porcelain"])
                repo_ok = bool(
                    git and git.returncode == 0 and git.stdout.strip() == commit
                    and origin and origin.returncode == 0 and origin.stdout.strip() == url
                    and dirty and dirty.returncode == 0 and not dirty.stdout.strip()
                )
                self.result(f"external repository pinned: {name}", repo_ok)
            source = clone_dir if source_subdir == "." else clone_dir / source_subdir
            if not (source / "SKILL.md").is_file():
                self.result(f"external skill source: {name}", False, "SKILL.md missing")
                continue
            if pi_link != "-":
                self.check_link(source, Path.home() / ".pi/agent/skills" / pi_link, f"Pi external skill link: {name}")
            if agy_link != "-":
                legacy = Path.home() / ".gemini/skills" / agy_link
                canonical = Path.home() / ".gemini/config/skills" / agy_link
                legacy_ok = legacy.is_symlink() and self._link_resolves(legacy, source)
                if legacy_ok:
                    self.result(f"AGY external skill link: {name}", True)
                else:
                    self.check_link(source, canonical, f"AGY external skill link: {name}")

    @staticmethod
    def _link_resolves(target: Path, source: Path) -> bool:
        try:
            return target.resolve(strict=True) == source.resolve(strict=True)
        except (OSError, RuntimeError):
            return False

    def run(self) -> int:
        home = Path.home()
        pi_dir = home / ".pi/agent"
        agy_state = home / ".gemini/antigravity-cli"
        agy_config_dir = home / ".gemini/config"
        pi_secret = pi_dir / "secrets/typesafe_api_key"

        print("== prerequisites ==")
        self.check_program("pi", (1, 3, 0))
        self.check_program("agy", (1, 4, 0))
        self.check_program("node", (20, 0, 0))
        for program in ("npm", "git", "rsync", "python3"):
            self.check_program(program)

        print("== Pi ==")
        pi_settings = self.load_json(pi_dir / "settings.json", "Pi settings JSON") or {}
        expected_pi = {
            "defaultProvider": "openrouter",
            "defaultModel": "cohere/north-mini-code:free",
            "defaultThinkingLevel": "high",
            "defaultProjectTrust": "ask",
        }
        for key, value in expected_pi.items():
            self.result(f"Pi setting {key}", pi_settings.get(key) == value)
        project_settings = self.load_json(REPO_ROOT / ".pi/settings.json", "repo project settings JSON") or {}
        self.result("repo project default model", project_settings.get("defaultProvider") == "openrouter" and project_settings.get("defaultModel") == "cohere/north-mini-code:free")
        packages = pi_settings.get("packages", [])
        package_items = packages if isinstance(packages, list) else []
        package_present = any(
            item == "npm:pi-jev" or (isinstance(item, dict) and item.get("source") == "npm:pi-jev")
            for item in package_items
        )
        self.result("Pi pi-jev package declared", package_present)
        package_manifest = pi_dir / "npm/node_modules/pi-jev/package.json"
        installed_package = None
        try:
            installed_package = json.loads(package_manifest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            pass
        self.result("Pi pi-jev package installed", isinstance(installed_package, dict) and installed_package.get("name") == "pi-jev")
        pi_sources = {
            "AGENT.md": REPO_ROOT / "config/pi/AGENT.md",
            "keybindings.json": REPO_ROOT / "config/pi/keybindings.json",
            "extensions/delete-guard.ts": REPO_ROOT / "config/pi/extensions/delete-guard.ts",
            "extensions/session-snapshot.ts": REPO_ROOT / "config/pi/extensions/session-snapshot.ts",
            "extensions/popular-models.ts": REPO_ROOT / "tools/popular-models/popular-models.ts",
        }
        for relative, source in pi_sources.items():
            self.check_equal_file(source, pi_dir / relative, f"Pi managed file: {relative}")
        self.check_equal_file(REPO_ROOT / "tools/pi-snap", pi_dir / "bin/pi-snap", "Pi pi-snap executable source")
        bashrc = home / ".bashrc"
        jev_auto = False
        try:
            jev_auto = "export PI_JEV_AUTO=1" in bashrc.read_text(encoding="utf-8")
        except OSError:
            pass
        self.result("Pi automatic Jev routing configured", jev_auto)
        for skill in ("catch-up-project", "grill-me"):
            self.check_link(REPO_ROOT / "skills/common" / skill, pi_dir / "skills" / skill, f"Pi common skill: {skill}")
        pi_snap = self.command([str(pi_dir / "bin/pi-snap"), "help"])
        self.result("pi-snap command works", bool(pi_snap and pi_snap.returncode == 0))

        print("== Antigravity ==")
        agy_settings = self.load_json(agy_state / "settings.json", "AGY CLI settings JSON") or {}
        self.result("AGY editor mode", agy_settings.get("editor") == "vim")
        self.result("AGY dark color scheme", agy_settings.get("colorScheme") == "dark")
        self.result("AGY notifications enabled", agy_settings.get("notifications") is True)
        status_line = agy_settings.get("statusLine") or {}
        self.result("AGY status line enabled", isinstance(status_line, dict) and status_line.get("enabled") is True)
        permissions = agy_settings.get("permissions") or {}
        allow = permissions.get("allow", []) if isinstance(permissions, dict) else []
        for tool in ("jev_evaluate", "jev_gate"):
            self.result(f"AGY MCP permission: {tool}", isinstance(allow, list) and f"mcp(pi-sandbox-jev/{tool})" in allow)

        keybindings = self.load_json(agy_state / "keybindings.json", "AGY keybindings JSON") or {}
        required_bindings = {
            "prompt.insert_newline": ["shift+enter", "ctrl+j"],
            "vim.insert.submit": ["enter", "ctrl+s"],
            "item.rename": ["f2"],
            "item.delete": ["f4"],
        }
        for key, values in required_bindings.items():
            found = keybindings.get(key, [])
            self.result(f"AGY keybinding {key}", all(value in found for value in values) if isinstance(found, list) else False)

        plugins_json = self.load_json(agy_config_dir / "plugins.json", "AGY plugins.json") or {}
        entries = plugins_json.get("entries", [])
        plugin_discoverable = any(isinstance(item, dict) and item.get("path") == "plugins" for item in entries)
        self.result("AGY plugin discovery configured", plugin_discoverable)
        config_json = self.load_json(agy_config_dir / "config.json", "AGY config.json") or {}
        plugin_states = config_json.get("plugins") or {}
        plugin_state = (plugin_states.get("pi-sandbox-jev") or {}) if isinstance(plugin_states, dict) else {}
        self.result("AGY Jev plugin enabled", isinstance(plugin_state, dict) and plugin_state.get("enabled") is True)
        plugin_source = REPO_ROOT / "config/agy/plugin/pi-sandbox-jev"
        self.check_link(plugin_source, agy_config_dir / "plugins/pi-sandbox-jev", "AGY Jev plugin source link")
        self.result("AGY plugin hooks present", (plugin_source / "hooks.json").is_file() and (plugin_source / "hooks/session-start.sh").is_file() and (plugin_source / "hooks/pre-invocation.sh").is_file())
        self.result("AGY plugin rule and skill present", (plugin_source / "rules/AGENTS.md").is_file() and (plugin_source / "skills/jev-development/SKILL.md").is_file())

        mcp_config = self.load_json(agy_config_dir / "mcp_config.json", "AGY MCP config JSON", required=False) or {}
        servers = mcp_config.get("mcpServers") or {}
        server = servers.get("pi-sandbox-jev") or {} if isinstance(servers, dict) else {}
        server_args = server.get("args", []) if isinstance(server, dict) else []
        expected_entry = str(REPO_ROOT / "tools/antigravity/jev-mcp/dist/index.js")
        mcp_registered = isinstance(server, dict) and server.get("command") == "node" and isinstance(server_args, list) and expected_entry in server_args and server.get("disabled") is not True
        self.result("AGY Jev MCP registration configured", mcp_registered)
        mcp_list = self.command(["agy", "mcp", "list"])
        mcp_enabled = False
        if mcp_list and mcp_list.returncode == 0:
            for line in mcp_list.stdout.splitlines():
                columns = line.split()
                if columns and columns[0] == "pi-sandbox-jev":
                    mcp_enabled = len(columns) >= 3 and columns[2] == "enabled"
                    break
        self.result("AGY Jev MCP server enabled", mcp_enabled)
        self.result("AGY MCP adapter built", (REPO_ROOT / "tools/antigravity/jev-mcp/dist/index.js").is_file())
        for skill in ("catch-up-project", "grill-me"):
            self.check_link(REPO_ROOT / "skills/common" / skill, agy_config_dir / "skills" / skill, f"AGY common skill: {skill}")

        mcp_config_arg = mcp_config if isinstance(mcp_config, dict) else {}
        self.check_credentials(pi_secret, mcp_config_arg)

        print("== third-party skills ==")
        self.check_external_skills()

        print("== component drift checks ==")
        component_checks = [
            ["bash", str(REPO_ROOT / "tools/install/install-pi.sh"), "--check"],
            ["bash", str(REPO_ROOT / "tools/install/install-agy.sh"), "--check"],
            ["bash", str(REPO_ROOT / "tools/install/install-skills.sh"), "--check"],
        ]
        if self.no_external:
            component_checks[-1].append("--no-external")
        for command in component_checks:
            result = self.command(command, timeout=60)
            label = Path(command[1]).name
            self.result(f"{label} --check", bool(result and result.returncode == 0), "see component installer for details" if not result or result.returncode else "")

        print("== summary ==")
        print(f"{self.failures} failure(s), {self.warnings} warning(s)")
        print("INFO Live Jev API calls were not made by this verifier.")
        return 1 if self.failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-external", action="store_true", help="skip third-party skill clone/link checks")
    parser.add_argument("--strict-credentials", action="store_true", help="fail if a protected TypeSafe credential is not configured")
    args = parser.parse_args()
    return Verifier(no_external=args.no_external, strict_credentials=args.strict_credentials).run()


if __name__ == "__main__":
    raise SystemExit(main())
