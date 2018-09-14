require_relative 'shared_libraries_widget'
require_relative 'binary_strings_widget'
require_relative 'weak_class_dump_widget'
require_relative 'classdump_dyld_widget'

module Idb
  class AppBinaryTabWidget < Qt::TabWidget
    def initialize(*args)
      super(*args)

      @tabs = {}

      @shared_libs = SharedLibrariesWidget.new self
      @tabs[:@shared_libs] = addTab(@shared_libs, "Shared Libraries")

      @strings = BinaryStringsWidget.new self
      @tabs[:strings] = addTab(@strings, "Strings")

      @weak_class_dump = WeakClassDumpWidget.new self
      @tabs[:weak_class_dump] = addTab(@weak_class_dump, "Weak Class Dump")

      @classdump_dyld = ClassdumpDyldWidget.new self
      @tabs[:classdump_dyld] = addTab(@classdump_dyld, "classdump-dyld")
    end

    def clear
      @tabs.each(&:clear)
    end

    def refresh_current_tab
      puts "Refreshing current tab in App binary tab"
    end

    def refresh
    end

    def enable_tabs
      @shared_libs.setEnabled(true)
      setTabEnabled(@tabs[:@shared_libs], true)
    end
  end
end
