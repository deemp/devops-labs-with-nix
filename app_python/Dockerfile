# syntax=docker/dockerfile:1.3-labs
###############################################
# Base Image
###############################################

FROM python:3.10-slim as python-base


ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv"
    

# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

# builder-base is used to build dependencies
FROM python-base AS builder-base
RUN <<EOF
buildDeps="build-essential"
apt-get update
apt-get install --no-install-recommends -y curl vim netcat
apt-get install -y --no-install-recommends $buildDeps
rm -rf /var/lib/apt/lists/*
EOF

# Install Poetry - respects $POETRY_VERSION & $POETRY_HOME
ENV POETRY_VERSION=1.2.1
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN <<EOF
curl -sSL https://install.python-poetry.org/ | python
chmod a+x /opt/poetry/bin/poetry
EOF

# We copy our Python requirements here to cache them
# and install only runtime deps using poetry
WORKDIR $PYSETUP_PATH
COPY ./poetry.lock ./pyproject.toml ./
RUN poetry install --no-dev  # respects

# 'development' stage installs all dev deps and can be used to develop code.
# For example using docker-compose to mount local volume under /app
FROM python-base as development
ENV FASTAPI_ENV=development

# Copying poetry and venv into image
COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH

WORKDIR /app
COPY . .

EXPOSE $PORT

RUN . /opt/pysetup/.venv/bin/activate

ENTRYPOINT [ "bash", "-c"]
CMD ["uvicorn --reload --host $HOST --port $PORT app.main:app"]


# 'lint' stage runs black and isort
# running in check mode means build will fail if any linting errors occur
# FROM development AS lint
# RUN black --config ./pyproject.toml --check app tests
# RUN isort --settings-path ./pyproject.toml --recursive --check-only
# CMD ["tail", "-f", "/dev/null"]

# 'test' stage runs our unit tests with pytest and
# coverage.  Build will fail if test coverage is under 95%
# FROM development AS test
# RUN coverage run --rcfile ./pyproject.toml -m pytest ./tests
# RUN coverage report --fail-under 95

# # 'production' stage uses the clean 'python-base' stage and copyies
# # in only our runtime deps that were installed in the 'builder-base'
# FROM python-base AS production
# ENV FASTAPI_ENV=production

# COPY --from=builder-base $VENV_PATH $VENV_PATH
# COPY ./docker/gunicorn_conf.py /gunicorn_conf.py

# COPY ./docker/docker-entrypoint.sh /docker-entrypoint.sh
# RUN chmod +x /docker-entrypoint.sh

# # Create user
# RUN groupadd -g 1500 sven && \
#     useradd -m -u 1500 -g sven sven

# COPY --chown=sven:sven ./app /app
# USER sven
# WORKDIR /app

# ENTRYPOINT /docker-entrypoint.sh $0 $@
# CMD [ "gunicorn", "--worker-class uvicorn.workers.UvicornWorker", "--config /gunicorn_conf.py", "main:app"]