# Makefile for rBUM Project Integrity Checks
# First created: 7 February 2025
# Last updated: 7 February 2025

.PHONY: check check_unreferenced check_build check_syntax check_project

# Directories to exclude from searches
EXCLUDE_DIRS := -not -path "*/\.*" -not -path "*/build/*" -not -path "*/DerivedData/*" -not -path "*/xcuserdata/*" -not -path "*/Pods/*"

# File types to check
SOURCE_FILES := -name "*.swift" -o -name "*.h" -o -name "*.m" -o -name "*.mm" -o -name "*.c" -o -name "*.cpp"

# Run all checks
check: check_unreferenced check_build check_syntax check_project

# Check for unreferenced source files
check_unreferenced:
	@echo "\n=== Checking for Unreferenced Files ===\n"
	@find . -type f \( $(SOURCE_FILES) \) $(EXCLUDE_DIRS) | sort > /tmp/all_files.txt
	@grep -oE 'path = .*\.swift;|path = .*\.h;|path = .*\.m;|path = .*\.mm;|path = .*\.c;|path = .*\.cpp;' \
		rBUM.xcodeproj/project.pbxproj | sed -E 's/path = (.*);/\1/' | sort > /tmp/referenced_files.txt
	@comm -23 /tmp/all_files.txt /tmp/referenced_files.txt || echo "All files are properly referenced"
	@rm -f /tmp/all_files.txt /tmp/referenced_files.txt

# Check if project builds
check_build:
	@echo "\n=== Checking Build Status ===\n"
	@xcodebuild -project rBUM.xcodeproj -scheme rBUM clean build \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
		| grep -E "error:|warning:" || echo "Build successful"

# Check Swift syntax
check_syntax:
	@echo "\n=== Checking Swift Syntax ===\n"
	@find . -name "*.swift" $(EXCLUDE_DIRS) -exec swift -syntax-check {} \; \
		|| echo "Syntax check failed"

# Check project structure
check_project:
	@echo "\n=== Checking Project Structure ===\n"
	@echo "Checking for required directories..."
	@test -d "Core/Sources" || echo "Missing Core/Sources directory"
	@test -d "rBUM" || echo "Missing rBUM directory"
	@test -d "rBUMTests" || echo "Missing rBUMTests directory"
	@test -d "rBUMUITests" || echo "Missing rBUMUITests directory"
	@test -d "ResticService" || echo "Missing ResticService directory"
	
	@echo "\nChecking for required project files..."
	@test -f "rBUM.xcodeproj/project.pbxproj" || echo "Missing project.pbxproj"
	@test -f ".swiftlint.yml" || echo "Missing .swiftlint.yml"
	
	@echo "\nChecking for build configurations..."
	@grep -q "Debug" rBUM.xcodeproj/project.pbxproj || echo "Missing Debug configuration"
	@grep -q "Release" rBUM.xcodeproj/project.pbxproj || echo "Missing Release configuration"

# Helper target to list all source files
list_sources:
	@echo "\n=== Listing All Source Files ===\n"
	@find . -type f \( $(SOURCE_FILES) \) $(EXCLUDE_DIRS) | sort

# Helper target to check specific target membership
check_target_membership:
	@echo "\n=== Checking Target Membership ===\n"
	@echo "Files in Core target:"
	@grep -A 1 "Core.*\.buildPhase" rBUM.xcodeproj/project.pbxproj | grep -oE 'path = .*\.swift;' | sed -E 's/path = (.*);/\1/'
	@echo "\nFiles in rBUM target:"
	@grep -A 1 "rBUM.*\.buildPhase" rBUM.xcodeproj/project.pbxproj | grep -oE 'path = .*\.swift;' | sed -E 's/path = (.*);/\1/'
	@echo "\nFiles in ResticService target:"
	@grep -A 1 "ResticService.*\.buildPhase" rBUM.xcodeproj/project.pbxproj | grep -oE 'path = .*\.swift;' | sed -E 's/path = (.*);/\1/'

# Helper target to suggest fixes for unreferenced files
suggest_fixes:
	@echo "\n=== Suggesting Fixes for Unreferenced Files ===\n"
	@echo "Core Framework Files:"
	@find ./Core -type f \( $(SOURCE_FILES) \) $(EXCLUDE_DIRS) | sort > /tmp/core_files.txt
	@grep -oE 'path = .*\.swift;|path = .*\.h;|path = .*\.m;|path = .*\.mm;|path = .*\.c;|path = .*\.cpp;' \
		rBUM.xcodeproj/project.pbxproj | grep "Core" | sed -E 's/path = (.*);/\1/' | sort > /tmp/core_referenced.txt
	@echo "Unreferenced Core files (add to Core target):"
	@comm -23 /tmp/core_files.txt /tmp/core_referenced.txt
	
	@echo "\nrBUM App Files:"
	@find ./rBUM -type f \( $(SOURCE_FILES) \) $(EXCLUDE_DIRS) | sort > /tmp/rbum_files.txt
	@grep -oE 'path = .*\.swift;|path = .*\.h;|path = .*\.m;|path = .*\.mm;|path = .*\.c;|path = .*\.cpp;' \
		rBUM.xcodeproj/project.pbxproj | grep "rBUM" | sed -E 's/path = (.*);/\1/' | sort > /tmp/rbum_referenced.txt
	@echo "Unreferenced rBUM files (add to rBUM target):"
	@comm -23 /tmp/rbum_files.txt /tmp/rbum_referenced.txt
	
	@echo "\nResticService Files:"
	@find ./ResticService -type f \( $(SOURCE_FILES) \) $(EXCLUDE_DIRS) | sort > /tmp/restic_files.txt
	@grep -oE 'path = .*\.swift;|path = .*\.h;|path = .*\.m;|path = .*\.mm;|path = .*\.c;|path = .*\.cpp;' \
		rBUM.xcodeproj/project.pbxproj | grep "ResticService" | sed -E 's/path = (.*);/\1/' | sort > /tmp/restic_referenced.txt
	@echo "Unreferenced ResticService files (add to ResticService target):"
	@comm -23 /tmp/restic_files.txt /tmp/restic_referenced.txt
	
	@rm -f /tmp/core_files.txt /tmp/core_referenced.txt /tmp/rbum_files.txt /tmp/rbum_referenced.txt /tmp/restic_files.txt /tmp/restic_referenced.txt
	
	@echo "\nTo fix:"
	@echo "1. Open Xcode"
	@echo "2. Select the project in the navigator"
	@echo "3. Select the appropriate target"
	@echo "4. Go to Build Phases > Compile Sources"
	@echo "5. Click + and add the unreferenced files"
