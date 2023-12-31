# syntax=docker/dockerfile:experimental

# Build stage: Install python dependencies
# ===
FROM ubuntu:jammy AS python-dependencies
RUN apt-get update && apt-get install --no-install-recommends --yes python3-pip python3-setuptools build-essential python3-dev
ADD requirements.txt /tmp/requirements.txt
RUN pip3 config set global.disable-pip-version-check true
RUN --mount=type=cache,target=/root/.cache/pip pip3 install --user --requirement /tmp/requirements.txt


# Build stage: Install yarn dependencies
# ===
FROM node:19 AS yarn-dependencies
WORKDIR /srv
ADD package.json .
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn yarn install

# Build stage: Run "yarn run build-css"
# ===
FROM yarn-dependencies AS build-css
WORKDIR /srv
COPY static/sass static/sass
RUN yarn run build

# Build the production image
# ===
FROM ubuntu:jammy

# Install python and import python dependencies
RUN apt-get update && apt-get install --no-install-recommends --yes python3 python3-setuptools python3-pip build-essential python3-dev
COPY . .
COPY --from=python-dependencies /root/.local/lib/python3.10/site-packages /root/.local/lib/python3.10/site-packages
COPY --from=python-dependencies /root/.local/bin /root/.local/bin
ENV PATH="/root/.local/bin:${PATH}"


# Import code, build assets
COPY . .
RUN rm -rf package.json yarn.lock .babelrc webpack.config.js requirements.txt
COPY --from=build-css /srv/static/css static/css

# Set revision ID
ARG BUILD_ID
ENV TALISKER_REVISION_ID "${BUILD_ID}"

# Setup commands to run server
ENTRYPOINT ["./entrypoint"]
CMD ["0.0.0.0:80"]
