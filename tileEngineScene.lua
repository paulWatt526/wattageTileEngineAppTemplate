local Composer = require( "composer" )
local TileEngine = require "plugin.wattageTileEngine"

local scene = Composer.newScene()

-- -----------------------------------------------------------------------------------
-- This table represents a simple environment.  Replace this with
-- the model needed for your application.
-- -----------------------------------------------------------------------------------
local ENVIRONMENT = {
    {2,2,2,2,2,1,1,1,1,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {1,1,1,1,1,1,0,0,0,1,1,1,1,1,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
    {1,1,1,1,1,1,0,0,0,1,1,1,1,1,1},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,0,0,0,1,2,2,2,2,2},
    {2,2,2,2,2,1,1,1,1,1,2,2,2,2,2},
}

local ROW_COUNT         = #ENVIRONMENT      -- Row count of the environment
local COLUMN_COUNT      = #ENVIRONMENT[1]   -- Column count of the environment

local tileEngine                            -- Reference to the tile engine
local lightingModel                         -- Reference to the lighting model
local tileEngineViewControl                 -- Reference to the UI view control
local lastTime = 0                          -- Used to track how much time passes between frames

-- -----------------------------------------------------------------------------------
-- This will load in the example sprite sheet.  Replace this with the sprite
-- sheet needed for your application.
-- -----------------------------------------------------------------------------------
local spriteSheetInfo = require "tiles"
local spriteSheet = graphics.newImageSheet("tiles.png", spriteSheetInfo:getSheet())

-- -----------------------------------------------------------------------------------
-- A sprite resolver is required by the engine.  Its function is to create a
-- SpriteInfo object for the supplied key.  This function will utilize the
-- example sprite sheet.
-- -----------------------------------------------------------------------------------
local spriteResolver = {}
spriteResolver.resolveForKey = function(key)
    local frameIndex = spriteSheetInfo:getFrameIndex(key)
    local frame = spriteSheetInfo.sheet.frames[frameIndex]
    local displayObject = display.newImageRect(spriteSheet, frameIndex, frame.width, frame.height)
    return TileEngine.SpriteInfo.new({
        imageRect = displayObject,
        width = frame.width,
        height = frame.height
    })
end

-- -----------------------------------------------------------------------------------
-- A simple helper function to add floor tiles to a layer.
-- -----------------------------------------------------------------------------------
local function addFloorToLayer(layer)
    for row=1,ROW_COUNT do
        for col=1,COLUMN_COUNT do
            local value = ENVIRONMENT[row][col]
            if value == 0 then
                layer.updateTile(
                    row,
                    col,
                    TileEngine.Tile.new({
                        resourceKey="tiles_0"
                    })
                )
            elseif value == 1 then
                layer.updateTile(
                    row,
                    col,
                    TileEngine.Tile.new({
                        resourceKey="tiles_1"
                    })
                )
            end
        end
    end
end

-- -----------------------------------------------------------------------------------
-- This is a callback required by the lighting model to determine whether a tile
-- is transparent.
-- -----------------------------------------------------------------------------------
local function isTileTransparent(column, row)
    local rowTable = ENVIRONMENT[row]
    if rowTable == nil then
        return true
    end
    local value = rowTable[column]
    return value == nil or value == 0
end

-- -----------------------------------------------------------------------------------
-- This is a callback required by the lighting model to determine whether a tile
-- should be affected by ambient light.  This simple implementation always returns
-- true which indicates that all tiles are affected by ambient lighting.
-- -----------------------------------------------------------------------------------
local function allTilesAffectedByAmbient(column, row)
    return true
end

-- -----------------------------------------------------------------------------------
-- This will be called every frame.  It is responsible for setting the camera
-- positiong, updating the lighting model, rendering the tiles, and reseting
-- the dirty tiles on the lighting model.
-- -----------------------------------------------------------------------------------
local function onFrame(event)
    local camera = tileEngineViewControl.getCamera()
    local lightingModel = tileEngine.getActiveModule().lightingModel

    if lastTime ~= 0 then
        local curTime = event.time
        local deltaTime = curTime - lastTime
        lastTime = curTime

        lightingModel.update(deltaTime)
    else
        lastTime = event.time

        camera.setLocation(7.5, 7.5)
        lightingModel.update(1)
    end

    tileEngine.render(camera)

    lightingModel.resetDirtyFlags()
end

-- -----------------------------------------------------------------------------------
-- Scene event functions
-- -----------------------------------------------------------------------------------

-- create()
function scene:create( event )
    local sceneGroup = self.view

    local tileEngineLayer = display.newGroup()
    tileEngine = TileEngine.Engine.new({
        parentGroup=tileEngineLayer,
        tileSize=32,
        spriteResolver=spriteResolver,
        compensateLightingForViewingPosition=false,
        hideOutOfSightElements=false
    })

    lightingModel = TileEngine.LightingModel.new({
        isTransparent = isTileTransparent,
        isTileAffectedByAmbient = allTilesAffectedByAmbient,
        useTransitioners = false,
        compensateLightingForViewingPosition = false
    })

    lightingModel.setAmbientLight(1,1,1,0.7)

    local module = TileEngine.Module.new({
        name="moduleMain",
        rows=ROW_COUNT,
        columns=COLUMN_COUNT,
        lightingModel=lightingModel,
        losModel=TileEngine.LineOfSightModel.ALL_VISIBLE
    })

    local floorLayer = TileEngine.TileLayer.new({
        rows = ROW_COUNT,
        columns = COLUMN_COUNT
    })
    addFloorToLayer(floorLayer)
    module.insertLayerAtIndex(floorLayer, 1, 0)

    tileEngine.addModule({module = module})

    module.layers[1].layer.resetDirtyTileCollection()

    tileEngine.setActiveModule({
        moduleName = "moduleMain"
    })

    tileEngineViewControl = TileEngine.ViewControl.new({
        parentGroup = sceneGroup,
        centerX = display.contentCenterX,
        centerY = display.contentCenterY,
        pixelWidth = display.actualContentWidth,
        pixelHeight = display.actualContentHeight,
        tileEngineInstance = tileEngine
    })
end


-- show()
function scene:show( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is still off screen (but is about to come on screen)
        lastTime = 0
        Runtime:addEventListener( "enterFrame", onFrame )
    elseif ( phase == "did" ) then
        -- Code here runs when the scene is entirely on screen
    end
end


-- hide()
function scene:hide( event )
    local sceneGroup = self.view
    local phase = event.phase

    if ( phase == "will" ) then
        -- Code here runs when the scene is on screen (but is about to go off screen)
        Runtime:removeEventListener( "enterFrame", onFrame )
    elseif ( phase == "did" ) then
        -- Code here runs immediately after the scene goes entirely off screen
    end
end


-- destroy()
function scene:destroy( event )

    local sceneGroup = self.view
    -- Code here runs prior to the removal of scene's view
    tileEngine.destroy()
    tileEngine = nil

    tileEngineViewControl.destroy()
    tileEngineViewControl = nil

    lightingModel = nil
end


-- -----------------------------------------------------------------------------------
-- Scene event function listeners
-- -----------------------------------------------------------------------------------
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )
-- -----------------------------------------------------------------------------------

return scene