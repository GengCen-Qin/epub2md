require 'rspec'
require_relative '../lib/epub2md'

RSpec.describe Epub2md do
  it 'has a version number' do
    expect(Epub2md::VERSION).not_to be nil
  end

  describe Epub2md::Parser do
    it 'has the correct class defined' do
      expect { Epub2md::Parser }.not_to raise_error
    end
  end

  describe Epub2md::Converter do
    it 'has the correct class defined' do
      expect { Epub2md::Converter }.not_to raise_error
    end
  end
end