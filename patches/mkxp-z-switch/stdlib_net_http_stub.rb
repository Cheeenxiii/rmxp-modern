# SPDX-FileCopyrightText: 2026 Cheeenxiii
# SPDX-License-Identifier: MIT

# disabled: this build has no usable net/http. Reborn requires it at startup
# for its updater: mark the feature as loaded and answer every request with a
# normal "503 Service Unavailable", so the updater logs "unable to get the
# latest version" and returns no update. No connection is ever attempted.
#
# The updater also needs URI(): Reborn ships Ruby's stdlib, but on mkxp-z the
# game's stdlib directory is added to $LOAD_PATH after the preloads run, so
# `require "uri"` fails here. Reuse the real library when the target has it;
# otherwise provide the few methods the updater uses (URI(), #host, #port and
# #scheme). It never calls URI.open or URI#read, so this shim does not pretend
# to open resources.

begin
  require "net/http"
rescue LoadError
end

unless defined?(::URI)
  begin
    require "uri"
  rescue LoadError
  end
end

unless defined?(::URI)
  module URI
    # Result of URI.parse for the updater. Not URI::Generic: if the real uri
    # library is loaded later, it reopens this module without a name clash.
    class Parsed
      attr_reader :scheme, :host, :port, :path

      def initialize(string)
        text = string.to_s
        scheme, rest = text.split("://", 2)
        if rest
          @scheme = scheme.downcase
        else
          rest = text
          @scheme = nil
        end
        authority, path = rest.split("/", 2)
        @host, port = authority.split(":", 2)
        @port = port ? port.to_i : (@scheme == "https" ? 443 : 80)
        @path = path ? "/" + path.split(/[?#]/, 2).first.to_s : ""
      end
    end

    def self.parse(string)
      Parsed.new(string)
    end
  end

  module Kernel
    # Same contract as uri/common.rb: URI("http://...") parses a string.
    def URI(uri)
      ::URI.parse(uri)
    end
    module_function :URI
  end
end

unless defined?(::Net::HTTP)
  module Net
    class HTTP
      class Get
        def initialize(*_args); end
      end

      # Just enough of a response for code that checks the HTTP status.
      class Response
        attr_reader :code, :body

        def initialize
          @code = "503"
          @body = ""
        end

        def [](_header)
          nil
        end

        def read_body; end
      end

      def self.start(*_args)
        http = new
        block_given? ? yield(http) : http
      end

      def open_timeout=(_seconds); end

      def read_timeout=(_seconds); end

      def request(_request)
        response = Response.new
        block_given? ? yield(response) : response
      end
    end
  end
end

$LOADED_FEATURES << "net/http.rb" unless $LOADED_FEATURES.include?("net/http.rb")
