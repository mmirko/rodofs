# RodoFS

**A Tag-Based Virtual Filesystem with Redis Backend**

RodoFS is a FUSE-based virtual filesystem that provides tag-based organization for your files using Redis as a persistent metadata store. Instead of traditional hierarchical directory structures, RodoFS allows you to organize and access files through taxonomies, tags, and flexible rule-based queries.

## Features

- **Tag-Based Organization**: Classify files using custom taxonomies and tags
- **Virtual Filesystem**: Access tagged resources through a FUSE-mounted directory structure
- **Redis Backend**: Fast, persistent metadata storage
- **Rule-Based Filtering**: Create dynamic collections based on tag rules
- **MD5 Deduplication**: Automatic identification of duplicate files
- **Multi-URL Support**: Associate multiple URLs/locations with a single resource
- **Auto-Tagging**: Automatically tag files based on filename patterns
- **Flexible Querying**: Browse files by tags or search by MD5

## Architecture

### Project Structure

```
rodofs/
├── lib/
│   ├── rodofs.rb                # Main module entry point
│   └── rodofs/
│       ├── version.rb           # Version information
│       ├── rodo_object.rb       # Object model for resources, taxonomies, tags, and rules
│       └── fuse_dir.rb          # FUSE filesystem implementation
├── bin/
│   └── rodofs                   # Command-line executable
├── scripts/
│   ├── plumb                    # Generic file viewer/editor launcher
│   ├── rodo-tag                 # Perl utility to manually tag files
│   ├── rodo-autotag             # Perl utility for automatic tagging
│   ├── rodo-check               # Perl utility to check file metadata
│   └── rodo-del                 # Perl utility to delete file metadata
└── test/
    ├── rodofstest.rb            # Integration tests
    └── RodoObjectTest.rb        # Unit tests
```

### Directory Structure

When mounted, RodoFS exposes the following virtual directories:

```
/
├── ctl              # Control file for commands
├── tax/             # Taxonomies directory
│   └── <taxonomy>/
│       └── <tag>/
│           └── <file>
├── res/             # Resources matching current rule
├── rules/           # Rule-based dynamic collections
│   └── <rule>/
│       ├── ctl
│       └── <file>
└── auto/            # Auto-tagging rule definitions
```

## Installation

### Option 1: Install as a Gem (Recommended)

```bash
# Clone the repository
git clone https://github.com/mmirko/rodofs.git
cd rodofs

# Build and install the gem
gem build rodofs.gemspec
gem install rodofs-0.1.0.gem

# Or install dependencies for development
bundle install
```

### Option 2: Run from Source

```bash
# Clone and setup
git clone https://github.com/mmirko/rodofs.git
cd rodofs
bundle install
```

### Prerequisites

### Prerequisites

**System Requirements:**
- Ruby 2.6 or later
- FUSE libraries (libfuse)
- Redis server
- Perl 5 (for utility scripts)

**Install system dependencies:**
```bash
sudo apt-get install ruby fuse libfuse-dev redis-server perl
```


**On Debian/Ubuntu:**
```bash
sudo apt-get install ruby fuse libfuse-dev redis-server perl
```

**On Fedora/RHEL:**
```bash
sudo dnf install ruby fuse fuse-devel redis perl
```

**Start Redis server:**
```bash
sudo systemctl start redis
# or run manually:
redis-server
```

## Usage

### Using the Installed Gem

```bash
# Start Redis if not already running
redis-server &

# Create a mountpoint
mkdir -p /tmp/rodofs

# Mount RodoFS
rodofs /tmp/rodofs

# In another terminal, use the filesystem
cd /tmp/rodofs
```

### Configuration

Set environment variables to configure RodoFS:

- `REDIS_HOST`: Redis server hostname (default: `127.0.0.1`)
- `REDIS_PORT`: Redis server port (default: `6379`)
- `RODOFS_LANG`: Language code (default: `it`)

Example:
```bash
REDIS_HOST=myredis.local REDIS_PORT=6380 rodofs /tmp/rodofs
```

### Using from Source

bundle exec scripts/rodo-tag -T "subject=physics,type=paper" /path/to/document.pdf
```

**Auto-tagging based on filename patterns:**
```bash
bundle exec scripts## Basic Workflow

#### 1. Create a Taxonomy and Tags

```bash
cd /path/to/mountpoint
mkdir -p tax/subject/physics
mkdir -p tax/subject/mathematics
```

#### 2. Tag Files

