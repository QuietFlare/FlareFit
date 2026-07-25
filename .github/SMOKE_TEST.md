# Pipeline smoke test

Throwaway PR to confirm the human-authored review path runs:
- CI (build + test + SwiftLint)
- AI Review (PR-Agent + Gemini Flash) posts comments

Once you've seen the review comments, **close this PR without merging** and delete
the `test/verify-review` branch. Nothing here ships.
