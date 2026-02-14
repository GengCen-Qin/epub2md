require 'rspec'
require 'fileutils'
require_relative '../lib/epub2md'

RSpec.describe Epub2md::Parser do
  let(:epub_path) { './demo.epub' }

  describe '#initialize' do
    it 'creates a new parser instance' do
      expect { Epub2md::Parser.new(epub_path) }.not_to raise_error
    end
  end

  describe '#parse' do
    it 'parses the EPUB file successfully' do
      parser = Epub2md::Parser.new(epub_path)
      expect { parser.parse }.not_to raise_error
    end

    it 'extracts metadata correctly' do
      parser = Epub2md::Parser.new(epub_path)
      parser.parse

      expect(parser.metadata[:title]).to eq('Three Wishing Tales')
      expect(parser.metadata[:author]).to eq('Ruth Chew')
    end

    it 'extracts sections correctly' do
      parser = Epub2md::Parser.new(epub_path)
      parser.parse

      expect(parser.sections.length).to be > 0
    end
  end
end

RSpec.describe Epub2md::Converter do
  let(:epub_path) { './demo.epub' }
  let(:parser) { Epub2md::Parser.new(epub_path).parse }
  let(:converter) { Epub2md::Converter.new(parser) }

  describe '#convert_to_markdown' do
    it 'converts to markdown files' do
      expect { 
        converter.convert_to_markdown(output_dir: './test_output')
      }.not_to raise_error

      # Clean up
      FileUtils.rm_rf('./test_output') if Dir.exist?('./test_output')
    end
  end

  describe '#convert_to_single_markdown' do
    it 'converts to a single markdown file' do
      expect { 
        converter.convert_to_single_markdown(output_filename: './test_merged.md')
      }.not_to raise_error

      # Clean up
      File.delete('./test_merged.md') if File.exist?('./test_merged.md')
    end
  end
end