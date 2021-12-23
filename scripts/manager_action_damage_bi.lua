-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local getReductionTypeOriginal;
local checkReductionTypeHelperOriginal;
local getDamageAdjustOriginal;
local messageDamageOriginal;

local aResistanceMessages;

function onInit()
	getReductionTypeOriginal = ActionDamage.getReductionType;
	ActionDamage.getReductionType = getReductionType;
	
	checkReductionTypeHelperOriginal = ActionDamage.checkReductionTypeHelper;
	ActionDamage.checkReductionTypeHelper = checkReductionTypeHelper;
	
	getDamageAdjustOriginal = ActionDamage.getDamageAdjust;
	ActionDamage.getDamageAdjust = getDamageAdjust;
	
	messageDamageOriginal = ActionDamage.messageDamage;
	ActionDamage.messageDamage = messageDamage;
end

function getReductionType(rSource, rTarget, sEffectType)
	local aFinal = getReductionTypeOriginal(rSource, rTarget, sEffectType);

	local aEffects = EffectManager5E.getEffectsByType(rSource, "IGNORE" .. sEffectType, {}, rTarget);
	for _,rEffect in pairs(aEffects) do
		for _,sType in pairs(rEffect.remainder) do
			local rReduction = aFinal[sType];
			if rReduction then
				if not rReduction.aIgnored then
					rReduction.aIgnored = {};
				end
				table.insert(rReduction.aIgnored, sType);
			end

			rReduction = aFinal["all"];
			if rReduction then
				if not rReduction.aIgnored then
					rReduction.aIgnored = {};
				end
				table.insert(rReduction.aIgnored, sType);
				if sEffectType == "IMMUNE" then
					aFinal["all"] = nil;
					for _,sDamage in ipairs(DataCommon.dmgtypes) do
						aFinal[sDamage] = rReduction;
					end
				end
			end
		end
	end

	return aFinal;
end

function checkReductionTypeHelper(rMatch, aDmgType)
	local result = checkReductionTypeHelperOriginal(rMatch, aDmgType);
	if result and rMatch.aIgnored and #rMatch.aIgnored > 0 then
		local bMatchIgnore = false;
		for _,sIgnored in pairs(rMatch.aIgnored) do
			if StringManager.contains(aDmgType, sIgnored) then
				table.insert(aResistanceMessages, "[RESISTANCE IGNORED]")
				return false;
			end
		end
	end
	return result;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
	local result = checkNumericalReductionTypeHelperOriginal(rMatch, aDmgType, nLimit);
	if (result ~= 0) and rMatch.aIgnored and #rMatch.aIgnored > 0 then
		local bMatchIgnore = false;
		for _,sIgnored in pairs(rMatch.aIgnored) do
			if StringManager.contains(aDmgType, sIgnored) then
				table.insert(aResistanceMessages, "[RESISTANCE IGNORED]")
				return 0;
			end
		end
	end
	return result;
end

function getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	aResistanceMessages = rDamageOutput.tNotifications;
	local nDamageAdjust, bVulnerable, bResist = getDamageAdjustOriginal(rSource, rTarget, rDamageOutput.nVal, rDamageOutput);

	return nDamageAdjust, bVulnerable, bResist;
end

function messageDamage(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult)
	--todo probably not needed
	--table.insert(aResistanceMessages, 1, sExtraResult);
	--sExtraResult = table.concat(aResistanceMessages, " ");
	messageDamageOriginal(rSource, rTarget, bSecret, sDamageType, sDamageDesc, sTotal, sExtraResult);
end