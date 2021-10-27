# This Dockerfile uses multi-stage build to customize DEV and PROD images:
# https://docs.docker.com/develop/develop-images/multistage-build/

FROM python:3.7.9-slim-buster AS development_build

ARG DJANGO_ENV
ARG UID=101
ARG GID=101

ENV DJANGO_ENV=${DJANGO_ENV} \
  # user
  UID=${UID} \
  GID=${GID} \
  # python:
  PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  # pip:
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  # dockerize:
  DOCKERIZE_VERSION=v0.6.1 \
  # tini:
  TINI_VERSION=v0.19.0 \
  # poetry:
  POETRY_VERSION=1.1.3 \
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_CREATE=false \
  POETRY_CACHE_DIR='/var/cache/pypoetry' \
  PATH="$PATH:/root/.poetry/bin" \
  # dockerfile:
  MY_PIP_CONSTRAINT='pip~=21.1.1'

# System deps:
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    bash \
    build-essential \
    curl \
    gettext \
    git \
    libpq-dev \
    wget \
  # Cleaning cache:
  && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/* \
  # Set dramatic config
  && mkdir -p /tmp/dramatiq-prometheus \
  && env prometheus_multiproc_dir=/tmp/dramatiq-prometheus dramatiq_prom_db=/tmp/dramatiq-prometheus \
  # Installing `dockerize` utility:
  # https://github.com/jwilder/dockerize
  && wget "https://github.com/jwilder/dockerize/releases/download/${DOCKERIZE_VERSION}/dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz" \
  && tar -C /usr/local/bin -xzvf "dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz" \
  && rm "dockerize-linux-amd64-${DOCKERIZE_VERSION}.tar.gz" && dockerize --version \
  # Installing `tini` utility:
  # https://github.com/krallin/tini
  && wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini" \
  && chmod +x /usr/local/bin/tini && tini --version \
  && pip install -U ${MY_PIP_CONSTRAINT} \
  # Installing `poetry` package manager:
  # https://github.com/python-poetry/poetry
  && curl -sSL 'https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py' | python \
  && poetry --version

# Copy only requirements, to cache them in docker layer
WORKDIR /code
COPY ./poetry.lock ./pyproject.toml /code/
COPY ./whls/ /code/whls

# Project initialization:
RUN echo "$DJANGO_ENV" \
  && poetry install \
    $(if [ "$DJANGO_ENV" = 'production' ]; then echo '--no-dev'; fi) \
    --no-interaction --no-ansi \
  # Cleaning poetry installation's cache for production:
  && if [ "$DJANGO_ENV" = 'production' ]; then rm -rf "$POETRY_CACHE_DIR"; fi

# This is a special case. We need to run this script as an entry point:
COPY ./docker/django/develop-entrypoint.sh /develop-entrypoint.sh

# Setting up proper permissions:
RUN chmod +x '/develop-entrypoint.sh' \
  && groupadd -r web && useradd -d /code -r -g web web \
 && chown web:web -R /code \
  && mkdir /code/static /code/media && chown web:web /code/static /code/media
RUN usermod -u $UID web && groupmod -g $GID web

# Running as non-root user:
USER web

# COPY src
COPY --chown=web:web . /code

# We customize how our app is loaded with the custom entrypoint:
ENTRYPOINT ["tini", "--", "/develop-entrypoint.sh"]


# The following stage is only for Prod:
# https://wemake-django-template.readthedocs.io/en/latest/pages/template/production.html
FROM development_build AS production_build

ENTRYPOINT ["tini", "--"]
