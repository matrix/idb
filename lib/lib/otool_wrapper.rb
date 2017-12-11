require 'awesome_print'

module Idb
  class OtoolWrapper
    attr_accessor :load_commands, :shared_libraries, :pie, :arc, :canaries

    def initialize(binary)
      @otool_path = Pathname.new("/usr/bin/otool")
      if(!@otool_path.exist?)
        @otool_path = Pathname.new("/usr/local/bin/otool")
        if(!@otool_path.exist?)
          $log.error "otool not available. Some functions will not work properly."
          error = Qt::MessageBox.new
          msg = "This feature requires  otool to be installed on the host running idb." \
                " This is the default on OS X but it may not be available for other platforms."
          error.setInformativeText(msg)
          error.setIcon(Qt::MessageBox::Critical)
          error.exec
          @otool_path = nil

          return
        end
      end

      @binary = binary
      parse_load_commands
      parse_shared_libraries
      parse_header
      process_symbol_table
    end

    private

    def parse_shared_libraries
      if @otool_path.nil?
        @shared_libraries = []
        @shared_libraries << "Error; otool not available"
        return
      end
      @raw_shared_libraries_output = `#{@otool_path} -L '#{@binary}'`
      lines = @raw_shared_libraries_output.split("\n")
      @shared_libraries = lines[1, lines.size].map(&:strip) unless lines.nil?
    end

    def process_symbol_table
      if @otool_path.nil?
        @canaries = "Error"
        @arc = "Error"
        return
      end
      symbols = `#{@otool_path} -I -v '#{@binary}'`
      @canaries = if symbols.include?("stack_chk_fail") || symbols.include?("stack_chk_guard")
                    true
                  else
                    false
                  end

      @arc = if symbols.include? "_objc_release"
               true
             else
               false
             end
    end

    def hashify_otool_output(otool_output)
      # otool output may contain multiple mach headers
      mach_headers = otool_output.split("Mach header\n").map(&:strip)

      # The newest otool version no longer echos the path of the binary being
      # inspected. Here we reject that line if it shows up in the output of
      # otool as well as any blank lines
      mach_headers.reject! { |line| (line == "") || line.include?(@binary) }

      # convert otool output to a hash
      mach_headers.map do |mach_header|
        mach_hash = {}
        headers, values = mach_header.split("\n").map(&:split)
        headers.each_with_index do |header, index|
          mach_hash[header] = values[index]
        end
        mach_hash
      end
    end

    def parse_header
      if @otool_path.nil?
        @pie = "Error"
        return
      end
      pie_flag = 0x00200000
      @raw_load_output = `#{@otool_path} -h '#{@binary}'`

      mach_hashes = hashify_otool_output(@raw_load_output)
      $log.info "Mach Hashes: #{mach_hashes}"

      # extract the Position Independent Executable (PIE) flag from the flags
      # value.
      mach_hashes.each do |mach_hash|
        @pie = if (mach_hash["flags"].to_i(16) & pie_flag) == pie_flag
                 true
               else
                 false
               end
      end
    end

    def parse_load_commands
      if @otool_path.nil?
        @load_commands = nil
        return
      end
      @raw_load_output = `#{@otool_path} -l '#{@binary}'`
      regex_cmd = /Load command (\d+)/
      regex_parse_key_vals = /\s*(cmd|cryptid)\s(.+)/

      @load_commands = {}

      @raw_load_output.split("\n").each do |line|
        if (match = regex_cmd.match(line))
          @load_commands[@cmd] = @command unless @cmd.nil?
          @cmd = match[1]
          @command = {}
        end

        if (match = regex_parse_key_vals.match(line))
          @command[match[1]] = match[2]
        end
      end
    end
  end
end
