# RodoFS Utility Scripts

This directory contains Perl utility scripts for managing RodoFS resources and tags.

## Scripts

### rodo-tag

Manually tag files with taxonomies and tags.

**Usage:**
```bash
rodo-tag -T "taxonomy=tag,another=tag2" /path/to/file
```

**Options:**
- `-T tags` - Tag specification in format "taxonomy1=tag1,taxonomy2=tag2"
- `-u url` - Custom URL (default: file:// path)
- `-m mime` - MIME type (default: detected from file)

### rodo-autotag

Automatically tag files based on filename patterns and rules.

**Usage:**
```bash
rodo-autotag -s /path/to/directory
```

**Options:**
- `-s path` - Scan directory for files to auto-tag
- `-R` - Recursive scanning
- `-v` - Verbose output

### rodo-check

Check and display metadata for tagged files.

**Usage:**
```bash
rodo-check /path/to/file
```

Displays:
- Object ID (oid)
- Associated tags
- MD5 hash
- URL
- MIME type

### rodo-del

Delete file metadata from RodoFS.

**Usage:**
```bash
rodo-del /path/to/file
```

Removes the file's entry from Redis and all tag associations.

### plumb

Smart file viewer/launcher with RodoFS integration.

**Usage:**
```bash
# View files by pattern
plumb -f -s "*.pdf"

# View tagged files
plumb -t -T "subject=physics" -s

# Random selection (no repetitions)
plumb -t -T "subject=physics" -R -c 5

# List filenames only
plumb -t -L

# Edit instead of view
plumb -f -e "document.txt"
```

**Options:**
- `-f` - File mode (use filesystem paths)
- `-t` - Tag mode (use RodoFS tags)
- `-s pattern` - Search pattern or show all
- `-T tags` - Tag specification
- `-R` - Random mode (no repetitions)
- `-c count` - Number of random files
- `-L` - List mode (filenames only)
- `-e` - Edit mode (instead of view)

## Requirements

All scripts require:
- Perl 5
- Access to RodoFS mountpoint
- Standard Perl modules: `Getopt::Std`, `File::Find`, `File::Spec`

## Configuration

Scripts use the RodoFS filesystem mounted at the location specified during mount.
Ensure RodoFS is mounted before running these utilities.
