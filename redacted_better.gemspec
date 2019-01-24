$LOAD_PATH << File.expand_path('lib', __dir__)
require 'redacted_better/version'

Gem::Specification.new do |s|
  s.name        = 'redacted_better'
  s.version     = RedactedBetter::VERSION
  s.licenses    = ['MIT']
  s.summary     = 'Automatically upload transcodes that Redacted is missing.'
  s.description = 'Automatically search your Redacted downloads for opportunities to upload transcodes.'
  s.authors     = ['Taylor Thurlow']
  s.email       = 'taylorthurlow8@gmail.com'
  s.files       = Dir['{bin,lib}/**/*']
  s.homepage    = 'https://github.com/taylorthurlow/redacted_better'
  s.executables = ['redactedbetter']
  s.platform    = 'ruby'
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 2.3'

  s.add_dependency('faraday', '~> 0.15')
  s.add_dependency('pastel', '~> 0.7')
  s.add_dependency('require_all', '~> 2.0')
  s.add_dependency('slop', '~> 4.6.2')
  s.add_dependency('tty-config', '~> 0.3')
  s.add_dependency('tty-file', '~> 0.7')
  s.add_dependency('tty-prompt', '~> 0.18')

  s.add_development_dependency('factory_bot', '~> 4.11')
  s.add_development_dependency('guard', '~> 2.15')
  s.add_development_dependency('guard-rspec', '~> 4.7')
  s.add_development_dependency('pry', '~> 0.12')
  s.add_development_dependency('pry-byebug', '~> 3.6')
  s.add_development_dependency('rspec', '~> 3.8')
  s.add_development_dependency('rubocop', '~> 0.63')
  s.add_development_dependency('rubocop-rspec', '~> 1.31')
  s.add_development_dependency('simplecov', '~> 0.16')
end
