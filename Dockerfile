FROM elixir:1.12

LABEL maintainer="smitka.j@gmail.com"

RUN apt update -y \
    && apt install -y \
      inotify-tools

RUN mix local.rebar --force \
    && mix local.hex --force

COPY mix.exs /usr/src/app/
COPY mix.lock /usr/src/app/
WORKDIR /usr/src/app
RUN mix do deps.get, deps.compile

COPY . /usr/src/app
ENV SECRET_KEY="zmentotonanejakybezpecnyklicbrzy"
ENV DATABASE_URL="postrgres://user:password@host/database"
ENV EVENTSTORE_URL="postgres://user:password@localhost/database"
RUN mix compile

CMD ["mix", "run", "--no-halt"]
