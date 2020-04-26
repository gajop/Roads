VFS.Include("libs/gfx/internal.lua")

Shaders = Shaders or {}

function Shaders.Compile(shaderCode, shaderName)
    local shaderID = gl.CreateShader(shaderCode)
    if not shaderID then
        local shaderLog = gl.GetShaderLog(shaderID)
        Spring.Echo("Errors found when compiling shader: " .. tostring(shaderName))
        Spring.Echo(shaderLog)
        return
    end

    local shaderLog = gl.GetShaderLog(shaderID)
    if shaderLog ~= "" then
        Spring.Echo("Potential problems found when compiling shader: " .. tostring(shaderName))
        Spring.Echo(shaderLog)
	end

	local shader = {
		id = shaderID,
		uniforms = {}
	}

	for k, v in pairs(gl.GetActiveUniforms(shaderID)) do
		local uniform = {}
		for k1, v1 in pairs(v) do
			uniform[k1] = v1
		end
		Spring.Echo(uniform.name)
		uniform.id = gl.GetUniformLocation(shaderID, uniform.name)
		Spring.Echo(uniform.id)
		shader.uniforms[uniform.name] = uniform
	end

    return shader
end

Graphics = {}

function Graphics:init()
    self:__InitTempTextures()
end


-- The temp texture functionality provides texture copies on demand.
-- The copies aren't destroyed, as creating and destroying textures can be expensive.
-- They are cached here, and provided when necessary.
-- Users request a list of textures to be copied, which can be of various sizes and types

local __tmpsByCategory = {}
function Graphics:__InitTempTextures()
end

function Graphics:__GetTemp(texInfo)
    -- give away one of the free textures if they exist
    local category = ("%d_%d"):format(texInfo.xsize, texInfo.ysize)

    local tmps = __tmpsByCategory[category]
    if tmps == nil then
        tmps = {}
        __tmpsByCategory[category] = tmps
    end

    for _, tmp in ipairs(tmps) do
        if tmp.free then
            tmp.free = false
            return tmp
        end
    end

    local tmp = {
        free = false,
        texture = gl.CreateTexture(
            texInfo.xsize,
            texInfo.ysize,
            {
                border = false,
                min_filter = GL.LINEAR,
                mag_filter = GL.LINEAR,
                wrap_s = GL.CLAMP_TO_EDGE,
                wrap_t = GL.CLAMP_TO_EDGE,
                fbo = true
            }
        )
    }
    table.insert(tmps, tmp)

    return tmp
end ---------------- -- API: BEGIN ----------------
--

--[[
function Graphics:__MarkAllFree()
	for _, temps in pairs(self.__tempsByCategory) do
		for _, temp in ipairs(temp) do
			temp.free = true
		end
	end
end
]]

function Graphics:MakeTextureCopies(textures)
    local tmps = {}
    for _, texture in ipairs(textures) do
        local tmp = self:__GetTemp(gl.TextureInfo(texture))
        table.insert(tmps, tmp)
    end

    for i, texture in ipairs(textures) do
        local tmp = tmps[i]
        Graphics:Blit(texture, tmp.texture)
    end

    local ret = {}
    for _, tmp in ipairs(tmps) do
        tmp.free = true
        table.insert(ret, tmp.texture)
    end
    return ret
end

-- TODO: Data specific - move someplace else?
function Graphics:MakeMapTextureCopies(mapTextures)
    local wantedCopies = {}
    for i, v in ipairs(mapTextures) do
        table.insert(wantedCopies, v.renderTexture.texture)
    end
    return Graphics:MakeTextureCopies(wantedCopies)
end

function Graphics:DrawBrush(brush, renderTextures)
    -- 0. Get textures and push undo stack textures?
    -- 1. Make copies of target texture(s)
    -- 2. Setup custom shader and its uniforms
    -- 3. Bind textures (brush and material textures)
    -- 4. Perform draw
    -- 5. Unbind shader and textures
end

TextureManager = {}

function TextureManager:AssignShadingTexture(name, opts)
    local source = opts.tex
    local sizeX = opts.sizeX
    local sizeY = opts.sizeY

    local tex = self:MakeShadingTexture(name, sizeX, sizeY)

    Graphics:Blit(source, tex)
    if name:find("splat_normals") then
        gl.GenerateMipmap(tex)
    end
    self:SetShadingTexture(source, tex)

    return tex
end

function TextureManager:SetShadingTexture(name, tex)
    local success = Spring.SetMapShadingTexture(name, tex)
    if not success then
        Spring.Echo("Failed to set new texture: " .. tostring(name) .. ", engine name: " .. tostring(name))
        return
    end
end

function TextureManager:MakeShadingTexture(name, sizeX, sizeY)
    local min_filter = GL.LINEAR
    -- if name == "splat_distr" then
    --    min_filter = GL.LINEAR_MIPMAP_NEAREST
    -- end
	local tex
	Spring.Echo(Spring.GetConfigInt("SSMFTexAniso"))
    if name:find("splat_normals") then
        --gl.GenerateMipmap(tex)
        tex =
            gl.CreateTexture(
            sizeX,
            sizeY,
            {
                border = false,
                min_filter = GL.LINEAR_MIPMAP_NEAREST,
                mag_filter = GL.LINEAR,
                wrap_s = GL.REPEAT,
                wrap_t = GL.REPEAT,
                aniso = Spring.GetConfigInt("SSMFTexAniso"),
                fbo = true
            }
        )
    else
        tex =
            gl.CreateTexture(
            sizeX,
            sizeY,
            {
                border = false,
                min_filter = min_filter,
                mag_filter = GL.LINEAR,
                wrap_s = GL.CLAMP_TO_EDGE,
                wrap_t = GL.CLAMP_TO_EDGE,
                fbo = true
            }
        )
    end
    return tex
end

function Graphics:Blit(tex1, tex2)
	gl.Blending("disable")
    gl.Texture(tex1)
    gl.RenderToTexture(
        tex2,
        function()
            gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
        end
    )
    gl.Texture(false)
end

function TextureManager:TextureFromFile(path)
	local texInfo = gl.TextureInfo(path)
	local texture = TextureManager:MakeShadingTexture(
		"splat_normals_" .. tostring(i),
		texInfo.xsize,
		texInfo.ysize
	)
	Graphics:Blit(':l:' .. path, texture)
	gl.GenerateMipmap(texture)

	return texture
end