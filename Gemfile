source 'https://rubygems.org/'

gem 'sinatra', '~> 1.3.4'
gem 'rack-contrib', :git => 'https://github.com/rack/rack-contrib'
gem 'pebblebed', '>=0.2.1'
gem 'pebbles-uid', '~> 0.0.22'
gem 'pebbles-river', '~> 0.2.4'
gem 'pebbles-cors', :git => 'https://github.com/bengler/pebbles-cors'
gem 'petroglyph', '~> 0.0.3'
gem 'main', '~> 5.0.1'
gem 'pebbles-path', '~> 0.0.3'
gem 'servolux', '~> 0.10.0'
gem 'thor', '~> 0.18.0'
gem 'curb', '~> 0.8.8'
gem 'backports', '~> 3.6.4'

group :development, :test do
  gem 'rspec', '~> 2.14.1'
  gem 'approvals', '~> 0.0.16'
  gem 'simplecov', '~> 0.6.4'
  gem 'sinatra-contrib', '~> 1.3.1'
  gem 'memcache_mock', '~> 0.0.14'
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn', '~> 4.8.3'
end
