local Path = require("plenary.path")
local strings = require("plenary.strings")
local git_worktree = require("git-worktree")

local M = {}

local force_next_deletion = false

---@class GitWorktreeItem
---@field path string
---@field sha string
---@field branch string
---@field text string

-- Helper function to get worktree path from item
---@param item GitWorktreeItem
---@return string
local function get_worktree_path(item)
    return item.path
end

-- Action to switch to the selected worktree
---@param picker snacks.Picker
---@param item GitWorktreeItem
local function switch_worktree(picker, item)
    picker:close()
    if item and item.path then
        git_worktree.switch_worktree(item.path)
    end
end

-- Toggle forced deletion mode
local function toggle_forced_deletion()
    if force_next_deletion then
        print('The next deletion will not be forced')
        force_next_deletion = false
    else
        print('The next deletion will be forced')
        force_next_deletion = true
    end
end

-- Success handler for deletion
local function delete_success_handler()
    force_next_deletion = false
end

-- Failure handler for deletion  
local function delete_failure_handler()
    print("Deletion failed, use <C-f> to force the next deletion")
end

-- Ask user to confirm deletion
---@param forcing boolean
---@return string
local function ask_to_confirm_deletion(forcing)
    if forcing then
        return vim.fn.input("Force deletion of worktree? [y/n]: ")
    end
    return vim.fn.input("Delete worktree? [y/n]: ")
end

-- Check if deletion should be confirmed
---@param forcing? boolean
---@return boolean
local function confirm_deletion(forcing)
    -- Use the same config as telescope extension
    if not git_worktree._config or not git_worktree._config.confirm_telescope_deletions then
        return true
    end

    local confirmed = ask_to_confirm_deletion(forcing or false)
    if string.sub(string.lower(confirmed), 1, 1) == "y" then
        return true
    end

    vim.notify("Didn't delete worktree", vim.log.levels.INFO)
    return false
end

-- Action to delete the selected worktree
---@param picker snacks.Picker
---@param item GitWorktreeItem
local function delete_worktree(picker, item)
    if not confirm_deletion(force_next_deletion) then
        return
    end

    local worktree_path = get_worktree_path(item)
    picker:close()
    if worktree_path then
        git_worktree.delete_worktree(worktree_path, force_next_deletion, {
            on_failure = delete_failure_handler,
            on_success = delete_success_handler
        })
    end
end

-- Get git worktree list and parse it
---@return GitWorktreeItem[]?, string? -- returns nil and error message on failure
local function get_worktrees()
    -- Check if we're in a git repository
    local git_check = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        return nil, "Not in a git repository"
    end

    local output = vim.fn.systemlist({"git", "worktree", "list"})
    
    -- Check if git command failed
    if vim.v.shell_error ~= 0 then
        return nil, "Failed to get git worktree list"
    end

    local results = {}
    local widths = {
        path = 0,
        sha = 0,
        branch = 0
    }

    for _, line in ipairs(output) do
        local fields = vim.split(string.gsub(line, "%s+", " "), " ")
        local entry = {
            path = fields[1],
            sha = fields[2],
            branch = fields[3] or "",
        }

        if entry.sha ~= "(bare)" then
            -- Calculate widths for consistent formatting
            for key, val in pairs(widths) do
                if key == 'path' then
                    local path_len = strings.strdisplaywidth(entry[key] or "")
                    widths[key] = math.max(val, path_len)
                else
                    widths[key] = math.max(val, strings.strdisplaywidth(entry[key] or ""))
                end
            end

            table.insert(results, entry)
        end
    end

    -- Create display text after calculating widths for proper formatting
    for _, entry in ipairs(results) do
        -- Use Path to transform the path similar to telescope
        local display_path = entry.path
        if string.len(display_path) > 40 then
            display_path = "..." .. string.sub(display_path, -37)
        end
        
        entry.text = string.format("%-*s %-*s %s", 
            math.max(widths.branch, 15), entry.branch or "",
            10, entry.sha or "",
            display_path)
    end

    return results, nil
end

