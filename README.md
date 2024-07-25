# git-commit-standards

Check PR git commit standards

## Usage

```yaml
name: CI

on:
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
          
      - uses: arivictor/git-commit-standards@v11
        with:
            must-have-subject-line: true
            subject-line-capitalised: true
            no-period-at-end-of-subject-line: true
            first-word-in-subject-line-must-be-imperative-verb: true
            body-must-have-blank-line: true
            body-line-max-length: 72
```