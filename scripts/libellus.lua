local DIALOG = {
  ch1 = {
    "Octavia: Me vocant Octaviam.",
    "Octavia: Puella sum.",
    "Octavia: Poetam amo.",
    "Octavia: Lupam meam bene curo.",

    "Octavia: Poetam in agro video.",

    "Octavia: Salve, poeta! Quomodo te vocant?",
    "Publius: Me vocant Publium.",
    "Octavia: Papae! Filium lupa mea habet. Publilium eum voco. Videre debes.",
    "Publius: Ubi habitat Publilius?",
    "Octavia: Lupa et Publilius in casā habitant. Mecum veni!",
  }
}

for ch, contents in pairs(DIALOG) do
  for idx, sent in ipairs(contents) do
    local name = sent:match("^([^:]*):")
    local striped = sent:gsub("^[^:]*:", "")
    striped = striped:match("^%s*(.-)%s*$")
    contents[idx] = {name = name, content = striped}
  end
end

DIALOG.CH1_SEP = {4, 5, 10}


-- debug only
local function printTable(tbl, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)

    if type(tbl) ~= "table" then
        print(prefix .. tostring(tbl))
        return
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. ":")
            printTable(v, indent + 1)
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end
-- printTable(DIALOG)


return DIALOG
