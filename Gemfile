source 'https://rubygems.org/'

gem 'sinatra'
gem 'rack-contrib', :git => 'https://github.com/rack/rack-contrib'
gem 'pebblebed', '>=0.2.1'
gem 'pebbles-uid'
gem 'pebbles-river'
gem 'pebbles-cors', :git => 'https://github.com/bengler/pebbles-cors'
gem 'petroglyph'
gem 'main', '~> 5.0.1'
gem 'pebble_path'
gem 'feedzirra'
gem 'servolux'
gem 'thor'

group :development, :test do
  gem 'rspec'
  gem 'approvals'
  gem 'simplecov'
  gem 'sinatra-contrib'
  gem 'memcache_mock'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn'
end
