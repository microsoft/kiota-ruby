# frozen_string_literal: true

require_relative 'lib/microsoft_kiota_abstractions/version'

Gem::Specification.new do |spec|
  spec.name          = 'microsoft_kiota_abstractions'
  spec.version       = MicrosoftKiotaAbstractions::VERSION
  spec.authors       = 'Microsoft Corporation'
  spec.email         = 'graphsdkpub+ruby@microsoft.com'
  spec.description   = 'Microsoft Kiota Abstractions - Ruby abstractions for building library agnostic http client'
  spec.summary       = 'The Kiota abstractions are language specific libraries defining the basic constructs Kiota projects need once an SDK has been generated from an OpenAPI definition.'
  spec.homepage      = 'https://learn.microsoft.com/openapi/kiota/'
  spec.license       = 'MIT'
  spec.metadata      = {
    'bug_tracker_uri' => 'https://github.com/microsoft/kiota-ruby/issues',
    'changelog_uri' => 'https://github.com/microsoft/kiota-ruby/blob/main/CHANGELOG.md',
    'homepage_uri' => spec.homepage,
    'source_code_uri' => 'https://github.com/microsoft/kiota-ruby/tree/main/components/abstractions',
    'github_repo' => 'ssh://github.com/microsoft/kiota-ruby',
    'rubygems_mfa_required' => 'true'
  }
  spec.required_ruby_version = '>= 3.3.0'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.add_dependency 'iso8601', '~> 0.13.0'
  spec.add_dependency 'stduritemplate', '>= 2.0.13', '< 2.1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
end
