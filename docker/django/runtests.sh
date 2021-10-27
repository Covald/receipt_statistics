#!/usr/bin/env sh

set -o errexit
set -o nounset

# Initializing global variables and functions:
: "${DJANGO_ENV:=development}"

# Fail CI if `DJANGO_ENV` is not set to `development`:
if [ "$DJANGO_ENV" = 'production' ]; then
  echo 'DJANGO_ENV is set to production. Running tests is not safe.'
  exit 1
fi

# Python path is required for `mypy` to be run correcty with `django-stubs`:
: "${PYTHONPATH:=''}"

pyclean () {
  # Cleaning cache:
  find . \
  | grep -E '(__pycache__|\.hypothesis|\.perm|\.cache|\.static|\.py[cod]$)' \
  | xargs rm -rf
}

run_ci () {
  echo '[tests started]'
  set -x  # we want to print commands during the CI process.

  # Testing filesystem and permissions:
  touch .perm && rm -f .perm

  pytest

  # Run checks to be sure settings are correct (production flag is required):
  DJANGO_ENV=production python manage.py check --deploy --fail-level ERROR

  # Check that staticfiles app is working fine:
  DJANGO_ENV=production python manage.py collectstatic --no-input --dry-run

  # Check that all migrations worked fine:
  python manage.py makemigrations --dry-run --check

  # Check that all migrations are backwards compatible:
  python manage.py lintmigrations \
    --no-cache \
    --warnings-as-errors \
    --exclude-apps axes django_dramatiq admin_interface \
    --ignore-name 0002_fix_ip_addr_max_len 0011_remove_application_current_task_idx

  # Checking if all the dependencies are secure and do not have any
  # known vulnerabilities:
  # Ignoring sphinx@2 security issue for now, see:
  # https://github.com/miyakogi/m2r/issues/51
  safety check --full-report -i 38330 -i 39462

  # Checking translation files, ignoring ordering and locations:
  polint -i location,unsorted locale

  # Also checking translation files for syntax errors:
  if find locale -name '*.po' -print0 | grep -q "."; then
    # Only executes when there is at least one `.po` file:
    dennis-cmd lint --errorsonly locale
  fi

  set +x
  echo '[tests finished]'
}

# Remove any cache before the script:
pyclean

# Clean everything up:
trap pyclean EXIT INT TERM

# Run the CI process:
run_ci
