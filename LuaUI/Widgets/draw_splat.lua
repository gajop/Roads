function widget:GetInfo()
    return {
        name = "splat drawing",
        desc = "splat drawing",
        author = "gajop",
        license = "MIT",
        layer = 1001,
        enabled = true
        -- handler   = true,
    }
end

VFS.Include("Libs/gfx/gfx.lua")

local initialized = false

local name = "splat_distr"
local engineName = "$ssmf_splat_distr"
local dntsTexture
local splatNormalTextures = {}

local dntsTextureCopy

local doDraw

local startX, startZ
local endX, endZ
local inDrawState = false
local drawType = 0

local GRID_ITEM_SIZE = 64


local function GenerateMapTextures()
    local texInfo = gl.TextureInfo(engineName)
    if not texInfo or texInfo.xsize == 0 then
        Spring.Echo("This map has no splat_texture, things won't work")
    end

    Spring.SetMapShadingTexture(engineName, "")
    local sizeX = Game.mapSizeX / GRID_ITEM_SIZE
    local sizeY = Game.mapSizeZ / GRID_ITEM_SIZE
    dntsTexture = TextureManager:AssignShadingTexture(name,
        {
            tex = engineName,
            sizeX = sizeX,
            sizeY = sizeY
        }
    )
    for i = 1, 4 do
        local imageName = 'road_textures/dnts' .. tostring(i) .. '.png'
        local texture = TextureManager:TextureFromFile(imageName)
        table.insert(splatNormalTextures, texture)

        local success = Spring.SetMapShadingTexture("$ssmf_splat_normals", texture, i - 1)
        if not success then
            Spring.Echo('Failed to set map texture: $ssmf_splat_normals: ', i - 1)
        end
    end
--     dntsTexture = TextureManager:AssignShadingTexture(,
--     {
--         tex = engineName,
--         sizeX = sizeX,
--         sizeY = sizeY
--     }
-- )
    -- dntsTextureCopy =
end

function widget:DrawWorld()
    if not initialized then
        GenerateMapTextures()
        initialized = true
    end

    if doDraw then
        doDraw()
        doDraw = nil
    end
end

local function ClampToGrid(value)
    value = value + GRID_ITEM_SIZE / 2
    return value - value % GRID_ITEM_SIZE
end

function widget:MousePress(x, y, button)
    if button ~= 1 then
        return
    end
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if not coords then
        return
    end
    local x, y, z = coords[1], coords[2], coords[3]
    startX, startZ = ClampToGrid(x), ClampToGrid(z)
    doDraw = function()
        dntsTextureCopy = Graphics:MakeTextureCopies({dntsTexture})[1]
        TextureManager:SetShadingTexture(engineName, dntsTextureCopy)
    end
    inDrawState = true
    return true
end

function widget:MouseMove(x, y, dx, dy, button)
    if not inDrawState then
        return
    end
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if not coords then
        return
    end
    local endX, endZ = ClampToGrid(coords[1]), ClampToGrid(coords[3])
    doDraw = function()
        dntsTextureCopy = Graphics:MakeTextureCopies({dntsTexture})[1]
        DrawDNTS(dntsTextureCopy, startX, startZ, endX, endZ, drawType)
    end
    return true
end

function widget:MouseRelease(x, y, button)
    if not inDrawState then
        return
    end
    if button ~= 1 then
        return
    end
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if not coords then
        return
    end
    endX, endZ = ClampToGrid(coords[1]), ClampToGrid(coords[3])
    doDraw = function()
        TextureManager:SetShadingTexture(engineName, dntsTexture)
        DrawDNTS(dntsTexture, startX, startZ, endX, endZ, drawType)
    end
    inDrawState = false
end

function widget:KeyPress(key)
    local redoDraw = false

    if key == KEYSYMS.ESCAPE then
        inDrawState = false
        TextureManager:SetShadingTexture(engineName, dntsTexture)
        return true
    elseif key == 49 then
        drawType = 0
        Spring.Echo("Texture 1")
        redoDraw = true
    elseif key == 50 then
        drawType = 1
        Spring.Echo("Texture 2")
        redoDraw = true
    elseif key == 51 then
        drawType = 2
        Spring.Echo("Eraser")
        redoDraw = true
    end

    if redoDraw and inDrawState then
        doDraw = function()
            dntsTextureCopy = Graphics:MakeTextureCopies({dntsTexture})[1]
            DrawDNTS(dntsTextureCopy, startX, startZ, endX, endZ, drawType)
        end
        return true
    end
end

function widget:Shutdown()
    if dntsTexture then
        gl.DeleteTexture(dntsTexture)
    end
    if dntsTextureCopy then
        gl.DeleteTexture(dntsTextureCopy)
    end
    if splatNormalTextures then
        for _, texture in ipairs(splatNormalTextures) do
            gl.DeleteTexture(texture)
        end
    end
end

---------------------------------------------------
-- TODO: Code below this line needs serious cleanup
---------------------------------------------------

local dntsShader

function getDNTSShader()
    if dntsShader == nil then
        local shaderFragStr = VFS.LoadFile("shaders/dnts_drawing.glsl", nil, VFS.MOD)
        local shaderTemplate = {
            fragment = shaderFragStr,
            uniformInt = {
                mapTex = 0,
            }
        }

        local shader = Shaders.Compile(shaderTemplate, "dnts")
        if not shader then
            return
        end
        dntsShader = shader
    end

    return dntsShader
end

-- FIXME: This is unnecessary probably. Confirm with engine code
local function CheckGLSL(shader)
    local errors = gl.GetShaderLog(shader)
    if errors ~= "" then
        Spring.Echo("Shader error!")
        Spring.Echo(errors)
    end
end

function DrawDNTS(texture, x1, z1, x2, z2, drawType)
    local texType = "splat_distr"

    local originalTex = Graphics:MakeTextureCopies({texture})[1]

    local shader = getDNTSShader()
    if shader == nil then
        return
    end
    local shaderID = shader.shader
    local uniforms = shader.uniforms

    local centerX = math.min(x1, x2)
    local centerZ = math.min(z1, z2)
    local sizeX = math.abs(x1 - x2)
    local sizeZ = math.abs(z1 - z2)

    local sizeX = sizeX / Game.mapSizeX
    local sizeZ = sizeZ / Game.mapSizeZ
    local mx = centerX / Game.mapSizeX
    local mz = centerZ / Game.mapSizeZ

    gl.Blending("enable")
    gl.UseShader(shader.id)

    local mCoord, vCoord = __GenerateMapCoords(mx, mz, sizeX, sizeZ)

    gl.UniformInt(uniforms.colorIndex.id, drawType)

    gl.Texture(0, originalTex)
    gl.RenderToTexture(texture, ApplyDNTSTexture, mCoord, vCoord)

    CheckGLSL(shader.id)

    gl.Texture(0, false)
    gl.Texture(1, false)
    gl.UseShader(0)
end