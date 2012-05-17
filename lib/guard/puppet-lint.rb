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

    # Print the result of the command(s), if there are results to be printed.
    def run_on_change(res)
      messages = []
      res.each do |file|
        @linter.file = file
        @linter.clear_messages
        @linter.run
        linter_msg = @linter.messages.reject { |s| !options[:show_warnings] && s =~ /WARNING/ }
        messages += linter_msg.map {|x| "#{file}: #{x}"} if linter_msg
      end
      Notifier.notify( messages.join("\n"), :title => "Puppet lint", :image => :failed )
    end
  end
end
