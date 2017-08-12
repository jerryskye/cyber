FROM ruby:2.3

RUN apt-get update -qq && apt-get install -y build-essential cron
ENV APP_HOME /app
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY Gemfile* ./
RUN bundle install
ADD . $APP_HOME/
RUN echo "PATH=$PATH\nGEM_HOME=$GEM_HOME\n* * * * * root cd $APP_HOME && bundle exec ruby cyber.rb >> error.log 2>&1" > /etc/cron.d/cyber
RUN chmod +x cyber.rb
RUN touch error.log
VOLUME $APP_HOME/persistent

CMD cron && bundle exec thin start
