require 'guard'
require 'guard/guard'
require 'guard/watcher'
require 'puppet-lint'

class PuppetLint

  attr_reader :messages

  def clear_messages
    @messages = []
  end

  def format_message(message)
    @messages << (log_format % message)
  end
end

module Guard
  class Puppetlint < Guard

    def initialize(watchers = [], options = {})
      options = { :syntax_check => true }.merge(options)
      @linter = PuppetLint.new
      super
    end

    # Calls #run_all if the :all_on_start option is present.
    def start
      run_all if options[:all_on_start]
    end

    # Call #run_on_change for all files which match this guard.
    def run_all
      run_on_change(Watcher.match_files(self, Dir.glob('{,**/}*{,.*}').uniq))
    end

    def prepend_filename(msg, file)
      if msg
        msg.map {|x| "#{file}: #{x}"}
      else
        []
      end
    end

    # Print the result of the command(s), if there are results to be printed.
    def run_on_change(res)
      messages = []
      res.each do |file|
        file = File.join( options[:watchdir].to_s,file ) if options[:watchdir]

        if options[:syntax_check]
          parser_messages = `puppet parser validate #{file} --color=false`.split("\n")
          parser_messages.reject! { |s| s =~ /puppet help parser validate/ }
          parser_messages.map! { |s| s.gsub 'err: Could not parse for environment production:', '' }

          messages += prepend_filename(parser_messages, file)
        end

        @linter.file = file
        @linter.clear_messages
        @linter.run
        linter_msg = @linter.messages.reject { |s| !options[:show_warnings] && s =~ /WARNING/ }
        messages += prepend_filename(linter_msg, file)
      end
      if messages.empty?
        messages = ["Files are ok:"] + res
        image = :success
      else
        image = :failed
      end
      Notifier.notify( messages.join("\n"), :title => "Puppet lint", :image => image )
    end
  end
end
