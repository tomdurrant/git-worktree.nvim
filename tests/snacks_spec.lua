local git_worktree = require('git-worktree')

describe('snacks picker extension', function()
    local snacks_extension

    before_each(function()
        git_worktree.reset()
    end)

    after_each(function()
        git_worktree.reset()
    end)

    it('should load the snacks extension without error', function()
        local ok, extension = pcall(require, 'snacks.picker._extensions.git_worktree')
        assert.truthy(ok)
        assert.truthy(extension)
        assert.truthy(extension.git_worktrees)
        assert.truthy(extension.create_git_worktree)
        snacks_extension = extension
    end)

    it('should have the main functions available', function()
        local ok, extension = pcall(require, 'snacks.picker._extensions')
        assert.truthy(ok)
        assert.truthy(extension)
        assert.truthy(extension.git_worktrees)
        assert.truthy(extension.create_git_worktree)
    end)

    it('should handle missing snacks gracefully', function()
        -- Mock absence of snacks
        package.loaded['snacks'] = nil
        package.preload['snacks'] = function()
            error('snacks not found')
        end

        local extension = require('snacks.picker._extensions.git_worktree')
        
        -- Should not error when calling functions, but should print error
        local ok = pcall(extension.git_worktrees)
        assert.falsy(ok)

        -- Reset
        package.loaded['snacks'] = nil  
        package.preload['snacks'] = nil
    end)
end)