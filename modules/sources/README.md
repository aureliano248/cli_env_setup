# Sources Module

This module owns source URLs, archive download/extraction, and install stamps.

- `urls.sh` derives all download URLs from pinned versions and detected platform values.
- `archive.sh` manages cache downloads, archive unpacking, source preparation, and component stamps.

Keep network and source-cache behavior here. Build modules should call `fetch_source` or `install_archive_component`.
