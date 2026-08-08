---
id: obs-20260616-ghcr-package-visibility-blocks-pull
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- ghcr
- docker
- packages
- visibility
- github
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:02.544207+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-ghcr-package-visibility-blocks-pull

## content

After publishing a new image to GHCR, pulling the image from outside the org failed because the package defaulted to private visibility. The publish workflow itself succeeded (push worked with write:packages scope) but the pull gate required the package to be public or the pulling token to have read:packages.

## resolution

Noah manually flipped the package to public in the GitHub UI. For future releases, either pre-set package visibility to public or add a visibility-flip step to the publish workflow.
