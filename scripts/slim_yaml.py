#!/usr/bin/env python3
"""
YAML Slimming Utility

Removes completed/archived items from YAML queue files to maintain performance.
- For Karo: Archives completed task/report files and finished command queue entries.
- For all agents: Archives read: true messages from inbox files.
"""

import os
import sys
import time
from datetime import datetime
from pathlib import Path

import re

import yaml

CANONICAL_TASKS = {f'ashigaru{i}' for i in range(1, 9)} | {'gunshi'}
CANONICAL_REPORTS = {f'ashigaru{i}_report' for i in range(1, 9)} | {'gunshi_report'}
IDLE_STUB = {'task': {'status': 'idle'}}

# Statuses considered "finished" for archiving purposes
DONE_STATUSES = {'done', 'cancelled', 'completed', 'complete', 'obsolete'}


def sanitize_yaml_text(text):
    """Fix common YAML issues: unquoted strings containing colons."""
    lines = text.split('\n')
    fixed = []
    for line in lines:
        stripped = line.lstrip()
        indent = line[:len(line) - len(stripped)]
        # Fix list items like: - チェック内容: "Application error"...
        # These have a colon after non-key text in a list item value
        if stripped.startswith('- ') and ':' in stripped[2:]:
            prefix = '- '
            value = stripped[2:]
            # If it looks like a key: value pair (key has no spaces before colon), leave it
            # Otherwise it's a value that contains a colon and needs quoting
            colon_pos = value.find(':')
            before_colon = value[:colon_pos]
            # Real YAML keys don't contain spaces before the colon (usually)
            # But acceptance_criteria items often have Japanese text with colons
            if ' ' in before_colon and not value.startswith("'") and not value.startswith('"'):
                # Quote the entire value
                escaped = value.replace("'", "''")
                fixed.append(f"{indent}- '{escaped}'")
                continue
        fixed.append(line)
    return '\n'.join(fixed)


