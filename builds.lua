-- builds.lua
local BuildsModule = {}

function BuildsModule.init(ENV)
    local mk          = ENV.mk
    local corner      = ENV.corner
    local stroke      = ENV.stroke
    local pad         = ENV.pad
    local lbl         = ENV.lbl
    local box         = ENV.box
    local btn         = ENV.btn
    local T           = ENV.T
    local SG          = ENV.SG
    local Body        = ENV.Body
    local RunService  = ENV.RunService
    local Camera      = ENV.Camera
    local Mouse       = ENV.Mouse
    local envF        = ENV.envF
    local savePrevF   = ENV.savePrevF
    local LP          = ENV.LP
    local Players     = ENV.Players
    local closestZone = ENV.closestZone
    local myRefPos    = ENV.myRefPos
    local zoneDeltaRot    = ENV.zoneDeltaRot
    local getTool     = ENV.getTool
    local equipTool   = ENV.equipTool
    local userFolder  = ENV.userFolder
    local dataFolder  = ENV.dataFolder
    local captureBuild = ENV.captureBuild
    local countPB     = ENV.countPB
    local getTeamColor = ENV.getTeamColor
    local paintBatch  = ENV.paintBatch
    local ICON_MOVE   = ENV.ICON_MOVE
    local ICON_ROT    = ENV.ICON_ROT
    local ICON_LEADER = ENV.ICON_LEADER
    local FSys        = ENV.FSys
    local FS2         = ENV.FS2
    local readBF      = ENV.readBF
    local writeBF     = ENV.writeBF
    local ORD         = ENV.ORD
    local lOrd        = ENV.lOrd
    local syncOrd     = ENV.syncOrd
    local addSaveOrd  = ENV.addSaveOrd
    local delSaveOrd  = ENV.delSaveOrd
    local Saves       = ENV.Saves
    local autoName    = ENV.autoName
    local GKEY        = ENV.GKEY
    local gbRunningRef = ENV.gbRunning
    local openCP      = ENV.openCP

    local function isLdr(playerName)
        local p = (playerName and Players:FindFirstChild(playerName)) or LP
        if not p or not p.Team then return false end
        local leaderVal = p.Team:FindFirstChild("TeamLeader")
        if leaderVal and leaderVal:IsA("StringValue") then
            return leaderVal.Value == p.Name
        end
        return false
    end

    local function isSharing()
        local shareVal = LP:FindFirstChild("Settings") and LP.Settings:FindFirstChild("ShareBlocks")
        if shareVal and shareVal:IsA("BoolValue") then
            return shareVal.Value
        end
        return false
    end

    local PageSave = mk("ScrollingFrame", Body, {
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.purple,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        Visible = false
    })
    mk("UIListLayout", PageSave, {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})
    pad(PageSave, 10, 10, 10, 10)

    local myBaseCF    = nil
    local selPlayer   = LP.Name
    local selSaveIdx  = nil
    local placePosV   = nil
    local placeScale  = 1
    local placeRot    = CFrame.identity
    local saveToolMode = "move"
    local savePrevOn  = true
    local savePrevAlpha = 0.3
    local useCZ       = true
    local SaveUI      = {}
    local whoVis      = false
    local whoFrame    = nil
    local whoBtn      = nil
    local whoInner    = nil
    local curUID      = LP.UserId
    local curDN       = "Yo"
    local curUN       = LP.Name
    local saveBuildState = {running=false, cancel=false}
    local isShareModeOn = false
    local copyScope   = "zone"

    -- Estado extendido (1 local para agrupar todo lo nuevo)
    local extState = {favs={}, colors={}, rowView=1}
    -- Colores pastel para guardados
    local PASTEL_COLS = {
        Color3.fromRGB(255,182,193), -- rosa
        Color3.fromRGB(173,216,230), -- celeste
        Color3.fromRGB(144,238,144), -- verde menta
        Color3.fromRGB(255,255,153), -- amarillo
        Color3.fromRGB(221,160,221), -- violeta
    }

    local PURPLE_GAMER = Color3.fromRGB(170, 0, 255)

    -- ── Helpers de UI ──────────────────────────────────────────────────────
    local function sec(parent, order)
        local f=mk("Frame",parent,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=T.card,BorderSizePixel=0,LayoutOrder=order or 0})
        corner(f,8); pad(f,10,10,8,10); mk("UIListLayout",f,{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder})
        return f
    end

    -- ── Inventario helper ───────────────────────────────────────────────────
    local DEF_IMG = "rbxassetid://12328114032"

    local function getBlockImage(name)
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        if pg then
            local bf = pg:FindFirstChild("BuildGui")
                and pg.BuildGui:FindFirstChild("InventoryFrame")
                and pg.BuildGui.InventoryFrame:FindFirstChild("ScrollingFrame")
                and pg.BuildGui.InventoryFrame.ScrollingFrame:FindFirstChild("BlocksFrame")
            if bf then
                local tpl = bf:FindFirstChild(name)
                if tpl and tpl:IsA("ImageButton") then return tpl.Image end
            end
        end
        return ""
    end

    local function getPlayerBlocks()
        local result = {}
        local df = LP:FindFirstChild("Data")
        if not df then return result end
        for _, item in ipairs(df:GetChildren()) do
            if item:IsA("ValueBase") and item.Name:sub(-5) == "Block" then
                local qty = tonumber(item.Value) or 0
                if qty > 0 then
                    result[#result+1] = {name=item.Name, qty=qty, image=getBlockImage(item.Name)}
                end
            end
        end
        table.sort(result, function(a,b) return a.name < b.name end)
        return result
    end

    -- ── Zonas ───────────────────────────────────────────────────────────────
    local ZONE_NAMES = {
        "MagentaZone", "New YellerZone", "Really blueZone",
        "Really redZone", "WhiteZone", "CamoZone", "BlackZone",
    }
    local function findZoneByName(name)
        if not name then return nil end
        local z = game:GetService("Workspace"):FindFirstChild(name, true)
        if z and z:IsA("BasePart") then return z end
        return nil
    end
    local function zoneContainsXZ(zone, pos)
        local localPos = zone.CFrame:ToObjectSpace(CFrame.new(pos)).Position
        local half = zone.Size / 2
        return math.abs(localPos.X) <= half.X and math.abs(localPos.Z) <= half.Z
    end
    local function teamZone(player)
        if not player then return nil end
        local team = player.Team
        if not team or not team.TeamColor then return nil end
        local zName = team.TeamColor.Name .. "Zone"
        local ok, z = pcall(function() return workspace:FindFirstChild(zName, true) end)
        if ok and z and z:IsA("BasePart") then return z end
        return nil
    end
    local _myZoneCache = nil
    local function myZone()
        if _myZoneCache and _myZoneCache.Parent then return _myZoneCache end
        local z = teamZone(LP)
        if not z then
            local cz = closestZone(myRefPos())
            if cz and cz:IsA("BasePart") then z = cz end
        end
        if z then _myZoneCache = z end
        return z
    end

    local findPlayerZone

    local function countFor(un)
        if copyScope ~= "zone" then return countPB(un) end
        local uf = userFolder(un); if not uf then return 0 end
        local p = Players:FindFirstChild(un)
        local zone = p and teamZone(p)
        if not zone then
            local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            zone = hrp and findPlayerZone(hrp.Position)
        end
        if not zone then return countPB(un) end
        local zPos = zone.Position; local zCF = zone.CFrame; local half = zone.Size/2
        local c = 0
        for _,d in ipairs(uf:GetDescendants()) do
            if d:IsA("BasePart") then
                local off = d.Position - zPos
                if math.abs(off:Dot(zCF.XVector)) <= half.X and math.abs(off:Dot(zCF.ZVector)) <= half.Z then c = c + 1 end
            end
        end
        return c
    end

    -- ── cCache / buildCenter ──────────────────────────────────────────────
    local cCache = {}
    local function buildCenter(sv)
        if not sv or not sv.data or not sv.data.Block or #sv.data.Block==0 then return Vector3.zero end
        if cCache[sv] then return cCache[sv] end
        local minv=Vector3.new(math.huge,math.huge,math.huge); local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,pd in ipairs(sv.data.Block) do local p=Vector3.new(pd.RelX or 0,pd.RelY or 0,pd.RelZ or 0); minv=Vector3.new(math.min(minv.X,p.X),math.min(minv.Y,p.Y),math.min(minv.Z,p.Z)); maxv=Vector3.new(math.max(maxv.X,p.X),math.max(maxv.Y,p.Y),math.max(maxv.Z,p.Z)) end
        local c=(minv+maxv)/2; cCache[sv]=c; return c
    end
    local function defaultCenter(sv)
        local mz=myZone()
        if mz then return (mz.CFrame * CFrame.new(buildCenter(sv))).Position end
        return myRefPos()
    end
    local function blockWorldCF(pd, center, centerWorld, destRot)
        local relRot = CFrame.Angles(math.rad(pd.RotX or 0), math.rad(pd.RotY or 0), math.rad(pd.RotZ or 0))
        local off = Vector3.new((pd.RelX or 0) - center.X, (pd.RelY or 0) - center.Y, (pd.RelZ or 0) - center.Z)
        return CFrame.new(centerWorld) * destRot * placeRot * CFrame.new(off * placeScale) * relRot
    end
    local function curPlacePos()
        if placePosV then return placePosV end
        local z=myZone(); if z then return z.Position+Vector3.new(0,z.Size.Y/2+1,0) end
        return myRefPos()
    end

    -- ── Handles 3D ────────────────────────────────────────────────────────
    local saveDummy = mk("Part", envF, {Size=Vector3.new(4,4,4),Transparency=1,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})
    local SaveHandles = mk("Handles", SG, {
        Adornee = saveDummy,
        Style   = Enum.HandlesStyle.Movement,
        Color3  = PURPLE_GAMER,
        Visible = false,
    })
    pcall(function() SaveHandles.AlwaysOnTop = true end)

    local saveArcAdornee = mk("Part", envF, {Size=Vector3.new(12,12,12),Transparency=1,Anchored=true,CanCollide=false,CanQuery=false,Material=Enum.Material.Plastic,Position=Vector3.new(0,-9999,0)})
    local SaveArc = mk("ArcHandles", SG, {
        Adornee = saveArcAdornee,
        Color3  = PURPLE_GAMER,
        Visible = false,
    })
    pcall(function() SaveArc.AlwaysOnTop = true end)

    local function updSaveHandles()
        local hasSel=selSaveIdx~=nil and savePrevOn
        if not PageSave.Visible then SaveHandles.Visible=false; SaveArc.Visible=false; return end
        SaveHandles.Visible=hasSel and saveToolMode=="move"
        SaveArc.Visible    =hasSel and saveToolMode=="rotate"
        if hasSel then
            local pos=curPlacePos()
            saveDummy.CFrame=CFrame.new(pos)*placeRot
            saveArcAdornee.CFrame=CFrame.new(pos)*placeRot
        else
            saveArcAdornee.Position=Vector3.new(0,-9999,0)
        end
    end

    local savePool={}
    local renderSavePrev
    renderSavePrev = function()
        local sv=selSaveIdx and Saves[selSaveIdx]
        if not sv or not sv.data or not sv.data.Block or not savePrevOn then
            for _,p in ipairs(savePool) do p.Transparency=1; p.Size=Vector3.new(0.05,0.05,0.05) end
            saveDummy.Position=Vector3.new(0,-9999,0); saveArcAdornee.Position=Vector3.new(0,-9999,0)
            SaveHandles.Visible=false; SaveArc.Visible=false; return
        end
        local pos=curPlacePos(); local center=buildCenter(sv); local mz=myZone(); local destRot=mz and (mz.CFrame-mz.CFrame.Position) or CFrame.identity
        local blocks=sv.data.Block; local n=0
        local minv=Vector3.new(math.huge,math.huge,math.huge); local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
        for _,pd in ipairs(blocks) do
            n=n+1; local p=savePool[n]
            if not p then p=mk("Part",savePrevF,{Anchored=true,CanCollide=false,CanQuery=false,CanTouch=false,CastShadow=false,Material=Enum.Material.Plastic}); savePool[n]=p end
            local bCF=blockWorldCF(pd, center, pos, destRot); local bSz=Vector3.new(pd.SizeX or 2,pd.SizeY or 2,pd.SizeZ or 2)*placeScale
            p.Size=bSz; p.CFrame=bCF
            p.Material = Enum.Material[pd.Material] or Enum.Material.Plastic
            p.Color=(pd.ColorR and Color3.new(pd.ColorR,pd.ColorG,pd.ColorB)) or T.purple
            p.Transparency=savePrevAlpha
            local hS=bSz/2; local pP=bCF.Position
            minv=Vector3.new(math.min(minv.X,pP.X-hS.X),math.min(minv.Y,pP.Y-hS.Y),math.min(minv.Z,pP.Z-hS.Z))
            maxv=Vector3.new(math.max(maxv.X,pP.X+hS.X),math.max(maxv.Y,pP.Y+hS.Y),math.max(maxv.Z,pP.Z+hS.Z))
        end
        for i=n+1,#savePool do savePool[i].Transparency=1; savePool[i].Size=Vector3.new(0.05,0.05,0.05) end
        if minv.X~=math.huge then local sz=maxv-minv; saveDummy.Size=Vector3.new(math.clamp(sz.X,4,200),math.clamp(sz.Y,4,200),math.clamp(sz.Z,4,200)); saveArcAdornee.Size=saveDummy.Size else saveDummy.Size=Vector3.new(4,4,4) end
        saveDummy.CFrame=CFrame.new(pos)*placeRot; saveArcAdornee.CFrame=CFrame.new(pos)*placeRot
        updSaveHandles()
    end

    do
        local sDrag=false; local sDragOP=nil; local sSavedCam=nil
        local sArcDrag=false; local sArcStartRot=nil; local sArcSavedCam=nil
        SaveHandles.MouseButton1Down:Connect(function() if not PageSave.Visible or not selSaveIdx then return end; sDrag=true; sDragOP=curPlacePos(); sSavedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable end)
        SaveHandles.MouseDrag:Connect(function(face,dist) if not sDrag or not sDragOP then return end; local st=tonumber(SaveUI.saveMoveStep and SaveUI.saveMoveStep.Text) or 0; if st<0 then st=0 end; local d=(st>0)and(math.floor(dist/st+0.5)*st)or dist; local dir=(CFrame.new(sDragOP)*placeRot):VectorToWorldSpace(Vector3.FromNormalId(face)); placePosV=sDragOP+dir*d; useCZ=false; renderSavePrev() end)
        SaveHandles.MouseButton1Up:Connect(function() if not sDrag then return end; sDrag=false; sSavedCam=nil; Camera.CameraType=Enum.CameraType.Custom end)
        SaveArc.MouseButton1Down:Connect(function() if not PageSave.Visible or not selSaveIdx then return end; sArcDrag=true; sArcStartRot=placeRot; sArcSavedCam=Camera.CFrame; Camera.CameraType=Enum.CameraType.Scriptable end)
        SaveArc.MouseDrag:Connect(function(axis,relAngle) if not sArcDrag then return end; local av=(axis==Enum.Axis.X and Vector3.xAxis)or(axis==Enum.Axis.Y and Vector3.yAxis)or Vector3.zAxis; local st=tonumber(SaveUI.saveRotStep and SaveUI.saveRotStep.Text) or 0; if st<0 then st=0 end; local snapped=(st>0)and math.rad(math.floor(math.deg(relAngle)/st+0.5)*st)or relAngle; placeRot=sArcStartRot*CFrame.fromAxisAngle(av,snapped); renderSavePrev() end)
        SaveArc.MouseButton1Up:Connect(function() if not sArcDrag then return end; sArcDrag=false; sArcSavedCam=nil; Camera.CameraType=Enum.CameraType.Custom end)
        RunService.RenderStepped:Connect(function() if sDrag and sSavedCam then Camera.CFrame=sSavedCam end; if sArcDrag and sArcSavedCam then Camera.CFrame=sArcSavedCam end end)
    end

    -- ── setWhoBtn / refreshWho ─────────────────────────────────────────────
    local function setWhoBtn(uid,dn,un)
        if not whoBtn then return end
        for _,c in ipairs(whoBtn:GetChildren()) do if not c:IsA("UICorner") and not c:IsA("UIStroke") then c:Destroy() end end
        whoBtn.BackgroundColor3=getTeamColor(un)
        local isL=isLdr(un); if isL then mk("ImageLabel",whoBtn,{Name="LdrIco",Size=UDim2.new(0,14,0,14),Position=UDim2.new(0,4,0.5,-7),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) end
        local avX=isL and 20 or 4; local av=mk("ImageLabel",whoBtn,{Name="Avatar",Size=UDim2.new(0,22,0,22),Position=UDim2.new(0,avX,0.5,-11),BackgroundColor3=T.card,BorderSizePixel=0}); corner(av,6)
        task.spawn(function() local ok2,url=pcall(function() return Players:GetUserThumbnailAsync(uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end); if ok2 and av and av.Parent then av.Image=url end end)
        local nX=avX+26; local nL=mk("TextLabel",whoBtn,{Position=UDim2.new(0,nX,0,0),Size=UDim2.new(1,-nX-18,1,0),Text=dn.." (@"..un..")",TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd})
        mk("TextLabel",whoBtn,{Position=UDim2.new(1,-18,0,0),Size=UDim2.new(0,16,1,0),Text=whoVis and"▲"or"▼",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center})
        task.spawn(function() local bc=countFor(un); if nL and nL.Parent then nL.Text=dn.." (@"..un..") · "..bc end end)
    end

    local selTickToken = nil
    local refreshWho
    do
        local whoRows={}; local whoEmptyL=nil
        local function listTC(un)
            if un==LP.Name then return T.btnAlt end
            for _,p in ipairs(Players:GetPlayers()) do if p.Name==un and p.Team and p.Team.TeamColor then local tc=p.Team.TeamColor.Color; return Color3.new(tc.R*0.25,tc.G*0.25,tc.B*0.25) end end
            return T.btnAlt
        end
        local function whoMembers()
            local m={}; local allP=Players:GetPlayers()
            local myTeam = LP.Team
            table.sort(allP, function(a, b)
                local aIsMyTeam = (a.Team == myTeam)
                local bIsMyTeam = (b.Team == myTeam)
                if aIsMyTeam ~= bIsMyTeam then return aIsMyTeam end
                local aLdr, bLdr = isLdr(a.Name), isLdr(b.Name)
                if aLdr ~= bLdr then return aLdr end
                local at = a.Team and a.Team.TeamColor.Number or -1
                local bt = b.Team and b.Team.TeamColor.Number or -1
                if at ~= bt then return at < bt end
                return a.Name < b.Name
            end)
            for _,p in ipairs(allP) do if p.Name~=selPlayer then m[#m+1]={uid=p.UserId,dname=p.DisplayName or p.Name,uname=p.Name} end end
            return m
        end
        local function buildWhoRow(mem)
            local row=mk("Frame",whoInner,{Size=UDim2.new(1,0,0,36),BackgroundColor3=listTC(mem.uname),BorderSizePixel=0}); corner(row,8)
            local isL=isLdr(mem.uname); if isL then mk("ImageLabel",row,{Name="LdrIco",Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0.5,-8),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) end
            local avX2=isL and 22 or 5; local av=mk("ImageLabel",row,{Name="Avatar",Size=UDim2.new(0,26,0,26),Position=UDim2.new(0,avX2,0.5,-13),BackgroundColor3=T.card,BorderSizePixel=0}); corner(av,6)
            task.spawn(function() local ok2,url=pcall(function() return Players:GetUserThumbnailAsync(mem.uid,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end); if ok2 and av and av.Parent then av.Image=url end end)
            local nX2=avX2+30
            mk("TextLabel",row,{Position=UDim2.new(0,nX2,0,4),Size=UDim2.new(1,-100,0,14),Text=mem.dname,TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left})
            mk("TextLabel",row,{Position=UDim2.new(0,nX2,0,20),Size=UDim2.new(1,-100,0,12),Text="@"..mem.uname,TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left})
            local bkL=mk("TextLabel",row,{Position=UDim2.new(1,-62,0,0),Size=UDim2.new(0,60,1,0),Text="...",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right})
            local rb=mk("TextButton",row,{Size=UDim2.new(1,0,1,0),Text="",BackgroundTransparency=1})
            rb.MouseButton1Click:Connect(function()
                selPlayer=mem.uname; curUID=mem.uid; curDN=mem.dname; curUN=mem.uname
                whoVis=false; if whoFrame then whoFrame.Visible=false end
                if whoBtn then for _,ch in ipairs(whoBtn:GetChildren()) do if ch:IsA("TextLabel")and(ch.Text=="▲"or ch.Text=="▼") then ch.Text="▼" end end end
                setWhoBtn(curUID, curDN, curUN)
                refreshWho()
            end)
            return {row=row,blockLbl=bkL,lastCount=nil,lastTC=nil}
        end
        refreshWho = function()
            if not whoInner then return end
            local members=whoMembers(); local present={}; for _,m in ipairs(members) do present[m.uid]=m end
            for uid,rec in pairs(whoRows) do if not present[uid] then rec.row:Destroy(); whoRows[uid]=nil end end
            local order=0
            for _,m in ipairs(members) do
                order=order+1; local rec=whoRows[m.uid]
                if not rec then rec=buildWhoRow(m); whoRows[m.uid]=rec end
                rec.row.LayoutOrder=order
                local tc=listTC(m.uname); if rec.lastTC~=tc then rec.lastTC=tc; rec.row.BackgroundColor3=tc end
                local bc=countFor(m.uname); if rec.lastCount~=bc then rec.lastCount=bc; rec.blockLbl.Text=bc>0 and tostring(bc) or"0"; rec.blockLbl.TextColor3=bc>0 and T.ok or T.sub end
                local lIco=rec.row:FindFirstChild("LdrIco"); local isL=isLdr(m.uname)
                if isL and not lIco then mk("ImageLabel",rec.row,{Name="LdrIco",Size=UDim2.new(0,16,0,16),Position=UDim2.new(0,3,0.5,-8),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) elseif not isL and lIco then lIco:Destroy() end
                local av=rec.row:FindFirstChild("Avatar"); if av then av.Position=UDim2.new(0,isL and 22 or 5,0.5,-13) end
            end
            if #members==0 then if not whoEmptyL then whoEmptyL=mk("TextLabel",whoInner,{Size=UDim2.new(1,0,0,24),LayoutOrder=1,Text="Eres el único jugador",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center}) end
            elseif whoEmptyL then whoEmptyL:Destroy(); whoEmptyL=nil end
        end
    end

    local function startSelTicker()
        if selTickToken then selTickToken=false end
        local tok={}; selTickToken=tok
        task.spawn(function()
            while selTickToken==tok and SG and SG.Parent do
                task.wait(1); if selTickToken~=tok then break end
                if not PageSave.Visible then continue end
                if whoBtn and whoBtn.Parent and not whoVis then
                    local bc=countFor(curUN); local isL=isLdr(curUN)
                    local lIco=whoBtn:FindFirstChild("LdrIco")
                    if isL and not lIco then mk("ImageLabel",whoBtn,{Name="LdrIco",Size=UDim2.new(0,14,0,14),Position=UDim2.new(0,4,0.5,-7),BackgroundTransparency=1,Image=ICON_LEADER,ZIndex=3}) elseif not isL and lIco then lIco:Destroy() end
                    local av=whoBtn:FindFirstChild("Avatar"); if av then av.Position=UDim2.new(0,isL and 20 or 4,0.5,-11) end
                    for _,ch in ipairs(whoBtn:GetChildren()) do if ch:IsA("TextLabel") and ch.TextXAlignment==Enum.TextXAlignment.Left then ch.Text=curDN.." (@"..curUN..") · "..bc; break end end
                    whoBtn.BackgroundColor3=getTeamColor(curUN)
                end
                if whoVis then refreshWho() end
            end
        end)
    end

    -- ── SECCIÓN SELECCIÓN JUGADOR ──────────────────────────────────────────
    local secSave = sec(PageSave, 3)
    mk("TextLabel",secSave,{Size=UDim2.new(1,0,0,14),Text="Seleccionar jugador",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0})
    local playerRow=mk("Frame",secSave,{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,LayoutOrder=1})
    whoBtn=mk("TextButton",playerRow,{Size=UDim2.new(1,0,0,28),Position=UDim2.new(0,0,0,0),BackgroundColor3=T.input,BorderSizePixel=0,Text="",TextXAlignment=Enum.TextXAlignment.Left}); corner(whoBtn,8); stroke(whoBtn,T.sub,1)
    setWhoBtn(LP.UserId,"Yo",LP.Name)
    whoFrame=mk("Frame",secSave,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=T.card,BorderSizePixel=0,Visible=false,LayoutOrder=3}); corner(whoFrame,8); stroke(whoFrame,T.sub,1); pad(whoFrame,4,4,4,4)
    whoInner=mk("Frame",whoFrame,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1}); mk("UIListLayout",whoInner,{Padding=UDim.new(0,3)})
    whoBtn.MouseButton1Click:Connect(function()
        whoVis=not whoVis; whoFrame.Visible=whoVis
        if whoVis then refreshWho(); task.spawn(function() while whoVis and whoFrame.Parent do task.wait(1); if not whoVis then break end; refreshWho() end end) end
        for _,ch in ipairs(whoBtn:GetChildren()) do if ch:IsA("TextLabel")and(ch.Text=="▲"or ch.Text=="▼") then ch.Text=whoVis and"▲"or"▼" end end
    end)

    local scopeRow=mk("Frame",secSave,{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,LayoutOrder=2})
    SaveUI.btnScopeMode=btn(scopeRow,"Copiar: Zona",UDim2.new(1,0,0,28),nil,T.accent)
    SaveUI.btnScopeMode.TextSize=10
    SaveUI.btnScopeMode.TextColor3=T.bg
    SaveUI.btnScopeMode.MouseButton1Click:Connect(function()
        if copyScope == "zone" then
            copyScope = "all"
            SaveUI.btnScopeMode.Text = "Copiar: Todo el Mapa"
            SaveUI.btnScopeMode.BackgroundColor3 = T.btnAlt
            SaveUI.btnScopeMode.TextColor3 = T.text
        else
            copyScope = "zone"
            SaveUI.btnScopeMode.Text = "Copiar: Zona"
            SaveUI.btnScopeMode.BackgroundColor3 = T.accent
            SaveUI.btnScopeMode.TextColor3 = T.bg
        end
    end)

    -- Auto-detección modo compartir
    local function getMyLeaderName()
        if not LP.Team then return nil end
        local leaderVal = LP.Team:FindFirstChild("TeamLeader")
        if leaderVal and leaderVal:IsA("StringValue") then
            local v = leaderVal.Value
            if v and v ~= "" then return v end
        end
        return nil
    end

    local function computeShareMode()
        if isLdr(LP.Name) then return false end
        return isSharing()
    end

    local applyAutoShare
    local function updateShareUI()
        if not SaveUI.btnShareMode then return end
        local leader = getMyLeaderName()
        local iAmLeader = isLdr(LP.Name)
        local txt
        if iAmLeader then
            txt = "Compartir: OFF · eres líder"
        elseif isShareModeOn and leader then
            txt = "Compartir: ON → @"..leader
        elseif not isSharing() then
            txt = "Compartir: OFF · ShareBlocks off"
        else
            txt = "Compartir: OFF"
        end
        SaveUI.btnShareMode.Text = txt
        SaveUI.btnShareMode.BackgroundColor3 = isShareModeOn and T.ok or T.btnAlt
        SaveUI.btnShareMode.TextColor3 = isShareModeOn and T.bg or T.text
    end

    applyAutoShare = function()
        local newMode = computeShareMode()
        if newMode ~= isShareModeOn then
            isShareModeOn = newMode
            if isShareModeOn then
                local leader = getMyLeaderName()
                if leader and leader ~= LP.Name then
                    local lp2 = Players:FindFirstChild(leader)
                    if lp2 then
                        selPlayer = lp2.Name
                        curUID = lp2.UserId
                        curDN = lp2.DisplayName or lp2.Name
                        curUN = lp2.Name
                        if whoBtn then setWhoBtn(curUID, curDN, curUN) end
                        if whoVis and refreshWho then refreshWho() end
                    end
                end
            end
        end
        updateShareUI()
    end

    local shareConn, teamLeaderConn, teamChildConn
    local function hookShareWatchers()
        if shareConn then shareConn:Disconnect(); shareConn = nil end
        if teamLeaderConn then teamLeaderConn:Disconnect(); teamLeaderConn = nil end
        if teamChildConn then teamChildConn:Disconnect(); teamChildConn = nil end
        local shareVal = LP:FindFirstChild("Settings") and LP.Settings:FindFirstChild("ShareBlocks")
        if shareVal and shareVal:IsA("BoolValue") then
            shareConn = shareVal:GetPropertyChangedSignal("Value"):Connect(function()
                task.wait(0.1); applyAutoShare()
            end)
        end
        if LP.Team then
            local leaderVal = LP.Team:FindFirstChild("TeamLeader")
            if leaderVal and leaderVal:IsA("StringValue") then
                teamLeaderConn = leaderVal:GetPropertyChangedSignal("Value"):Connect(function()
                    task.wait(0.1); applyAutoShare()
                end)
            end
            teamChildConn = LP.Team.ChildAdded:Connect(function(c)
                if c.Name == "TeamLeader" and c:IsA("StringValue") then
                    task.wait(0.1)
                    if teamLeaderConn then teamLeaderConn:Disconnect() end
                    teamLeaderConn = c:GetPropertyChangedSignal("Value"):Connect(function()
                        task.wait(0.1); applyAutoShare()
                    end)
                    applyAutoShare()
                end
            end)
        end
    end

    local saveRow=mk("Frame",secSave,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=4})
    SaveUI.nameInp=box(saveRow,UDim2.new(1,-80,0,26),UDim2.new(0,0,0,0),""); SaveUI.nameInp.PlaceholderText="Nombre del build..."
    SaveUI.btnSaveNow=btn(saveRow,"Captura",UDim2.new(0,76,0,26),UDim2.new(1,-74,0,0),T.build); SaveUI.btnSaveNow.TextSize=10

    -- Header "Mis Builds" con toggle de vista en fila
    do
        local hdr=mk("Frame",secSave,{Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,LayoutOrder=5})
        lbl(hdr,"Mis Builds",UDim2.new(1,-54,1,0),nil,T.sub)
        SaveUI.btnRowView=btn(hdr,"▤ 1×",UDim2.new(0,50,1,0),UDim2.new(1,-52,0,0),T.btnAlt)
        SaveUI.btnRowView.TextSize=9
    end

    SaveUI.listScroll=mk("ScrollingFrame",secSave,{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.purple,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),LayoutOrder=6}); pad(SaveUI.listScroll,2,2,2,2)
    SaveUI.listCont=mk("Frame",SaveUI.listScroll,{Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    -- UIGridLayout reemplaza UIListLayout para soportar 1/2/3 columnas
    SaveUI.listGrid=mk("UIGridLayout",SaveUI.listCont,{SortOrder=Enum.SortOrder.LayoutOrder,CellPadding=UDim2.new(0,3,0,3),CellSize=UDim2.new(1,-6,0,30),FillDirection=Enum.FillDirection.Horizontal})

    -- ── Rename section ──────────────────────────────────────────────────────
    mk("TextLabel",secSave,{Size=UDim2.new(1,0,0,12),Text="Renombrar guardado",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=7})
    do
        local renRow=mk("Frame",secSave,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=8})
        SaveUI.renameInp=box(renRow,UDim2.new(1,-82,0,24),UDim2.new(0,0,0,0),"")
        SaveUI.renameInp.PlaceholderText="Nuevo nombre..."
        SaveUI.btnRenameConfirm=btn(renRow,"Renombrar",UDim2.new(0,78,0,24),UDim2.new(1,-78,0,0),T.btnAlt)
        SaveUI.btnRenameConfirm.TextSize=9
    end
    SaveUI.renameStatus=mk("TextLabel",secSave,{Size=UDim2.new(1,0,0,12),BackgroundTransparency=1,Text="",TextColor3=T.ok,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=9})

    -- ── SECCIÓN VISTA PREVIA ───────────────────────────────────────────────
    local secPrev = sec(PageSave, 4)

    local rSP=mk("Frame",secPrev,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=2})
    SaveUI.BtnSavePrev=btn(rSP,"Vista previa: On",UDim2.new(1,-80,1,0),nil,T.accent); SaveUI.BtnSavePrev.TextColor3=T.bg
    local spAlphaFrame=mk("Frame",rSP,{Size=UDim2.new(0,76,1,0),Position=UDim2.new(1,-76,0,0),BackgroundColor3=T.btnAlt,BorderSizePixel=0}); corner(spAlphaFrame,6)
    local spAlphaDown=btn(spAlphaFrame,"-",UDim2.new(0,22,1,0),UDim2.new(0,0,0,0),T.btnAlt)
    local spAlphaLbl=lbl(spAlphaFrame,math.floor(savePrevAlpha*100).."%",UDim2.new(0,28,1,0),UDim2.new(0,22,0,0),T.text); spAlphaLbl.TextXAlignment=Enum.TextXAlignment.Center; spAlphaLbl.Font=Enum.Font.GothamBold; spAlphaLbl.TextSize=10
    local spAlphaUp=btn(spAlphaFrame,"+",UDim2.new(0,22,1,0),UDim2.new(1,-22,0,0),T.btnAlt)
    local function setSPAlpha(v)
        savePrevAlpha=math.clamp(v,0,0.95)
        spAlphaLbl.Text=math.floor(savePrevAlpha*100).."%"
        renderSavePrev()
    end
    spAlphaDown.MouseButton1Click:Connect(function() setSPAlpha(savePrevAlpha-0.10) end)
    spAlphaUp.MouseButton1Click:Connect(function()   setSPAlpha(savePrevAlpha+0.10) end)

    local sTRow=mk("Frame",secPrev,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=4})
    SaveUI.BtnSaveMove=btn(sTRow,"",UDim2.new(0,38,0,24),UDim2.new(0,0,0,0),T.btn); mk("ImageLabel",SaveUI.BtnSaveMove,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_MOVE})
    SaveUI.saveMoveStep=box(sTRow,UDim2.new(0,44,0,24),UDim2.new(0,42,0,0),"1"); SaveUI.saveMoveStep.TextXAlignment=Enum.TextXAlignment.Center
    SaveUI.BtnSaveRot=btn(sTRow,"",UDim2.new(0,38,0,24),UDim2.new(0,92,0,0),T.btnAlt); mk("ImageLabel",SaveUI.BtnSaveRot,{Size=UDim2.new(0,18,0,18),Position=UDim2.new(0.5,-9,0.5,-9),BackgroundTransparency=1,Image=ICON_ROT})
    SaveUI.saveRotStep=box(sTRow,UDim2.new(0,44,0,24),UDim2.new(0,134,0,0),"15"); SaveUI.saveRotStep.TextXAlignment=Enum.TextXAlignment.Center
    SaveUI.btnScaleDown=btn(sTRow,"-",UDim2.new(0,22,0,24),UDim2.new(1,-72,0,0),T.btnAlt)
    SaveUI.scaleLbl=lbl(sTRow,"1.0x",UDim2.new(0,26,0,24),UDim2.new(1,-48,0,0),T.text); SaveUI.scaleLbl.TextXAlignment=Enum.TextXAlignment.Center
    SaveUI.btnScaleUp=btn(sTRow,"+",UDim2.new(0,22,0,24),UDim2.new(1,-22,0,0),T.btnAlt)

    local pPRow=mk("Frame",secPrev,{Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=5})
    SaveUI.BtnPlaceZone=btn(pPRow,"Centro zona",UDim2.new(0.5,-3,1,0),UDim2.new(0,0,0,0),T.accent)
    SaveUI.BtnSaveSel=btn(pPRow,"Sel. Posicion",UDim2.new(0.5,-3,1,0),UDim2.new(0.5,3,0,0),T.btnAlt)
    SaveUI.btnBuildSaved=btn(secPrev,"CONSTRUIR GUARDADO",UDim2.new(1,0,0,32),nil,T.purple); SaveUI.btnBuildSaved.LayoutOrder=6
    SaveUI.prevStatus=mk("TextLabel",SaveUI.btnBuildSaved,{Size=UDim2.new(0,100,0,12),Position=UDim2.new(1,-104,1,-16),Text="",TextColor3=T.text,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Right})
    -- Thumbnail button
    SaveUI.btnThumb=btn(secPrev,"📷  Thumbnail Build",UDim2.new(1,0,0,24),nil,T.btnAlt); SaveUI.btnThumb.TextSize=10; SaveUI.btnThumb.LayoutOrder=7

    local selBox=mk("SelectionBox",SG,{Color3=T.accent,LineThickness=0.04})

    local function refPlaceBtns()
        SaveUI.BtnPlaceZone.BackgroundColor3=useCZ and T.accent or T.btnAlt; SaveUI.BtnPlaceZone.TextColor3=useCZ and T.bg or T.text
        SaveUI.BtnSaveSel.BackgroundColor3=(not useCZ)and T.accent or T.btnAlt; SaveUI.BtnSaveSel.TextColor3=(not useCZ)and T.bg or T.text
    end
    refPlaceBtns()

    local function setSavePrev(on)
        if saveBuildState.running then on = false end
        savePrevOn = on
        if SaveUI.BtnSavePrev and SaveUI.BtnSavePrev.Parent then
            SaveUI.BtnSavePrev.Text = on and "Vista previa: On" or "Vista previa: Off"
            SaveUI.BtnSavePrev.BackgroundColor3 = on and T.accent or T.btnAlt
            SaveUI.BtnSavePrev.TextColor3 = on and T.bg or T.text
        end
        renderSavePrev()
    end
    SaveUI.BtnSavePrev.MouseButton1Click:Connect(function()
        setSavePrev(not savePrevOn)
    end)

    local function refSaveTool()
        SaveUI.BtnSaveMove.BackgroundColor3=(saveToolMode=="move")   and T.btn or T.btnAlt
        SaveUI.BtnSaveRot.BackgroundColor3=(saveToolMode=="rotate") and T.btn or T.btnAlt
        updSaveHandles()
    end
    SaveUI.BtnSaveMove.MouseButton1Click:Connect(function() saveToolMode="move";   refSaveTool() end)
    SaveUI.BtnSaveRot.MouseButton1Click:Connect(function()  saveToolMode="rotate"; refSaveTool() end)

    SaveUI.btnScaleDown.MouseButton1Click:Connect(function() placeScale=math.max(0.1,placeScale-0.1); SaveUI.scaleLbl.Text=string.format("%.1fx",placeScale); renderSavePrev() end)
    SaveUI.btnScaleUp.MouseButton1Click:Connect(function()   placeScale=math.min(10,placeScale+0.1);  SaveUI.scaleLbl.Text=string.format("%.1fx",placeScale); renderSavePrev() end)

    SaveUI.BtnPlaceZone.MouseButton1Click:Connect(function()
        useCZ=true; refPlaceBtns()
        local sv=selSaveIdx and Saves[selSaveIdx]; placePosV=defaultCenter(sv)
        placeRot=CFrame.identity; renderSavePrev()
    end)

    local saveSel2=false
    SaveUI.BtnSaveSel.MouseButton1Click:Connect(function()
        if saveSel2 then return end; saveSel2=true
        SaveUI.BtnSaveSel.Text="Haz clic en una parte..."
        local rc,cc
        rc=RunService.RenderStepped:Connect(function() selBox.Adornee=Mouse.Target end)
        cc=Mouse.Button1Down:Connect(function()
            local t=Mouse.Target; if t and t:IsA("BasePart") and not t:IsDescendantOf(SG) then
                useCZ=false; refPlaceBtns(); placePosV=t.Position; placeRot=CFrame.identity
                rc:Disconnect(); cc:Disconnect(); selBox.Adornee=nil; saveSel2=false
                SaveUI.BtnSaveSel.Text="Sel. Posicion"; renderSavePrev()
            end
        end)
    end)

    LP:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.5)
        _myZoneCache = nil
        if not PageSave.Visible then return end
        local z=myZone()
        if z then
            local sv=selSaveIdx and Saves[selSaveIdx]
            if sv then placePosV=defaultCenter(sv) end
            useCZ=true; refPlaceBtns(); renderSavePrev()
        end
    end)

    -- ── renderSaveList ─────────────────────────────────────────────────────
    local renderToken = 0
    local rowPool = {}
    local renderSaveList
    renderSaveList = function(isAsync, onComplete)
        renderToken = renderToken + 1
        local myToken = renderToken

        -- Orden de display: favoritos primero
        local function getDispPos()
            local fi, ni = {}, {}
            for i=1,#Saves do
                if extState.favs[Saves[i].name] then fi[#fi+1]=i else ni[#ni+1]=i end
            end
            local pos={}
            for d,s in ipairs(fi) do pos[s]=d end
            for d,s in ipairs(ni) do pos[s]=#fi+d end
            return pos
        end
        local dispPos = getDispPos()

        local function updateRow(i)
            if myToken ~= renderToken then return false end
            local sv = Saves[i]
            local row = rowPool[i]
            if not row then
                row = mk("Frame",SaveUI.listCont,{BackgroundColor3=T.input,LayoutOrder=dispPos[i] or i,BorderSizePixel=0}); corner(row,6)
                row:SetAttribute("SaveIdx", i)
                local bar=mk("Frame",row,{Name="Bar",Size=UDim2.new(0,4,1,-10),Position=UDim2.new(0,3,0,5),BackgroundColor3=T.accent,BorderSizePixel=0,Visible=false}); corner(bar,2)
                local nL=lbl(row,"",UDim2.new(1,-96,1,0),UDim2.new(0,24,0,0),T.text); nL.Name="NameLbl"
                local useB=mk("TextButton",row,{Name="UseBtn",Size=UDim2.new(0,48,0,22),Position=UDim2.new(1,-92,0.5,-11),Text="Usar",TextColor3=T.text,BackgroundColor3=T.purple,Font=Enum.Font.GothamBold,TextSize=9}); corner(useB,4)
                local delB=mk("TextButton",row,{Name="DelBtn",Size=UDim2.new(0,40,0,22),Position=UDim2.new(1,-42,0.5,-11),Text="X",TextColor3=T.text,BackgroundColor3=T.danger,Font=Enum.Font.GothamBold,TextSize=11}); corner(delB,4)
                -- ★ Favorito
                local favB=mk("TextButton",row,{Name="FavBtn",Size=UDim2.new(0,20,0,20),Position=UDim2.new(0,2,0.5,-10),Text="☆",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=14,ZIndex=2})
                -- Punto de color (clic izq cicla, clic der limpia)
                local colDot=mk("Frame",row,{Name="ColDot",Size=UDim2.new(0,9,0,9),Position=UDim2.new(0,24,0,3),BackgroundColor3=T.sub,BorderSizePixel=0,ZIndex=2}); corner(colDot,5)
                local colBtn=mk("TextButton",colDot,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text=""})

                useB.MouseButton1Click:Connect(function()
                    local idx=row:GetAttribute("SaveIdx")
                    useB.Text="✓"; useB.BackgroundColor3=T.ok; useB.TextColor3=T.bg
                    task.delay(0.6,function() if useB.Parent then useB.Text="Usar"; useB.BackgroundColor3=T.purple; useB.TextColor3=T.text end end)
                    selSaveIdx=idx; placeScale=1; placeRot=CFrame.identity; SaveUI.scaleLbl.Text="1.0x"
                    placePosV=defaultCenter(Saves[idx])
                    renderSaveList(); setSavePrev(true)
                end)
                delB.MouseButton1Click:Connect(function()
                    local idx=row:GetAttribute("SaveIdx")
                    local sv2=Saves[idx]
                    if sv2 then
                        local fp=sv2._path or(FS2.."/"..sv2.name..".json"); FSys.del(fp); delSaveOrd(sv2.name)
                        extState.favs[sv2.name]=nil; extState.colors[sv2.name]=nil
                    end
                    table.remove(Saves,idx)
                    if selSaveIdx==idx then selSaveIdx=nil elseif selSaveIdx and selSaveIdx>idx then selSaveIdx=selSaveIdx-1 end
                    _G[GKEY]=Saves; renderSaveList(); renderSavePrev(); cCache={}
                end)
                favB.MouseButton1Click:Connect(function()
                    local idx=row:GetAttribute("SaveIdx"); local sv2=Saves[idx]; if not sv2 then return end
                    extState.favs[sv2.name]=not extState.favs[sv2.name] or nil
                    renderSaveList()
                end)
                colBtn.MouseButton1Click:Connect(function()
                    local idx=row:GetAttribute("SaveIdx"); local sv2=Saves[idx]; if not sv2 then return end
                    extState.colors[sv2.name]=(extState.colors[sv2.name] or 0)%5+1
                    renderSaveList()
                end)
                colBtn.MouseButton2Click:Connect(function()
                    local idx=row:GetAttribute("SaveIdx"); local sv2=Saves[idx]; if not sv2 then return end
                    extState.colors[sv2.name]=nil; renderSaveList()
                end)
                -- Clic en la fila (modo multi-col): seleccionar
                mk("TextButton",row,{Name="RowSel",Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=1}).MouseButton1Click:Connect(function()
                    local idx=row:GetAttribute("SaveIdx"); if not Saves[idx] then return end
                    if extState.rowView>1 then
                        selSaveIdx=idx; placeScale=1; placeRot=CFrame.identity; SaveUI.scaleLbl.Text="1.0x"
                        placePosV=defaultCenter(Saves[idx]); renderSaveList(); setSavePrev(true)
                    end
                end)
                rowPool[i] = row
            else
                row.Parent = SaveUI.listCont
                row.LayoutOrder = dispPos[i] or i
                row:SetAttribute("SaveIdx", i)
            end

            if sv then
                row.Visible = true
                local isSel=(selSaveIdx==i)
                local isMulti=extState.rowView>1
                -- Color de fondo (pastel del save o input por defecto)
                row.BackgroundColor3=extState.colors[sv.name] and PASTEL_COLS[extState.colors[sv.name]] or T.input
                local bar=row:FindFirstChild("Bar"); if bar then bar.Visible=isSel and not isMulti end
                local nblk=sv.data and sv.data.Block and #sv.data.Block or 0
                local nL=row:FindFirstChild("NameLbl")
                if nL then
                    nL.Text=isMulti and sv.name or sv.name.." ("..nblk..")"
                    nL.Position=UDim2.new(0,isSel and(isMulti and 24 or 30)or 24,0,0)
                    nL.TextColor3=isSel and Color3.new(1,1,1) or T.text
                    nL.Font=isSel and Enum.Font.GothamBold or Enum.Font.GothamSemibold
                    nL.Size=isMulti and UDim2.new(1,-24,1,0) or UDim2.new(1,-96,1,0)
                    nL.TextSize=isMulti and 9 or 11
                end
                local favB=row:FindFirstChild("FavBtn")
                if favB then
                    favB.Text=extState.favs[sv.name] and "★" or "☆"
                    favB.TextColor3=extState.favs[sv.name] and Color3.new(1,0.7,0) or T.sub
                    favB.TextSize=isMulti and 11 or 14
                end
                local colDot=row:FindFirstChild("ColDot")
                if colDot then colDot.BackgroundColor3=extState.colors[sv.name] and PASTEL_COLS[extState.colors[sv.name]] or T.sub end
                local useB=row:FindFirstChild("UseBtn"); if useB then useB.Visible=not isMulti end
                local delB=row:FindFirstChild("DelBtn"); if delB then delB.Visible=not isMulti end
                -- Ajuste de posición del ColDot en multi-col
                if colDot then colDot.Position=isMulti and UDim2.new(1,-12,0,3) or UDim2.new(0,24,0,3) end
                -- Stroke de selección en multi-col
                local st=row:FindFirstChildOfClass("UIStroke")
                if isSel and isMulti then
                    if not st then stroke(row,T.accent,2) end
                elseif st then
                    st:Destroy()
                end
                -- Bloque count label en multi-col
                local cntL=row:FindFirstChild("CntLbl")
                if isMulti then
                    if not cntL then
                        cntL=mk("TextLabel",row,{Name="CntLbl",Size=UDim2.new(1,0,0,12),Position=UDim2.new(0,0,1,-14),BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=8,TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=2})
                    end
                    cntL.Text=nblk.." blk"
                elseif cntL then
                    cntL:Destroy()
                end
            else
                row.Visible = false
            end
            return true
        end

        if #Saves==0 then
            for _, row in ipairs(rowPool) do row.Visible = false end
            SaveUI.listScroll.Size=UDim2.new(1,0,0,22)
            local emptyLbl = SaveUI.listCont:FindFirstChild("EmptyLbl")
            if not emptyLbl then
                emptyLbl = mk("TextLabel",SaveUI.listCont,{Name="EmptyLbl",Size=UDim2.new(1,0,0,18),LayoutOrder=1,Text="(sin guardados)",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Top})
            else
                emptyLbl.Text = "(sin guardados)"
            end
            emptyLbl.Visible = true
            if onComplete then onComplete() end
            return
        else
            local emptyLbl = SaveUI.listCont:FindFirstChild("EmptyLbl")
            if emptyLbl then emptyLbl.Visible = false end
        end

        -- Ajustar altura del scroll según vista
        local rv=extState.rowView; local cols=rv; local rH=rv==1 and 34 or 62
        local newH=math.clamp(math.ceil(#Saves/cols)*rH,rH,rv==1 and 102 or 190)
        SaveUI.listScroll.Size=UDim2.new(1,0,0,newH)

        if isAsync then
            task.spawn(function()
                local i = 1
                while i <= #Saves do
                    if myToken ~= renderToken then break end
                    local batchEnd = math.min(i + 9, #Saves)
                    for j = i, batchEnd do
                        if myToken ~= renderToken then break end
                        updateRow(j)
                    end
                    i = batchEnd + 1
                    task.wait()
                end
                if myToken == renderToken then
                    for j = #Saves + 1, #rowPool do
                        if rowPool[j] then rowPool[j].Visible = false end
                    end
                    if onComplete then onComplete() end
                end
            end)
        else
            for i=1,#Saves do
                if myToken ~= renderToken then break end
                updateRow(i)
            end
            if myToken == renderToken then
                for j = #Saves + 1, #rowPool do
                    if rowPool[j] then rowPool[j].Visible = false end
                end
                if onComplete then onComplete() end
            end
        end
    end

    -- ── findPlayerZone ──────────────────────────────────────────────────────
    findPlayerZone = function(pos)
        local z = closestZone(pos)
        if z and z:IsA("BasePart") and zoneContainsXZ(z, pos) then return z end
        for _, name in ipairs(ZONE_NAMES) do
            local zone = findZoneByName(name)
            if zone and zoneContainsXZ(zone, pos) then return zone end
        end
        return nil
    end

    -- ── btnSaveNow ─────────────────────────────────────────────────────────
    SaveUI.btnSaveNow.MouseButton1Click:Connect(function()
        local syncP = selPlayer or LP.Name
        local uf = userFolder(syncP)
        if uf then
            SaveUI.btnSaveNow.Text="Sincronizando..."; SaveUI.btnSaveNow.BackgroundColor3=T.btnAlt
            local last = -1; local stableAt = nil; local t0 = tick()
            while tick()-t0 < 1.0 do
                local cur = 0
                for _,d in ipairs(uf:GetDescendants()) do if d:IsA("BasePart") then cur = cur + 1 end end
                if cur == last then
                    if not stableAt then stableAt = tick() end
                    if tick()-stableAt >= 0.25 then break end
                else
                    last = cur; stableAt = nil
                end
                task.wait(0.1)
            end
        end
        local base=myBaseCF or CFrame.new(myRefPos())
        local data,cnt=captureBuild(selPlayer or LP.Name, base)
        if not data then
            SaveUI.btnSaveNow.Text="Error"; SaveUI.btnSaveNow.BackgroundColor3=T.danger
            task.delay(1.5,function() if SaveUI.btnSaveNow and SaveUI.btnSaveNow.Parent then SaveUI.btnSaveNow.Text="Captura"; SaveUI.btnSaveNow.BackgroundColor3=T.build end end)
            return
        end

        do
            local p = Players:FindFirstChild(selPlayer)
            if not p and selPlayer == LP.Name then p = LP end
            local pZone = p and teamZone(p) or nil
            if not pZone then
                local refPos = nil
                if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    refPos = p.Character.HumanoidRootPart.Position
                elseif selPlayer == LP.Name and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                    refPos = LP.Character.HumanoidRootPart.Position
                end
                if refPos then pZone = findPlayerZone(refPos) end
            end
            local srcZone = data and data.SrcZoneName and findZoneByName(data.SrcZoneName)
            local srcCF = srcZone and srcZone.CFrame or base

            if pZone and data then
                if copyScope == "zone" and data.Block then
                    local newBlocks = {}
                    local tPos = pZone.Position; local tCF = pZone.CFrame; local tHalf = pZone.Size/2
                    for _, pd in ipairs(data.Block) do
                        local worldPos = (srcCF * CFrame.new(pd.RelX or 0, pd.RelY or 0, pd.RelZ or 0)).Position
                        local off = worldPos - tPos
                        if math.abs(off:Dot(tCF.XVector)) <= tHalf.X and math.abs(off:Dot(tCF.ZVector)) <= tHalf.Z then
                            table.insert(newBlocks, pd)
                        end
                    end
                    if #newBlocks > 0 or #data.Block == 0 then
                        data.Block = newBlocks
                        cnt = #newBlocks
                    end
                end
                data.SrcZoneName = pZone.Name
            end
        end

        local nm=SaveUI.nameInp.Text; nm=nm:gsub("%s+","_"); nm=nm:gsub("[^%w_%-]","")
        if nm=="" or nm=="_" then nm=autoName() end
        local used={}; for _,s in ipairs(Saves) do used[s.name]=true end
        if used[nm] then nm=nm.."_"..autoName() end
        local bd={name=nm,data=data}; local path=writeBF(nm,bd)
        if path then table.insert(Saves,1,{name=nm,data=data,_path=path}); addSaveOrd(nm)
        else table.insert(Saves,1,{name=nm,data=data,_path=FS2.."/"..nm..".json"}); addSaveOrd(nm) end
        renderSaveList(); SaveUI.nameInp.Text=""
        SaveUI.btnSaveNow.Text="✓"; SaveUI.btnSaveNow.BackgroundColor3=T.ok
        task.delay(1.2,function() if SaveUI.btnSaveNow and SaveUI.btnSaveNow.Parent then SaveUI.btnSaveNow.Text="Captura"; SaveUI.btnSaveNow.BackgroundColor3=T.build end end)
    end)

    -- ── Build saved ────────────────────────────────────────────────────────
    local blockQueue2={}; local blockConn2=nil
    local function hookFolder2(folder) if blockConn2 then blockConn2:Disconnect(); blockConn2=nil end; blockQueue2={}; if folder then blockConn2=folder.ChildAdded:Connect(function(c) blockQueue2[#blockQueue2+1]=c end) end end
    local function popBlock2(timeout) local t0=tick(); while #blockQueue2==0 do if saveBuildState.cancel then return nil end; if tick()-t0>timeout then return nil end; task.wait() end; return table.remove(blockQueue2,1) end

    SaveUI.btnBuildSaved.MouseButton1Click:Connect(function()
        if saveBuildState.running then saveBuildState.cancel=true; SaveUI.prevStatus.Text="cancelando..."; SaveUI.prevStatus.TextColor3=T.danger; SaveUI.btnBuildSaved.Text="CANCELAR..."; return end
        if gbRunningRef.value then SaveUI.prevStatus.Text="ya hay una construcción en curso"; SaveUI.prevStatus.TextColor3=T.danger; return end
        local sv=selSaveIdx and Saves[selSaveIdx]; if not sv then SaveUI.prevStatus.Text="Selecciona un guardado"; SaveUI.prevStatus.TextColor3=T.danger; return end
        local bTool2=getTool("BuildingTool"); if not bTool2 then SaveUI.prevStatus.Text="Falta BuildingTool"; SaveUI.prevStatus.TextColor3=T.danger; return end
        local sTool2=getTool("ScalingTool"); local pTool2=getTool("PaintingTool")
        task.spawn(function()
            saveBuildState.running=true; saveBuildState.cancel=false; gbRunningRef.value=true
            setSavePrev(false)
            SaveUI.btnBuildSaved.Text="CANCELAR"; SaveUI.btnBuildSaved.BackgroundColor3=T.danger; SaveUI.btnBuildSaved.Active=true
            local ok2,err=pcall(function()
                equipTool(bTool2); equipTool(sTool2); equipTool(pTool2)
                local bRF2=bTool2:FindFirstChild("RF"); local sRF2=sTool2 and sTool2:FindFirstChild("RF"); local pRF2=pTool2 and pTool2:FindFirstChild("RF")
                if not bRF2 then error("BuildingTool sin RF") end
                local pos=curPlacePos(); local center=buildCenter(sv); local mz=myZone(); local destRot=mz and (mz.CFrame-mz.CFrame.Position) or CFrame.identity

                local targetName = isShareModeOn and selPlayer or LP.Name
                local folder2 = userFolder(targetName)
                if not folder2 or folder2.Parent == nil then folder2 = userFolder(LP.Name) end
                hookFolder2(folder2)

                local blocks=sv.data.Block; local total=#blocks; local placed=0;
                local WORKERS2 = 15
                if not isShareModeOn then
                    WORKERS2 = isSharing() and 15 or 50
                end
                local nextIdx2=1; local active2=WORKERS2; local ppairs={}
                local function pOB(pd)
                    local nm=pd.BlockName
                    local inv = dataFolder and dataFolder:FindFirstChild(nm)
                    local invVal = (inv and inv.Value) or 1

                    if not isShareModeOn and (not inv or invVal <= 0) then return end

                    local world=blockWorldCF(pd, center, pos, destRot)

                    if not folder2 or folder2.Parent==nil then
                        folder2 = userFolder(targetName)
                        if not folder2 or folder2.Parent == nil then folder2 = userFolder(LP.Name) end
                        hookFolder2(folder2)
                    end

                    local ret=bRF2:InvokeServer(nm,invVal,nil,world,true,world,false); local blk
                    if typeof(ret)=="Instance" and ret:IsA("BasePart") then blk=ret else blk=popBlock2(2) end

                    if blk then
                        placed=placed+1
                        local sz=Vector3.new(pd.SizeX or 2,pd.SizeY or 2,pd.SizeZ or 2)*placeScale
                        if sRF2 then pcall(function() sRF2:InvokeServer(blk,sz,world) end) end
                        if pd.ColorR then ppairs[#ppairs+1]={blk,Color3.new(pd.ColorR,pd.ColorG,pd.ColorB)} end
                    end
                end
                local function worker2() while true do if saveBuildState.cancel then break end; local i=nextIdx2; nextIdx2=nextIdx2+1; if i>total then break end; pOB(blocks[i]) end; active2=active2-1 end
                for _=1,WORKERS2 do task.spawn(worker2) end
                while active2>0 do SaveUI.prevStatus.Text=string.format("Construyendo %d/%d",placed,total); SaveUI.prevStatus.TextColor3=T.warn; task.wait(0.03) end
                if blockConn2 then blockConn2:Disconnect(); blockConn2=nil end
                if pRF2 and #ppairs>0 and not saveBuildState.cancel then SaveUI.prevStatus.Text=string.format("Pintando %d bloques...",#ppairs); SaveUI.prevStatus.TextColor3=T.warn; paintBatch(pRF2,ppairs) end
                if saveBuildState.cancel then SaveUI.prevStatus.Text="Cancelado ("..placed.." colocados)"; SaveUI.prevStatus.TextColor3=T.danger
                else SaveUI.prevStatus.Text="listo! "..placed.."/"..total.." colocados"; SaveUI.prevStatus.TextColor3=T.ok end
            end)
            if blockConn2 then blockConn2:Disconnect(); blockConn2=nil end
            if not ok2 then SaveUI.prevStatus.Text="error: "..tostring(err); SaveUI.prevStatus.TextColor3=T.danger end
            local hum2=LP.Character and LP.Character:FindFirstChild("Humanoid"); if hum2 then pcall(function() hum2:UnequipTools() end) end
            saveBuildState.running=false; saveBuildState.cancel=false; gbRunningRef.value=false
            setSavePrev(true)
            SaveUI.btnBuildSaved.Text="CONSTRUIR GUARDADO"; SaveUI.btnBuildSaved.BackgroundColor3=T.purple; SaveUI.btnBuildSaved.Active=true
        end)
    end)

    local function updSelTC() if whoBtn and whoBtn.Parent then whoBtn.BackgroundColor3=getTeamColor(curUN) end end
    local function watchPTeam(p) p:GetPropertyChangedSignal("Team"):Connect(function() if p.Name==curUN then updSelTC() end; if whoVis then refreshWho() end end) end
    for _,p in ipairs(Players:GetPlayers()) do watchPTeam(p) end
    Players.PlayerAdded:Connect(function(p) watchPTeam(p); if whoVis then refreshWho() end end)
    Players.PlayerRemoving:Connect(function() task.defer(function() if whoVis then refreshWho() end end) end)

    -- ════════════════════════════════════════════════════════════════════════
    -- INSPECTOR DE BLOQUES Y COLORES
    -- ════════════════════════════════════════════════════════════════════════
    local Win = ENV.Win

    -- ── Overlay reutilizable para picker de bloques ────────────────────────
    local pickerOverlay = mk("Frame", Win, {
        Size = UDim2.new(1,0,1,0),
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 60,
    })
    mk("TextButton", pickerOverlay, {
        Size = UDim2.new(1,0,1,0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 60,
        AutoButtonColor = false,
    }).MouseButton1Click:Connect(function() pickerOverlay.Visible = false end)

    local pickerBox = mk("Frame", pickerOverlay, {
        Size = UDim2.new(1,-20,0.82,0),
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new(0.5,0,0.5,0),
        BackgroundColor3 = T.panel,
        BorderSizePixel = 0,
        ZIndex = 61,
    })
    corner(pickerBox, 10)

    local pickerTitle = mk("TextLabel", pickerBox, {
        Size = UDim2.new(1,0,0,30),
        BackgroundTransparency = 1,
        Text = "ELEGIR BLOQUE",
        TextColor3 = T.text,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 62,
    })

    local pickerScroll = mk("ScrollingFrame", pickerBox, {
        Size = UDim2.new(1,-8,1,-38),
        Position = UDim2.new(0,4,0,32),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = T.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0,0,0,0),
        ZIndex = 62,
    })
    mk("UIListLayout", pickerScroll, {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})
    pad(pickerScroll, 4,4,4,4)

    local pickerCallback = nil

    local function openBlockPicker(titleText, onChosen)
        pickerCallback = onChosen
        pickerTitle.Text = titleText or "ELEGIR BLOQUE"
        for _, c in ipairs(pickerScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
        end
        local blocks = getPlayerBlocks()
        if #blocks == 0 then
            mk("TextLabel", pickerScroll, {
                Size=UDim2.new(1,0,0,30), BackgroundTransparency=1,
                Text="No tienes bloques en tu inventario",
                TextColor3=T.sub, Font=Enum.Font.Gotham, TextSize=11,
                TextXAlignment=Enum.TextXAlignment.Center, ZIndex=63,
            })
        else
            for i, item in ipairs(blocks) do
                local row = mk("TextButton", pickerScroll, {
                    Size=UDim2.new(1,0,0,38),
                    BackgroundColor3=T.card, BorderSizePixel=0,
                    Text="", LayoutOrder=i, ZIndex=63,
                })
                corner(row, 6)
                mk("ImageLabel", row, {
                    Size=UDim2.new(0,28,0,28),
                    Position=UDim2.new(0,5,0.5,-14),
                    BackgroundTransparency=1, ZIndex=64,
                    Image = item.image~="" and item.image or DEF_IMG,
                })
                mk("TextLabel", row, {
                    Size=UDim2.new(1,-90,1,0),
                    Position=UDim2.new(0,38,0,0),
                    BackgroundTransparency=1,
                    Font=Enum.Font.GothamSemibold, TextSize=11,
                    TextColor3=T.text, TextXAlignment=Enum.TextXAlignment.Left,
                    Text=item.name, ZIndex=64,
                })
                mk("TextLabel", row, {
                    Size=UDim2.new(0,76,1,0),
                    Position=UDim2.new(1,-80,0,0),
                    BackgroundTransparency=1,
                    Font=Enum.Font.GothamBold, TextSize=11,
                    TextColor3=T.sub, TextXAlignment=Enum.TextXAlignment.Right,
                    Text="x"..item.qty, ZIndex=64,
                })
                row.MouseButton1Click:Connect(function()
                    pickerOverlay.Visible = false
                    if pickerCallback then pickerCallback(item.name) end
                end)
            end
        end
        pickerOverlay.Visible = true
    end

    -- ── Stats overlay ──────────────────────────────────────────────────────
    SaveUI.statsOverlay=mk("Frame",Win,{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.35,BorderSizePixel=0,Visible=false,ZIndex=65})
    mk("TextButton",SaveUI.statsOverlay,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=65,AutoButtonColor=false}).MouseButton1Click:Connect(function() SaveUI.statsOverlay.Visible=false end)
    do
        local sBox=mk("Frame",SaveUI.statsOverlay,{Size=UDim2.new(1,-20,0.86,0),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=T.panel,BorderSizePixel=0,ZIndex=66}); corner(sBox,10)
        mk("TextLabel",sBox,{Size=UDim2.new(1,0,0,30),BackgroundTransparency=1,Text="📊  INVENTARIO REQUERIDO",TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=67})
        mk("TextButton",sBox,{Size=UDim2.new(0,26,0,22),Position=UDim2.new(1,-30,0,4),BackgroundColor3=T.danger,BorderSizePixel=0,Text="✕",TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=12,ZIndex=68}).MouseButton1Click:Connect(function() SaveUI.statsOverlay.Visible=false end)
        SaveUI.statsScroll=mk("ScrollingFrame",sBox,{Size=UDim2.new(1,-8,1,-38),Position=UDim2.new(0,4,0,32),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.accent,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),ZIndex=67})
        mk("UIListLayout",SaveUI.statsScroll,{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder}); pad(SaveUI.statsScroll,4,4,4,4)
    end

    -- ── Thumbnail overlay ──────────────────────────────────────────────────
    SaveUI.thumbOverlay=mk("Frame",Win,{Size=UDim2.new(1,0,1,0),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.4,BorderSizePixel=0,Visible=false,ZIndex=70})
    mk("TextButton",SaveUI.thumbOverlay,{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Text="",ZIndex=70,AutoButtonColor=false}).MouseButton1Click:Connect(function() SaveUI.thumbOverlay.Visible=false end)
    do
        SaveUI.thumbVF=mk("ViewportFrame",SaveUI.thumbOverlay,{Size=UDim2.new(1,-30,0.84,0),AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=Color3.fromRGB(22,22,32),BorderSizePixel=0,ZIndex=71}); corner(SaveUI.thumbVF,10)
        SaveUI.thumbWM=mk("WorldModel",SaveUI.thumbVF,{})
        SaveUI.thumbCam=mk("Camera",SaveUI.thumbVF,{CameraType=Enum.CameraType.Scriptable}); SaveUI.thumbVF.CurrentCamera=SaveUI.thumbCam
        mk("TextLabel",SaveUI.thumbVF,{Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,1,-22),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.5,Text="Clic fuera para cerrar",TextColor3=Color3.new(1,1,1),Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=72})
        mk("TextButton",SaveUI.thumbVF,{Size=UDim2.new(0,30,0,24),Position=UDim2.new(1,-34,0,4),BackgroundColor3=T.danger,BorderSizePixel=0,Text="✕",TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=12,ZIndex=72}).MouseButton1Click:Connect(function() SaveUI.thumbOverlay.Visible=false end)
    end

    -- ── Inspector helpers ─────────────────────────────────────────────────
    local function getUniqueBuildBlocks(sv)
        if not sv or not sv.data or not sv.data.Block then return {} end
        local seen = {}
        local result = {}
        for _, pd in ipairs(sv.data.Block) do
            local nm = pd.BlockName or "?"
            if not seen[nm] then
                seen[nm] = {count=0, image=getBlockImage(nm)}
            end
            seen[nm].count = seen[nm].count + 1
        end
        for nm, info in pairs(seen) do
            result[#result+1] = {name=nm, count=info.count, image=info.image}
        end
        table.sort(result, function(a,b) return a.count > b.count end)
        return result
    end

    local function getUniqueBuildColors(sv)
        if not sv or not sv.data or not sv.data.Block then return {} end
        local seen = {}
        local result = {}
        for _, pd in ipairs(sv.data.Block) do
            if pd.ColorR then
                local r = math.floor((pd.ColorR or 0)*255+0.5)
                local g = math.floor((pd.ColorG or 0)*255+0.5)
                local b = math.floor((pd.ColorB or 0)*255+0.5)
                local key = r..","..g..","..b
                if not seen[key] then
                    seen[key] = {color = Color3.fromRGB(r,g,b), r = pd.ColorR, g = pd.ColorG, b = pd.ColorB, count = 0}
                end
                seen[key].count = seen[key].count + 1
            end
        end
        for _, info in pairs(seen) do result[#result+1] = info end
        table.sort(result, function(a,b) return a.count > b.count end)
        return result
    end

    -- ── SECCIÓN INSPECTOR ──────────────────────────────────────────────────
    local secInspector = sec(PageSave, 5)

    local inspHeaderRow = mk("Frame", secInspector, {Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,LayoutOrder=0})
    local inspCollapsed = true
    local inspToggleBtn = btn(inspHeaderRow, "▲  Bloques y Colores del Build", UDim2.new(1,0,1,0), nil, T.btnAlt)
    inspToggleBtn.TextSize = 11
    inspToggleBtn.Font = Enum.Font.GothamBold
    inspToggleBtn.TextXAlignment = Enum.TextXAlignment.Left

    local inspContent = mk("Frame", secInspector, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Visible=false,LayoutOrder=1})
    mk("UIListLayout", inspContent, {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})

    inspToggleBtn.MouseButton1Click:Connect(function()
        inspCollapsed = not inspCollapsed
        inspContent.Visible = not inspCollapsed
        inspToggleBtn.Text = inspCollapsed and "▲  Bloques y Colores del Build" or "▼  Bloques y Colores del Build"
    end)

    local inspNoSelLbl = mk("TextLabel", inspContent, {Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Text="⚠ Selecciona un build primero",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=0,Visible=true})

    local inspBlockSection = mk("Frame", inspContent, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1,Visible=false})
    mk("UIListLayout", inspBlockSection, {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})
    mk("TextLabel", inspBlockSection, {Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="TIPOS DE BLOQUES",TextColor3=T.sub,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0})

    local inspBlockScroll = mk("ScrollingFrame", inspBlockSection, {Size=UDim2.new(1,0,0,120),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.purple,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),LayoutOrder=1})
    pad(inspBlockScroll, 2,2,2,2)
    local inspBlockCont = mk("Frame", inspBlockScroll, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    mk("UIListLayout", inspBlockCont, {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder})

    local inspBlockStatusLbl = mk("TextLabel", inspBlockSection, {Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="",TextColor3=T.ok,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=2})
    -- Botón stats inventario
    SaveUI.btnStats=btn(inspBlockSection,"📊  Stats inventario",UDim2.new(1,0,0,22),nil,T.btnAlt); SaveUI.btnStats.TextSize=9; SaveUI.btnStats.LayoutOrder=3

    local inspColorSection = mk("Frame", inspContent, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2,Visible=false})
    mk("UIListLayout", inspColorSection, {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})
    mk("TextLabel", inspColorSection, {Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="COLORES EN EL BUILD",TextColor3=T.sub,Font=Enum.Font.GothamSemibold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0})

    local inspColorScroll = mk("ScrollingFrame", inspColorSection, {Size=UDim2.new(1,0,0,110),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=T.purple,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(0,0,0,0),LayoutOrder=1})
    pad(inspColorScroll, 2,2,2,2)
    local inspColorCont = mk("Frame", inspColorScroll, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1})
    mk("UIListLayout", inspColorCont, {Padding=UDim.new(0,3), SortOrder=Enum.SortOrder.LayoutOrder})

    local inspColorStatusLbl = mk("TextLabel", inspColorSection, {Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="",TextColor3=T.ok,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=2})

    local inspBtnClearColors = btn(inspColorSection, "Quitar todos los colores", UDim2.new(1,0,0,24), nil, T.btnAlt)
    inspBtnClearColors.TextSize = 9
    inspBtnClearColors.LayoutOrder = 3

    -- populateInspector
    local function populateInspector()
        local sv = selSaveIdx and Saves[selSaveIdx]
        for _, c in ipairs(inspBlockCont:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        for _, c in ipairs(inspColorCont:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        inspBlockStatusLbl.Text = ""; inspColorStatusLbl.Text = ""

        if not sv then
            inspNoSelLbl.Visible = true; inspBlockSection.Visible = false; inspColorSection.Visible = false; return
        end
        inspNoSelLbl.Visible = false; inspBlockSection.Visible = true; inspColorSection.Visible = true

        -- Poblar bloques
        local uniqueBlocks = getUniqueBuildBlocks(sv)
        if #uniqueBlocks == 0 then
            mk("TextLabel", inspBlockCont, {Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Text="(build sin bloques)",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=1})
        else
            for idx, item in ipairs(uniqueBlocks) do
                local row = mk("Frame", inspBlockCont, {Size=UDim2.new(1,0,0,34),BackgroundColor3=T.input,BorderSizePixel=0,LayoutOrder=idx}); corner(row, 6)
                mk("ImageLabel", row, {Size=UDim2.new(0,24,0,24),Position=UDim2.new(0,4,0.5,-12),BackgroundTransparency=1,Image=item.image~="" and item.image or DEF_IMG})
                mk("TextLabel", row, {Size=UDim2.new(1,-120,1,0),Position=UDim2.new(0,32,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=item.name,TextTruncate=Enum.TextTruncate.AtEnd})
                mk("TextLabel", row, {Size=UDim2.new(0,30,1,0),Position=UDim2.new(1,-112,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=10,TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Right,Text="×"..item.count})
                local changeBtn = mk("TextButton", row, {Size=UDim2.new(0,76,0,24),Position=UDim2.new(1,-80,0.5,-12),BackgroundColor3=T.accent,BorderSizePixel=0,Text="Cambiar",TextColor3=T.bg,Font=Enum.Font.GothamBold,TextSize=9}); corner(changeBtn, 5)
                local capturedName = item.name
                changeBtn.MouseButton1Click:Connect(function()
                    openBlockPicker("Reemplazar: "..capturedName, function(newBlockName)
                        if newBlockName == capturedName then
                            inspBlockStatusLbl.Text = "Ya es ese bloque"; inspBlockStatusLbl.TextColor3 = T.sub; return
                        end
                        local changed = 0
                        for _, pd in ipairs(sv.data.Block) do if pd.BlockName == capturedName then pd.BlockName = newBlockName; changed = changed + 1 end end
                        inspBlockStatusLbl.Text = string.format("✓ %d '%s'→'%s'", changed, capturedName, newBlockName); inspBlockStatusLbl.TextColor3 = T.ok
                        cCache[sv] = nil; renderSavePrev(); task.defer(populateInspector)
                    end)
                end)
            end
            inspBlockScroll.Size = UDim2.new(1,0,0,math.clamp(#uniqueBlocks*37,37,148))
        end

        -- Poblar colores
        local uniqueColors = getUniqueBuildColors(sv)
        if #uniqueColors == 0 then
            mk("TextLabel", inspColorCont, {Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Text="(build sin colores personalizados)",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,LayoutOrder=1})
            inspBtnClearColors.Visible = false
        else
            inspBtnClearColors.Visible = true
            for idx, item in ipairs(uniqueColors) do
                local row = mk("Frame", inspColorCont, {Size=UDim2.new(1,0,0,32),BackgroundColor3=T.input,BorderSizePixel=0,LayoutOrder=idx}); corner(row, 6)
                local swatch = mk("Frame", row, {Size=UDim2.new(0,22,0,22),Position=UDim2.new(0,5,0.5,-11),BackgroundColor3=item.color,BorderSizePixel=0}); corner(swatch, 4); stroke(swatch, T.sub, 1)
                local r255 = math.floor(item.r*255+0.5); local g255 = math.floor(item.g*255+0.5); local b255 = math.floor(item.b*255+0.5)
                mk("TextLabel", row, {Size=UDim2.new(1,-130,1,0),Position=UDim2.new(0,32,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=9,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left,Text=string.format("RGB(%d,%d,%d)",r255,g255,b255)})
                mk("TextLabel", row, {Size=UDim2.new(0,28,1,0),Position=UDim2.new(1,-112,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=9,TextColor3=T.sub,TextXAlignment=Enum.TextXAlignment.Right,Text="×"..item.count})
                local colChangeBtn = mk("TextButton", row, {Size=UDim2.new(0,76,0,22),Position=UDim2.new(1,-80,0.5,-11),BackgroundColor3=T.accent,BorderSizePixel=0,Text="Cambiar",TextColor3=T.bg,Font=Enum.Font.GothamBold,TextSize=9}); corner(colChangeBtn, 5)
                local capR, capG, capB = item.r, item.g, item.b
                colChangeBtn.MouseButton1Click:Connect(function()
                    if openCP then
                        openCP(Color3.new(capR, capG, capB), function(newCol)
                            local changed = 0
                            for _, pd in ipairs(sv.data.Block) do
                                if pd.ColorR then
                                    local pr=math.floor((pd.ColorR or 0)*255+0.5); local pg=math.floor((pd.ColorG or 0)*255+0.5); local pb=math.floor((pd.ColorB or 0)*255+0.5)
                                    if pr==math.floor(capR*255+0.5) and pg==math.floor(capG*255+0.5) and pb==math.floor(capB*255+0.5) then
                                        pd.ColorR=newCol.R; pd.ColorG=newCol.G; pd.ColorB=newCol.B; changed=changed+1
                                    end
                                end
                            end
                            inspColorStatusLbl.Text=string.format("✓ %d bloques recoloreados",changed); inspColorStatusLbl.TextColor3=T.ok
                            cCache[sv]=nil; renderSavePrev(); task.defer(populateInspector)
                        end, function(previewCol)
                            if swatch and swatch.Parent then swatch.BackgroundColor3=previewCol end
                        end)
                    else
                        inspColorStatusLbl.Text="Color picker no disponible"; inspColorStatusLbl.TextColor3=T.danger
                    end
                end)
            end
            inspColorScroll.Size = UDim2.new(1,0,0,math.clamp(#uniqueColors*35,35,140))
        end
    end

    inspBtnClearColors.MouseButton1Click:Connect(function()
        local sv = selSaveIdx and Saves[selSaveIdx]
        if not sv or not sv.data then return end
        local cleared = 0
        for _, pd in ipairs(sv.data.Block) do if pd.ColorR then pd.ColorR=nil; pd.ColorG=nil; pd.ColorB=nil; cleared=cleared+1 end end
        inspColorStatusLbl.Text=string.format("✓ %d colores eliminados",cleared); inspColorStatusLbl.TextColor3=T.ok
        cCache[sv]=nil; renderSavePrev(); task.defer(populateInspector)
    end)

    local function onSelSaveChanged() populateInspector() end

    inspToggleBtn.MouseButton1Click:Connect(function()
        if not inspCollapsed then populateInspector() end
    end)

    local _origRenderSaveList = renderSaveList
    renderSaveList = function(isAsync, onComplete)
        _origRenderSaveList(isAsync, function()
            onSelSaveChanged()
            if onComplete then onComplete() end
        end)
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- EDIT TOOLS SECTION
    -- ════════════════════════════════════════════════════════════════════════

    local function deepCopyTbl(t)
        local c = {}
        for k, v in pairs(t) do c[k] = type(v) == "table" and deepCopyTbl(v) or v end
        return c
    end

    local function eDist3(a, b)
        local dx=(a.RelX or 0)-(b.RelX or 0); local dy=(a.RelY or 0)-(b.RelY or 0); local dz=(a.RelZ or 0)-(b.RelZ or 0)
        return math.sqrt(dx*dx+dy*dy+dz*dz)
    end

    local function eCentroid(arr)
        local sx, sy, sz = 0, 0, 0
        for _, b in ipairs(arr) do sx=sx+(b.RelX or 0); sy=sy+(b.RelY or 0); sz=sz+(b.RelZ or 0) end
        return {x=sx/#arr, y=sy/#arr, z=sz/#arr}
    end

    local function buildSpatialHash(blks, cellSize)
        local map = {}
        for i, b in ipairs(blks) do
            local cx=math.floor((b.RelX or 0)/cellSize+0.5); local cy=math.floor((b.RelY or 0)/cellSize+0.5); local cz=math.floor((b.RelZ or 0)/cellSize+0.5)
            local key=cx..","..cy..","..cz; if not map[key] then map[key]={} end; table.insert(map[key],i)
        end
        return {map=map, cell=cellSize}
    end

    local function spatialNeighbors(hash, b, radius)
        local cs=hash.cell; local cx=math.floor((b.RelX or 0)/cs+0.5); local cy=math.floor((b.RelY or 0)/cs+0.5); local cz=math.floor((b.RelZ or 0)/cs+0.5)
        local r=math.ceil(radius); local result={}
        for dx=-r,r do for dy=-r,r do for dz=-r,r do
            local key=(cx+dx)..","..(cy+dy)..","..(cz+dz)
            if hash.map[key] then for _,i in ipairs(hash.map[key]) do table.insert(result,i) end end
        end end end
        return result
    end

    local function algoSmooth(blks, params)
        local iter=params.iter or 2; local str=(params.str or 4)/10; local rad=(params.radius or 2)*3
        local cur=deepCopyTbl(blks)
        for _=1,iter do
            local hash=buildSpatialHash(cur,math.max(1,rad*0.5)); local nxt=deepCopyTbl(cur)
            for i,b in ipairs(cur) do
                local nbIdxs=spatialNeighbors(hash,b,1.5); local nbs={}
                for _,j in ipairs(nbIdxs) do if j~=i and eDist3(cur[j],b)<=rad then table.insert(nbs,j) end end
                if #nbs>=2 then
                    local ax,ay,az=0,0,0
                    for _,j in ipairs(nbs) do ax=ax+(cur[j].RelX or 0); ay=ay+(cur[j].RelY or 0); az=az+(cur[j].RelZ or 0) end
                    ax=ax/#nbs; ay=ay/#nbs; az=az/#nbs
                    nxt[i].RelX=(b.RelX or 0)+(ax-(b.RelX or 0))*str; nxt[i].RelY=(b.RelY or 0)+(ay-(b.RelY or 0))*str; nxt[i].RelZ=(b.RelZ or 0)+(az-(b.RelZ or 0))*str
                end
            end
            cur=nxt
        end
        return cur
    end

    local function algoBevel(blks, params)
        local thresh=params.thresh or 2; local fill=params.fill and params.fill>=1; local cs=thresh*2.5
        local hash=buildSpatialHash(blks,cs); local result=deepCopyTbl(blks); local toRemove={}
        for i,b in ipairs(blks) do
            local nbIdxs=spatialNeighbors(hash,b,1.5); local nbs={}
            for _,j in ipairs(nbIdxs) do if j~=i and eDist3(blks[j],b)<=cs then table.insert(nbs,j) end end
            local isEdge=#nbs<=thresh
            if isEdge and not fill then toRemove[i]=true
            elseif isEdge and fill and #nbs>=1 then
                local pts={}; for _,j in ipairs(nbs) do table.insert(pts,blks[j]) end; local c=eCentroid(pts)
                result[i].RelX=(b.RelX or 0)*0.6+c.x*0.4; result[i].RelY=(b.RelY or 0)*0.6+c.y*0.4; result[i].RelZ=(b.RelZ or 0)*0.6+c.z*0.4
            end
        end
        if fill then return result end
        local filtered={}; for i,b in ipairs(result) do if not toRemove[i] then table.insert(filtered,b) end end
        return filtered
    end

    local function algoSimplify(blks, params)
        local snap=params.snap or 2; local merge=params.merge or 2; local cur={}
        for _,b in ipairs(blks) do
            local nb=deepCopyTbl(b); nb.RelX=math.floor((b.RelX or 0)/snap+0.5)*snap; nb.RelY=math.floor((b.RelY or 0)/snap+0.5)*snap; nb.RelZ=math.floor((b.RelZ or 0)/snap+0.5)*snap
            table.insert(cur,nb)
        end
        local seen={}; local dedup={}
        for _,b in ipairs(cur) do local k=b.RelX..","..b.RelY..","..b.RelZ; if not seen[k] then seen[k]=true; table.insert(dedup,b) end end
        cur=dedup
        if merge>=3 then
            local cs2=snap*merge; local hash=buildSpatialHash(cur,cs2); local merged={}; local result={}
            for i,b in ipairs(cur) do
                if not merged[i] then
                    local nbIdxs=spatialNeighbors(hash,b,1.2); local cluster={}
                    for _,j in ipairs(nbIdxs) do if not merged[j] and eDist3(cur[j],b)<=cs2*1.4 then table.insert(cluster,j) end end
                    if #cluster>=3 then
                        local pts={}; for _,j in ipairs(cluster) do table.insert(pts,cur[j]) end; local c=eCentroid(pts)
                        local rep=deepCopyTbl(b); rep.RelX=math.floor(c.x/snap+0.5)*snap; rep.RelY=math.floor(c.y/snap+0.5)*snap; rep.RelZ=math.floor(c.z/snap+0.5)*snap
                        table.insert(result,rep); for _,j in ipairs(cluster) do merged[j]=true end
                    else table.insert(result,b); merged[i]=true end
                end
            end
            local seen2={}; local final={}
            for _,b in ipairs(result) do local k=b.RelX..","..b.RelY..","..b.RelZ; if not seen2[k] then seen2[k]=true; table.insert(final,b) end end
            return final
        end
        return cur
    end

    local function algoDefloat(blks, params)
        local dist=params.dist or 4; local minn=params.minn or 1; local cs=dist*1.2
        local hash=buildSpatialHash(blks,cs); local result={}
        for i,b in ipairs(blks) do
            local nbIdxs=spatialNeighbors(hash,b,1.5); local cnt=0
            for _,j in ipairs(nbIdxs) do if j~=i and eDist3(blks[j],b)<=dist then cnt=cnt+1 end end
            if cnt>=minn then table.insert(result,b) end
        end
        return result
    end

    local function algoDedup(blks, params)
        local tol=params.tolerance or 1; local snap=tol; local seen={}; local result={}
        for _,b in ipairs(blks) do
            local k=math.floor((b.RelX or 0)/snap+0.5)..","..math.floor((b.RelY or 0)/snap+0.5)..","..math.floor((b.RelZ or 0)/snap+0.5)
            if not seen[k] then seen[k]=true; table.insert(result,b) end
        end
        return result
    end

    local function algoNormalize(blks, params)
        if #blks==0 then return blks end
        local snap=params.snap or 2; local minX,minY,minZ=math.huge,math.huge,math.huge; local cx,cz=0,0
        for _,b in ipairs(blks) do minX=math.min(minX,b.RelX or 0); minY=math.min(minY,b.RelY or 0); minZ=math.min(minZ,b.RelZ or 0); cx=cx+(b.RelX or 0); cz=cz+(b.RelZ or 0) end
        cx=cx/#blks; cz=cz/#blks
        local result={}
        for _,b in ipairs(blks) do
            local nb=deepCopyTbl(b); nb.RelX=math.floor(((b.RelX or 0)-cx)/snap+0.5)*snap; nb.RelY=math.floor(((b.RelY or 0)-minY)/snap+0.5)*snap; nb.RelZ=math.floor(((b.RelZ or 0)-cz)/snap+0.5)*snap
            table.insert(result,nb)
        end
        return result
    end

    local EDIT_TOOL_CONFIG = {
        smooth   = {label="Suavizar",   desc="Mueve cada bloque hacia el promedio de sus vecinos. Suaviza superficies irregulares.", params={{id="iter",label="Iteraciones",min=1,max=10,def=2},{id="str",label="Intensidad",min=1,max=10,def=4},{id="radius",label="Radio vec.",min=1,max=5,def=2}}},
        bevel    = {label="Bordes",     desc="Detecta bordes y esquinas expuestos y los lima. Reduce protuberancias.", params={{id="thresh",label="Umbral",min=1,max=6,def=2},{id="fill",label="Relleno",min=0,max=1,def=1}}},
        simplify = {label="Simplificar",desc="Combina bloques del mismo tipo y alineados. Reduce el conteo total.", params={{id="snap",label="Snap grid",min=1,max=8,def=2},{id="merge",label="Agresivo",min=1,max=5,def=2}}},
        defloat  = {label="Flotantes",  desc="Elimina bloques sin vecinos cercanos que quedan flotando solos.", params={{id="dist",label="Distancia",min=2,max=12,def=4},{id="minn",label="Mín vecinos",min=1,max=6,def=1}}},
        dedup    = {label="Duplicados", desc="Elimina bloques superpuestos en la misma posición.", params={{id="tolerance",label="Tolerancia",min=1,max=4,def=1}}},
        normalize= {label="Centrar",    desc="Centra el build en el origen y baja el piso al nivel Y=0.", params={{id="snap",label="Snap pos.",min=1,max=4,def=2}}},
    }

    local EDIT_TOOL_ORDER = {"smooth", "bevel", "simplify", "defloat", "dedup", "normalize"}

    local secEdit = sec(PageSave, 6)

    local editHeaderRow = mk("Frame", secEdit, {Size=UDim2.new(1,0,0,30),BackgroundColor3=T.input,BorderSizePixel=0,LayoutOrder=0}); corner(editHeaderRow,8); stroke(editHeaderRow,T.purple,1)
    local editCollapsed = false
    local editToggleBtn = btn(editHeaderRow,"▼  EDITAR BUILD",UDim2.new(1,0,1,0),nil,T.purple)
    editToggleBtn.TextSize=11; editToggleBtn.Font=Enum.Font.GothamBold; editToggleBtn.TextXAlignment=Enum.TextXAlignment.Left; editToggleBtn.TextColor3=T.bg

    local editContent = mk("Frame", secEdit, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=1})
    mk("UIListLayout", editContent, {Padding=UDim.new(0,6), SortOrder=Enum.SortOrder.LayoutOrder})

    editToggleBtn.MouseButton1Click:Connect(function()
        editCollapsed = not editCollapsed
        editContent.Visible = not editCollapsed
        editToggleBtn.Text = editCollapsed and "▲  Editar Build" or "▼  Editar Build"
    end)

    local editDescLbl = mk("TextLabel", editContent, {Size=UDim2.new(1,0,0,28),BackgroundTransparency=1,Text="",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=9,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top,LayoutOrder=0})

    local editToolRow = mk("Frame", editContent, {Size=UDim2.new(1,0,0,62),BackgroundTransparency=1,LayoutOrder=1})
    local editToolBtns = {}
    for idx, t in ipairs(EDIT_TOOL_ORDER) do
        local cfg = EDIT_TOOL_CONFIG[t]
        local r = math.floor((idx-1)/3); local c = (idx-1)%3
        local tb = mk("TextButton", editToolRow, {Size=UDim2.new(1/3,-2,0,28),Position=UDim2.new(c/3,0,r*32,0),BackgroundColor3=T.btnAlt,BorderSizePixel=0,Text=cfg.label,TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=10,LayoutOrder=idx}); corner(tb,6); stroke(tb,T.sub,1)
        editToolBtns[t] = tb
    end

    local editParamsCont = mk("Frame", editContent, {Size=UDim2.new(1,0,0,1),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2})
    mk("UIListLayout", editParamsCont, {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})

    local editTool = "smooth"
    local editParamInputs = {}

    local function buildEditParams(tool)
        for _, child in ipairs(editParamsCont:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
        editParamInputs = {}
        local cfg = EDIT_TOOL_CONFIG[tool]; if not cfg then return end
        for i, p in ipairs(cfg.params) do
            local row = mk("Frame",editParamsCont,{Size=UDim2.new(1,0,0,24),BackgroundTransparency=1,LayoutOrder=i})
            mk("TextLabel",row,{Size=UDim2.new(0,90,1,0),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Text=p.label,TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left})
            local decBtn=btn(row,"−",UDim2.new(0,22,0,22),UDim2.new(0,92,0.5,-11),T.btnAlt); decBtn.TextSize=12; decBtn.Font=Enum.Font.GothamBold
            local valLbl=mk("TextLabel",row,{Size=UDim2.new(0,36,1,0),Position=UDim2.new(0,116,0,0),BackgroundColor3=T.card,BorderSizePixel=0,Text=tostring(p.def),TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center}); corner(valLbl,4)
            local incBtn=btn(row,"+",UDim2.new(0,22,0,22),UDim2.new(0,154,0.5,-11),T.btnAlt); incBtn.TextSize=12; incBtn.Font=Enum.Font.GothamBold
            local state={val=p.def,min=p.min,max=p.max}; editParamInputs[p.id]={lbl=valLbl,state=state}
            local function upd(v) state.val=math.clamp(math.floor(v+0.5),p.min,p.max); valLbl.Text=tostring(state.val) end
            decBtn.MouseButton1Click:Connect(function() upd(state.val-1) end); incBtn.MouseButton1Click:Connect(function() upd(state.val+1) end)
        end
    end

    local function selectEditTool(tool)
        editTool = tool
        for t, b in pairs(editToolBtns) do
            local active=(t==tool); b.BackgroundColor3=active and T.accent or T.btnAlt; b.TextColor3=active and T.bg or T.text
            local st=b:FindFirstChildOfClass("UIStroke"); if st then st.Color=active and T.accent or T.sub; st.Thickness=active and 2 or 1 end
        end
        editDescLbl.Text = EDIT_TOOL_CONFIG[tool].desc or ""
        buildEditParams(tool)
    end

    for _, t in ipairs(EDIT_TOOL_ORDER) do editToolBtns[t].MouseButton1Click:Connect(function() selectEditTool(t) end) end

    local editApplyBtn = btn(editContent,"Aplicar",UDim2.new(1,0,0,28),nil,T.purple); editApplyBtn.TextSize=10; editApplyBtn.Font=Enum.Font.GothamBold; editApplyBtn.LayoutOrder=3
    local editUndoBtn  = btn(editContent,"↩  Deshacer edición",UDim2.new(1,0,0,22),nil,T.btnAlt); editUndoBtn.TextSize=9; editUndoBtn.LayoutOrder=4
    local editSaveBtn  = btn(editContent,"💾  Guardar cambios en disco",UDim2.new(1,0,0,24),nil,T.ok); editSaveBtn.TextSize=9; editSaveBtn.Font=Enum.Font.GothamBold; editSaveBtn.TextColor3=T.bg; editSaveBtn.LayoutOrder=5
    local editStatusLbl= mk("TextLabel",editContent,{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=6})

    local editUndoStack = {}

    local function getEditParams()
        local params = {}
        for pid, inp in pairs(editParamInputs) do params[pid]=inp.state.val end
        return params
    end

    editApplyBtn.MouseButton1Click:Connect(function()
        local sv=selSaveIdx and Saves[selSaveIdx]
        if not sv or not sv.data or not sv.data.Block then editStatusLbl.Text="⚠ Selecciona un guardado primero"; editStatusLbl.TextColor3=T.danger; return end
        table.insert(editUndoStack,{sv=sv,blocks=deepCopyTbl(sv.data.Block)}); if #editUndoStack>30 then table.remove(editUndoStack,1) end
        local params=getEditParams(); editApplyBtn.Text="Procesando..."; editApplyBtn.Active=false
        editStatusLbl.Text="Aplicando "..(EDIT_TOOL_CONFIG[editTool].label or "").."..."; editStatusLbl.TextColor3=T.warn
        task.spawn(function()
            local result; local ok,err=pcall(function()
                if editTool=="smooth" then result=algoSmooth(sv.data.Block,params)
                elseif editTool=="bevel" then result=algoBevel(sv.data.Block,params)
                elseif editTool=="simplify" then result=algoSimplify(sv.data.Block,params)
                elseif editTool=="defloat" then result=algoDefloat(sv.data.Block,params)
                elseif editTool=="dedup" then result=algoDedup(sv.data.Block,params)
                elseif editTool=="normalize" then result=algoNormalize(sv.data.Block,params) end
            end)
            if not ok or not result then editStatusLbl.Text="✗ Error: "..tostring(err); editStatusLbl.TextColor3=T.danger; editApplyBtn.Text="Aplicar"; editApplyBtn.Active=true; return end
            local before=#sv.data.Block; sv.data.Block=result; local after=#result; local diff=after-before; local sign=diff>=0 and "+" or ""
            editStatusLbl.Text=string.format("✓ %d → %d (%s%d)",before,after,sign,diff); editStatusLbl.TextColor3=T.ok
            editApplyBtn.Text="Aplicar"; editApplyBtn.Active=true; cCache[sv]=nil; renderSavePrev(); renderSaveList()
        end)
    end)

    editUndoBtn.MouseButton1Click:Connect(function()
        local sv=selSaveIdx and Saves[selSaveIdx]
        if not sv then editStatusLbl.Text="Nada que deshacer"; editStatusLbl.TextColor3=T.sub; return end
        local foundIdx=nil; for i=#editUndoStack,1,-1 do if editUndoStack[i].sv==sv then foundIdx=i; break end end
        if not foundIdx then editStatusLbl.Text="Nada que deshacer"; editStatusLbl.TextColor3=T.sub; return end
        local snapshot=table.remove(editUndoStack,foundIdx); sv.data.Block=snapshot.blocks
        cCache[sv]=nil; renderSavePrev(); renderSaveList(); editStatusLbl.Text="↩ Deshecho"; editStatusLbl.TextColor3=T.sub
    end)

    editSaveBtn.MouseButton1Click:Connect(function()
        local sv=selSaveIdx and Saves[selSaveIdx]
        if not sv or not sv.data then editStatusLbl.Text="⚠ Sin guardado seleccionado"; editStatusLbl.TextColor3=T.danger; return end
        editSaveBtn.Text="Guardando..."; editSaveBtn.Active=false
        task.spawn(function()
            local ok=pcall(function() writeBF(sv.name,{name=sv.name,data=sv.data}) end)
            if ok then editSaveBtn.Text="✓ Guardado"; editStatusLbl.Text="Cambios persistidos en disco"; editStatusLbl.TextColor3=T.ok
            else editSaveBtn.Text="✗ Error"; editStatusLbl.Text="No se pudo escribir el archivo"; editStatusLbl.TextColor3=T.danger end
            task.delay(1.5,function() if editSaveBtn and editSaveBtn.Parent then editSaveBtn.Text="💾  Guardar cambios en disco"; editSaveBtn.Active=true end end)
        end)
    end)

    selectEditTool("smooth")

    -- ── SECCIÓN RECORTE POR EJE ────────────────────────────────────────────
    do
        local secCrop=sec(PageSave,7)
        mk("TextLabel",secCrop,{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="✂  RECORTE POR EJE",TextColor3=T.sub,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=0})
        mk("TextLabel",secCrop,{Size=UDim2.new(1,0,0,11),BackgroundTransparency=1,Text="Dejá vacío = sin límite. Usa el Deshacer del editor si te equivocás.",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=8,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=1,TextWrapped=true})
        -- Fila de inputs por eje
        local function axRow(parent, label, lo)
            local f=mk("Frame",parent,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=lo})
            mk("TextLabel",f,{Size=UDim2.new(0,14,1,0),BackgroundTransparency=1,Text=label,TextColor3=T.text,Font=Enum.Font.GothamBold,TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})
            mk("TextLabel",f,{Size=UDim2.new(0,22,1,0),Position=UDim2.new(0,16,0,0),BackgroundTransparency=1,Text="min",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=9})
            local minI=box(f,UDim2.new(0,46,0,22),UDim2.new(0,38,0.5,-11),""); minI.PlaceholderText="-inf"; minI.TextXAlignment=Enum.TextXAlignment.Center
            mk("TextLabel",f,{Size=UDim2.new(0,22,1,0),Position=UDim2.new(0,88,0,0),BackgroundTransparency=1,Text="max",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=9})
            local maxI=box(f,UDim2.new(0,46,0,22),UDim2.new(0,110,0.5,-11),""); maxI.PlaceholderText="+inf"; maxI.TextXAlignment=Enum.TextXAlignment.Center
            return minI, maxI
        end
        SaveUI.cropYMin, SaveUI.cropYMax = axRow(secCrop,"Y",2)
        SaveUI.cropXMin, SaveUI.cropXMax = axRow(secCrop,"X",3)
        SaveUI.cropZMin, SaveUI.cropZMax = axRow(secCrop,"Z",4)
        do
            local bRow=mk("Frame",secCrop,{Size=UDim2.new(1,0,0,26),BackgroundTransparency=1,LayoutOrder=5})
            SaveUI.btnCropApply=btn(bRow,"Aplicar Recorte",UDim2.new(0.65,-3,1,0),nil,T.purple); SaveUI.btnCropApply.TextSize=9
            SaveUI.btnCropClear=btn(bRow,"Limpiar",UDim2.new(0.35,-3,1,0),UDim2.new(0.65,3,0,0),T.btnAlt); SaveUI.btnCropClear.TextSize=9
        end
        SaveUI.cropStatus=mk("TextLabel",secCrop,{Size=UDim2.new(1,0,0,14),BackgroundTransparency=1,Text="",TextColor3=T.sub,Font=Enum.Font.Gotham,TextSize=9,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=6})
    end

    -- ════════════════════════════════════════════════════════════════════════
    -- Inicializar auto-detección de modo compartir
    -- ════════════════════════════════════════════════════════════════════════
    hookShareWatchers()
    applyAutoShare()
    LP:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.3); hookShareWatchers(); applyAutoShare()
    end)
    task.spawn(function()
        while SG and SG.Parent do task.wait(2); if PageSave.Visible then pcall(applyAutoShare) end end
    end)

    -- ════════════════════════════════════════════════════════════════════════
    -- HANDLERS DE FUNCIONALIDADES NUEVAS (después de que todo esté definido)
    -- ════════════════════════════════════════════════════════════════════════
    do
        -- Vista en fila (1 / 2 / 3 columnas)
        SaveUI.btnRowView.MouseButton1Click:Connect(function()
            extState.rowView=extState.rowView%3+1
            local rv=extState.rowView
            SaveUI.btnRowView.Text=rv==1 and"▤ 1×"or rv==2 and"▤ 2×"or"▤ 3×"
            if rv==1 then SaveUI.listGrid.CellSize=UDim2.new(1,-6,0,30)
            elseif rv==2 then SaveUI.listGrid.CellSize=UDim2.new(0.5,-4,0,58)
            else SaveUI.listGrid.CellSize=UDim2.new(1/3,-4,0,58) end
            renderSaveList()
        end)

        -- Renombrar guardado
        SaveUI.btnRenameConfirm.MouseButton1Click:Connect(function()
            local sv=selSaveIdx and Saves[selSaveIdx]
            if not sv then SaveUI.renameStatus.Text="⚠ Selecciona un guardado primero"; SaveUI.renameStatus.TextColor3=T.danger; return end
            local nm=SaveUI.renameInp.Text:gsub("%s+","_"):gsub("[^%w_%-]","")
            if nm=="" or nm=="_" then SaveUI.renameStatus.Text="⚠ Nombre vacío"; SaveUI.renameStatus.TextColor3=T.danger; return end
            for i,s in ipairs(Saves) do if s.name==nm and i~=selSaveIdx then SaveUI.renameStatus.Text="⚠ Ya existe ese nombre"; SaveUI.renameStatus.TextColor3=T.danger; return end end
            local oldName=sv.name; local oldPath=sv._path or(FS2.."/"..oldName..".json")
            local ok=pcall(writeBF,nm,{name=nm,data=sv.data})
            if ok then
                pcall(FSys.del,oldPath)
                for i,n in ipairs(ORD) do if n==oldName then ORD[i]=nm; break end end
                -- Preservar favorito y color con el nuevo nombre
                if extState.favs[oldName] then extState.favs[nm]=true; extState.favs[oldName]=nil end
                if extState.colors[oldName] then extState.colors[nm]=extState.colors[oldName]; extState.colors[oldName]=nil end
                sv.name=nm; sv._path=FS2.."/"..nm..".json"
                SaveUI.renameStatus.Text="✓ Renombrado a '"..nm.."'"; SaveUI.renameStatus.TextColor3=T.ok
                SaveUI.renameInp.Text=""; renderSaveList()
            else
                SaveUI.renameStatus.Text="✗ Error al escribir archivo"; SaveUI.renameStatus.TextColor3=T.danger
            end
            task.delay(2.5,function() if SaveUI.renameStatus and SaveUI.renameStatus.Parent then SaveUI.renameStatus.Text="" end end)
        end)

        -- Stats de inventario
        SaveUI.btnStats.MouseButton1Click:Connect(function()
            local sv=selSaveIdx and Saves[selSaveIdx]; if not sv then return end
            for _,c in ipairs(SaveUI.statsScroll:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
            local needed=getUniqueBuildBlocks(sv); local inInv={}
            for _,item in ipairs(getPlayerBlocks()) do inInv[item.name]=item.qty end
            local total,allOk=0,true
            for idx,item in ipairs(needed) do
                local have=inInv[item.name] or 0; total=total+item.count
                local ok2=have>=item.count; if not ok2 then allOk=false end
                local row=mk("Frame",SaveUI.statsScroll,{Size=UDim2.new(1,0,0,32),BackgroundColor3=ok2 and Color3.fromRGB(144,238,144)or Color3.fromRGB(255,182,193),BorderSizePixel=0,LayoutOrder=idx}); corner(row,5)
                mk("ImageLabel",row,{Size=UDim2.new(0,24,0,24),Position=UDim2.new(0,4,0.5,-12),BackgroundTransparency=1,Image=item.image~="" and item.image or DEF_IMG})
                mk("TextLabel",row,{Size=UDim2.new(1,-120,1,0),Position=UDim2.new(0,32,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamSemibold,TextSize=10,TextColor3=Color3.new(0,0,0),TextXAlignment=Enum.TextXAlignment.Left,Text=item.name,TextTruncate=Enum.TextTruncate.AtEnd})
                mk("TextLabel",row,{Size=UDim2.new(0,86,1,0),Position=UDim2.new(1,-90,0,0),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=10,TextColor3=ok2 and Color3.fromRGB(0,100,0)or Color3.fromRGB(150,0,0),TextXAlignment=Enum.TextXAlignment.Right,Text=tostring(have).."/"..tostring(item.count)})
            end
            mk("TextLabel",SaveUI.statsScroll,{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,LayoutOrder=#needed+1,
                Text=(allOk and"✓ ¡Tenés todo!"or"✗ Faltan bloques").."  ·  total: "..tostring(total).." blq.",
                TextColor3=allOk and T.ok or T.danger,Font=Enum.Font.GothamBold,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center})
            SaveUI.statsOverlay.Visible=true
        end)

        -- Thumbnail Build
        SaveUI.btnThumb.MouseButton1Click:Connect(function()
            local sv=selSaveIdx and Saves[selSaveIdx]; if not sv or not sv.data or not sv.data.Block then return end
            for _,c in ipairs(SaveUI.thumbWM:GetChildren()) do c:Destroy() end
            local center=buildCenter(sv); local mz=myZone()
            local destRot=mz and(mz.CFrame-mz.CFrame.Position)or CFrame.identity
            local minv=Vector3.new(math.huge,math.huge,math.huge); local maxv=Vector3.new(-math.huge,-math.huge,-math.huge)
            local MAX_THUMB=600
            for idx,pd in ipairs(sv.data.Block) do
                if idx>MAX_THUMB then break end
                local off=Vector3.new((pd.RelX or 0)-center.X,(pd.RelY or 0)-center.Y,(pd.RelZ or 0)-center.Z)
                local relRot=CFrame.Angles(math.rad(pd.RotX or 0),math.rad(pd.RotY or 0),math.rad(pd.RotZ or 0))
                local bCF=destRot*CFrame.new(off)*relRot
                local p2=mk("Part",SaveUI.thumbWM,{Anchored=true,CanCollide=false,CanQuery=false,
                    Size=Vector3.new(pd.SizeX or 2,pd.SizeY or 2,pd.SizeZ or 2)*placeScale,
                    CFrame=bCF,
                    Color=pd.ColorR and Color3.new(pd.ColorR,pd.ColorG,pd.ColorB)or Color3.fromRGB(160,160,170),
                    Material=Enum.Material[pd.Material]or Enum.Material.Plastic})
                local pp=p2.Position
                minv=Vector3.new(math.min(minv.X,pp.X),math.min(minv.Y,pp.Y),math.min(minv.Z,pp.Z))
                maxv=Vector3.new(math.max(maxv.X,pp.X),math.max(maxv.Y,pp.Y),math.max(maxv.Z,pp.Z))
            end
            if minv.X<math.huge then
                local bc=(minv+maxv)/2; local bsz=(maxv-minv).Magnitude
                local cd=math.max(bsz*0.75,25)
                -- Vista isométrica: arriba-derecha-frente
                local co=Vector3.new(cd*0.65,cd*0.55,cd*0.65)
                SaveUI.thumbCam.CFrame=CFrame.lookAt(bc+co,bc)
            end
            SaveUI.thumbOverlay.Visible=true
        end)

        -- Recorte aplicar
        SaveUI.btnCropApply.MouseButton1Click:Connect(function()
            local sv=selSaveIdx and Saves[selSaveIdx]
            if not sv or not sv.data or not sv.data.Block then
                if SaveUI.cropStatus then SaveUI.cropStatus.Text="⚠ Selecciona un guardado primero"; SaveUI.cropStatus.TextColor3=T.danger end; return
            end
            local yMin=tonumber(SaveUI.cropYMin.Text); local yMax=tonumber(SaveUI.cropYMax.Text)
            local xMin=tonumber(SaveUI.cropXMin.Text); local xMax=tonumber(SaveUI.cropXMax.Text)
            local zMin=tonumber(SaveUI.cropZMin.Text); local zMax=tonumber(SaveUI.cropZMax.Text)
            if not yMin and not yMax and not xMin and not xMax and not zMin and not zMax then
                SaveUI.cropStatus.Text="⚠ Definí al menos un límite"; SaveUI.cropStatus.TextColor3=T.danger; return
            end
            -- Guardar undo antes de modificar
            table.insert(editUndoStack,{sv=sv,blocks=deepCopyTbl(sv.data.Block)}); if #editUndoStack>30 then table.remove(editUndoStack,1) end
            local before=#sv.data.Block; local filtered={}
            for _,pd in ipairs(sv.data.Block) do
                local y=pd.RelY or 0; local x=pd.RelX or 0; local z=pd.RelZ or 0
                local pass=(not yMin or y>=yMin)and(not yMax or y<=yMax)
                           and(not xMin or x>=xMin)and(not xMax or x<=xMax)
                           and(not zMin or z>=zMin)and(not zMax or z<=zMax)
                if pass then filtered[#filtered+1]=pd end
            end
            sv.data.Block=filtered
            local after=#filtered
            SaveUI.cropStatus.Text=string.format("✓ %d → %d (%d removidos)",before,after,before-after)
            SaveUI.cropStatus.TextColor3=T.ok; cCache[sv]=nil; renderSavePrev(); renderSaveList()
        end)

        -- Recorte limpiar
        SaveUI.btnCropClear.MouseButton1Click:Connect(function()
            if SaveUI.cropYMin then SaveUI.cropYMin.Text="" end; if SaveUI.cropYMax then SaveUI.cropYMax.Text="" end
            if SaveUI.cropXMin then SaveUI.cropXMin.Text="" end; if SaveUI.cropXMax then SaveUI.cropXMax.Text="" end
            if SaveUI.cropZMin then SaveUI.cropZMin.Text="" end; if SaveUI.cropZMax then SaveUI.cropZMax.Text="" end
            if SaveUI.cropStatus then SaveUI.cropStatus.Text="" end
        end)
    end

    return {
        page            = PageSave,
        renderSaveList  = renderSaveList,
        renderSavePrev  = renderSavePrev,
        updSaveHandles  = updSaveHandles,
        startSelTicker  = startSelTicker,
        reloadAndRender = function()
            task.spawn(function()
                if SaveUI.listCont then
                    renderToken = renderToken + 1
                    for _,c in ipairs(SaveUI.listCont:GetChildren()) do
                        if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") then c.Visible = false end
                    end
                    local emptyLbl = SaveUI.listCont:FindFirstChild("EmptyLbl")
                    if not emptyLbl then
                        emptyLbl = mk("TextLabel",SaveUI.listCont,{Name="EmptyLbl",Size=UDim2.new(1,0,0,18),LayoutOrder=1,Text="Cargando guardados...",TextColor3=T.sub,BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Top})
                    else
                        emptyLbl.Text = "Cargando guardados..."
                    end
                    emptyLbl.Visible = true
                end

                for i = 1, #Saves do Saves[i] = nil end
                cCache = {}

                if lOrd then lOrd() end
                if syncOrd then syncOrd() end

                local total = ORD and #ORD or 0
                local toRemove = {}
                for i = 1, total do
                    local name = ORD[i]
                    if name then
                        local path = FS2.."/"..name..".json"
                        local ok, res = pcall(readBF, name)
                        if not ok or not res then ok, res = pcall(readBF, path) end
                        if ok and res and type(res) == "table" then
                            local svData = res.data or res
                            Saves[#Saves+1] = {name=name, data=svData, _path=path}
                        else
                            toRemove[#toRemove+1] = name
                        end
                    end
                    if i % 10 == 0 then task.wait() end
                end

                for _, name in ipairs(toRemove) do if delSaveOrd then delSaveOrd(name) end end
                if selSaveIdx and not Saves[selSaveIdx] then selSaveIdx = nil end

                renderSaveList(true, function()
                    if selSaveIdx then renderSavePrev() else updSaveHandles() end
                    startSelTicker()
                end)
            end)
        end,
        hidePreview     = function()
            for _,p in ipairs(savePool) do p.Transparency=1; p.Size=Vector3.new(0.05,0.05,0.05) end
            saveDummy.Position=Vector3.new(0,-9999,0); saveArcAdornee.Position=Vector3.new(0,-9999,0)
            SaveHandles.Visible=false; SaveArc.Visible=false
        end,
        myBaseCFSetter  = function(cf) myBaseCF=cf end,
        SaveHandles     = SaveHandles,
        SaveArc         = SaveArc,
    }
end

return BuildsModule
