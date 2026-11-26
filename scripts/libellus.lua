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
  },
  ch4 = {
    {name="Passer", content="Ego cum amicis meis in silvā semper una manebam."},
    {name="Passer", content="Sed silva ardebat."},
    {name="Passer", content="Homines animum magnum petere silvamque delere cupiebant."},
    {name="Passer", content="Multi pugnabant sed mors eos cepit."},
    {name="Passer", content="Ego felix eram et a flammis fugere poteram."},
    {name="Passer", content="Dum fugiebam, speluncam celebrem vidi donaque deae in speluncā esse dicuntur."},
    {name="Octavia", content="Donane habes nunc?"},
    {name="Passer", content="Non habeo. Rex animalium in silvā dona habet."},

    {name="Octavia", content="Pigrum regem animalium in silvā iacere video!"},
    {name="Rex animalium", content="Discedite, homines! Nolite in silvam venire!"},
    {name="Octavia", content="Unusquisque nostrum propter ignes dolet, sed a timore regis vinci non debemus."},
    {name="Octavia", content="Si auxilium nobis dederis, contra regem hominum tecum pugnabimus."},
    {name="Rex animalium", content="Bene. Dona divitia vobis do."},
  },
  ch5 = {
    {name="Rex animalium", content="Dona multa, quae animalia a speluncā ceperunt, vobis dabo."},
    {name="Octavia", content="Quid agit saxum in donis?"},
    {name="Rex animalium", content="Nolite id tangere! Saxum sacrum est."},
    {name="Rex animalium", content="Si moverit, animum crudelem excitabit, qui tantā irā veniet et omnia delebit."},
    {name="Octavia", content="Quid est saxum aliud?"},
    {name="Rex animalium", content="Saxum somni sicut os est."},
    {name="Rex animalium", content="Cum dixerit, iubebit omnes prope id diu iacere dormireque."},
    {name="Octavia", content="Quae consilia donā capere possumus?", facing="Publius"},
    {name="Publius", content="Bonum dolum habeo.", facing="Octavia"},
    {name="Publius", content="Senex in nave semper erit.", facing="Octavia"},
    {name="Octavia", content="Si autem is in somno fuerit, eum e nave movere poterimus!"},

    {name="Senex", content="A vos excitor. Quid nunc cupitis?"},
    {name="Octavia", content="Navigare ad regem cupimus."},
    {name="Senex", content="Ante bellum, rex ad litorem occultum in mari moverat. Numquam id videbitis."},
    {name="Octavia", content="Temptare debemus."},
    {name="Senex", content="Discedite! A vos non vincar."},

    {name="Octavia", content="Iace!"},
  }
}

DIALOG.CH1_SEP = {4, 5, #DIALOG.ch1}
DIALOG.CH2_SEP = {2, 5, 6, 13, #DIALOG.ch2}
DIALOG.CH3_SEP = {1, 8, 10, 11, #DIALOG.ch3}
DIALOG.CH4_SEP = {8, #DIALOG.ch4}
DIALOG.CH5_SEP = {11, 16, #DIALOG.ch5}

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
