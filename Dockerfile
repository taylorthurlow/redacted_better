FROM ruby:2.6.3

RUN apt update -qq
RUN apt install -y flac lame sox git

RUN git clone https://github.com/Rudde/mktorrent.git
WORKDIR mktorrent
RUN make
RUN make install
WORKDIR /
RUN rm -r mktorrent
RUN echo $(mktorrent -v)
