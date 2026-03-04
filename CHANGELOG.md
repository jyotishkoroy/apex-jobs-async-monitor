# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

## [1.0.0] - 2026-03-04
### Added
- Overview dashboard for AsyncApexJob health
- Async Jobs table with filters, details modal, and CSV export
- Scheduled Jobs table with filters and CSV export
- Optional abort action (guarded by permissions and error handling)
- Permission set for required setup access
- Apex test suite that generates async jobs in-test (queueable/batch/schedule)
