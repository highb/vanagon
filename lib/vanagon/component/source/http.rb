require 'vanagon/utilities'
require 'net/http'
require 'uri'

class Vanagon
  class Component
    class Source
      class Http
        include Vanagon::Utilities
        attr_accessor :url, :sum, :file, :extension, :workdir

        # Constructor for the Http source type
        #
        # @param url [String] url of the http source to fetch
        # @param sum [String] sum to verify the download against
        # @param workdir [String] working directory to download into
        # @raise [RuntimeError] an exception is raised is sum is nil
        def initialize(url, sum, workdir)
          unless sum
            fail "sum is required to validate the http source"
          end
          @url = url
          @sum = sum
          @workdir = workdir
        end

        # Download the source from the url specified. Sets the full path to the
        # file as @file and the @extension for the file as a side effect.
        def fetch
          @file = download
          @extension = get_extension
        end

        # Verify the downloaded file matches the provided sum
        #
        # @raise [RuntimeError] an exception is raised if the sum does not match the sum of the file
        def verify
          puts "Verifying file: #{@file} against sum: '#{@sum}'"
          actual = get_md5sum(File.join(@workdir, @file))
          unless @sum == actual
            fail "Unable to verify '#{@file}'. Expected: '#{@sum}', got: '#{actual}'"
          end
        end

        # Downloads the file from @url into the @workdir
        #
        # @raise [RuntimeError] an exception is raised if the URI scheme cannot be handled
        def download
          uri = URI.parse(@url)
          target_file = File.basename(uri.path)

          case uri.scheme
          when 'http', 'https'
            Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
              request = Net::HTTP::Get.new(uri)

              http.request request do |response|
                open(File.join(@workdir, target_file), 'w') do |io|
                  response.read_body do |chunk|
                    io.write(chunk)
                  end
                end
              end
            end
          else
            fail "Unable to download files using the uri scheme '#{uri.scheme}'. Maybe you have a typo or need to teach me a new trick?"
          end

          target_file
        end

        # Gets the command to extract the archive given if needed (uses @extension)
        #
        # @return [String, nil] command to extract the source
        # @raise [RuntimeError] an exception is raised if there is no known extraction method for @extension
        def extract
          case @extension
          when '.tar.gz', '.tgz'
            return "gunzip -c '#{@file}' | tar xf -"
          when '.gem'
            # Don't need to unpack gems
            return nil
          else
            fail "Extraction unimplemented for '#{@extension}' in source '#{@file}'. Please teach me."
          end
        end

        # Returns the extension for @file
        #
        # @return [String] the extension of @file
        # @raise [RuntimeError] an exception is raised if the extension isn't in the current list
        def get_extension
          extension_match = @file.match(/.*(\.tar\.gz|\.tgz|\.gem|\.tar\.bz)/)
          unless extension_match
            fail "Unrecognized extension for '#{@file}'. Don't know how to extract this format. Please teach me."
          end

          extension_match[1]
        end

        # The dirname to reference when building from the source
        #
        # @return [String] the directory that should be traversed into to build this source
        # @raise [RuntimeError] if the @extension for the @file isn't currently handled by the method
        def dirname
          case @extension
          when '.tar.gz', '.tgz'
            return @file.chomp(@extension)
          when '.gem'
            # Because we cd into the source dir, using ./ here avoids special casing gems in the Makefile
            return './'
          else
            fail "Don't know how to guess dirname for '#{@file}' with extension: '#{@extension}'. Please teach me."
          end
        end
      end
    end
  end
end