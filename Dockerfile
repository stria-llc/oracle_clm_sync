FROM ruby:2.6.0
COPY . /oracle_hcm_clm_sync
WORKDIR /oracle_hcm_clm_sync
RUN gem install bundler:2.1.4
RUN bundle install
CMD bundle exec ruby main.rb
