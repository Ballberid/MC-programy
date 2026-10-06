-- Partition vertical face columns, keeping one shared service opening.
local segments = {}
local function length(box) return box.perimeter - 4 end
local function column(box, index, first)
    local nx, nz = box.size.x, box.size.z
    local n1, n2 = nx - 2, nz - 2
    local i, x, z = index - 1
    if i < n1 then x,z=i+1,0
    elseif i < n1+n2 then x,z=nx-1,i-n1+1
    elseif i < 2*n1+n2 then x,z=nx-2-(i-n1-n2),nz-1
    else x,z=0,nz-2-(i-2*n1-n2) end
    local sx,sz=first.x==box.max.x and -1 or 1,first.z==box.max.z and -1 or 1
    return {x=first.x+sx*x,y=first.y,z=first.z+sz*z}
end
function segments.configure(box, range, first)
    if type(range)~="table" or type(range.first)~="number" or type(range.last)~="number"
        or range.first%1~=0 or range.last%1~=0 or range.first<1 or range.last<range.first
        or range.last>length(box) then return nil,"invalid_wall_segment" end
    box.segment={first=range.first,last=range.last}
    box.cornerColumns={}
    if box.includeCorners then
        local n1,n2=box.size.x-2,box.size.z-2
        local starts={1,n1+1,n1+n2+1,2*n1+n2+1}
        local xs={first.x,first.x==box.min.x and box.max.x or box.min.x}
        local zs={first.z,first.z==box.min.z and box.max.z or box.min.z}
        for i,idx in ipairs(starts) do
            if idx>=range.first and idx<=range.last then
                box.cornerColumns[#box.cornerColumns+1]={x=xs[(i==2 or i==3) and 2 or 1],z=zs[i>=3 and 2 or 1]}
            end
        end
    end
    box.closeOpening=range.last==length(box)
    box.volume=(range.last-range.first+1+#box.cornerColumns)*box.size.y
    return box
end
function segments.cell(box, index, first)
    if index<1 or index>box.volume then return nil,"invalid_cell_index" end
    if box.closeOpening and index==box.volume then
        return {x=box.opening.x,y=box.opening.y,z=box.opening.z}
    end
    local sy=first.y==box.max.y and -1 or 1
    local ny=box.size.y
    local cornerCount=#box.cornerColumns*ny
    if index<=cornerCount then
        local c=box.cornerColumns[math.floor((index-1)/ny)+1]
        local level=(index-1)%ny
        return {x=c.x,y=first.y+sy*level,z=c.z}
    end
    local width=box.segment.last-box.segment.first+1
    local gateLayer=(box.opening.y-first.y)*sy
    local gateIndex=cornerCount+gateLayer*width+(gateLayer%2==0 and width or 1)
    if box.closeOpening and index>=gateIndex then index=index+1 end
    local offset=index-cornerCount-1
    local layer=math.floor(offset/width)
    local i=offset%width
    if layer%2==1 then i=width-1-i end
    local p=column(box,box.segment.first+i,first)
    p.y=first.y+sy*layer
    return p
end
function segments.split(box, count)
    if type(count)~="number" or count%1~=0 or count<1 or count>32 then return nil,"invalid_worker_count" end
    if count>length(box) then return nil,"too_many_workers_for_walls" end
    local result,offset={},0
    for i=1,count do
        local width=math.floor(length(box)/count)+(i<=length(box)%count and 1 or 0)
        result[i]={first=offset+1,last=offset+width}; offset=offset+width
    end
    return result
end
return segments
