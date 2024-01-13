FROM alpine

RUN apk update
RUN apk add ruby ruby-dev git bash make gcc musl-dev
RUN gem install rake

RUN git clone https://github.com/jomy10/beaver
RUN cd beaver && bash build.sh build install

# Remove build dependencies & clean
RUN gem uninstall rake
RUN apk del git bash ruby-dev gcc musl-dev
RUN apk cache clean

