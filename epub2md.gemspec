# frozen_string_literal: true

require_relative 'lib/epub2md/version'

Gem::Specification.new do |spec|
  spec.name          = 'epub2md'
  spec.version       = Epub2md::VERSION
  spec.authors       = ['lucas.qin']
  spec.email         = ['qsc1956826@gmail.com']

  spec.summary       = 'A Ruby gem to convert EPUB files to Markdown format'
  spec.description   = 'Convert EPUB files to Markdown with support for images, chapters, and formatting'
  spec.homepage      = 'https://github.com/GengCen-Qin/epub2md'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'rubyzip', '~> 2.3'
  spec.add_dependency 'nokogiri', '~> 1.13'
  spec.add_dependency 'reverse_markdown', '~> 2.1'
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'httparty', '~> 0.21'

  # Development dependencies
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'pry', '~> 0.14'
end
