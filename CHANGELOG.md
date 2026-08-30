# Changelog

All notable changes to **__ProjectName__** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
-

### Changed
- The template and generated-repository guidance now use Git directly without secondary version-control metadata.

### Fixed
- `scripts/check-env.sh` now rejects unknown and extra arguments instead of silently ignoring them.
- Package migration now fails closed when a destination already exists, preserving the existing destination file.
- Template initialization now fails closed when `.claude/settings.json` already exists, preserving the user's settings file.
- The release workflow now ignores prerelease and metadata tags when selecting the latest stable version.

[Unreleased]: https://github.com/__GitHubOwner__/__ProjectName__/commits/main
