install:
	bundle install

test:
	bundle exec rspec

release:
	bundle exec rake release
