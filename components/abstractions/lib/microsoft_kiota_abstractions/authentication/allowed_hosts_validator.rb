# frozen_string_literal: true

require 'uri'

module MicrosoftKiotaAbstractions
  # Maintains a list of valid hosts and allows authentication providers to check whether
  # a host is valid before authenticating a request
  class AllowedHostsValidator
    LOCALHOST_STRINGS = ['localhost', '::1', '[::1]', '127.0.0.1'].freeze

    # creates a new AllocatedHostsValidator with provided values
    def initialize(allowed_hosts)
      self.allowed_hosts = allowed_hosts
    end

    # sets the list of valid hosts with provided value (val)
    def allowed_hosts=(val)
      if val.nil? || (val.respond_to?(:empty?) && val.empty?)
        @allowed_hosts = {}
        return
      end

      hosts = {}
      val.each do |host|
        next if host.nil?

        cleaned = host.to_s.strip
        next if cleaned.empty?

        raise ArgumentError, "host should not contain http or https prefix: #{cleaned}" if cleaned.match?(%r{\Ahttps?://}i)

        hosts[cleaned.downcase] = true
      end

      raise ArgumentError, 'allowed_hosts must contain at least one valid host when provided as a non-empty list' if hosts.empty?

      @allowed_hosts = hosts
    end

    # checks whether the provided host is valid
    def url_host_valid?(url)
      return false if url.nil? || (url.respond_to?(:empty?) && url.empty?)

      begin
        parsed_url = URI(url.respond_to?(:strip) ? url.strip : url)
      rescue URI::InvalidURIError, ArgumentError
        return false
      end

      return false if parsed_url.host.nil?

      is_https = parsed_url.is_a?(URI::HTTPS)
      is_http_localhost = parsed_url.is_a?(URI::HTTP) && localhost?(parsed_url)
      return false unless is_https || is_http_localhost

      return true if @allowed_hosts.empty?

      host = parsed_url.host.downcase
      return true if @allowed_hosts.key?(host)

      stripped_host = host.delete_prefix('[').delete_suffix(']')
      return true if @allowed_hosts.key?(stripped_host)

      hostname = (parsed_url.hostname || host).downcase
      return true if @allowed_hosts.key?(hostname)

      @allowed_hosts.any? { |allowed_host, _| allowed_host.start_with?('.') && hostname.end_with?(allowed_host) }
    end

    # checks whether the host in the parsed url is a loopback/localhost address
    def localhost?(parsed_url)
      host = parsed_url.host
      return false if host.nil?

      return true if LOCALHOST_STRINGS.include?(host.downcase)

      hostname = parsed_url.hostname
      return false if hostname.nil?

      LOCALHOST_STRINGS.include?(hostname.downcase)
    end

    # gets the list of valid hosts
    attr_reader :allowed_hosts
  end
end
