# Agent Instructions

- Never add a "Co-Authored-By: Claude" (or any AI attribution) trailer to git commit messages.
- Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages: `feat(thing): ...`, `fix(thing): ...`, `docs(thing): ...`, `chore(thing): ...`, etc.
- Never commit directly to `main`. Always create a feature branch and open a pull request.
- Never use triple-slash (`///`) doc comments in Swift code. Use block comments instead, formatted as:
  ```swift
  /**
   * Comment text goes here.
   */
  ```
