local function summarize(row)
    local c = row.charinfo or {}
    return {
        citizenid = row.citizenid,
        cid = row.cid,
        firstname = c.firstname,
        lastname = c.lastname,
        birthdate = c.birthdate,
        gender = c.gender,
        nationality = c.nationality,
        job = row.job and row.job.label or 'Civilian',
        grade = row.job and row.job.grade and row.job.grade.name,
        cash = row.money and row.money.cash or 0,
        bank = row.money and row.money.bank or 0,
    }
end

local function validName(name)
    return type(name) == 'string' and #name >= 2 and #name <= 24 and name:match("^[%a][%a%-' ]*$") ~= nil
end

local function validBirthdate(date)
    if type(date) ~= 'string' then return false end
    local y, m, d = date:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return false end
    local age = tonumber(os.date('%Y')) - y
    return age >= CharConfig.MinAge and age <= CharConfig.MaxAge
end

local function capitalize(name)
    return (name:lower():gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

Arca.Callback.Register('arca_character:getCharacters', function(source)
    local rows = exports.arca_core:GetCharacters(source)
    local list = {}
    for i = 1, #rows do list[i] = summarize(rows[i]) end
    return list, Arca.Config.Server.MaxCharacters, CharConfig.Nationalities
end)

Arca.Callback.Register('arca_character:select', function(source, citizenid)
    if type(citizenid) ~= 'string' then return false end
    return exports.arca_core:Login(source, citizenid) and true or false
end)

Arca.Callback.Register('arca_character:create', function(source, data)
    if type(data) ~= 'table' then return false, 'Invalid data' end
    if not validName(data.firstname) or not validName(data.lastname) then
        return false, 'Names must be 2-24 letters'
    end
    if not validBirthdate(data.birthdate) then
        return false, ('Birthdate must be YYYY-MM-DD and age %d-%d'):format(CharConfig.MinAge, CharConfig.MaxAge)
    end
    local gender = tonumber(data.gender)
    if gender ~= 0 and gender ~= 1 then return false, 'Invalid gender' end

    local nationality = 'Other'
    for _, n in ipairs(CharConfig.Nationalities) do
        if n == data.nationality then nationality = n end
    end

    local cid = tonumber(data.cid)
    if not cid or cid < 1 or cid > Arca.Config.Server.MaxCharacters then return false, 'Invalid slot' end

    local player = exports.arca_core:Login(source, nil, {
        cid = cid,
        charinfo = {
            firstname = capitalize(data.firstname),
            lastname = capitalize(data.lastname),
            birthdate = data.birthdate,
            gender = gender,
            nationality = nationality,
        },
    })
    if not player then return false, 'Could not create character' end
    return true
end)

Arca.Callback.Register('arca_character:delete', function(source, citizenid)
    if type(citizenid) ~= 'string' then return false end
    if exports.arca_core:GetPlayer(source) then return false end -- must be on the selection screen
    return exports.arca_core:DeleteCharacter(source, citizenid)
end)

---------------------------------------------------------------------
-- Appearance (illenium-appearance). Stored in `playerskins`, same
-- layout as qb so existing skins/tools keep working.
---------------------------------------------------------------------
Arca.Callback.Register('arca_character:getAppearance', function(source)
    local player = exports.arca_core:GetPlayer(source)
    if not player then return nil end
    local skin = MySQL.scalar.await('SELECT skin FROM playerskins WHERE citizenid = ? AND active = 1 LIMIT 1', {
        player.PlayerData.citizenid,
    })
    return skin and json.decode(skin) or nil
end)

RegisterNetEvent('arca_character:server:saveAppearance', function(appearance)
    local src = source
    local player = exports.arca_core:GetPlayer(src)
    if not player or type(appearance) ~= 'table' or not appearance.model then return end

    local skin = json.encode(appearance)
    if #skin > 65535 then return end

    local citizenid = player.PlayerData.citizenid
    MySQL.update.await('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
    MySQL.insert.await('INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)', {
        citizenid, tostring(appearance.model), skin,
    })
end)

AddEventHandler('arca_core:server:characterDeleted', function(_, citizenid)
    MySQL.update('DELETE FROM playerskins WHERE citizenid = ?', { citizenid })
end)
