# Troubleshooting

## No results returned
- Build the project in Xcode to regenerate indexing.
- Re-run with verbose logging:
  ```bash
  swiftfindrefs -p <Project> -n <Symbol> -t <Type> -v
  ```
- If multiple DerivedData folders exist, pass `--derivedDataPath`.

## Wrong DerivedData selected
- Prefer explicit `--derivedDataPath` in CI or multi-clone setups.
- Use `--verbose` to confirm path selection.

## Do not fall back to grep
- Text search is not acceptable for reference discovery.
- grep/rg may only be used inside files already returned by `swiftfindrefs`
  (for example, to check if an import already exists).
