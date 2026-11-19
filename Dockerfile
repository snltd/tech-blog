FROM docker.io/ruby:4.0-slim AS build
ENV BUNDLE_WITHOUT=development BUNDLE_DEPLOYMENT=true
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .

FROM docker.io/ruby:4.0-slim
ENV BUNDLE_WITHOUT=development BUNDLE_DEPLOYMENT=true
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
EXPOSE 8080
USER nobody
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "8080"]
