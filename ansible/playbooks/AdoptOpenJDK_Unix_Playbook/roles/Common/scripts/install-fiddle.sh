git clone https://github.com/ruby/fiddle
cd fiddle
bundle install --path vendor/bundle
bundle exec rake build
sudo gem install pkg/fiddle-1.0.1.gem