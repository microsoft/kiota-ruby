# Kiota SDK for Ruby

![Ruby](https://github.com/microsoft/kiota-ruby/actions/workflows/ruby.yml/badge.svg)

This repository contains the Ruby libraries for [Kiota](https://github.com/microsoft/kiota)-generated API clients.

## Requirements

Ruby 3.3 or newer is required.

## Components

| Gem | Description | RubyGems |
|-----|-------------|----------|
| [microsoft_kiota_abstractions](components/abstractions/) | Core abstractions for Kiota-generated clients | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_abstractions.svg)](https://rubygems.org/gems/microsoft_kiota_abstractions) |
| [microsoft_kiota_serialization_json](components/serialization/json/) | JSON serialization implementation | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_serialization_json.svg)](https://rubygems.org/gems/microsoft_kiota_serialization_json) |
| [microsoft_kiota_serialization_form](components/serialization/form/) | Form serialization implementation | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_serialization_form.svg)](https://rubygems.org/gems/microsoft_kiota_serialization_form) |
| [microsoft_kiota_serialization_text](components/serialization/text/) | Text serialization implementation | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_serialization_text.svg)](https://rubygems.org/gems/microsoft_kiota_serialization_text) |
| [microsoft_kiota_serialization_multipart](components/serialization/multipart/) | Multipart serialization implementation | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_serialization_multipart.svg)](https://rubygems.org/gems/microsoft_kiota_serialization_multipart) |
| [microsoft_kiota_faraday](components/http/) | HTTP client implementation with Faraday | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_faraday.svg)](https://rubygems.org/gems/microsoft_kiota_faraday) |
| [microsoft_kiota_authentication_oauth](components/authentication/oauth/) | OAuth authentication provider | [![Gem Version](https://badge.fury.io/rb/microsoft_kiota_authentication_oauth.svg)](https://rubygems.org/gems/microsoft_kiota_authentication_oauth) |

## Installation

Add the gems you need to your application's Gemfile:

```ruby
gem 'microsoft_kiota_abstractions'
gem 'microsoft_kiota_serialization_json'
gem 'microsoft_kiota_serialization_form'
gem 'microsoft_kiota_serialization_text'
gem 'microsoft_kiota_serialization_multipart'
gem 'microsoft_kiota_faraday'
gem 'microsoft_kiota_authentication_oauth'
```

## Development

Install Ruby 3.3 or newer, then run:

```shell
git clone https://github.com/microsoft/kiota-ruby.git
cd kiota-ruby
bundle install
rake spec        # run all tests
rake rubocop     # run linter
```

To run tests for a specific component:

```shell
rake abstractions:spec
rake serialization-json:spec
rake serialization-form:spec
rake serialization-text:spec
rake serialization-multipart:spec
rake http:spec
rake authentication-oauth:spec
```

To auto-fix formatting issues:

```shell
bundle exec rubocop -a
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
