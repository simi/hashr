require 'hashr/core_ext/ruby/hash'

class Hashr < Hash
  autoload :EnvDefaults, 'hashr/env_defaults'

  TEMPLATE = new

  class << self
    attr_accessor :raise_missing_keys

    def define(definition)
      @definition = definition.deep_symbolize_keys
    end

    def definition
      @definition ||= {}
    end

    def default(defaults)
      @defaults = defaults
    end

    def defaults
      @defaults ||= {}
    end
  end

  def initialize(data = {}, definition = self.class.definition, &block)
    replace((deep_hashrize(definition.deep_merge((data || {}).deep_symbolize_keys))))
    deep_defaultize(self)
    (class << self; self; end).class_eval(&block) if block_given?
  end

  def []=(key, value)
    super(key, value.is_a?(Hash) ? self.class.new(value, {}) : value)
  end

  def respond_to?(name)
    true
  end

  def method_missing(name, *args, &block)
    case name.to_s[-1, 1]
    when '?'
      !!self[name.to_s[0..-2].to_sym]
    when '='
      self[name.to_s[0..-2].to_sym] = args.first
    else
      raise(IndexError.new("Key #{name.inspect} is not defined.")) if !key?(name) && self.class.raise_missing_keys
      self[name]
    end
  end

  def include_modules(modules)
    Array(modules).each { |mod| meta_class.send(:include, mod) } if modules
  end

  def include_accessors(accessors)
    Array(accessors).each { |accessor| meta_class.send(:define_method, accessor) { self[accessor] } } if accessors
  end

  def meta_class
    class << self; self end
  end

  protected

    def deep_hashrize(hash)
      hash.inject(TEMPLATE.dup) do |result, (key, value)|
        case key.to_sym
        when :_include
          result.include_modules(value)
        when :_access
          result.include_accessors(value)
        else
          result.store(key.to_sym, value.is_a?(Hash) ? deep_hashrize(value) : value)
        end
        result
      end
    end

    def deep_defaultize(hash)
      self.class.defaults.each do |key, value|
        case key.to_sym
        when :_include
          hash.include_modules(value)
        when :_access
          hash.include_accessors(value)
        end
      end
      hash.each do |key, value|
        deep_defaultize(value) if value.is_a?(Hash)
      end
      hash
    end
end

