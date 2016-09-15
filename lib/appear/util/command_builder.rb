module Appear
  module Util
    # Builds command strings.
    #
    # @example A tmux query command
    #   tmux_panes = CommandBuilder.new(%w(tmux list-panes)).
    #     flags(:a => true, :F => '#{session_name} #{pane_index}')
    #   services.runner.run(tmux_panes.to_a)
    class CommandBuilder
      # @param command [#to_s, Array<#to_s>] the command. Use an array if you
      #   need multiple words before we start listing arguments, eg %w(vagrant
      #   up)
      def initialize(command, opts = {})
        @command = command
        @flags = opts.delete(:flags) || Hash.new { |h, k| h[k] = [] }
        @argv = opts.delete(:argv) || []
        @options = {
          :single_dash_long_flags => false,
          :dashdash_after_flags => false,
        }.merge(opts)
      end

      # Add a flag to this command
      #
      # @param name [#to_s] flag name, eg 'cached' for --cached
      # @param val [Boolean, #to_s] flag value, eg '3fdb21'. Can pass "true"
      #   for boolean, set-only flags.
      # @return self
      def flag(name, val)
        @flags[name] << val
        self
      end

      # Add a bunch of flags at once, using a map of flag => argument.
      #
      # @param flag_map Hash<#to_s, [TrueClass, #to_s, Array<#to_s>]>
      # @return self
      #
      # @example multiple duplicate args
      #   CommandBuilder.new('foo').flags(:o => ['Val1', 'Val2]).to_s
      #   # "foo -o Val1 -o Val2"
      def flags(flag_map)
        flag_map.each do |f, v|
          if v.is_a?(Array)
            v.each do |v_prime|
              flag(f, v_prime)
            end
          else
            flag(f, v)
          end
        end
        self
      end

      # Add arguments to this command. Arguments always come after flags, and
      # may be seperated from flags with -- if you pass :dashdash_after_flags
      # option in the constructor.
      #
      # @param args [Array<#to_s>] args to add
      def args(*args)
        @argv.concat(args)
        self
      end

      # Add a subcommand, with its own flags arguments, after the current
      # command. This is useful for eg building calls to nested commands.
      #
      # @example eg, vagrant
      #   v_up = CommandBuilder.new('vagrant').flags(:root => pwd).subcommand('up') do |up|
      #     up.flags(:provider => :virtualbox', 'no-provision' => true).args('apollo')
      #   end
      def subcommand(name, opts = {})
        # use our options as the defaults
        # then use the given options as the overrides
        # finally, override that the parent is this command
        subc = CommandBuilder.new(name, @opts.merge(opts).merge(:parent => self))
        yield(subc)
        args(*subc.to_a)
        self
      end

      # @return [Array<#to_s>] command arguments
      def to_a
        res = [@command].flatten
        @flags.each do |name, params|
          flag = flag_name_to_arg(name)
          params.each do |param|
            res << flag
            res << param.to_s unless param == true
          end
        end
        res << '--' if @options[:dashdash_after_flags]
        res.concat(@argv)
        res.map { |v| v.to_s }
      end

      # @return [String] the command
      def to_s
        to_a.shelljoin
      end

      # Duplicate this command builder
      #
      # @return [CommandBuilder]
      def dup
        opts = @options.dup
        opts[:argv] = @argv.dup
        opts[:flags] = @flags.dup
        self.class.new(@command.dup, opts)
      end

      private

      # @param flag [#to_s]
      # @return [String]
      def flag_name_to_arg(flag)
        if flag.to_s.length == 1 || @options[:single_dash_long_flags]
          "-#{flag}"
        else
          "--#{flag}"
        end
      end
    end
  end
end
