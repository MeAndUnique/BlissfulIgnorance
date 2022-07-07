--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local resetHealthOriginal;
local setDBValueOriginal;

function onInit()
	resetHealthOriginal = CombatManager2.resetHealth;
	CombatManager2.resetHealth = resetHealth;
end

function resetHealth(nodeCT, bLong)
	if bLong then
		local rActor = ActorManager.resolveActor(nodeCT);
		if EffectManager5E.hasEffectCondition(rActor, "UNHEALABLE")
		or #(EffectManager5E.getEffectsByType(rActor, "UNHEALABLE", {"rest"})) > 0 then
			setDBValueOriginal = DB.setValue;
			DB.setValue = setDBValue;
		end
	end

	resetHealthOriginal(nodeCT, bLong);
end

function setDBValue(vFirst, vSecond, ...)
	if vSecond == "wounds" then
		DB.setValue = setDBValueOriginal;
	else
		setDBValueOriginal(vFirst, vSecond, unpack(arg));
	end
end