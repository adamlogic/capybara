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
      attr_accessor :locator, :options, :xpath_options, :property_options

      class << self
        attr_accessor :name
      end

      def self.inherited(klass)
        Capybara::Selector.add(klass)
      end

      def self.match?(locator)
        false
      end

      def initialize(locator, options = {})
        self.locator = locator
        self.options = options
        self.xpath_options, self.property_options = split_options(options)
      end

      def xpath
      end

      def failure_message(node)
        "Unable to find #{self.class.name} #{locator.inspect}"
      end

      def filter(node)
        return false if property_options[:text]      and not node.text.match(property_options[:text])
        return false if property_options[:visible]   and not node.visible?
        return false if property_options[:with]      and not node.value == property_options[:with]
        return false if property_options[:checked]   and not node.checked?
        return false if property_options[:unchecked] and node.checked?
        return false if property_options[:selected]  and not has_selected_options?(node, property_options[:selected])
        true
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

      private

      def split_options(options)
        xpath_options    = options.dup
        property_options = [:text, :visible, :with, :checked, :unchecked, :selected].inject({}) do |opts, key|
          opts[key] = xpath_options.delete(key) if xpath_options.has_key?(key)
          opts
        end

        if text = property_options[:text]
          property_options[:text] = Regexp.escape(text) unless text.kind_of?(Regexp)
        end

        if !property_options.has_key?(:visible)
          property_options[:visible] = Capybara.ignore_hidden_elements
        end

        if selected = property_options[:selected]
          property_options[:selected] = [selected].flatten
        end

        [ xpath_options, property_options ]
      end

      def has_selected_options?(node, expected)
        actual = node.all(:xpath, './/option').select { |option| option.selected? }.map { |option| option.text }
        (expected - actual).empty?
      end
    end

    class XPathSelector < Base
      self.name = :xpath

      def xpath
        locator
      end
    end

    class CSSSelector < Base
      self.name = :css

      def xpath
        XPath.css(locator)
      end
    end

    class IDSelector < Base
      self.name = :id

      def self.match?(value)
        value.is_a?(Symbol)
      end

      def xpath
        XPath.descendant[XPath.attr(:id) == locator.to_s]
      end
    end

    class FieldSelector < Base
      self.name = :field

      def xpath
        XPath::HTML.field(locator)
      end
    end

    class FieldsetSelector < Base
      self.name = :fieldset

      def xpath
        XPath::HTML.fieldset(locator)
      end
    end

    class LinkOrButtonSelector < Base
      self.name = :link_or_button

      def xpath
        XPath::HTML.link_or_button(locator)
      end

      def failure_message(node)
        "no link or button '#{locator}' found"
      end
    end

    class LinkSelector < Base
      self.name = :link

      def xpath
        XPath::HTML.link(locator, xpath_options)
      end

      def failure_message(node)
        "no link with title, id or text '#{locator}' found"
      end
    end

    class ButtonSelector < Base
      self.name = :button

      def xpath
        XPath::HTML.button(locator)
      end

      def failure_message(node)
        "no button with value or id or text '#{locator}' found"
      end
    end

    class FillableFieldSelector < Base
      self.name = :fillable_field

      def xpath
        XPath::HTML.fillable_field(locator, xpath_options)
      end

      def failure_message(node)
        "no text field, text area or password field with id, name, or label '#{locator}' found"
      end
    end

    class RadioButtonSelector < Base
      self.name = :radio_button

      def xpath
        XPath::HTML.radio_button(locator, xpath_options)
      end

      def failure_message(node)
        "no radio button with id, name, or label '#{locator}' found"
      end
    end

    class CheckboxSelector < Base
      self.name = :checkbox

      def xpath
        XPath::HTML.checkbox(locator, xpath_options)
      end

      def failure_message(node)
        "no checkbox with id, name, or label '#{locator}' found"
      end
    end

    class SelectSelector < Base
      self.name = :select

      def xpath
        XPath::HTML.select(locator, xpath_options)
      end

      def failure_message(node)
        "no select box with id, name, or label '#{locator}' found"
      end
    end

    class OptionSelector < Base
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
      self.name = :file_field

      def xpath
        XPath::HTML.file_field(locator, xpath_options)
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
      self.name = :table

      def xpath
        XPath::HTML.table(locator, xpath_options)
      end
    end
  end
end

