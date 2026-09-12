local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local f = ls.function_node
local fmt = require("luasnip.extras.fmt").fmt

-- Helper: Map Go types to their zero values
local function type_to_zero(type_str)
  if type_str == "string" then
    return '""'
  end
  if type_str == "bool" then
    return "false"
  end
  if
    type_str:match("^int")
    or type_str:match("^uint")
    or type_str:match("^float")
    or type_str == "rune"
    or type_str == "byte"
    or type_str == "complex"
  then
    return "0"
  end
  if
    type_str:match("^%*")
    or type_str:match("^%[%]")
    or type_str:match("^map%[")
    or type_str:match("^chan")
    or type_str == "any"
    or type_str:match("^interface")
  then
    return "nil"
  end
  -- Default for value structs (e.g., MyStruct{})
  return type_str .. "{}"
end

-- Treesitter logic to parse the current function's return signature
local function go_err_returns()
  local node = vim.treesitter.get_node()

  -- 1. Walk up the tree to find the function declaration
  while node do
    if
      node:type() == "function_declaration"
      or node:type() == "method_declaration"
      or node:type() == "func_literal"
    then
      break
    end
    node = node:parent()
  end
  if not node then
    return ""
  end

  -- 2. Find the return types (the "result" field in Treesitter)
  local result = node:field("result")[1]
  if not result then
    return ""
  end

  local zeros = {}

  -- 3. Parse the return types
  if result:type() == "parameter_list" then
    -- Multiple returns (e.g., `(int, string, error)`)
    for child in result:iter_children() do
      if child:type() == "parameter_declaration" then
        local type_node = child:field("type")[1]
        if type_node then
          -- Account for multiple named returns sharing a type: `(a, b int)`
          local count = 0
          for c in child:iter_children() do
            if c:type() == "identifier" then
              count = count + 1
            end
          end
          if count == 0 then
            count = 1
          end

          local type_text = vim.treesitter.get_node_text(type_node, 0)
          local zero = type_to_zero(type_text)
          for _ = 1, count do
            table.insert(zeros, zero)
          end
        end
      end
    end
  else
    -- Single return (e.g., `error`)
    local type_text = vim.treesitter.get_node_text(result, 0)
    table.insert(zeros, type_to_zero(type_text))
  end

  -- 4. Remove the last return type (which is the `error` we are wrapping)
  if #zeros > 0 then
    table.remove(zeros, #zeros)
  end

  -- 5. Format the output
  if #zeros == 0 then
    return "" -- Returns just `fmt.Errorf(...)`
  end

  -- Returns `0, "", ` etc.
  return table.concat(zeros, ", ") .. ", "
end

return {
  s(
    "iferrw",
    fmt(
      [[
    if err != nil {{
    	return {}fmt.Errorf("{}: %w", err)
    }}
  ]],
      {
        f(go_err_returns), -- Automatically injects `nil, "", ` or nothing
        i(1, "interface error"), -- Cursor lands here
      }
    )
  ),
}
