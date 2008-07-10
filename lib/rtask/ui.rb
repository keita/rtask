module RTask::UI
  # Start the user interface.
  def self.start(rtask, name)
    case name
    when :curses
      require "rtask/ui/curses"
      RTask::UI::CursesInterface.new(rtask).start
    end
  end
end
