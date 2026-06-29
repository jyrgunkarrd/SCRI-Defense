-- data/dice.lua
-- dice definitions

local dice = {

    {

        id = "WHT",
        faces = {

            F1 = { type = "ammo" },
            F2 = { type = "blank" },
            F3 = { type = "blank" },
            F4 = { type = "damage", value = 1 },
            F5 = { type = "damage", value = 1 },
            F6 = { type = "damage", value = 1 },

        },
        color = "ffffff",

    },

    {

        id = "ORG",
        faces = {

            F1 = { type = "ammo" },
            F2 = { type = "blank" },
            F3 = { type = "damage", value = 1 },
            F4 = { type = "damage", value = 1 },
            F5 = { type = "damage", value = 1 },
            F6 = { type = "damage", value = 2 },

        },
        color = "f9a101",

    },

    {

        id = "BLU",
        faces = {

            F1 = { type = "ammo" },
            F2 = { type = "blank" },
            F3 = { type = "shield", value = 1 },
            F4 = { type = "shield", value = 1 },
            F5 = { type = "damage", htype = "shield", value = 1 },
            F6 = { type = "damage", htype = "shield", value = 2 },

        },
        color = "24d0ff",

    },


    {

        id = "RED",
        faces = {

            F1 = { type = "ammo" },
            F2 = { type = "damage", value = 1 },
            F3 = { type = "damage", value = 1 },
            F4 = { type = "damage", value = 1 },
            F5 = { type = "damage", value = 2 },
            F6 = { type = "damage", htype = "tac", value = 2 },

        },
        color = "fe1210",

    },

    {

        id = "PNK",
        faces = {

            F1 = { type = "blank" },
            F2 = { type = "tac", value = 1 },
            F3 = { type = "tac", value = 1 },
            F4 = { type = "damage", htype = "tac" value = 1 },
            F5 = { type = "tac", value = 2 },
            F6 = { type = "damage", htype = "tac", value = 2 },

        },
        color = "ff2bff",

    },

    {

        id = "BLK",
        faces = {

            F1 = { type = "damage", value = 1 },
            F2 = { type = "damage", value = 1 },
            F3 = { type = "damage", value = 1 },
            F4 = { type = "damage", value = 2 },
            F5 = { type = "damage", value = 2 },
            F6 = { type = "damage", value = 3 },

        },
        color = "000000",

    },

}

return dice