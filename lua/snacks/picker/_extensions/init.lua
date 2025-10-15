-- Snacks picker extensions for git-worktree.nvim
-- 
-- This module provides Snacks.nvim picker alternatives to the Telescope extensions.
-- To use these extensions, simply require this module and call the functions.
--
-- Example usage:
-- local snacks_git_worktree = require('snacks.picker._extensions')
-- snacks_git_worktree.git_worktrees()
-- snacks_git_worktree.create_git_worktree()

return require('snacks.picker._extensions.git_worktree')