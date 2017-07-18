local utilities = 
{
	SetBlendParam = function(sm, blendParam, blendParamID)
		CharacterAnimationRequestBus.Event.SetBlendParameter(sm.EntityId, blendParamID, blendParam);
	end,
	
	-- Calculate the SlopeAngle blend parameter
	GetSlopeAngle = function(movementcontroller)
		local tm = TransformBus.Event.GetWorldTM(movementcontroller.entityId);
		local pos = tm:GetTranslation();
		local up = Vector3(0,0,1);
		
		local rayCastConfig = RayCastConfiguration();
		rayCastConfig.origin = pos + Vector3(0,0,0.5);
		rayCastConfig.direction =  Vector3(0,0,-1);
		rayCastConfig.maxDistance = 2.0;
		rayCastConfig.maxHits = 1;
		rayCastConfig.physicalEntityTypes = PhysicalEntityTypes.Static + PhysicalEntityTypes.Dynamic;		
		local hits = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfig);
		if(#hits > 0) then
			up = hits[1].normal;
		end
		local forward = tm:GetColumn(1):GetNormalized();
		local right = Vector3.Cross(forward, up);
		forward = Vector3.Cross(up, right);
		local slopeAngle = Math.ArcCos(-forward.z) / 3.14159265359;
		return slopeAngle;
	end,
	
	GetMoveSpeed = function(moveLocal)
        local moveMag = moveLocal:GetLength();
        if (moveMag > 1.0) then 
            moveMag = 1.0 
        end
		return moveMag;
	end,
	
	CheckFragmentPlaying = function(entityId, requestId)
    	if (requestId) then
        	local status = MannequinRequestsBus.Event.GetRequestStatus(entityId, requestId);
        	return status == 1 or status == 2
        end	
		return false;
	end,
	
	IsNaN = function(value)
		return value ~= value;
	end,
	
	Abs = function(value)
		return value * Math.Sign(value);
	end,

	Clamp = function(_n, _min, _max)
		if (_n > _max) then _n = _max; end
		if (_n < _min) then _n = _min; end
		return _n;
	end,
	
	Sqr = function(value)
		return value * value;
	end,
	
	-- Calculates a random value between 0 and 'value'.
	-- 'pm' should be between 0 and 1 and is used for shifting the 'mid-point' of the result.
	-- For example:
	--	- a pm of 0 means the result will always be positive;
	--	- a pm of 1 means the result will always be negative;
	--	- a pm of 0.5 means the result will be between -(value/2) and +(value/2)
	RandomPlusMinus = function(value, pm)
		return StarterGameUtility.randomF(0.0, value) - (value * pm);
	end,
	
	Lerp = function(a, b, i)
		return a + ((b - a) * i);
	end,

	DebugManagerGetBool = function(str, default)
		local result = default;
		local debugMan = TagGlobalRequestBus.Event.RequestTaggedEntities(Crc32("DebugManager"));
		if ((debugMan ~= nil) and (debugMan:IsValid())) then
			result = DebugManagerComponentRequestsBus.Event.GetDebugBool(debugMan, str);
		end
		return result;
	end,
}

return utilities;
