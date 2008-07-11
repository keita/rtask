require "delegate"
require "cursesx"
require "readline"
require "termios"

module RTask::UI
  class CursesInterface
    include ::Curses

    def initialize(rtask)
      @rtask = rtask
    end

    def start
      # init curses
      init_screen; start_color; cbreak; noecho; nl

      # init color
      define_color :banner, :white, :blue
      define_color :attribute, :blue, :black
      define_color :current_position, :red, :black
      define_color :required, :red, :black
      define_color :usage, :white, :blue

      # start the main window
      @main = stdscr
      @main.instance_variable_set(:@spec, @rtask.spec)
      @main.extend Main
      @main.start
    end

    module Main
      attr_reader :spec

      def self.extended(obj)
        obj.instance_eval do
          @awin = subwin maxy-7, maxx, 4, 0, Attribute
          @bwin = subwin 4, maxx, 0, 0, Banner
          @dwin = subwin 1, maxx, maxy-1, 0, Display
          @uwin = subwin 1, maxx, maxy-2, 0, Usage
        end
      end

      # Start to render main window.
      def start
        draw; @awin.start
      end

      # Draw windows.
      def draw
        clear; children.each {|win| win.draw }
      end

      # Show the message.
      def message(msg); @dwin << msg; end

      # Input.
      def input(msg, val=""); @dwin.input(msg, val); end

      # Wait to input a character.
      def input_char(msg); @dwin.input_char(msg); end
    end

    # Hedding banner.
    module Banner
      def draw
        clear
        attron(color(:banner)) do
          self << "RTask: gemspec editor".center(maxx)
        end
        setpos(2, 0)
        addstr "Edit .gemspec"
        refresh
      end
    end

    # Display window for showing messages.
    module Display
      def draw; clear; end

      # Show the message.
      def <<(msg)
        clear
        setpos(0, 0)
        addstr(msg.to_s.ljust(maxx))
        refresh
      end

      # Wait to input a line.
      def input(msg, val = "")
        clear
        setpos(0, 0)
        refresh

        # setup io config
        tio = Termios.getattr(STDIN)
        tio.lflag |= Termios::ECHO
        Termios.setattr(STDIN, Termios::TCSANOW, tio)

        # read
        Readline::HISTORY << val.to_s
        res = Readline.readline("> #{msg}: ")

        # restore io config
        tio.lflag &= ~Termios::ECHO
        Termios.setattr(STDIN, Termios::TCSANOW, tio)

        return res
      end

      # Wait to input a character.
      def input_char(msg)
        clear
        setpos(0, 0)
        addstr("> #{msg}: ")
        refresh
        return echo { getch }
      end
    end

    # Attribute list window.
    module Attribute

      def self.extended(obj)
        obj.instance_eval do
          # doesn't show all
          @show_all = false
          # gem spec
          @spec = parent.spec
          # displayed top item
          @top = 0
          # selected position
          @position = 0
          # width
          @key_width = @spec.attributes.inject(0) do |m, n|
            m > n.to_s.size ? m : n.to_s.size
          end
          # keypad is ok
          keypad(true)
        end
      end

      def attributes
        @show_all ? @spec.attributes : @spec.standard
      end

      def draw
        clear
        @top.upto(@top+maxy-1) do |idx|
          break unless attributes[idx]
          setpos(idx - @top, 0)
          show_attribute(attributes[idx], @position == idx)
        end
        refresh
      end

      def start
        loop do
          # handles input
          case c = getch
          when ?a; toogle_show_all
          when ?u, ::Curses::KEY_UP     ; up
          when ?d, ::Curses::KEY_DOWN   ; down
          when ?c, ::Curses::KEY_CTRL_J ; change
          when ?b; build_gem
          when ?s; save
          when ?i; IncludedFiles.new(parent.files)
          when ?q; quit
          else
            parent.message "[" + ::Curses.keyname(c).to_s + "]" if $DEBUG
          end

          # redraw
          draw
        end
      end

      # Move up.
      def up
        if @position != 0
          @position -= 1
          @top -= 1 if @top == @position + 1
        end
      end

      # Move down.
      def down
        if @position < attributes.size - 1
          @position += 1
          @top += 1 if @position == @top + maxy
        end
      end

      # Show all items.
      def toogle_show_all
        @show_all = !@show_all
        @top, @position = 0, 0
      end

      # Build the gem.
      def build_gem
        unless RTask::Gem.build(@spec)
          parent.message "You need to fill out all the required fields"
        else
          gemname = "#{@spec.name}-#{@spec.version}.gem"
          parent.message("Created " + gemname)
        end
      end

      def save
        specname = "#{@spec.name}.gemspec"

        # check required attrs
        if Gem::Specification.required_attributes.any? do |sym|
            @spec.send(sym).nil?
          end
          parent.message "You need to fill out all the required fields"
        else
          File.open(specname, "w") do |file|
            file.write @spec.to_ruby
          end
          parent.message "Saved #{specname}"
          @changed = false
        end
      end

      def quit
        if @changed
          res = ::Curses.keyname(parent.input_char(<<-__Q__.chomp))
Changes are not saved. Quit? (y or n)
          __Q__
          return unless res.upcase == "Y"
        end
        exit
      end

      def change
        name = attributes[@position]
        val = parent.spec.send(name)
        res = case @spec.type_of(name)
              when :array
                msg = "#{name.to_s.capitalize}(Split by ',')"
                (parent.input msg, val.join(",")).strip.split(",")
              when :bool
                !val
              when :string
                parent.input name.to_s.capitalize, val
              end
        if name == :dependencies
          parent.spec.dependencies.clear
          res.each {|dep| parent.spec.add_runtime_dependency dep}
        else
          parent.spec.send("#{name}=", res)
        end
        parent.message "Updated '#{name}'"
        @changed = true
      end

      def show_attribute(name, highlight)
        val = @spec.send(name)

        # star
        attron(highlight ? ::Curses::A_UNDERLINE : 0)
        addstr " * "
        addstr name.to_s
        key_width = name.to_s.size

        # required
        if Gem::Specification.required_attribute?(name) and val.nil?
          attron(color(:required)){ addstr " (required)" }
          key_width += 11
        end

        # padding + separator
        addstr " ".rjust(@key_width - key_width + 1)

        # value
        case val
        when Array
          addstr val.join(", ")
        else
          addstr val.to_s
        end unless val.nil?

        attroff(highlight ? ::Curses::A_UNDERLINE : 0)
      end
    end

    module Usage
      def draw
        clear
        setpos(0, 0)
        attron(color(:usage)) do
          addstr " q) Quit, s) Save, b) Build the gem, h) Help".ljust(maxx)
        end
        refresh
      end
    end

    class IncludedFiles < DelegateClass(::Curses::Window)
      def initialize(files)
        @files = files
        window = ::Curses.stdscr
        window.clear
        super(window.subwin(window.maxy, window.maxx, 0, 0))
        draw
        getch
        close
        MAIN_WINDOW.draw
      end

      def draw
        setpos(0, 0)
        standout
        addstr "Manifest(included files)".center(maxx)
        standend
        @files.each_with_index do |file, idx|
          setpos(idx+1, 0)
          addstr file
        end
        refresh
      end
    end

  end
end

