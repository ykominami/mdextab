source "https://rubygems.org"

# Specify your gem's dependencies in mdextab.gemspec
# gem "filex", path: "../filex-gem"
# gem "messagex", path: "../messagex"
gemspec

gem "bundler"
gem "debug"
gem "erubis"
gem "filex"
gem "messagex"
gem "rake", "~> 13.3"
gem "simpleoptparse"

group :development do
  gem 'yard', "~> 0.9.38"
end

group :development, :test, optional: true do
  gem "rspec", "~> 3.13"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
end
