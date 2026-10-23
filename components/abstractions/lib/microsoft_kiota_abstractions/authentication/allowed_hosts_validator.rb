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
      hosts = {}
      val.each do |host|
        raise ArgumentError, "host should not contain http or https prefix: #{host}" if host.match?(%r{\Ahttps?://}i)

        hosts[host.downcase] = true
      end
      @allowed_hosts = hosts
    end

    # checks whether the provided host is valid
    def url_host_valid?(url)
      return false if url.nil?

      parsed_url = URI(url)
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
    rescue URI::InvalidURIError
      false
    end

    # gets the list of valid hosts
    attr_reader :allowed_hosts

    private

    def localhost?(parsed_url)
      host = parsed_url.host
      return false if host.nil?

      return true if LOCALHOST_STRINGS.include?(host.downcase)

      hostname = parsed_url.hostname
      return false if hostname.nil?

      LOCALHOST_STRINGS.include?(hostname.downcase)
    end
  end
end
