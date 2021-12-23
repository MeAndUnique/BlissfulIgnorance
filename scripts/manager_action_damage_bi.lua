-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local getReductionTypeOriginal;
local checkReductionTypeHelperOriginal;
local getDamageAdjustOriginal;

local sResistanceMessage;
local tReductions = {};

function onInit()
	getReductionTypeOriginal = ActionDamage.getReductionType;
	ActionDamage.getReductionType = getReductionType;
	
	checkReductionTypeHelperOriginal = ActionDamage.checkReductionTypeHelper;
	ActionDamage.checkReductionTypeHelper = checkReductionTypeHelper;
	
	getDamageAdjustOriginal = ActionDamage.getDamageAdjust;
	ActionDamage.getDamageAdjust = getDamageAdjust;
end

function getReductionType(rSource, rTarget, sEffectType)
	local aFinal = getReductionTypeOriginal(rSource, rTarget, sEffectType);

	local bIgnoreAll = false;
	local aEffects = EffectManager5E.getEffectsByType(rSource, "IGNORE" .. sEffectType, {}, rTarget);
	for _,rEffect in pairs(aEffects) do
		for _,sType in pairs(rEffect.remainder) do
			if sType == "all" then
				for _,sDamage in ipairs(DataCommon.dmgtypes) do
					addIgnoredDamageType(aFinal, sDamage, sEffectType);
				end
				bIgnoreAll = true;
				break;
			end
			addIgnoredDamageType(aFinal, sType, sEffectType);
		end
		if bIgnoreAll then
			break;
		end
	end
	
	if sEffectType == "IMMUNE" and aFinal["all"] then
		local rReduction = aFinal["all"];
		aFinal["all"] = nil;
		for _,sDamage in ipairs(DataCommon.dmgtypes) do
			aFinal[sDamage] = rReduction;
		end
	end

	if sEffectType == "RESIST" then -- Represents the last set
		bDemoteAll = false;
		aEffects = EffectManager5E.getEffectsByType(rSource, "DEMOTEIMMUNE", {}, rTarget);
		for _,rEffect in pairs(aEffects) do
			for _,sType in pairs(rEffect.remainder) do
				if sType == "all" then
					for _,sDamage in ipairs(DataCommon.dmgtypes) do
						addDemotedDamagedType(aFinal, tReductions["IMMUNE"], sDamage);
					end
					bDemoteAll = true;
					break;
				end
				addDemotedDamagedType(aFinal, tReductions["IMMUNE"], sType);
			end
			if bDemoteAll then
				break;
			end
		end
	end

	tReductions[sEffectType] = aFinal;
	return aFinal;
end

function addIgnoredDamageType(aEffects, sDamageType, sEffectType)
	local rReduction = aEffects[sDamageType];
	if rReduction then
		if not rReduction.aIgnored then
			rReduction.aIgnored = {};
		end
		table.insert(rReduction.aIgnored, sDamageType);
	end

	rReduction = aEffects["all"];
	if rReduction then
		if not rReduction.aIgnored then
			rReduction.aIgnored = {};
		end
		table.insert(rReduction.aIgnored, sDamageType);
	end
end

function addDemotedDamagedType(aResistEffects, aImmuneEffects, sDamageType)
	local rReduction = aImmuneEffects[sDamageType];
	if rReduction and not (rReduction.aIgnored and StringManager.contains(rReduction.aIgnored, sDamageType)) then
		aResistEffects[sDamageType] = UtilityManager.copyDeep(rReduction);

		if not rReduction.aDemoted then
			rReduction.aDemoted = {};
		end
		table.insert(rReduction.aDemoted, sDamageType);
	end

	rReduction = aImmuneEffects["all"];
	if rReduction then
		aResistEffects[sDamageType] = UtilityManager.copyDeep(rReduction);
	
		if not rReduction.aDemoted then
			rReduction.aDemoted = {};
		end
		table.insert(rReduction.aDemoted, sDamageType);
	end
end

function checkReductionTypeHelper(rMatch, aDmgType)
	local result = checkReductionTypeHelperOriginal(rMatch, aDmgType);
	if result then
		if rMatch.aIgnored then
			for _,sIgnored in pairs(rMatch.aIgnored) do
				if StringManager.contains(aDmgType, sIgnored) then
					sResistanceMessage ="[RESISTANCE IGNORED]";
					return false;
				end
			end
		end

		if rMatch.aDemoted then
			for _,sDemoted in pairs(rMatch.aDemoted) do
				if StringManager.contains(aDmgType, sDemoted) then
					sResistanceMessage ="[IMMUNITY DEMOTED]";
					return false;
				end
			end
		end
	end
	return result;
end

function checkNumericalReductionTypeHelper(rMatch, aDmgType, nLimit)
	local result = checkNumericalReductionTypeHelperOriginal(rMatch, aDmgType, nLimit);
	if (result ~= 0) and rMatch.aIgnored and #rMatch.aIgnored > 0 then
		for _,sIgnored in pairs(rMatch.aIgnored) do
			if StringManager.contains(aDmgType, sIgnored) then
				sResistanceMessage ="[RESISTANCE IGNORED]";
				return 0;
			end
		end
	end
	return result;
end

function getDamageAdjust(rSource, rTarget, nDamage, rDamageOutput)
	tReductions = {
		["VULN"] = {},
		["RESIST"] = {},
		["IMMUNE"] = {}
	};
	local nDamageAdjust, bVulnerable, bResist = getDamageAdjustOriginal(rSource, rTarget, rDamageOutput.nVal, rDamageOutput);

	if sResistanceMessage then
		table.insert(rDamageOutput.tNotifications, sResistanceMessage);
		sResistanceMessage = nil;
	end

	return nDamageAdjust, bVulnerable, bResist;
end