**Manual tagging:**
```bash
./rodo-tag -T "subject=physics,type=paper" /path/to/document.pdf
```

**Auto-tagging based on filename patterns:**
```bash
./rodo-autotag -s /path/to/directory
```

#### 3. Browse Tagged Files

```bash
# Access files through taxonomy structure
ls tax/subject/physics/

# Use rules to create dynamic views
echo "rule: subject=physics" > ctl
ls res/
```

#### 4. Check File Metadata

```bash
./rodo-check /path/to/document.pdf
```

#### 5. Remove File Metadata

```bash
./rodo-del /path/to/document.pdf
```

### Advanced Features

#### Rule-Based Queries

Create rules to filter resources:

```bash
# Positive match: files tagged with subject=physics
echo "rule: subject=physics" > ctl

# Negative match: files NOT tagged with subject=physics  
echo "rule: subject!=physics" > ctl
```

#### MD5-Based Lookup

Find files by MD5 hash:

```bash
MD5=$(md5sum myfile.pdf | cut -d' ' -f1)
echo "md5: $MD5" > ctl
ls res/
```

#### Persistent Rules

Create named rules:

```bash
mkdir rules/physics-papers
echo "rule: subject=physics" > rules/physics-papers/ctl
ls rules/physics-papers/
```

## File Format

Resource metadata files contain key-value pairs:

```
oid: 42
tags: subject=physics subject=quantum_mechanics
url: file:///home/user/documents/paper.pdf
mime: application/pdf
md5: d41d8cd98f00b204e9800998ecf8427e
```

## Utility Scripts

### plumb

A smart file launcher that uses file type and RodoFS metadata:

```bash
# View files in current directory matching pattern
./plumb -f -s "*.pdf"

# Use tag-based view
./plumb -t -T "subject=physics" -s

# Random file selection (no repetitions)
./plumb -t -T "subject=physics" -R -c 5

# Show filenames only
./plumb -t -L

# Launch editor instead of viewer
./plumb -f -e "document.txt"
```

## Configuration

### Redis Connection

Edit `rodofs.rb` to change Redis connection settings:

```ruby
r = Redis.new(:host => "127.0.0.1", :port => 6379)
```

### Mount Options

The default language can be changed in `rodofs.rb`:

```ruby
root = RodoFS.new('it', r)  # Change 'it' to your preferred language
```

## Troubleshooting

### "fusefs" gem not found

If you see errors about `fusefs`, make sure you've installed `rfusefs`:

```bash
gem uninstall fusefs  # Remove old gem if present
gem install rfusefs
```

### Permission Denied

Ensure your user has permission to mount FUSE filesystems:

```bash
sudo usermod -a -G fuse $USER
# Log out and back in
```

### Redis Connection Failed

Verify Redis is running:

```bash
redis-cli ping
# Should return: PONG
```

## Compatibility Notes

This version has been updated for compatibility with modern Ruby (2.4+) and Redis gem (4.2+):

- `Fixnum` → `Integer` (Ruby 2.4+)
- `Redis.exists()` → `Redis.exists?()` (redis gem 4.2+)
- `fusefs` → `rfusefs` (actively maintained FUSE library)

All Perl scripts have been updated for modern Perl compatibility.

## Development

### Building the Gem

```bash
# Build gem package
gem build rodofs.gemspec

# Install locally
gem install rodofs-0.1.0.gem

# Or use bundler for development
bundle install
```

### Running Tests

```bash
cd test
ruby RodoObjectTest.rb
ruby rodofstest.rb
```

### Code Structure

The gem follows standard Ruby conventions:

- `lib/rodofs.rb` - Main entry point and public API
- `lib/rodofs/` - Internal modules and classes
  - `version.rb` - Version constant
  - `rodo_object.rb` - Data model for Redis-backed objects
  - `fuse_dir.rb` - FUSE filesystem implementation
- `bin/rodofs` - Command-line executable
- `scripts/` - Perl utility scripts for file tagging and management

### Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Contributions are welcome! Please feel free to submit pull requests or open issues on GitHub.

## License

Licensed under the Apache License 2.0. See [LICENSE](LICENSE) file for details.

## Author

Copyright 2014-2026 - Mirko Mariotti
- Website: https://www.mirkomariotti.it
- GitHub: https://github.com/mmirko/rodofs

## See Also

- [FUSE](https://github.com/libfuse/libfuse) - Filesystem in Userspace
- [Redis](https://redis.io/) - In-memory data structure store
- [rfusefs](https://github.com/lwoggardner/rfusefs) - Ruby FUSE library
