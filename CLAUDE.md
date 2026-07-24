# Development Workflow

This project's feature work passes through a fixed team pipeline. Follow this
for every non-trivial change:

1. **Pipeline order**: product-architect -> flutter-developer -> code-reviewer
   -> app-store-specialist -> play-store-specialist -> tester -> player-reviewer.
   Each stage hands off to the next; don't skip stages for real feature work.
   (Trivial fixes/chores can skip the full pipeline at judgment call.)
2. **codebase-memory-mcp**: query the index before starting a request (to cut
   token usage instead of re-reading files from scratch), and update the index
   before closing out a request (after the final commit for that request).
3. **Branching**: if there's an open MR/PR for the current work, push to that
   branch. Otherwise create a new branch from the base branch and push there.
4. **Tester scope**: test only the part implemented in the current request,
   not the entire flow end-to-end every time.
5. **Testing requirement**: add unit tests and integration tests for every
   logical change, and run the full test suite after making it.
6. **Frontend/UX verification**: for any frontend/game-UI change, the
   game-ux-designer must verify the built screen matches the mockup exactly
   before it's considered done.
7. **Memory-safety review**: this app is designed to be as much as possible an
   in-memory (RAM-resident) game. Before making any logical change, highlight
   possible memory-related failure modes and how they'll be handled.
