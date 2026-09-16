ARG SERVICE

FROM ruby:4.0

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG SERVICE

COPY services/${SERVICE}/Gemfile services/${SERVICE}/Gemfile.lock ./
RUN bundle install

COPY services/${SERVICE}/ ./
COPY proto/ /proto/

ENV RAILS_ENV=production
ENV CASSANDRA_HOST=cassandra
ENV GRPC_PORT=50051

EXPOSE 50051

CMD ["bundle", "exec", "ruby", "bin/grpc_server"]