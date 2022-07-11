--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local resetHealthOriginal;
local setDBValueOriginal;

function onInit()
	resetHealthOriginal = CharManager.resetHealth;
	CharManager.resetHealth = resetHealth;
end

function resetHealth(nodeChar, bLong)
	if bLong then
		local rActor = ActorManager.resolveActor(nodeChar);
		if EffectManager5E.hasEffectCondition(rActor, "UNHEALABLE")
		or #(EffectManager5E.getEffectsByType(rActor, "UNHEALABLE", {"rest"})) > 0 then
			setDBValueOriginal = DB.setValue;
			DB.setValue = setDBValue;
		end
	end

	resetHealthOriginal(nodeChar, bLong);
end

function setDBValue(vFirst, vSecond, ...)
	if vSecond == "hp.wounds" then
		DB.setValue = setDBValueOriginal;
	else
		setDBValueOriginal(vFirst, vSecond, unpack(arg));
	end
end