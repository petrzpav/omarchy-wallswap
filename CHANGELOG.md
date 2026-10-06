# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [1.0.4] - 2026-10-06

### Added

- Instructions for AI agents: the repository follows Flow (ig-flow and ig-changelog skills).

## [1.0.3] - 2026-09-29

### Security

- Cache metadata and kept images are written via mktemp + rename, so planted symlinks are replaced, never followed.

## [1.0.2] - 2026-09-29

### Security

- The NASA key stays out of argv; state and lock are symlink-safe.

## [1.0.1] - 2026-09-29

### Added

- Popup panel with next / previous / open / keep and a pause switch; sources and interval can be set from it.
- Preview image; README covers requirements, network use and removal.

### Changed

- Readable source names, Wallhaven titles from tags; sources can be a plain string; the sources footer wraps.

### Security

- Fetching is HTTPS-only, without redirects, with size ceilings and per-source URL allowlists.

## [1.0.0] - 2026-09-29

### Added

- Rotate Omarchy backgrounds from NASA APOD, Bing, Wikimedia and Wallhaven.

[Unreleased]: https://github.com/petrzpav/omarchy-wallswap/compare/staging...dev
[1.0.4]: https://github.com/petrzpav/omarchy-wallswap/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/petrzpav/omarchy-wallswap/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/petrzpav/omarchy-wallswap/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/petrzpav/omarchy-wallswap/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/petrzpav/omarchy-wallswap/releases/tag/v1.0.0
