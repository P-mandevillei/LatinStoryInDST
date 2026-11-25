local DIALOG = {
  ch1 = {
    {name="Octavia", content="Me vocant Octaviam."},
    {name="Octavia", content="Puella sum"},
    {name="Octavia", content="Poetam pulchrum amo."},
    {name="Octavia", content="Lupam meam bene curo."},

    {name="Octavia", content="Poetam in agro video."},

    {name="Octavia", content="Salve, poeta! Quomodo te vocant?", facing="Publius"},
    {name="Publius", content="Me vocant Publium.", facing="Octavia"},
    {name="Octavia", content="Papae! Filium lupa mea habet. Publilium eum voco. Videre debes.", facing="Publius"},
    {name="Publius", content="Fabulam narras! Audio lupam magnam esse. Ubi habitat Publilius?", facing="Octavia"},
    {name="Octavia", content="Lupa et Publilius in casā gaudio habitant. Mecum veni!", facing="Publius"},
  },
  ch2 = {
    {name="Publius", content="Publilium autem non video!"},
    {name="Octavia", content="Lupa vincta est! Viri armati sunt!"},

    {name="Milites", content="E casā ambulate!", facing="Octavia"},
    {name="Milites", content="Rex magnam lupam vult.", facing="Octavia"},
    {name="Octavia", content="Viros timeo. Fugere debemus!", facing="Publius"},

    {name="Publius", content="Lupam servare possumus. Auxilium in agro exspecto.", facing="Octavia"},

    {name="Agricola", content="Quomodo valetis?", facing="Octavia"},
    {name="Octavia", content="Lupa mea a rege tenetur. Filium lupae non video.", facing="Agricola"},
    {name="Agricola", content="Propter bellum, rex animos magnos vult.", facing="Octavia"},
    {name="Agricola", content="Rex dicitur numquam vinci posse.", facing="Octavia"},
    {name="Agricola", content="Si auxilium lupae dare cupitis, animum magnum parari debet.", facing="Octavia"},
    {name="Octavia", content="Ubi est rex?", facing="Agricola"},
    {name="Agricola", content="Rex in aquā longe a terrā habitat.", facing="Octavia"}
  },
  ch3 = {
    {name="Octavia", content="Senex in nave similis militi videtur."},

    {name="Octavia", content="Auxilium nobis dare debes! Deliciae meae a rege crudeli capiuntur.", facing="Senex"},
    {name="Senex", content="Delicias vestras aestimo unius assis.", facing="Octavia"},
    {name="Octavia", content="Miles decernit se fortitudinem non habere.", facing="Publius"},
    {name="Senex", content="Fortitudo auxilium non est. Rex a puellā et peuro non vincitur."},
    {name="Senex", content="Delicias liberare dolo debetis."},
    {name="Octavia", content="Navigare ad regem cupimus. Navemne tuam capimus?"},
    {name="Senex", content="Si mortem petere cupitis, nolite id agere in nave meā!"},

    {name="Octavia", content="Animum magnum cum industriā diu petimus sed non videmus."},
    {name="Publius", content="Forma animi magni non scio!"},
    {name="Passer", content="Lacrimas miseras audio. Ecce! Callidus sum."},
    {name="Passer", content="Animus magnus oculis boni hominis videri non potest, sed sentiri debet."},
    {name="Octavia", content="Te vinculis libero."},

    {name="Octavia", content="Quid scis de rege?"},
  }
}

DIALOG.CH1_SEP = {4, 5, #DIALOG.ch1}
DIALOG.CH2_SEP = {2, 5, 6, 13, #DIALOG.ch2}
DIALOG.CH3_SEP = {1, 8, 13, #DIALOG.ch3}

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
-- local function split(inputstr, sep)
--   printTable(inputstr, 4)
--   if sep == nil then
--     sep = "%s" -- defaults to whitespace
--   end
--   local t = {}
--   for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
--     table.insert(t, str)
--   end
--   return t
-- end
-- for ch, str in pairs(DIALOG) do
--   local contents = split(str, "\n")
--   for idx, sent in ipairs(contents) do
--     local name = sent:match("^([^:]*):")
--     local striped = sent:gsub("^[^:]*:", "")
--     striped = striped:match("^%s*(.-)%s*$")
--     contents[idx] = {name = name, content = striped}
--   end
-- end
-- printTable(DIALOG)

return DIALOG