# CrucibleDatasets Type System Design

**Date:** 2025-12-20
**Status:** Tinker parity focus (full parity extensions noted)

## Current Types (implemented)
- `CrucibleDatasets.Types.Message`
- `CrucibleDatasets.Types.Conversation`
- `CrucibleDatasets.Types.Comparison`
- `CrucibleDatasets.Types.LabeledComparison`

These cover chat and preference datasets, but they are not wired to a formal schema system.

## Gaps
- Dataset items are plain maps with no schema enforcement.
- No dataset-level feature metadata (Value/ClassLabel/Sequence/etc.).
- No validation pipeline for loader outputs.
- No media feature types (Image/Audio/Video/NIfTI).

## Proposed Schema Layers

### 1) Dataset Item Schemas
Define normalized schemas per dataset class:
- MathItem: `problem`, `answer`, `metadata` (level/type)
- ChatItem: `conversation` (messages), `metadata`
- PreferenceItem: `comparison` + `label`
- CodeItem: `prompt`, `solution`, `language`
- VisionItem: `image_ref` + `label`
- AudioItem: `audio_ref` + `label`
- VideoItem: `video_ref` + `label`
- PdfItem: `pdf_ref` + `label`
- NiftiItem: `nifti_ref` + `label`

### 2) Feature Types
A full Features layer:
- Value (string/int/float/bool)
- ClassLabel (list of labels)
- Sequence (list of values)
- Array2D/Array3D/Array4D
- Image / Audio / Video / PDF / NIfTI (MediaRef-backed)

### 3) Optional Validation (Sinter)
Use Sinter to validate loader outputs when `validate: true` is set.
Validation should be opt-in to avoid overhead.

## MediaRef
A simple representation for media data:

```
%MediaRef{
  path: "...",
  bytes: nil,
  mime: "image/jpeg",
  metadata: %{width: 224, height: 224}
}
```

Decoding is handled by media_ex adapters.

## Tinker Parity vs Full Parity
- Tinker parity requires Message/Conversation/Comparison and ClassLabel + Image support.
- PDF and NIfTI are full-parity extensions and are not required for tinker parity.
