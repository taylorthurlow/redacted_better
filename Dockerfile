FROM ruby:2.6.3

RUN apt update -qq
RUN apt install -y flac lame sox
