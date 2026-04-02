# Project Actions — LLM Reference

Project Actions lets you define local CLI workflows in YAML, similar to GitHub Actions
but for your own project. Users install a ./project script into their project root and
run commands like ./project setup or ./project test.

This page is optimized for automated consumers. Full documentation: https://project-actions.org/docs


## Installation

Run in the project root:

    curl -fsSL https://project-actions.org/install.sh | bash

The installer:
- Creates .project/ and .project/.runtime/ directories
- Downloads the runner binary for the current platform
- Creates a ./project wrapper script in the project root
- Auto-detects the project framework and suggests a starter template


## Starter Templates

After installing, download starter commands for the project framework:

    ./project init laravel       # Laravel PHP
    ./project init django        # Django Python
    ./project init nextjs        # Next.js
    ./project init rails         # Ruby on Rails
    ./project init node          # Generic Node.js
    ./project init python        # Generic Python
    ./project init docker        # Docker Compose (add-on, combine with any framework)

Run without arguments to list all available templates:

    ./project init


## Directory Structure

.project/
  commands/          <- YAML command files (committed to source control)
    setup.yaml
    test.yaml
  .runtime/          <- runner binary and cache (gitignored)
    runner.sh
    command-runner-darwin-arm64
project              <- wrapper script (committed to source control)


## Command File Format

Each file in .project/commands/ defines one command. Filename becomes the command name.

# .project/commands/setup.yaml
help:
  short: Set up the project          # shown in ./project command listing
  long: |                            # optional, shown with --help
    Installs dependencies and
    prepares the environment.
  order: 1                           # controls sort order in ./project listing

steps:
  - run: composer install            # run a shell command
  - echo: "Setup complete"           # print a message


## Built-in Actions

### run
Executes a shell command. Fails the step if the command exits non-zero.

    - run: npm install
    - run: php artisan migrate

### echo
Prints a message to stdout.

    - echo: "Dependencies installed"

### check-for
Checks that a CLI tool is available. Exits with an error message if not found.

    - check-for: composer
      if-missing: "Composer is required. See https://getcomposer.org"

### if-missing
Runs the nested then: steps only if a file or directory does not exist.

    - if-missing: .env
      then:
        - run: cp .env.example .env

### if-option
Runs the nested then: steps only if a CLI flag was passed by the user.

    - if-option: production
      then:
        - run: php artisan config:cache

### if-no-option
Inverse of if-option -- runs steps only when the flag is NOT present.

    - if-no-option: skip-tests
      then:
        - run: php artisan test


## Running Commands

    ./project              # list all available commands
    ./project <name>       # run a command by name
    ./project <name> --help          # show full help for a command
    ./project <name> --<flag>        # pass an option flag to a command
    ./project init                   # list available starter templates
    ./project init <name>            # download a starter template
    ./project actions list           # list all external action sources in use


## Complete Example

A full setup command that checks dependencies, installs, and prepares the environment:

# .project/commands/setup.yaml
help:
  short: Set up the project
  order: 1

steps:
  - check-for: composer
    if-missing: "Composer is required. See https://getcomposer.org"
  - check-for: php
    if-missing: "PHP is required. See https://php.net"
  - run: composer install
  - if-missing: .env
    then:
      - run: cp .env.example .env
  - run: php artisan key:generate
  - run: php artisan migrate
  - echo: "Setup complete"