def load_yaml(filepath):
    """Safely load YAML file, with sanitization fallback for malformed files."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            text = f.read()
    except FileNotFoundError:
        return {}

    # Try normal parse first
    try:
        return yaml.safe_load(text) or {}
    except yaml.YAMLError:
        pass

    # Try with sanitization
    try:
        sanitized = sanitize_yaml_text(text)
        return yaml.safe_load(sanitized) or {}
    except yaml.YAMLError as e:
        print(f"Error parsing {filepath} (even after sanitization): {e}", file=sys.stderr)
        return {}


def save_yaml(filepath, data):
    """Safely save YAML file."""
    try:
        with open(filepath, 'w', encoding='utf-8') as f:
            yaml.dump(data, f, allow_unicode=True, sort_keys=False, default_flow_style=False)
        return True
    except Exception as e:
        print(f"Error writing {filepath}: {e}", file=sys.stderr)
        return False


def get_timestamp():
    """Generate archive filename timestamp."""
    return datetime.now().strftime('%Y%m%d%H%M%S')


def get_queue_dir():
    return Path(__file__).resolve().parent.parent / 'queue'


def get_active_cmd_ids():
    """Return command IDs in shogun_to_karo that are not done.

    Uses text-based parsing to handle malformed YAML.
    """
    queue_dir = get_queue_dir()
    shogun_file = queue_dir / 'shogun_to_karo.yaml'

    try:
        with open(shogun_file, 'r', encoding='utf-8') as f:
            text = f.read()
    except FileNotFoundError:
        return set()

    _, blocks = _split_commands_by_text(text)
    active = set()
    for _, cmd_id, status in blocks:
        if status not in DONE_STATUSES:
            active.add(cmd_id)
    return active


def ensure_parent_dir(path):
    path.parent.mkdir(parents=True, exist_ok=True)


def archive_taskspec(filepath, archive_path, data, dry_run=False):
    if dry_run:
        print(f"[DRY-RUN] would archive: {filepath}")
        print(f"[DRY-RUN] would write: {archive_path}")
        return True

    ensure_parent_dir(archive_path)
    if not save_yaml(archive_path, data):
        return False

    if filepath.name in archive_path.name:
        return True
    return filepath.rename(archive_path)


def slim_tasks(dry_run=False):
    queue_dir = get_queue_dir()
    tasks_dir = queue_dir / 'tasks'
    archive_dir = queue_dir / 'archive' / 'tasks'

    if not tasks_dir.exists():
        return True

    timestamp = get_timestamp()
    done_statuses = DONE_STATUSES

    for filepath in sorted(tasks_dir.glob('*.yaml')):
        data = load_yaml(filepath)
        if not isinstance(data, dict):
            continue

        task = data.get('task', {}) if isinstance(data.get('task', {}), dict) else {}
        status = task.get('status', '') if isinstance(task, dict) else ''
        if not status:
            continue

        stem = filepath.stem
        if stem in CANONICAL_TASKS:
            if status not in done_statuses:
                continue

            archive_path = archive_dir / f'{stem}_{timestamp}.yaml'
            if not archive_taskspec(filepath, archive_path, data, dry_run=dry_run):
                return False

            if dry_run:
                print(f"[DRY-RUN] would overwrite: {filepath} with {IDLE_STUB}")
                continue

            if not save_yaml(filepath, IDLE_STUB):
                return False
            continue

        if status not in DONE_STATUSES:
            continue

        archive_path = archive_dir / filepath.name
        if archive_path.exists():
            archive_path = archive_dir / f'{filepath.stem}_{timestamp}{filepath.suffix}'

        if dry_run:
            print(f"[DRY-RUN] would archive: {filepath}")
            print(f"[DRY-RUN] would move to: {archive_path}")
            continue

        ensure_parent_dir(archive_path)
        filepath.rename(archive_path)

    return True


def slim_reports(dry_run=False):
    queue_dir = get_queue_dir()
    reports_dir = queue_dir / 'reports'
    archive_dir = queue_dir / 'archive' / 'reports'

    if not reports_dir.exists():
        return True

    active_cmd_ids = get_active_cmd_ids()
    timestamp = get_timestamp()

    for filepath in sorted(reports_dir.glob('*.yaml')):
        if filepath.stem in CANONICAL_REPORTS:
            continue

        data = load_yaml(filepath)
        parent_cmd = data.get('parent_cmd') if isinstance(data, dict) else None
        is_active = parent_cmd in active_cmd_ids
        is_stale = (time.time() - filepath.stat().st_mtime) >= 86400

        if not is_stale:
            continue
        if is_active:
            continue

        archive_path = archive_dir / filepath.name
        if archive_path.exists():
            archive_path = archive_dir / f'{filepath.stem}_{timestamp}{filepath.suffix}'

        if dry_run:
            print(f"[DRY-RUN] would archive: {filepath}")
            print(f"[DRY-RUN] would move to: {archive_path}")
            continue

        ensure_parent_dir(archive_path)
        filepath.rename(archive_path)

    return True


def slim_inbox(agent_id, dry_run=False):
    """Archive read: true messages from inbox file."""
    queue_dir = get_queue_dir()
    archive_dir = queue_dir / 'archive'
    inbox_file = queue_dir / 'inbox' / f'{agent_id}.yaml'

    if not inbox_file.exists():
        # Inbox doesn't exist yet - that's fine
        return True

    data = load_yaml(inbox_file)
    if not data or 'messages' not in data:
        return True

    messages = data.get('messages', [])
    if not isinstance(messages, list):
        print("Error: messages is not a list", file=sys.stderr)
        return False

    # Separate unread and archived messages
    unread = []
    archived = []

    for msg in messages:
        is_read = msg.get('read', False)
        if is_read:
            archived.append(msg)
        else:
            unread.append(msg)

    # If nothing to archive, return success without writing
    if not archived:
        return True

    archive_timestamp = get_timestamp()
    archive_file = archive_dir / f'inbox_{agent_id}_{archive_timestamp}.yaml'

    if dry_run:
        print(f"[DRY-RUN] would archive: {inbox_file}")
        print(f"[DRY-RUN] would move to: {archive_file}")
        return True

    # Write archived messages to timestamped file
    archive_data = {'messages': archived}
    if not save_yaml(archive_file, archive_data):
        return False

    # Update main file with unread messages only
    data['messages'] = unread
    if not save_yaml(inbox_file, data):
        print(f"Error: Failed to update {inbox_file}, but archive was created", file=sys.stderr)
        return False

    if archived:
        print(f"Archived {len(archived)} messages from {agent_id} to {archive_file.name}", file=sys.stderr)
    return True


def _split_commands_by_text(text):
    """Split shogun_to_karo.yaml into (header, cmd_blocks) using regex.

    This avoids yaml.safe_load which fails on malformed entries
    (unquoted colons, invalid escape sequences in double-quoted strings, etc.).
    Each cmd_block is a tuple of (raw_text, cmd_id, status).
    """
    # Find the start of each command entry: "- id: cmd_NNN" at 0 or 2-space indent
    pattern = re.compile(r'^- id:\s+(cmd_\d+)', re.MULTILINE)
    matches = list(pattern.finditer(text))

    if not matches:
        return text, []

    header = text[:matches[0].start()]
    blocks = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block_text = text[start:end]
        cmd_id = m.group(1)
        # Extract status from "  status: <value>" line within this block
        status_match = re.search(r'^\s{2}status:\s*(\S+)', block_text, re.MULTILINE)
        status = status_match.group(1).strip("'\"") if status_match else 'unknown'
        blocks.append((block_text, cmd_id, status))

    return header, blocks


def slim_shugun_to_karo(dry_run=False):
    """Archive completed/cancelled/obsolete commands from shogun_to_karo.yaml.

    Uses text-based splitting instead of yaml.safe_load because the file
    contains malformed YAML (unquoted colons, invalid escape sequences)
    that cannot be parsed by the standard YAML library.
    """
    queue_dir = get_queue_dir()
    archive_dir = queue_dir / 'archive'
    shogun_file = queue_dir / 'shogun_to_karo.yaml'

    if not shogun_file.exists():
        print(f"Warning: {shogun_file} not found", file=sys.stderr)
        return True

    try:
        with open(shogun_file, 'r', encoding='utf-8') as f:
            text = f.read()
    except Exception as e:
        print(f"Error reading {shogun_file}: {e}", file=sys.stderr)
        return False

    header, blocks = _split_commands_by_text(text)
    if not blocks:
        print("No command entries found in shogun_to_karo.yaml", file=sys.stderr)
        return True

    # Separate active and archived command blocks
    active_blocks = []
    archived_blocks = []

    for block_text, cmd_id, status in blocks:
        if status in DONE_STATUSES:
            archived_blocks.append((block_text, cmd_id, status))
        else:
            active_blocks.append((block_text, cmd_id, status))

    if not archived_blocks:
        print("No commands to archive.", file=sys.stderr)
        return True

    if dry_run:
        from collections import Counter
        status_counts = Counter(s for _, _, s in archived_blocks)
        print(f"[DRY-RUN] Would archive {len(archived_blocks)} commands (keeping {len(active_blocks)} active)", file=sys.stderr)
        for s, n in status_counts.most_common():
            print(f"  {s}: {n}", file=sys.stderr)
        return True

    # Write archived commands as raw text (preserving original formatting)
    archive_timestamp = get_timestamp()
    archive_file = archive_dir / f'shogun_to_karo_{archive_timestamp}.yaml'
    ensure_parent_dir(archive_file)

    archive_text = header + ''.join(bt for bt, _, _ in archived_blocks)
    try:
        with open(archive_file, 'w', encoding='utf-8') as f:
            f.write(archive_text)
    except Exception as e:
        print(f"Error writing archive {archive_file}: {e}", file=sys.stderr)
        return False

    # Write active commands back to main file
    active_text = header + ''.join(bt for bt, _, _ in active_blocks)
    try:
        with open(shogun_file, 'w', encoding='utf-8') as f:
            f.write(active_text)
    except Exception as e:
        print(f"Error writing {shogun_file}: {e}", file=sys.stderr)
        return False

    print(f"Archived {len(archived_blocks)} commands to {archive_file.name} (kept {len(active_blocks)} active)", file=sys.stderr)
    return True


def slim_all_inboxes(dry_run=False):
    queue_dir = get_queue_dir()
    inbox_dir = queue_dir / 'inbox'
    if not inbox_dir.exists():
        return True

    for filepath in sorted(inbox_dir.glob('*.yaml')):
        agent_id = filepath.stem
        if dry_run:
            print(f"[DRY-RUN] processing inbox file: {filepath}")
        if not slim_inbox(agent_id, dry_run=dry_run):
            return False
        if dry_run:
            print(f"[DRY-RUN] finished inbox file: {filepath}")

    return True


def migration(dry_run=False):
    queue_dir = get_queue_dir()
    legacy_archive_dir = queue_dir / 'reports' / 'archive'
    if not legacy_archive_dir.exists():
        return True

    target_dir = queue_dir / 'archive' / 'reports'
    candidates = sorted(legacy_archive_dir.glob('*.yaml'))
    if not candidates:
        if not dry_run:
            legacy_archive_dir.rmdir()
        return True

    if dry_run:
        print(f"[DRY-RUN] would migrate: {len(candidates)} files")
        return True

    target_dir.mkdir(parents=True, exist_ok=True)
    for path in candidates:
        dest = target_dir / path.name
        path.rename(dest)

    if not any(legacy_archive_dir.iterdir()):
        legacy_archive_dir.rmdir()

    return True


def parse_arguments():
    args = [arg for arg in sys.argv[1:] if arg != '--dry-run']
    dry_run = '--dry-run' in sys.argv[1:]
    if len(args) < 1:
        print("Usage: slim_yaml.py <agent_id> [--dry-run]", file=sys.stderr)
        sys.exit(1)

    return args[0], dry_run


def main():
    """Main entry point."""
    agent_id, dry_run = parse_arguments()

    # Ensure archive directory exists
    archive_dir = get_queue_dir() / 'archive'
    archive_dir.mkdir(parents=True, exist_ok=True)

    # Process shogun_to_karo if this is Karo
    if agent_id == 'karo':
        if not slim_shugun_to_karo(dry_run):
            sys.exit(1)
        migration(dry_run)
        if not slim_tasks(dry_run):
            sys.exit(1)
        if not slim_reports(dry_run):
            sys.exit(1)
        if not slim_all_inboxes(dry_run):
            sys.exit(1)

    # Process inbox for all agents
    if not slim_inbox(agent_id, dry_run):
        sys.exit(1)

    sys.exit(0)


if __name__ == '__main__':
    main()
