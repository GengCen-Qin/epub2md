require 'reverse_markdown'

module Epub2md
  # Converts EPUB content to Markdown format
  class Converter
    # Initialize converter with a parser instance
    # @param parser [Parser] EPUB parser instance
    def initialize(parser)
      @parser = parser
    end

    # Convert EPUB to multiple Markdown files
    # @param localize_images [Boolean] whether to extract images to local directory
    # @param output_dir [String] directory to save Markdown files
    # @return [Array<String>] list of created Markdown file paths
    def convert_to_markdown(localize_images: false, output_dir: nil)
      output_dir ||= File.dirname(@parser.epub_path) + "/#{@parser.epub_path.basename('.epub')}_markdown"
      Dir.mkdir(output_dir) unless Dir.exist?(output_dir)

      # Create images directory if needed
      images_dir = File.join(output_dir, 'images')
      Dir.mkdir(images_dir) unless Dir.exist?(images_dir)

      # Store the images directory for use in preprocessing
      @images_dir = images_dir
      @localize = localize_images

      # Extract all images from the EPUB to the images directory
      extract_images_to_directory(images_dir) if localize_images

      # Convert each section to markdown
      markdown_files = []
      @parser.sections.each_with_index do |section, index|
        # Format the filename with leading zeros based on total sections
        filename = sprintf("%0#{Math.log10(@parser.sections.length).to_i + 1}d", index + 1)
        filename += "-#{sanitize_filename(section[:title] || section[:id])}.md"
        
        markdown_content = convert_html_to_markdown(section[:html_content])
        
        # Process image links if localization is enabled
        if localize_images
          markdown_content = process_image_links(markdown_content, images_dir)
        end
        
        file_path = File.join(output_dir, filename)
        File.write(file_path, markdown_content, encoding: 'UTF-8')
        markdown_files << file_path
      end

      # Clear the stored variables
      @images_dir = nil
      @localize = nil

      markdown_files
    end

    def extract_images_to_directory(images_dir)
      # Extract all image files from the EPUB manifest to the images directory
      @parser.manifest.each do |id, item|
        href = item[:href]
        media_type = item[:media_type]
        
        # Check if the item is an image
        if media_type && media_type.start_with?('image/')
          # Determine the full path in the EPUB
          normalized_path = href.start_with?('/') ? href[1..-1] : File.join(@parser.root_dir, href).gsub(/^\.\//, '')
          
          # Find the image in the EPUB archive and extract it
          entry = @parser.zip_file.find_entry(normalized_path)
          if entry
            # Extract the image from the EPUB to the local images directory
            image_path = File.join(images_dir, File.basename(normalized_path))
            File.open(image_path, 'wb') do |f|
              f.write(entry.get_input_stream.read)
            end
          end
        end
      end
    end

    # Convert EPUB to a single merged Markdown file
    # @param localize_images [Boolean] whether to extract images to local directory
    # @param output_filename [String] path to save merged Markdown file
    # @return [String] path to the created Markdown file
    def convert_to_single_markdown(localize_images: false, output_filename: nil)
      output_filename ||= File.dirname(@parser.epub_path) + "/#{@parser.epub_path.basename('.epub')}_merged.md"
      
      # Create images directory if needed
      images_dir = File.join(File.dirname(output_filename), 'images')
      Dir.mkdir(images_dir) unless Dir.exist?(images_dir)

      # Store the images directory for use in preprocessing
      @images_dir = images_dir
      @localize = localize_images

      # Extract all images from the EPUB to the images directory
      extract_images_to_directory(images_dir) if localize_images

      markdown_content = ""
      @parser.sections.each_with_index do |section, index|
        # Add a header for each section
        title = section[:title] || section[:id]
        markdown_content += "# #{title}\n\n"
        
        content = convert_html_to_markdown(section[:html_content])
        
        # Process image links if localization is enabled
        if localize_images
          content = process_image_links(content, images_dir)
        end
        
        markdown_content += content
        markdown_content += "\n\n---\n\n" unless index == @parser.sections.length - 1
      end

      # Clear the stored variables
      @images_dir = nil
      @localize = nil

      File.write(output_filename, markdown_content, encoding: 'UTF-8')
      output_filename
    end

    # Extract all image files from the EPUB manifest to the specified directory
    # @param images_dir [String] directory to save extracted images
    def extract_images_to_directory(images_dir)
      # Extract all image files from the EPUB manifest to the images directory
      @parser.manifest.each do |id, item|
        href = item[:href]
        media_type = item[:media_type]
        
        # Check if the item is an image
        if media_type && media_type.start_with?('image/')
          # Determine the full path in the EPUB
          normalized_path = href.start_with?('/') ? href[1..-1] : File.join(@parser.root_dir, href).gsub(/^\.\//, '')
          
          # Find the image in the EPUB archive and extract it
          entry = @parser.zip_file.find_entry(normalized_path)
          if entry
            # Extract the image from the EPUB to the local images directory
            image_path = File.join(images_dir, File.basename(normalized_path))
            File.open(image_path, 'wb') do |f|
              f.write(entry.get_input_stream.read)
            end
          end
        end
      end
    end

    private

    # Convert HTML content to Markdown format
    # @param html_content [String] HTML content to convert
    # @return [String] converted Markdown content
    def convert_html_to_markdown(html_content)
      # First, process any image tags in the HTML to handle localization
      processed_html = preprocess_html_images(html_content) if @localize
      
      # Use ReverseMarkdown to convert HTML to Markdown
      # Options: GitHub Flavored Markdown compatible
      options = {
        github_flavored: true,
        unknown_tags: :pass_through,
        # Preserve certain tags as HTML
        preserve_tags: ['img', 'video', 'audio']
      }
      
      converted = ReverseMarkdown.convert(processed_html || html_content, options)
      
      # Clean up extra whitespace
      converted.gsub(/\n{3,}/, "\n\n")
    end

    private

    # Preprocess HTML content to handle image localization
    # Downloads external images and extracts internal images to local directory
    # Updates image sources in HTML to point to local copies
    # @param html_content [String] HTML content to process
    # @return [String] processed HTML content with updated image sources
    def preprocess_html_images(html_content)
      # Parse the HTML to find image tags
      doc = Nokogiri::HTML(html_content)
      
      # Find all image tags
      doc.css('img').each do |img|
        src = img['src']
        next unless src
        
        # Skip if it's already a local reference
        next if src.start_with?('.') || src.start_with?('/')
        
        if src.start_with?('http://', 'https://')
          # Handle external images
          begin
            require 'open-uri'
            uri = URI.parse(src)
            filename = File.basename(uri.path)
            filename = "image_#{Time.now.to_i}.jpg" if filename.empty? || filename == '/'
            
            image_path = File.join(@images_dir, filename)
            
            # Download the image
            open(src, 'rb') do |remote_file|
              File.open(image_path, 'wb') do |local_file|
                local_file.write(remote_file.read)
              end
            end
            
            # Update the image source to point to the local copy
            img['src'] = "./images/#{filename}"
          rescue => e
            puts "Failed to download image: #{src} - #{e.message}"
          end
        else
          # Handle internal image references within the EPUB
          begin
            # Extract the image filename from the URL
            filename = File.basename(src)
            image_path = File.join(@images_dir, filename)
            
            # Find the image in the EPUB archive and extract it
            # Normalize the path to handle both absolute and relative paths
            normalized_path = src.start_with?('/') ? src[1..-1] : File.join(@parser.root_dir, src).gsub(/^\.\//, '')
            
            entry = @parser.zip_file.find_entry(normalized_path)
            if entry
              # Extract the image from the EPUB to the local images directory
              File.open(image_path, 'wb') do |f|
                f.write(entry.get_input_stream.read)
              end
              
              # Update the image source to point to the local copy
              img['src'] = "./images/#{filename}"
            end
          rescue => e
            puts "Failed to extract internal image: #{src} - #{e.message}"
          end
        end
      end
      
      # Return the modified HTML
      doc.to_html
    end

    def process_image_links(markdown_content, images_dir)
      # Find all image links in markdown
      markdown_content.gsub(/!\[([^\]]*)\]\(([^)]+)\)/) do |match|
        alt_text = $1
        url = $2
        
        # Skip if it's already a local reference
        next match if url.start_with?('.') || url.start_with?('/')
        
        if url.start_with?('http://', 'https://')
          # Download the image
          begin
            require 'open-uri'
            uri = URI.parse(url)
            filename = File.basename(uri.path)
            filename = "image_#{Time.now.to_i}.jpg" if filename.empty? || filename == '/'
            
            image_path = File.join(images_dir, filename)
            
            # Download the image
            open(url, 'rb') do |remote_file|
              File.open(image_path, 'wb') do |local_file|
                local_file.write(remote_file.read)
              end
            end
            
            # Return local reference
            "!#{alt_text.empty? ? '' : "[#{alt_text}]"}(./images/#{filename})"
          rescue => e
            puts "Failed to download image: #{url} - #{e.message}"
            match
          end
        else
          # Handle internal image references within the EPUB
          # These are typically relative paths to images inside the EPUB archive
          begin
            # Extract the image filename from the URL
            filename = File.basename(url)
            image_path = File.join(images_dir, filename)
            
            # Find the image in the EPUB archive and extract it
            # Access the zip file from the parser instance
            # Normalize the path to handle both absolute and relative paths
            normalized_path = url.start_with?('/') ? url[1..-1] : File.join(@parser.root_dir, url).gsub(/^\.\//, '')
            
            entry = @parser.zip_file.find_entry(normalized_path)
            if entry
              # Extract the image from the EPUB to the local images directory
              File.open(image_path, 'wb') do |f|
                f.write(entry.get_input_stream.read)
              end
              
              # Return local reference
              "!#{alt_text.empty? ? '' : "[#{alt_text}]"}(./images/#{filename})"
            else
              match
            end
          rescue => e
            puts "Failed to extract internal image: #{url} - #{e.message}"
            match
          end
        end
      end
    end

    # Sanitize filename by removing invalid characters
    # @param filename [String] original filename
    # @return [String] sanitized filename
    def sanitize_filename(filename)
      # Remove invalid characters for filenames
      filename.gsub(/[<>:"\/\\|?*]/, '_').gsub(/\s+/, '_')
    end
  end
end