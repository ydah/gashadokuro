# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "rubocop", "~> 1.21"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
gem "yard"

local_gemfile = "Gemfile.local"
eval_gemfile(local_gemfile) if File.exist?(local_gemfile)
