# frozen_string_literal: true

module MicrosoftKiotaAbstractions
  class RequestHeaders
    def initialize
      @headers = {}
    end

    def add(key, value)
      if key.nil? || key.to_s.empty? || value.nil? || (value.respond_to?(:empty?) && value.empty?)
        raise ArgumentError, 'key and value cannot be nil or empty'
      end

      key = key.to_s
      existing_key = find_key(key)
      if existing_key.nil?
        @headers[key] = if value.is_a?(Array)
                          value.map(&:to_s)
                        else
                          [value.to_s]
                        end
      elsif value.is_a?(Array)
        @headers[existing_key] = @headers[existing_key] | value.map(&:to_s)
      else
        @headers[existing_key] = @headers[existing_key] | [value.to_s]
      end
    end

    def try_add(key, value)
      if key.nil? || key.to_s.empty? || value.nil? || (value.respond_to?(:empty?) && value.empty?)
        raise ArgumentError, 'key and value cannot be nil or empty'
      end

      key = key.to_s
      existing_key = find_key(key)
      return false if existing_key && !@headers[existing_key].empty?

      @headers[existing_key || key] = if value.is_a?(Array)
                                        value.map(&:to_s)
                                      else
                                        [value.to_s]
                                      end
      true
    end

    def get(key)
      raise ArgumentError, 'key cannot be nil or empty' if key.nil? || key.to_s.empty?

      existing_key = find_key(key.to_s)
      existing_key ? @headers[existing_key] : nil
    end

    def remove(key)
      raise ArgumentError, 'key cannot be nil or empty' if key.nil? || key.to_s.empty?

      existing_key = find_key(key.to_s)
      @headers.delete(existing_key) if existing_key
    end

    def key?(key)
      return false if key.nil? || key.to_s.empty?

      !find_key(key.to_s).nil?
    end

    def clear
      @headers.clear
    end

    def get_all
      @headers
    end

    def add_all(other)
      return if other.nil?

      if other.respond_to?(:get_all)
        other.get_all.each { |k, v| add(k.to_s, v) }
      elsif other.is_a?(Hash)
        other.each { |k, v| add(k.to_s, v) }
      end
    end

    private

    def find_key(key)
      return key if @headers.key?(key)

      key_str = key.to_s
      return key_str if @headers.key?(key_str)

      @headers.keys.find { |k| k.to_s.casecmp?(key_str) }
    end
  end
end
