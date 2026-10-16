# frozen_string_literal: true

COMPONENTS = {
  'abstractions' => 'components/abstractions',
  'serialization-json' => 'components/serialization/json',
  'serialization-form' => 'components/serialization/form',
  'serialization-text' => 'components/serialization/text',
  'serialization-multipart' => 'components/serialization/multipart',
  'http' => 'components/http',
  'authentication-oauth' => 'components/authentication/oauth'
}.freeze

def run_in_component(dir, command)
  Dir.chdir(dir) do
    sh 'bundle install --quiet' unless ENV['CI']
    sh command
  end
end

COMPONENTS.each do |name, path|
  namespace name do
    desc "Run specs for #{name}"
    task :spec do
      run_in_component(path, 'bundle exec rake spec')
    end

    desc "Build gem for #{name}"
    task :build do
      run_in_component(path, 'bundle exec rake build')
    end
  end
end

desc 'Run all component specs'
task :spec do
  COMPONENTS.each do |name, path|
    puts "\n=== Running specs for #{name} ==="
    run_in_component(path, 'bundle exec rake spec')
  end
end

desc 'Build all gems'
task :build do
  COMPONENTS.each do |name, path|
    puts "\n=== Building #{name} ==="
    run_in_component(path, 'bundle exec rake build')
  end
end

require 'rubocop/rake_task'

RuboCop::RakeTask.new(:rubocop)

task default: :spec
