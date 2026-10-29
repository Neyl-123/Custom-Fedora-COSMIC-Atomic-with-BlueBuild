#!/usr/bin/env python3
import os
import hashlib
import json
import sys

STATE_FILE = '.build_state.json'
IGNORE = {'.build_state.json', 'build.log', 'build.sh', '.git', 'files/etc/image-description'}

def get_hashes():
    hashes = {}
    for root, dirs, files in os.walk('.'):
        # Modify dirs in-place to skip hidden directories and ignored ones
        dirs[:] = [d for d in dirs if d not in IGNORE and not d.startswith('.')]
        for f in files:
            if f in IGNORE:
                continue
            path = os.path.join(root, f)
            # Normalize path for ignored files check
            norm_path = os.path.normpath(path)
            if norm_path in IGNORE:
                continue
                
            try:
                with open(path, 'rb') as file:
                    hashes[norm_path] = hashlib.md5(file.read()).hexdigest()
            except Exception:
                pass
    return hashes

def main():
    current = get_hashes()
    previous = {}
    
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f:
                previous = json.load(f)
        except Exception:
            pass

    added = [p for p in current if p not in previous]
    modified = [p for p in current if p in previous and current[p] != previous[p]]
    removed = [p for p in previous if p not in current]

    with open(STATE_FILE, 'w') as f:
        json.dump(current, f)

    changes = []
    
    # Process additions
    if added:
        if len(added) <= 2:
            changes.append(f"Added {', '.join([os.path.basename(p) for p in added])}")
        else:
            changes.append(f"Added {len(added)} files")
            
    # Process modifications
    if modified:
        if len(modified) <= 2:
            changes.append(f"Modified {', '.join([os.path.basename(p) for p in modified])}")
        else:
            changes.append(f"Modified {len(modified)} files")
            
    # Process removals
    if removed:
        if len(removed) <= 2:
            changes.append(f"Removed {', '.join([os.path.basename(p) for p in removed])}")
        else:
            changes.append(f"Removed {len(removed)} files")

    if not changes:
        print("Routine system update")
    else:
        print("; ".join(changes))

if __name__ == "__main__":
    main()
