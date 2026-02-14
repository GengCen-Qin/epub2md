# Ruby EPUB2MD

A Ruby implementation of the epub2md tool for converting EPUB files to Markdown format.

## Features

- Convert EPUB files to multiple Markdown files
- Convert EPUB files to a single merged Markdown file
- Extract EPUB metadata and structure information
- Localize images (extract images from EPUB to local directory when using `--localize` option)
- Command-line interface for easy usage
- Programmatic API for integration into other tools

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'epub2md'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install epub2md
```

## Usage

### Command Line Interface

```bash
# Convert EPUB to multiple Markdown files (text only, no images extracted)
bundle exec ruby bin/epub2md convert path/to/book.epub

# Convert EPUB to a single Markdown file (text only, no images extracted)
bundle exec ruby bin/epub2md merge path/to/book.epub

# Show EPUB information (human-readable format)
bundle exec ruby bin/epub2md info path/to/book.epub

# Show EPUB information (JSON format)
bundle exec ruby bin/epub2md info path/to/book.epub --json

# Show EPUB structure
bundle exec ruby bin/epub2md structure path/to/book.epub

# Show EPUB sections
bundle exec ruby bin/epub2md sections path/to/book.epub

# Localize images during conversion (extract images from EPUB to local directory)
# This creates an 'images' directory with all images from the EPUB
bundle exec ruby bin/epub2md convert path/to/book.epub --localize

# Specify output directory
bundle exec ruby bin/epub2md convert path/to/book.epub --output /custom/output/dir
```

**Note**: Image extraction only occurs when using the `--localize` option. Without this option, only text content is converted to Markdown, and images remain embedded in the EPUB file but are not extracted to the output directory.

### Programmatic Usage

```ruby
require 'epub2md'

# Parse an EPUB file
parser = Epub2md::Parser.new('path/to/book.epub')
parser.parse

# Convert to multiple markdown files
converter = Epub2md::Converter.new(parser)
converter.convert_to_markdown(output_dir: './output')

# Or convert to a single markdown file
converter.convert_to_single_markdown(output_filename: './output/merged_book.md')
```

#### Get EPUB Information

```ruby
require 'epub2md'

parser = Epub2md::Parser.new('path/to/book.epub')
parser.parse

# Get metadata
parser.metadata  # => { title: "...", author: "...", description: "...", language: "...", publisher: "..." }

# Get statistics
parser.sections.length    # Number of sections/chapters
parser.manifest.length    # Number of manifest items

# Get table of contents
parser.structure  # Array of TOC items with :name, :path, :children

# Get all sections
parser.sections  # Array of sections, each contains :id, :path, :html_content, :title
```

#### Control `--localize` Option

Use the `localize_images:` parameter in the Converter:

```ruby
require 'epub2md'

parser = Epub2md::Parser.new('path/to/book.epub')
parser.parse

converter = Epub2md::Converter.new(parser)

# Convert to multiple markdown files with image localization (equivalent to --localize)
converter.convert_to_markdown(
  localize_images: true,    # Enable image extraction to local directory
  output_dir: './output'
)

# Convert to a single merged markdown file with image localization
converter.convert_to_single_markdown(
  localize_images: true,
  output_filename: './output/book.md'
)
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome

## License

The gem is available as open source under the terms of the MIT License.
