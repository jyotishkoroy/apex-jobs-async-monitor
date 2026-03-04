# Contributing

Thanks for considering contributing.

## Quick Start (Local Dev)
1. Install Salesforce CLI (`sf`)
2. Clone the repo
3. Authenticate:
   ```bash
   sf org login web
   ```
4. Deploy:
   ```bash
   sf project deploy start
   ```
5. Run tests:
   ```bash
   sf apex run test --test-level RunLocalTests --wait 30
   ```

## Branching
- `main` is always deployable
- Use feature branches:
  - `feat/<short-name>`
  - `fix/<short-name>`

## Code Style
- Keep LWC logic split into:
  - data access (Apex calls)
  - state management
  - UI rendering
- Prefer small, well-named helper functions
- Avoid hard-coded org specifics
- Keep SOQL selective and bounded (use `LIMIT`)

## Submitting a PR
- Explain *why* the change exists
- Include screenshots for UI changes
- Ensure:
  - all tests pass
  - no new custom objects are introduced
  - security posture is unchanged or improved

## Reporting Issues
When filing an issue, include:
- org type (scratch/sandbox/prod)
- API version
- steps to reproduce
- any relevant logs / screenshots

## License
By contributing, you agree that your contributions will be licensed under the **MIT License** of this repository.
