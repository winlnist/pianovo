# Reference Materials

Milestone 6F.1 adds a logical reference-material catalogue. It does not add PDFs, audio, document importing, security-scoped bookmarks, PDF presentation, file copying, bundled resources, score-aware assessment, or Today UI.

## Boundary

The app source folder `Pianovo/ReferenceMaterials/` contains Swift source code only. The separate local `Reference Materials/` folder at the project root is ignored by Git and is available only for inspection during development.

Production catalogue data must use stable logical identifiers and descriptive metadata. It must not store permanent absolute development-machine paths or assume that local inspection files exist on an iPad.

These concerns remain separate:

- Catalogue metadata: what a material is.
- Document availability: whether the device can currently access it.
- Document location/access: how a later adapter opens it.
- Programme assignment: why the student should practise it.
- PDF presentation: how pages or excerpts are displayed.

## Logical Identity

Reference materials use stable `ReferenceMaterialID` values. Catalogue components use stable `ReferenceMaterialComponentID` values. Inspected document descriptors use stable `ReferenceDocumentDescriptorID` values.

`ExerciseSourceID` to `ReferenceMaterialID` mapping lives in the reference-material resolver, not in Programme Domain. A catalogue entry may exist without an `ExerciseSourceID` mapping, which allows known materials to be documented before they become assignments.

## Availability And Access

`DefaultUnavailableDocumentAvailabilityProvider` reports known materials as unavailable until a real document-access adapter exists.

Later adapters may resolve a logical material through:

- A user-imported document.
- A security-scoped document reference.
- An application-managed local copy.
- A legally approved bundled resource.
- An unavailable or missing state.

Milestone 6F.1 does not implement document importing, bookmarks, copying, or bundling.

## Page Terminology

PDF page references must distinguish:

- `pdfKitPageIndex`: zero-based page index used by PDFKit.
- `printedPageLabel`: visible page label printed in the document, when available.
- `pdfExcerptHint`: descriptive crop guidance. Exact crop rectangles are deferred until visual verification.

Do not use a generic `page` integer for PDF location.

## Licensing

Rights status is separate from access and assignment. Unverified material rights are recorded as `.unknown`. Catalogue inclusion does not imply that Pianovo may distribute, bundle, or publicly ship the material.

The inspected files show visible attribution or metadata for sources such as Edition Peters, Andrew D. Gordon, MuseScore, Piano Street, Gilbert DeBenedetti, and Chloe Anghelopoulou. Their distribution rights require review before any app bundle or public release use.

## Beyer No. 63

The inspected Beyer descriptor is the 88-page Edition Peters scan named `Beyer_-_Op.101_-_Vorschule_im_Klavierspiel.pdf`. Page locators for this scan must not automatically be applied to another Beyer PDF or edition.

Beyer Op. 101 No. 63 is modelled as one logical exercise with two required visible components:

- Seconda: `pdfKitPageIndex` 45, printed page label `46`.
- Prima: `pdfKitPageIndex` 46, printed page label `47`.

The student is required to practise both components for the complete exercise. Component-level completion and mastery are deferred to a later programme/session workflow.

The audit identified the top portion of each page as the relevant display area. Exact normalized crop rectangles remain deferred to Milestone 6F.5 visual verification.

## Current Non-Goals

- No SwiftUI screens.
- No Practice screen changes.
- No PDFKit presentation.
- No document picker/import.
- No security-scoped bookmarks.
- No local file copying.
- No bundled PDFs or audio.
- No MusicXML generation from PDFs.
- No OMR.
- No MIDI or audio analysis.
- No coach/API integration.
- No persistence schema changes.
- No 6F.2 or later work.
