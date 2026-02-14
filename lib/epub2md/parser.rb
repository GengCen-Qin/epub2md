require 'zip'
require 'nokogiri'
require 'pathname'

module Epub2md
  # Parses EPUB files to extract metadata, structure, and content
  class Parser
    attr_reader :epub_path, :zip_file, :opf_path, :root_dir, :manifest, :spine, :metadata, :structure, :sections

    # Initialize parser with EPUB file path
    # @param epub_path [String] path to EPUB file
    def initialize(epub_path)
      @epub_path = Pathname.new(epub_path)
      raise "EPUB file does not exist: #{epub_path}" unless @epub_path.exist?

      @zip_file = Zip::File.open(@epub_path.to_s)
      @manifest = {}
      @spine = []
      @metadata = {}
      @structure = []
      @sections = []
    end

    # Parse the EPUB file and populate internal data structures
    # @return [Parser] self for chaining
    def parse
      @opf_path = get_opf_path
      @root_dir = determine_root_dir(@opf_path)
      
      opf_content = read_file(@opf_path)
      opf_doc = Nokogiri::XML(opf_content)
      
      parse_package(opf_doc)
      # parse_structure is not a method, it refers to the instance variable @structure
      # which is populated during the parsing process
      parse_sections
      
      self
    end

    private

    # Get the path to the OPF (Open Packaging Format) file from container.xml
    # @return [String] path to OPF file
    def get_opf_path
      container_content = read_file('META-INF/container.xml')
      container_doc = Nokogiri::XML(container_content)
      
      rootfile = container_doc.at_xpath('//xmlns:rootfile[@full-path]')
      rootfile['full-path'] if rootfile
    end

    # Determine the root directory based on OPF path
    # @param opf_path [String] path to OPF file
    # @return [String] root directory path
    def determine_root_dir(opf_path)
      Pathname.new(opf_path).dirname.to_s
    end

    # Parse the package document (OPF file) to extract metadata, manifest, spine, and TOC
    # @param doc [Nokogiri::XML::Document] parsed OPF XML document
    def parse_package(doc)
      # Parse metadata
      metadata_node = doc.at_xpath('//opf:metadata', { 'opf' => 'http://www.idpf.org/2007/opf' })
      parse_metadata(metadata_node) if metadata_node

      # Parse manifest
      manifest_nodes = doc.xpath('//opf:manifest/opf:item', { 'opf' => 'http://www.idpf.org/2007/opf' })
      parse_manifest(manifest_nodes)

      # Parse spine
      spine_nodes = doc.xpath('//opf:spine/opf:itemref', { 'opf' => 'http://www.idpf.org/2007/opf' })
      parse_spine(spine_nodes)

      # Parse TOC (Table of Contents)
      parse_toc(doc)
    end

    # Parse metadata from the OPF document
    # @param node [Nokogiri::XML::Element] metadata node
    def parse_metadata(node)
      # Extract common metadata elements
      @metadata[:title] = get_text_content(node, 'dc:title')
      @metadata[:author] = get_text_content(node, 'dc:creator')
      @metadata[:description] = get_text_content(node, 'dc:description')
      @metadata[:language] = get_text_content(node, 'dc:language')
      @metadata[:publisher] = get_text_content(node, 'dc:publisher')
      @metadata[:rights] = get_text_content(node, 'dc:rights')
    end

    # Extract text content from a specific XPath within the metadata node
    # @param node [Nokogiri::XML::Element] parent node
    # @param xpath [String] xpath to the desired element
    # @return [String, nil] text content or nil if not found
    def get_text_content(node, xpath)
      element = node.at_xpath(xpath, { 'dc' => 'http://purl.org/dc/elements/1.1/' })
      element.text.strip if element
    rescue
      nil
    end

    # Parse manifest items from the OPF document
    # @param nodes [Array<Nokogiri::XML::Element>] manifest item nodes
    def parse_manifest(nodes)
      nodes.each do |node|
        id = node['id']
        href = node['href']
        media_type = node['media-type']
        
        @manifest[id] = {
          href: href,
          media_type: media_type
        }
      end
    end

    # Parse spine items from the OPF document
    # @param nodes [Array<Nokogiri::XML::Element>] spine itemref nodes
    def parse_spine(nodes)
      nodes.each_with_index do |node, index|
        idref = node['idref']
        linear = node['linear'] != 'no' # Default is linear unless explicitly marked as non-linear
        
        @spine << {
          idref: idref,
          linear: linear,
          position: index
        }
      end
    end

    # Parse the Table of Contents from either NCX or navigation document
    # @param doc [Nokogiri::XML::Document] parsed OPF XML document
    def parse_toc(doc)
      # Look for NCX file in manifest
      ncx_item = @manifest.find { |_, v| v[:media_type] == 'application/x-dtbncx+xml' }
      
      if ncx_item
        # Ensure we have a proper path without leading dot
        ncx_href = ncx_item[1][:href]
        ncx_path = ncx_href.start_with?('/') ? ncx_href[1..-1] : File.join(@root_dir, ncx_href).gsub(/^\.\//, '')
        ncx_content = read_file(ncx_path)
        ncx_doc = Nokogiri::XML(ncx_content)
        parse_ncx_toc(ncx_doc)
      else
        # Fallback to EPUB 3 navigation document
        nav_item = @manifest.find { |_, v| v[:media_type] == 'application/xhtml+xml' && v[:href].include?('nav') }
        if nav_item
          nav_href = nav_item[1][:href]
          nav_path = nav_href.start_with?('/') ? nav_href[1..-1] : File.join(@root_dir, nav_href).gsub(/^\.\//, '')
          nav_content = read_file(nav_path)
          nav_doc = Nokogiri::XML(nav_content)
          parse_nav_toc(nav_doc)
        end
      end
    end

    def parse_ncx_toc(doc)
      nav_map = doc.at_xpath('//ncx:navMap', { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' })
      return unless nav_map

      @structure = parse_nav_points(nav_map.xpath('.//ncx:navPoint', { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' }))
    end

    def parse_nav_toc(doc)
      # Parse navigation document for EPUB 3
      nav_elements = doc.xpath('//nav[@epub:type="toc"]//ol/li', { 'epub' => 'http://www.idpf.org/2007/ops' })
      @structure = parse_nav_list(nav_elements)
    end

    def parse_nav_points(nav_points)
      nav_points.map do |point|
        label = point.at_xpath('.//ncx:navLabel/ncx:text', { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' })
        content = point.at_xpath('.//ncx:content', { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' })
        
        nav_point = {
          name: (label.text.strip if label),
          path: (content['src'] if content),
          play_order: point['playorder'],
          children: []
        }
        
        child_points = point.xpath('./ncx:navPoint', { 'ncx' => 'http://www.daisy.org/z3986/2005/ncx/' })
        nav_point[:children] = parse_nav_points(child_points) if child_points.any?
        
        nav_point
      end
    end

    def parse_nav_list(nav_elements)
      nav_elements.map do |element|
        link = element.at_css('a')
        sub_list = element.at_css('ol')
        
        nav_item = {
          name: (link.text.strip if link),
          path: (link['href'] if link),
          children: []
        }
        
        if sub_list
          sub_items = sub_list.xpath('./li')
          nav_item[:children] = parse_nav_list(sub_items) if sub_items.any?
        end
        
        nav_item
      end
    end

    # Parse sections (chapters) from the spine and manifest
    # Adds section data to the @sections array
    def parse_sections
      @spine.each do |spine_item|
        manifest_item = @manifest[spine_item[:idref]]
        next unless manifest_item && manifest_item[:media_type] == 'application/xhtml+xml'

        href = manifest_item[:href]
        path = href.start_with?('/') ? href[1..-1] : File.join(@root_dir, href).gsub(/^\.\//, '')
        html_content = read_file(path)
        
        @sections << {
          id: spine_item[:idref],
          path: path,
          html_content: html_content,
          title: extract_title_from_html(html_content)
        }
      end
    end

    def extract_title_from_html(html_content)
      doc = Nokogiri::HTML(html_content)
      title_element = doc.at_css('title')
      title_element.text.strip if title_element
    rescue
      nil
    end

    # Read a file from the EPUB archive
    # @param path [String] path to file within EPUB
    # @return [String] file content
    def read_file(path)
      # Normalize the path to handle both absolute and relative paths
      normalized_path = path.start_with?('/') ? path[1..-1] : path
      # Use find instead of glob for exact match
      entry = @zip_file.find_entry(normalized_path)
      raise "File not found in EPUB: #{path}" unless entry

      entry.get_input_stream.read
    end
  end
end