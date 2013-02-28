source 'https://rubygems.org/'

gem 'sinatra'
gem 'rack-contrib', :git => 'git://github.com/rack/rack-contrib.git'
gem 'pebblebed'
gem 'pebbles-uid'
gem 'pebbles-cors', :git => 'git@github.com:bengler/pebbles-cors.git'
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
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.1.1'
end
