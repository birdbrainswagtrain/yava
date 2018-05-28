
if SERVER then return end
include("yava_lib/jit_watch.lua")
include("yava_lib/textures.lua")


-- maps id -> info table
-- maps name -> id
-- {name,(opacity,tex)*6,mesh_data?}
local block_info = {
    {"air",0,0,0,0,0,0,0,0,0,0,0,0},
    air=1
}
-- info table: 
    -- numeric indexes = frequently used shit
        -- name
        -- face data
        -- extra mesh data
    -- string indexes = callbacks and shit

local chunks = {}
local function chunk_key(x,y,z)
    return x+y*1024+z*1048576
end

function yava.setup(config)
    yava.config = config

    yava._setup_atlas()

    yava._setup_blockdata()

    yava.setup = function()
        error("Yava has already initialized.")
    end
    
    -- GENERATION
    --[[for cz=0,config.dimensions.z-1 do
        for cy=0,config.dimensions.y-1 do
            for cx=0,config.dimensions.x-1 do
                local base_block = cz <= 1 and 2 or 0
                local base_data = rep_packed_12(base_block)
                local block_data = {base_data,base_data,base_data,base_data,base_data,base_data,base_data,base_data}

                --JIT_WATCH_START()
                for z=0,31 do
                    for y=0,31 do
                        for x=0,31 do
                            --local c = math.random()>.9
                            local rx = cx*32+x
                            local ry = cy*32+y
                            local rz = cz*32+z

                            local c = rz < math.sin(rx/8)*8 + math.cos(ry/8)*8 + 64
                            chunk_set_block(block_data,x,y,z,c and 2 or 0,cx==0 and cy==0 and cz==2 and y==0 and z==0)
                        end
                    end
                end
                --JIT_WATCH_PAUSE()

                chunks[chunk_key(cx,cy,cz)] = {x=cx,y=cy,z=cz,block_data=block_data}
                --print(">>",#block_data)
            end
        end
    end
    local t2 = SysTime()
    local ts = 0
    local tn = 0

    for _,chunk in pairs(chunks) do
        --JIT_WATCH_START()
        local cnx = chunks[(chunk.x+1)..":"..chunk.y..":"..chunk.z]
        local cny = chunks[chunk.x..":"..(chunk.y+1)..":"..chunk.z]
        local cnz = chunks[chunk.x..":"..chunk.y..":"..(chunk.z+1)]
        local data,quad_count = chunk_gen_mesh_striped_rowfetch_stitch(chunk.block_data,chunk.x,chunk.y,chunk.z,cnx and cnx.block_data,cny and cny.block_data,cnz and cnz.block_data)
        --JIT_WATCH_PAUSE()
        
        local my_mesh = nil
        if quad_count>0 then
            local ta = SysTime()
            my_mesh = Mesh()
            
            local index = 1
            local normal = Vector()
            local pos = Vector()
            mesh.Begin(my_mesh,MATERIAL_QUADS,quad_count)
            for i=1,quad_count do
                normal.x = data[index]
                normal.y = data[index+1]
                normal.z = data[index+2]
                index = index+3
                
                for j=1,4 do
                    pos.x = data[index]
                    pos.y = data[index+1]
                    pos.z = data[index+2]
                    local u = data[index+3]
                    local v = data[index+4]
                    index = index+5
                    
                    mesh.Position(pos)
                    mesh.Normal(normal)
                    mesh.TexCoord(0, u, v)        
                    mesh.AdvanceVertex()
                end
            end
            mesh.End()
            
            local tb = SysTime()
            local t = tb - ta
            --print(string.format("%.10f",t/(count/6)))
        else
            --print("EMPTY")
        end
        
        chunk.mesh = my_mesh
    end
    
    local t3 = SysTime()
    
    return t2-t1, t3-t2]]
end

if false then
    local as = {}
    local bs = {}
    for i=1,21 do
        as[i],bs[i] = setup()
    end
    table.sort(as)
    table.sort(bs)
    print("WORLD GEN")
    PrintTable(as)
    print("MESH GEN")
    PrintTable(bs)
    print(bs[1],bs[7],bs[14],bs[21])
end

yava.setup{
    dimensions = Vector(4,4,4),
    block_types = {
        face={},
        checkers={},
        purple={},
        stripes={}
    },
    generator = function(x,y,z)
        local c = rz < math.sin(rx/8)*8 + math.cos(ry/8)*8 + 64
        return c and "face" or "air"
    end
}

--JIT_WATCH_PRINT()
--[[
local memory_sum = 0
for _,chunk in pairs(chunks) do
    memory_sum = memory_sum + #chunk.block_data
end
print("Memory usage:",(memory_sum*8).." bytes")
print("Memory/block:",string.format("%.2f",(memory_sum*8)/(128*128*128)).." bytes")

--local material_base = Material("atlas-ng.png")
--local material = CreateMaterial("yava-atlas", "VertexLitGeneric")
--material:SetTexture("$basetexture",material_base:GetTexture("$basetexture"))
local material = Material("yava-atlas")

local scale = 40

local matrix = Matrix()
matrix:Translate( Vector(-4000,-600,0) )
matrix:Scale( Vector( 1, 1, 1 ) * scale )

hook.Add("PostDrawOpaqueRenderables","pdoraawa",function()
    render.SetMaterial( material )

    render.SuppressEngineLighting(true) 
    render.SetModelLighting(BOX_TOP,    1,1,1 )
    render.SetModelLighting(BOX_FRONT,  .8,.8,.8 )
    render.SetModelLighting(BOX_RIGHT,  .6,.6,.6 )
    render.SetModelLighting(BOX_LEFT,   .5,.5,.5 )
    render.SetModelLighting(BOX_BACK,   .3,.3,.3 )
    render.SetModelLighting(BOX_BOTTOM, .1,.1,.1 )
    
    cam.PushModelMatrix( matrix )
    for _,chunk in pairs(chunks) do
        if chunk.mesh then
            chunk.mesh:Draw()
        end
    end
    cam.PopModelMatrix()
end)

--local poop = Material("yava/face.png")
--print(poop:GetTexture("$basetexture"))


local atlas_material = CreateMaterial("__yava_atlas_mat", "VertexLitGeneric")
atlas_material:SetTexture("$basetexture",atlas_texture) -- <--

--local poop_id = surface.GetTextureID("yava/face")
hook.Add("HUDPaint", "sd0f98sdf", function()

    --[[render.PushRenderTarget(atlas_texture)
    cam.Start2D()
    render.Clear(255,0,0,255)
    surface.DrawRect(0,0,100,100) 
    cam.End2D()
    render.PopRenderTarget()
    
    surface.SetMaterial(atlas_material)
    surface.SetDrawColor( 255, 255, 255, 255 )
    surface.DrawTexturedRect(10,10,16,1024)

    --print(poop_id)
end)]]