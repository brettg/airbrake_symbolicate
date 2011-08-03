require 'active_resource'
module AirbrakeSymbolicate
  class DsymFinder
    @@dyms = nil
    
    class << self
      def dsym_for_commit(commit_hash)
        find_dsyms  unless @@dyms
        
        @@dyms[commit_hash]
      end
      
      private 
      
      # use spotlight to find all the xcode archives
      # then use the Info.plist inside those archives to try and look up a git commit hash
      def find_dsyms
        @@dyms = {}
        
        files = `mdfind 'kMDItemKind = "Xcode Archive"'`.split("\n")
        files.each do |f|
          # puts `ls '#{f.chomp}'`
          info = `find '#{f}/Products' -name Info.plist`.chomp
          hash = `/usr/libexec/PlistBuddy -c 'Print :GCGitCommitHash' '#{info}' 2>/dev/null`.chomp
          if hash
            if bin_file = Dir[File.join(f, '/dSYMs/*.dSYM/**/DWARF/*')].first
              @@dyms[hash] = bin_file
            end
          end
        end
      end
    end
  end
  
  class Symbolicator
    class << self
      def symbolicated_backtrace(error)
        if dsym = DsymFinder.dsym_for_commit(error.environment.git_commit)
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
  
  class Hoptoad < ActiveResource::Base
    cattr_accessor :auth_token

    class << self
      def account=(a)
        self.site = "http://#{a}.airbrakeapp.com/" if a
      end
      
      def find(*arguments)
        arguments = append_auth_token_to_params(*arguments)
        super(*arguments)
      end

      def append_auth_token_to_params(*arguments)
        raise RuntimeError.new("Hoptoad.auth_token must be set!") if !auth_token
        
        opts = arguments.last.is_a?(Hash) ? arguments.pop : {}
        opts = opts.has_key?(:params) ? opts : opts.merge(:params => {})
        opts[:params] = opts[:params].merge(:auth_token => auth_token)
        arguments << opts
        arguments
      end
    end
    
  end
  
  class Error < Hoptoad  
  end
  
end
