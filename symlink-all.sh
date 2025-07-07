#!/bin/bash
# symlink-all.sh - Create symlinks in target directory for all items in current directory
# Usage: ./symlink-all.sh [target_directory]

target_dir="${1:-../symlinks}"
current_dir="$(pwd)"

# Files/directories to exclude
exclude_patterns=(
    ".git"
    ".DS_Store"
    "node_modules"
    ".vscode"
    ".idea"
    "*.log"
    ".env"
    ".env.local"
    ".env.production"
    "dist"
    "build"
    "__pycache__"
    ".pytest_cache"
    "coverage"
    ".nyc_output"
    ".next"
    ".nuxt"
    "target"
    "bin"
    "obj"
    "*.tmp"
    "*.temp"
    ".sass-cache"
    ".parcel-cache"
    ".cache"
    "thumbs.db"
    "desktop.ini"
    "symlink-all.sh"
)

# Create target directory if it doesn't exist
mkdir -p "$target_dir"

# Convert to absolute path
target_abs="$(cd "$target_dir" && pwd)"

echo "Creating symlinks in: $target_abs"
echo "Source directory: $current_dir"
echo "Excluding: ${exclude_patterns[*]}"
echo

# Function to check if item should be excluded
should_exclude() {
    local item="$1"
    for pattern in "${exclude_patterns[@]}"; do
        if [[ "$item" == $pattern ]]; then
            return 0  # Should exclude
        fi
    done
    return 1  # Should not exclude
}

# Create symlinks for all items (including hidden files)
linked_count=0
skipped_count=0

for item in .[^.]* *; do
    if [[ -e "$item" ]]; then
        if should_exclude "$item"; then
            echo "Skipping: $item (excluded)"
            ((skipped_count++))
        else
            echo "Linking: $item"
            ln -sf "$current_dir/$item" "$target_abs/$item"
            ((linked_count++))
        fi
    fi
done

echo
echo "Summary:"
echo "- Linked: $linked_count items"
echo "- Skipped: $skipped_count items"
echo "- Target: $target_abs"
echo "Done!"
