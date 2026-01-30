# SOLEN Test Suite

Bats-based test framework for SOLEN scripts.

## Prerequisites

Install bats (Bash Automated Testing System):

```bash
# Ubuntu/Debian
sudo apt-get install bats

# macOS
brew install bats-core

# From source
git clone https://github.com/bats-core/bats-core.git
cd bats-core && sudo ./install.sh /usr/local
```

## Running Tests

```bash
# Run all tests
bats tests/

# Run unit tests only
bats tests/unit/

# Run integration tests only
bats tests/integration/

# Run specific test file
bats tests/unit/test_solen_lib.bats

# Verbose output
bats --verbose-run tests/
```

## Test Structure

```
tests/
├── README.md           # This file
├── setup.bash          # Common test setup and helpers
├── fixtures/
│   └── golden/         # Expected JSON outputs for validation
├── unit/               # Unit tests for library functions
│   ├── test_solen_lib.bats
│   ├── test_deps.bats
│   └── test_policy.bats
└── integration/        # Integration tests for scripts
    ├── test_inventory.bats
    ├── test_health.bats
    └── test_services.bats
```

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

setup() {
  load '../setup.bash'
  load_solen_lib
}

@test "description of what is being tested" {
  run some_command
  [ "$status" -eq 0 ]
  [[ "$output" == *"expected text"* ]]
}
```

### Available Helpers

- `load_solen_lib`: Source the solen.sh library
- `skip_unless_command <cmd>`: Skip test if command not available
- `compare_json_structure`: Compare JSON output structure

## CI Integration

Tests run automatically via GitHub Actions on push and pull requests.
See `.github/workflows/test.yml` for configuration.
