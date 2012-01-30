require 'active_resource'
module AirbrakeSymbolicate
  class DsymFinder
    @@dsyms = nil
    
    class << self
      def dsym_for_error(error)
        find_dsyms  unless @@dsyms
        
        @@dsyms[error.environment.git_commit] || @@dsyms[error.environment.application_version]
      end
      
      private 
      
      # use spotlight to find all the xcode archives
      # then use the Info.plist inside those archives to try and look up a git commit hash
      def find_dsyms
        @@dsyms = {}
        
        files = `mdfind 'kMDItemKind = "Xcode Archive"'`.split("\n")
        files.each do |f|
          # puts `ls '#{f.chomp}'`
          info = `find '#{f}/Products' -name Info.plist`.chomp
          
          if commit = plist_val(info, 'GCGitCommitHash')
            if bin_file = Dir[File.join(f, '/dSYMs/*.dSYM/**/DWARF/*')].first
              @@dsyms[commit] = bin_file
            end
          else
            short_version = plist_val(info, 'CFBundleShortVersionString')
            long_version = plist_val(info, 'CFBundleVersion')
            # this is the format in HTApplicationVersion() in hoptoad-ios 
            @@dsyms["#{CFBundleShortVersionString} (#{CFBundleVersion})"] = bin_file
          end
        end
      end
      
      def plist_val(plist, key)
        `/usr/libexec/PlistBuddy -c 'Print :#{key}' '#{plist}' 2>/dev/null`.chomp
      end
    end
  end
  
  class Symbolicator
    class << self
      def symbolicated_backtrace(error)
        if dsym = DsymFinder.dsym_for_error(error)
          error.backtrace.line.map {|l| Symbolicator.symbolicate_line(dsym, l)}
        end
      end
      
      def symbolicate_line(dsym_file, line)
        binname = File.basename(dsym_file)
        if line[/#{binname}/] && loc = line[/0x\w+/]
          `/usr/bin/atos -arch armv7 -o "#{dsym_file}" #{loc}`.sub(/^[-_]+/, '')
        else
          line
        end.chomp
      end
    end
  end
  
  class Airbrake < ActiveResource::Base
    cattr_accessor :auth_token

    class << self
      def account=(a)
        self.site = "https://#{a}.airbrake.io/" if a
        self.format = ActiveResource::Formats::XmlFormat
      end
      
      def find(*arguments)
        arguments = append_auth_token_to_params(*arguments)
        super(*arguments)
      end

      def append_auth_token_to_params(*arguments)
        raise RuntimeError.new("Airbrake.auth_token must be set!") if !auth_token
        
        opts = arguments.last.is_a?(Hash) ? arguments.pop : {}
        opts = opts.has_key?(:params) ? opts : opts.merge(:params => {})
        opts[:params] = opts[:params].merge(:auth_token => auth_token)
        arguments << opts
        arguments
      end
    end
    
  end
  
  class Error < Airbrake  
  end
  
end
