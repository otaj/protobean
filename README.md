# protobean

Protobuf schemas for [Beancount](https://beancount.github.io/) ledgers, plus a generated [Dart](https://dart.dev/) package (`protobean`) that binds those messages.

The schemas cover a **parsed** ledger (parser output, including elided amounts and parse-time cost specs) and a **processed** ledger (booked, interpolated, and consistency-checked).

## Protobuf

Sources live under `proto/beancount/`. Lint and format with [Buf](https://buf.build/) 1.72.0 (see `buf.yaml`):

```bash
buf lint
buf format --diff --exit-code
```

## Dart package

Generated code is not committed. After `fvm use` (or otherwise putting Dart on `PATH`) and installing Buf:

```bash
./tool/generate.sh
dart pub get
dart analyze --fatal-infos
```

```dart
import 'package:protobean/protobean.dart';
```

The Dart SDK is pinned via FVM in `.fvmrc`.

## Contributing

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) and should be atomic (one concern each). Local hooks are in `.pre-commit-config.yaml`.

Every pull request adds **one** changelog line under `## [Unreleased]` in `CHANGELOG.md`. The line is the squash-merge subject (the PR title) and the PR number:

```markdown
- feat(proto): add processed ledger messages (#12)
```

Put that line in its **own** commit that only touches `CHANGELOG.md`. Open the PR first so you have a number, then add the changelog commit. CI runs `./tool/check-changelog.sh` and rejects PRs that skip this.

## License

[GPL-3.0](LICENSE)
