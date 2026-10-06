-- Four vertical faces, with corners counted once; no floor, ceiling or interior.
local cuboid = require("cuboid")
local plan = {}
function plan.new(a,b,options)
    if options~=nil and (type(options)~="table" or type(options.includeCorners)~="boolean") then
        return nil,"invalid_wall_options"
    end
    local box,err=cuboid.new(a,b)
    if not box then return nil,err end
    if box.size.x<3 or box.size.z<3 then return nil,"walls_need_three_blocks_in_x_and_z" end
    if box.min.x<=-30000000 or box.max.x>=30000000 or box.min.z<=-30000000 or box.max.z>=30000000 then
        return nil,"wall_access_out_of_range"
    end
    box.perimeter=2*(box.size.x+box.size.z)-4
    -- Keep existing library calls compatible; the interactive program explicitly defaults to false.
    box.includeCorners=options==nil or options.includeCorners
    box.volume=(box.perimeter-(box.includeCorners and 0 or 4))*box.size.y
    local sz=a.z==box.max.z and -1 or 1
    box.opening={x=a.x,y=box.min.y+math.floor((box.size.y-1)/2),z=a.z+sz}
    if options and options.segment then return require("wall_segments").configure(box,options.segment,a) end
    return box
end
function plan.protected(box)
    return {min=box.min,max=box.max,walls=true,opening=box.opening}
end
function plan.isWall(box,p)
    return cuboid.contains(box,p) and (p.x==box.min.x or p.x==box.max.x or p.z==box.min.z or p.z==box.max.z)
end
-- Finish the four corner columns outside first. Remaining faces are built
-- from the interior by layers. The service opening is always the last cell.
function plan.cell(box,index,first)
    if box.segment then return require("wall_segments").cell(box,index,first) end
    if index<1 or index>box.volume then return nil,"invalid_cell_index" end
    if index==box.volume then return {x=box.opening.x,y=box.opening.y,z=box.opening.z} end
    local sx=first.x==box.max.x and -1 or 1
    local sz=first.z==box.max.z and -1 or 1
    local sy=first.y==box.max.y and -1 or 1
    local nx,nz,ny=box.size.x,box.size.z,box.size.y
    local corners=box.includeCorners and 4*ny or 0
    if index<=corners then
        local column=math.floor((index-1)/ny)
        local level=(index-1)%ny
        if column%2==1 then level=ny-1-level end
        local x=(column==1 or column==2) and nx-1 or 0
        local z=column>=2 and nz-1 or 0
        return {x=first.x+sx*x,y=first.y+sy*level,z=first.z+sz*z}
    end
    local n1,n2=nx-2,nz-2
    local length=box.perimeter-4
    local gx,gz=(box.opening.x-first.x)*sx,(box.opening.z-first.z)*sz
    local gi
    if gz==0 then gi=gx-1
    elseif gx==nx-1 then gi=n1+gz-1
    elseif gz==nz-1 then gi=n1+n2+(nx-2-gx)
    else gi=2*n1+n2+(nz-2-gz) end
    local gl=(box.opening.y-first.y)*sy
    if gl%2==1 then gi=length-1-gi end
    local gateIndex=corners+gl*length+gi+1
    if index>=gateIndex then index=index+1 end
    local relative=index-corners-1
    local layer=math.floor(relative/length)
    local i=relative%length
    if layer%2==1 then i=length-1-i end
    local x,z
    if i<n1 then x,z=i+1,0
    elseif i<n1+n2 then x,z=nx-1,i-n1+1
    elseif i<2*n1+n2 then x,z=nx-2-(i-n1-n2),nz-1
    else x,z=0,nz-2-(i-2*n1-n2) end
    return {x=first.x+sx*x,y=first.y+sy*layer,z=first.z+sz*z}
end
return plan
