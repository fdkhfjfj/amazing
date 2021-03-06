# Copyright 2008 Dag Odenhall <dag.odenhall@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'amazing/helpers/lazy_data'
require 'amazing/helpers/pango_markup'
require 'erb'

module Amazing

  # Raised by widgets, and is then rescued and logged
  class WidgetError < Exception
  end

  # Parent class for widget construction, example:
  #
  #   class Clock < Widget
  #     description "Displays date and time"
  #     dependency "some/library", "how to get the library (url, gem name...)"
  #     option :time_format, "Time format as described in DATE(1)", "%R"
  #     field :time, "Formatted time"
  #     default "@time"
  # 
  #     init do
  #       @time = Time.now.strftime(@time_format)
  #       raise WidgetError, "An error occured!" if some_error?
  #     end
  #   end
  class Widget
    include Helpers::LazyData
    include Helpers::PangoMarkup
    include ERB::Util

    def initialize(opts={})
      self.class.dependencies.each do |name, description|
        begin
          require name
        rescue LoadError
          begin
            require 'rubygems'
            require name
          rescue LoadError
            raise WidgetError, "Missing dependency #{name.inspect}#{if description then " [#{description}]" end}"
          end
        end
      end
      self.class.options.each do |key, value|
        instance_variable_set "@#{key}".to_sym, value[:default]
      end
      opts.each do |key, value|
        instance_variable_set "@#{key}".to_sym, value
      end
      self.class.fields.each do |key, value|
        instance_variable_set "@#{key}".to_sym, value[:default]
      end
      self.class.init.each do |block|
        instance_eval(&block)
      end
      @default = case self.class.default
      when Proc
        instance_eval(&self.class.default)
      when String
        instance_eval(self.class.default)
      end
    end

    def self.description(description=nil)
      if description
        @description = description
      else
        @description
      end
    end

    def self.dependency(name, description=nil)
      @dependencies ||= {}
      @dependencies[name] = description
    end

    def self.dependencies
      @dependencies || {}
    end

    def self.option(name, description=nil, default=nil)
      @options ||= {}
      @options[name] = {:description => description, :default => default}
    end

    def self.options
      @options || {}
    end

    def self.field(name, description=nil, default=nil)
      @fields ||= {}
      @fields[name] = {:description => description, :default => default}
    end

    def self.fields
      @fields || {}
    end

    def self.default(format=nil, &block) # :yields:
      if format
        @default = format
      elsif block
        @default = block
      else
        @default
      end
    end

    def self.init(&block) # :yields:
      if block
        @init ||= []
        @init << block
      else
        @init
      end
    end

    def formatize(format=nil)
      ERB.new(case format
      when Proc
        instance_eval(&format)
      when String
        instance_eval(format)
      else
        case self.class.default
        when Proc
          instance_eval(&self.class.default)
        when String
          instance_eval(self.class.default)
        end
      end.to_s).result(binding())
    end
  end
end