-- Create input prompt for new worktree path
---@param cb function
local function create_input_prompt(cb)
    local subtree = vim.fn.input("Path to subtree > ")
    cb(subtree)
end

-- Main git worktree picker function
---@param opts? table
function M.git_worktrees(opts)
    opts = opts or {}
    
    local worktrees, err = get_worktrees()
    
    if err then
        vim.notify("Error: " .. err, vim.log.levels.ERROR)
        return
    end
    
    if not worktrees or #worktrees == 0 then
        vim.notify("No worktrees found", vim.log.levels.INFO)
        return
    end

    -- Check if Snacks is available
    local ok, snacks = pcall(require, "snacks")
    if not ok then
        vim.notify("Snacks.nvim is not installed. Please install it to use the snacks picker extension.", vim.log.levels.ERROR)
        return
    end

    -- Create the picker configuration
    local picker_opts = vim.tbl_deep_extend("force", {
        source = "git_worktrees",
        items = worktrees,
        title = "Git Worktrees",
        format = "text",
        preview = false,
        confirm = function(picker, item)
            switch_worktree(picker, item)
        end,
        win = {
            input = {
                keys = {
                    ["<c-d>"] = {
                        function(picker)
                            local item = picker:current()
                            if item then
                                delete_worktree(picker, item)
                            end
                        end,
                        mode = { "n", "i" },
                        desc = "Delete worktree"
                    },
                    ["<c-f>"] = {
                        function()
                            toggle_forced_deletion()
                        end,
                        mode = { "n", "i" },
                        desc = "Toggle forced deletion"
                    }
                }
            },
            list = {
                keys = {
                    ["<c-d>"] = {
                        function(picker)
                            local item = picker:current()
                            if item then
                                delete_worktree(picker, item)
                            end
                        end,
                        desc = "Delete worktree"
                    },
                    ["<c-f>"] = {
                        function()
                            toggle_forced_deletion()
                        end,
                        desc = "Toggle forced deletion"
                    }
                }
            }
        }
    }, opts)

    -- Create the picker
    snacks.picker.pick(picker_opts)
end

-- Create worktree picker function
---@param opts? table
function M.create_git_worktree(opts)
    opts = opts or {}
    
    -- Check if Snacks is available
    local ok, snacks = pcall(require, "snacks")
    if not ok then
        vim.notify("Snacks.nvim is not installed. Please install it to use the snacks picker extension.", vim.log.levels.ERROR)
        return
    end

    -- Check if we're in a git repository
    local git_check = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
    if vim.v.shell_error ~= 0 then
        vim.notify("Error: Not in a git repository", vim.log.levels.ERROR)
        return
    end

    -- Get git branches
    local branches_output = vim.fn.systemlist({"git", "branch", "-a"})
    
    -- Check if git command failed
    if vim.v.shell_error ~= 0 then
        vim.notify("Error: Failed to get git branches", vim.log.levels.ERROR)
        return
    end
    
    local branches = {}
    
    for _, line in ipairs(branches_output) do
        local branch = string.gsub(line, "^%s*%*?%s*", "")  -- Remove leading whitespace and *
        branch = string.gsub(branch, "^remotes/[^/]+/", "")  -- Remove remotes/ prefix
        if branch ~= "HEAD" and branch ~= "" and not string.match(branch, "->") then
            table.insert(branches, {
                text = branch,
                branch = branch
            })
        end
    end

    if #branches == 0 then
        vim.notify("No branches found", vim.log.levels.INFO)
        return
    end

    -- Create the picker configuration for branches
    local picker_opts = vim.tbl_deep_extend("force", {
        source = "git_branches",
        items = branches,
        title = "Create Git Worktree - Select Branch",
        format = "text",
        preview = false,
        confirm = function(picker, item)
            picker:close()
            if item then
                local branch = item.branch
                create_input_prompt(function(name)
                    if name == "" then
                        name = branch
                    end
                    git_worktree.create_worktree(name, branch)
                end)
            end
        end
    }, opts)

    -- Create the picker for branches
    snacks.picker.pick(picker_opts)
end

return M