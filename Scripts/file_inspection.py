import os
import re

# Read file references from Xcode project
pbxproj_path = "/Users/mpy/CascadeProjects/rBUM/rBUM.xcodeproj/project.pbxproj"
referenced_files = set()

with open(pbxproj_path, "r") as f:
    for line in f:
        match = re.search(r'path = (.*);', line)
        if match:
            referenced_files.add(match.group(1))

# Get all source files on disk
source_files = set()
for root, _, files in os.walk("."):
    for file in files:
        if file.endswith((".swift", ".m", ".h", ".mm", ".cpp")):  # Adjust as needed
            relative_path = os.path.relpath(os.path.join(root, file), ".")
            source_files.add(relative_path)

# Find unreferenced files
unreferenced_files = source_files - referenced_files

print("\n".join(sorted(unreferenced_files)))
