# HaulMate Design

- [HaulMate P0 - UI & Data Contract](https://www.figma.com/design/L9jaK7ixsxhJY1FL896LcK/HaulMate-P0---UI---Data-Contract)
- Core flow source: `haulmate-p0-core-flow.svg`
- Supporting flows source: `haulmate-p0-supporting-flows.svg`
- UI/model contract: `P0_UI_MODEL_MATRIX.md`
- Shared color, spacing, and radius tokens: `../../shared/design-tokens.json`
- Archived concept source: `haulmate-mvp-concept.svg`

The Figma file uses all three free pages:

1. `00 Archive - Concept 01`
2. `01 P0 Core Flow`
3. `02 P0 Supporting Flows`

The P0 pages are the implementation baseline. Keep active iteration in Figma
and commit approved milestone exports here so the implemented UI can be traced
back to a durable design and model revision.

The iOS implementation maps these tokens in
`haulmate-ios-app/HaulMate/Shared/DesignSystem/HaulMateDesignSystem.swift`.
