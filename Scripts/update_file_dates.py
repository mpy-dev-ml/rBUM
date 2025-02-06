#!/usr/bin/env python3
"""
First created: 6 February 2025
Last updated: 6 February 2025
Update count: 1 (disabled until release)

Script to update file headers with creation and update dates.
Counter functionality is disabled during core development.
"""

import os
import datetime
import re
from pathlib import Path

CREATION_DATE = "6 February 2025"
CURRENT_DATE = datetime.datetime.now().strftime("%-d %B %Y")
COUNTER_ENABLED = False  # Will be enabled upon first release

def get_update_count(content):
    """Extract existing update count or return 1 for new files."""
    if not COUNTER_ENABLED:
        return None
        
    match = re.search(r"Update count: (\d+)", content)
    return int(match.group(1)) + 1 if match else 1

def update_swift_file(content, file_path):
    header_pattern = r"//\n//.*?\n//.*?\n//\n"
    counter_str = f"//  Update count: {get_update_count(content)}\n" if COUNTER_ENABLED else ""
    new_header = f"""//
//  {file_path.name}
//  rBUM
//
//  First created: {CREATION_DATE}
//  Last updated: {CURRENT_DATE}
{counter_str}//
"""
    if re.match(header_pattern, content):
        return re.sub(header_pattern, new_header, content)
    return new_header + content

def update_markdown_file(content, file_path):
    # Keep existing title and description
    lines = content.split('\n')
    title_end = 0
    for i, line in enumerate(lines):
        if line.startswith('# '):
            title_end = i + 1
            break
    
    # Find description (non-empty lines after title)
    desc_end = title_end
    for i in range(title_end, len(lines)):
        if lines[i].strip() and not lines[i].startswith('First created:'):
            desc_end = i + 1
        elif not lines[i].strip():
            continue
        else:
            break
    
    header = '\n'.join(lines[:desc_end])
    if header:
        header += '\n\n'
    
    counter_str = f"Update count: {get_update_count(content)}\n" if COUNTER_ENABLED else ""
    date_section = f"First created: {CREATION_DATE}\nLast updated: {CURRENT_DATE}\n{counter_str}\n"
    
    # Remove existing dates and counter if present
    content = re.sub(r"First created:.*?\n.*?Last updated:.*?\n(Update count:.*?\n)?\n?", "", content)
    
    # Find the first section header
    match = re.search(r"\n##\s+", content[len(header):])
    if match:
        insert_pos = len(header) + match.start()
        return content[:insert_pos] + date_section + content[insert_pos:]
    
    return header + date_section + content[len(header):]

def process_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if file_path.suffix == '.swift':
        new_content = update_swift_file(content, file_path)
    elif file_path.suffix == '.md':
        new_content = update_markdown_file(content, file_path)
    else:
        return
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

def main():
    if COUNTER_ENABLED:
        print("Warning: Update counter is enabled. This should only be true for release.")
    else:
        print("Note: Update counter is disabled during core development.")
    
    project_root = Path("/Users/mpy/CascadeProjects/rBUM")
    
    # Process all Swift and Markdown files
    for ext in ['.swift', '.md']:
        for file_path in project_root.rglob(f"*{ext}"):
            # Skip build directories and external dependencies
            if any(part.startswith('.') or part in ['build', 'Pods', 'Carthage'] 
                  for part in file_path.parts):
                continue
            process_file(file_path)

if __name__ == "__main__":
    main()
