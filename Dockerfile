FROM golang:1.10.4-alpine as build

WORKDIR /go/src/github.com/alexellis/derek
COPY . .

RUN go test $(go list ./... | grep -v /vendor/) -cover

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o derek .

FROM alpine:3.10 as ship

RUN apk --no-cache add curl ca-certificates \ 
    && echo "Pulling watchdog binary from Github." \
    && curl -sSL https://github.com/alexellis/faas/releases/download/0.9.6/fwatchdog > /usr/bin/fwatchdog \
    && chmod +x /usr/bin/fwatchdog \
    && apk del curl --no-cache

RUN addgroup -S app && adduser -S -g app app
RUN mkdir -p /home/app

WORKDIR /home/app

COPY --from=build /go/src/github.com/alexellis/derek/derek derek

RUN chown -R app /home/app

USER app

ENV cgi_headers="true"
ENV validate_hmac="true"
ENV validate_customers="true"

ENV combine_output="true"

ENV fprocess="./derek"

HEALTHCHECK --interval=5s CMD [ -e /tmp/.lock ] || exit 1

EXPOSE 8080
CMD ["fwatchdog"]
