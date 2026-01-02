#!/bin/bash

# Usage: ./script.sh <file_list>
# Where file_list contains one file path per line

if [ $# -lt 1 ]; then
    echo "Usage: $0 <file_list>" >&2
    exit 1
fi

FILE_LIST="$1"

if [ ! -f "$FILE_LIST" ]; then
    echo "Error: File list '$FILE_LIST' not found" >&2
    exit 1
fi

# Use associative array to track processed files and avoid duplicates
declare -A processed

# Convert to canonical relative path
to_relative() {
    local path="$1"
    # Get absolute path and normalize
    local abs=$(readlink -f "$path" 2>/dev/null || realpath "$path" 2>/dev/null || echo "$path")
    # Convert to relative with ./ prefix
    echo ".${abs}"
}

process_file() {
    local file="$1"
    
    # First, normalize the input path to absolute (but don't resolve symlinks yet)
    if [[ "$file" != /* ]]; then
        file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    fi
    
    # Check if it's a symlink BEFORE resolving
    local is_symlink=0
    [ -L "$file" ] && is_symlink=1
    
    # For the output path, use the input file path
    local relpath=".${file}"
    
    # Skip if already processed this specific path
    [ "${processed[$relpath]}" = "1" ] && return
    processed[$relpath]=1
    
    # Get canonical path for checking kernel stubs
    local canonical=$(readlink -f "$file" 2>/dev/null || realpath "$file" 2>/dev/null || echo "$file")
    
    # Skip kernel stubs/virtual libs
    local basename=$(basename "$canonical")
    if [[ "$basename" =~ ^ld-linux.*\.so\. ]] || \
       [[ "$basename" =~ ^linux-(vdso|gate).*\.so\. ]] || \
       [[ "$canonical" =~ linux-(vdso|gate) ]]; then
        return
    fi
    
    # Check if file exists
    [ ! -e "$file" ] && return
    
    # Handle symbolic links
    if [ $is_symlink -eq 1 ]; then
        local target=$(readlink "$file")
        local abs_target
        
        # Resolve target to absolute path
        if [[ "$target" == /* ]]; then
            abs_target="$target"
        else
            local dir=$(dirname "$file")
            abs_target="$dir/$target"
            # Normalize to absolute
            abs_target=$(cd "$(dirname "$abs_target")" && pwd)/$(basename "$abs_target")
        fi
        
        # Canonicalize the target for final output
        local canonical_target=$(readlink -f "$abs_target" 2>/dev/null || realpath "$abs_target" 2>/dev/null || echo "$abs_target")
        local rel_target=".${canonical_target}"
        
        echo "l|${relpath}|${rel_target}"
        
        # Process the target file
        process_file "$canonical_target"
        return
    fi
    
    # Regular file
    echo "f|${relpath}|"
    
    # Try to run ldd on the file
    if [ -f "$file" ] && [ -x "$file" ] || file "$file" 2>/dev/null | grep -q "ELF"; then
        # Use process substitution to avoid subshell
        while read -r line; do
            # Parse ldd output: libname.so => /path/to/lib (0xaddress)
            # or /path/to/lib (0xaddress) for direct paths
            if [[ "$line" =~ =\>\ ([^[:space:]]+)\ \( ]]; then
                # Format: lib.so => /path/to/lib (0x...)
                libpath="${BASH_REMATCH[1]}"
                [ "$libpath" != "not" ] && process_file "$libpath"
            elif [[ "$line" =~ ^[[:space:]]*(/[^[:space:]]+)\ \( ]]; then
                # Format: /path/to/lib (0x...)
                libpath="${BASH_REMATCH[1]}"
                process_file "$libpath"
            fi
        done < <(ldd "$file" 2>/dev/null)
    fi
}

# Process each file in the list
while IFS= read -r file || [ -n "$file" ]; do
    # Skip empty lines and comments
    [[ -z "$file" || "$file" =~ ^[[:space:]]*# ]] && continue
    
    # Trim whitespace
    file=$(echo "$file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    process_file "$file"
done < "$FILE_LIST"
