module Capybara
  class Selector
    class << self
      def all
        @selectors ||= []
      end

      def add(klass)
        all << klass
      end

      def remove(name)
        all.reject! { |klass| klass.name == name }
      end

      def find(name)
        all.find { |klass| klass.name == name.to_sym }
      end

      def normalize(*args)
        klass = if args.length == 3 || args.length == 2 && !args.last.is_a?(Hash)
          find(args.shift)
        else
          all.find { |s| s.match?(args[0]) }
        end

        klass ||= find(Capybara.default_selector)
        klass.new(*args)
      end
    end

    class Base
      attr_accessor :locator, :options

      class << self
        attr_accessor :name

        def inherited(klass)
          Capybara::Selector.add(klass)
        end

        def match?(locator)
          false
        end
      end

      def initialize(locator, options = {})
        self.locator = locator
        self.options = options
      end

      def xpath
      end

      def filter(node)
        true
      end

      def failure_message(node)
        "Unable to find #{name} #{locator.inspect}"
      end

      def xpaths
        x = xpath
        if x.respond_to?(:to_xpaths)
          x.to_xpaths
        else
          [x.to_s].flatten
        end
      end

      def name
        self.class.name
      end
    end

    module FilterByText
      def initialize(locator, options = {})
        @property_options ||= {}
        text = options.delete(:text)
        @property_options[:text] = if text.kind_of?(String) then Regexp.escape(text) else text end
        super
      end

      def filter(node)
        return false if @property_options[:text] and not node.text.match(@property_options[:text])
        super
      end
    end

    module FilterByVisibility
      def initialize(locator, options = {})
        @property_options ||= {}
        visible = options.delete(:visible)
        @property_options[:visible] = if visible.nil? then Capybara.ignore_hidden_elements else visible end
        super
      end

      def filter(node)
        return false if @property_options[:visible] and not node.visible?
        super
      end
    end

    module FilterByValue
      def initialize(locator, options = {})
        @property_options ||= {}
        @property_options[:with] = options.delete(:with)
        super
      end

      def filter(node)
        return false if @property_options[:with] and not node.value == @property_options[:with]
        super
      end
    end

    module FilterByChecked
      def initialize(locator, options = {})
        @property_options ||= {}
        @property_options[:checked] = options.delete(:checked)
        super
      end

      def filter(node)
        return false if @property_options[:checked] and not node.checked?
        super
      end
    end

    module FilterByUnchecked
      def initialize(locator, options = {})
        @property_options ||= {}
        @property_options[:unchecked] = options.delete(:unchecked)
        super
      end

      def filter(node)
        return false if @property_options[:unchecked] and node.checked?
        super
      end
    end

    module FilterBySelected
      def initialize(locator, options = {})
        @property_options ||= {}
        selected = options.delete(:selected)
        @property_options[:selected] = [selected].flatten unless selected.nil?
        super
      end

      def filter(node)
        return false if @property_options[:selected] and not has_selected_options?(node, @property_options[:selected])
        super
      end

      private

      def has_selected_options?(node, expected)
        actual = node.all(:xpath, './/option').select { |option| option.selected? }.map { |option| option.text }
        (expected - actual).empty?
      end
    end

    class XPathSelector < Base
      include FilterByVisibility
      include FilterByText

      self.name = :xpath

      def xpath
        locator
      end
    end

    class CSSSelector < Base
      include FilterByVisibility
      include FilterByText

      self.name = :css

      def xpath
        XPath.css(locator)
      end
    end

    class IDSelector < Base
      include FilterByVisibility
      self.name = :id

      def self.match?(value)
        value.is_a?(Symbol)
      end

      def xpath
        XPath.descendant[XPath.attr(:id) == locator.to_s]
      end
    end

    class FieldSelector < Base
      include FilterByVisibility
      include FilterByValue
      include FilterByChecked
      include FilterByUnchecked
      include FilterBySelected

      self.name = :field

      def xpath
        XPath::HTML.field(locator)
      end
    end

    class FieldsetSelector < Base
      include FilterByVisibility
      include FilterByText

      self.name = :fieldset

      def xpath
        XPath::HTML.fieldset(locator)
      end
    end

    class LinkOrButtonSelector < Base
      include FilterByVisibility
      include FilterByText
      include FilterByValue

      self.name = :link_or_button

      def xpath
        XPath::HTML.link_or_button(locator)
      end

      def failure_message(node)
        "no link or button '#{locator}' found"
      end
    end

    class LinkSelector < Base
      include FilterByVisibility
      include FilterByText

      self.name = :link

      def xpath
        XPath::HTML.link(locator, options)
      end

      def failure_message(node)
        "no link with title, id or text '#{locator}' found"
      end
    end

    class ButtonSelector < Base
      include FilterByVisibility
      include FilterByText
      include FilterByValue

      self.name = :button

      def xpath
        XPath::HTML.button(locator)
      end

      def failure_message(node)
        "no button with value or id or text '#{locator}' found"
      end
    end

    class FillableFieldSelector < Base
      include FilterByVisibility
      include FilterByValue

      self.name = :fillable_field

      def xpath
        XPath::HTML.fillable_field(locator, options)
      end

      def failure_message(node)
        "no text field, text area or password field with id, name, or label '#{locator}' found"
      end
    end

    class RadioButtonSelector < Base
      include FilterByVisibility
      include FilterByValue

      self.name = :radio_button

      def xpath
        XPath::HTML.radio_button(locator, options)
      end

      def failure_message(node)
        "no radio button with id, name, or label '#{locator}' found"
      end
    end

    class CheckboxSelector < Base
      include FilterByVisibility
      include FilterByValue
      include FilterByChecked
      include FilterByUnchecked

      self.name = :checkbox

      def xpath
        XPath::HTML.checkbox(locator, options)
      end

      def failure_message(node)
        "no checkbox with id, name, or label '#{locator}' found"
      end
    end

    class SelectSelector < Base
      include FilterByVisibility
      include FilterBySelected

      self.name = :select

      def xpath
        XPath::HTML.select(locator, options)
      end

      def failure_message(node)
        "no select box with id, name, or label '#{locator}' found"
      end
    end

    class OptionSelector < Base
      include FilterByVisibility
      include FilterByValue

      self.name = :option

      def xpath
        XPath::HTML.option(locator)
      end

      def failure_message(node)
        "no option with text '#{locator}'".tap do |message|
          message << " in the select box" if node.tag_name == 'select'
        end
      end
    end

    class FileFieldSelector < Base
      include FilterByVisibility

      self.name = :file_field

      def xpath
        XPath::HTML.file_field(locator, options)
      end

      def failure_message(node)
        "no file field with id, name, or label '#{locator}' found"
      end
    end

    class ContentSelector < Base
      self.name = :content

      def xpath
        XPath::HTML.content(locator)
      end
    end

    class TableSelector < Base
      include FilterByVisibility

      self.name = :table

      def xpath
        XPath::HTML.table(locator, options)
      end
    end
  end
end

