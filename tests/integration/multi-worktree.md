# Integration Test: Multi-Worktree Pipeline

## Multi-Workstream Test

Run the following command:

```
/zuggie:implement Add two independent utility modules: (1) a string utils module at src/string-utils.js with functions capitalize and reverse, and (2) a math utils module at src/math-utils.js with functions clamp and lerp. Each module should export its functions. Add basic tests for each module.
```

This task is designed to produce at least 2 independent workstreams
(string-utils and math-utils) with no dependencies between them.

### Verification Checklist

After the pipeline completes, verify each item:

#### Worktree Isolation
- [ ] `git worktree list` showed at least 2 sub-worktrees (one per
      workstream) in addition to the feature worktree.
- [ ] Each engineer operated in a different worktree directory.
- [ ] The workstream worktree paths followed the naming convention:
      `.claude/zuggie/<feature-branch>-ws-<N>`.

#### Per-Workstream Review
- [ ] A `zuggie-reviewer` was invoked for each workstream individually
      (before merging into the feature branch).
- [ ] Each per-workstream review received a diff scoped to that
      workstream's changes only.

#### Merge
- [ ] All workstream branches were merged into the feature branch.
- [ ] `git log --oneline` on the feature branch shows merge commits
      or the workstream commits.
- [ ] No merge conflicts occurred (or if they did, they were resolved).

#### Cleanup
- [ ] `git worktree list` shows only the feature worktree and the
      main worktree (sub-worktrees removed).
- [ ] `git branch` does not list any `-ws-<N>` branches (deleted
      after merge).
- [ ] No leftover directories under `.claude/zuggie/` for the
      sub-worktrees.

#### Final Unified Review
- [ ] A final `zuggie-reviewer` invocation occurred after merging,
      reviewing the full diff from the base branch.
- [ ] The final review received all engineer summaries.

#### Result
- [ ] `src/string-utils.js` exists with `capitalize` and `reverse`.
- [ ] `src/math-utils.js` exists with `clamp` and `lerp`.
- [ ] Tests exist and pass.
- [ ] All changes are on the feature branch, not on main.

## Single Workstream Fallback

Run a simpler task:

```
/zuggie:implement Add a src/array-utils.js module with a unique function that removes duplicates from an array. Add a basic test.
```

### Verification Checklist

- [ ] No sub-worktrees were created (engineer worked directly on the
      feature worktree).
- [ ] Only one review pass occurred (no separate per-workstream and
      final review).
- [ ] The result is correct and on the feature branch.
